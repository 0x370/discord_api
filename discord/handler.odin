package discord

import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:math/rand"
import "core:os"
import "core:strings"
import "core:strconv"
import "core:sync"
import "core:thread"
import "core:time"
import "vendor:curl"

import "api"

Gateway_Intent :: enum u8 {
	GUILDS                        = 0,
	GUILD_MEMBERS                 = 1,
	GUILD_MODERATION              = 2,
	GUILD_EXPRESSIONS             = 3,
	GUILD_INTEGRATIONS            = 4,
	GUILD_WEBHOOKS                = 5,
	GUILD_INVITES                 = 6,
	GUILD_VOICE_STATES            = 7,
	GUILD_PRESENCES               = 8,
	GUILD_MESSAGES                = 9,
	GUILD_MESSAGE_REACTIONS       = 10,
	GUILD_MESSAGE_TYPING          = 11,
	DIRECT_MESSAGES               = 12,
	DIRECT_MESSAGE_REACTIONS      = 13,
	DIRECT_MESSAGE_TYPING         = 14,
	MESSAGE_CONTENT               = 15,
	GUILD_SCHEDULED_EVENTS        = 16,
	AUTO_MODERATION_CONFIGURATION = 20,
	AUTO_MODERATION_EXECUTION     = 21,
	GUILD_MESSAGE_POLLS           = 24,
	DIRECT_MESSAGE_POLLS          = 25,
}
Gateway_Intents_Set :: bit_set[Gateway_Intent;i32]

opcodes :: enum int {
	OP_DISPATCH        = 0,
	OP_HEARTBEAT       = 1,
	OP_IDENTIFY        = 2,
	OP_RESUME          = 6,
	OP_RECONNECT       = 7,
	OP_INVALID_SESSION = 9,
	OP_HELLO           = 10,
	OP_HEARTBEAT_ACK   = 11,
}

MAX_CACHED_MESSAGES :: 10000
Event_Callback :: #type proc(data: rawptr)
Event_Listener :: struct {
	callback: Event_Callback,
}

Command_Handler :: #type proc(ctx: ^Command_Context)

Command_Registration :: struct {
	command: api.ApplicationCommand,
	handler: Command_Handler,
}

Command_Context :: struct {
	cluster:     ^Client,
	interaction: api.Interaction,
	data:        api.ApplicationCommandInteractionData,
	received_at: time.Time,
	started_at:  time.Time,
	parsed_at:   time.Time,
}

Client :: struct {
	curl_handle:        ^curl.CURL,
	worker_pool:        thread.Pool,
	outbound_mutex:     sync.Mutex,
	outbound_queue:     [dynamic][]byte,
	is_running:         bool,
	is_reconnecting:    bool,
	last_sequence:      Maybe(int),
	sequence_mutex:     sync.Mutex,
	received_ack:       bool,
	ack_mutex:          sync.Mutex,
	token:              string,
	session_id:         string,
	resume_url:         string,
	heartbeat_interval: int,
	allocator:          runtime.Allocator,
	_init_done:         bool,

	shard_id:   int,
	num_shards: int,

	cache_mutex:     sync.Mutex,
	event_mutex:     sync.Mutex,
	message_cache:    map[api.Snowflake]^api.Message,
	message_order:    [dynamic]api.Snowflake,
	message_evict_idx: int,
	event_handlers:  map[string][dynamic]Event_Listener,

	rest_client:      api.Discord_Client,
	application_id:   api.Snowflake,
	command_registry: map[string]Command_Registration,
	known_guilds:     map[api.Snowflake]int,
	identify_log:     [dynamic]time.Time,
	identify_mutex:   sync.Mutex,
	max_concurrency:  int,
	heartbeat_gen:    u64,

	total_members:        int,
	total_events:         u64,
	total_messages:       u64,
	total_commands:       u64,
	last_event_type:      string,
	heartbeat_send_time:  time.Time,
	heartbeat_send_mutex: sync.Mutex,
	latency_history:      [dynamic]time.Duration,
	start_time:           time.Time,
	prev_proc_ticks:      u64,
	prev_sys_ticks:       u64,
	last_display_update:  time.Time,
}

Heartbeat_Task_Data :: struct {
	cluster: ^Client,
	gen:     u64,
}

identify_check :: proc(cluster: ^Client) -> bool {
	sync.lock(&cluster.identify_mutex)
	defer sync.unlock(&cluster.identify_mutex)

	now := time.now()
	cutoff_24h := time.time_add(now, -24 * time.Hour)
	cutoff_5s := time.time_add(now, -5 * time.Second)

	write_idx := 0
	for i in 0 ..< len(cluster.identify_log) {
		if time.diff(cluster.identify_log[i], cutoff_24h) <= 0 {
			cluster.identify_log[write_idx] = cluster.identify_log[i]
			write_idx += 1
		}
	}
	resize(&cluster.identify_log, write_idx)

	if len(cluster.identify_log) >= 1000 {
		fmt.eprintln("IDENTIFY rate limit reached: 1000/24h")
		return false
	}

	if cluster.max_concurrency > 0 {
		recent := 0
		for ts in cluster.identify_log {
			if time.diff(ts, cutoff_5s) <= 0 {
				recent += 1
			}
		}
		if recent >= cluster.max_concurrency {
			fmt.eprintfln("IDENTIFY concurrency limit reached: %d in last 5s", recent)
			return false
		}
	}

	return true
}

on :: proc(cluster: ^Client, event_name: string, callback: Event_Callback) {
	sync.lock(&cluster.event_mutex)

	if _, ok := cluster.event_handlers[event_name]; !ok {
		cluster.event_handlers[event_name] = make([dynamic]Event_Listener, allocator = cluster.allocator)
	}

	append(&cluster.event_handlers[event_name], Event_Listener{callback = callback})
	sync.unlock(&cluster.event_mutex)
}

Ready_Application :: struct {
	id: api.Snowflake `json:"id"`,
}

Ready_Event_Data :: struct {
	session_id: string         `json:"session_id"`,
	resume_url: string         `json:"resume_url"`,
	application: Ready_Application `json:"application"`,
}

Resume_Payload :: struct {
	op: opcodes    `json:"op"`,
	d:  Resume_Data `json:"d"`,
}

Resume_Data :: struct {
	token:      string `json:"token"`,
	session_id: string `json:"session_id"`,
	seq:        int    `json:"seq"`,
}

GateWay_task_Data :: struct {
	cluster:     ^Client,
	raw_payload: []byte,
}

Gateway_Meta :: struct {
	op: opcodes   `json:"op"`,
	s:  Maybe(int) `json:"s"`,
	t:  string     `json:"t"`,
}

extract_json_value :: proc(data: []byte) -> ([]byte, bool) {
	if len(data) == 0 do return nil, false

	first := data[0]

	if first == '{' {
		depth := 1
		in_str := false
		for i := 1; i < len(data); i += 1 {
			if in_str {
				if data[i] == '\\' { i += 1; continue }
				if data[i] == '"' { in_str = false }
				continue
			}
			if data[i] == '"' { in_str = true; continue }
			if data[i] == '{' { depth += 1; continue }
			if data[i] == '}' {
				depth -= 1
				if depth == 0 do return data[:i+1], true
			}
		}
		return nil, false
	}

	if first == '[' {
		depth := 1
		in_str := false
		for i := 1; i < len(data); i += 1 {
			if in_str {
				if data[i] == '\\' { i += 1; continue }
				if data[i] == '"' { in_str = false }
				continue
			}
			if data[i] == '"' { in_str = true; continue }
			if data[i] == '[' { depth += 1; continue }
			if data[i] == ']' {
				depth -= 1
				if depth == 0 do return data[:i+1], true
			}
		}
		return nil, false
	}

	if first == '"' {
		for i := 1; i < len(data); i += 1 {
			if data[i] == '\\' { i += 1; continue }
			if data[i] == '"' do return data[:i+1], true
		}
		return nil, false
	}

	if first == '-' || (first >= '0' && first <= '9') {
		i := 1
		for i < len(data) {
			c := data[i]
			if c >= '0' && c <= '9' || c == '.' || c == '-' || c == '+' || c == 'e' || c == 'E' {
				i += 1
			} else {
				break
			}
		}
		return data[:i], true
	}

	if len(data) >= 4 {
		tag := string(data[:4])
		if tag == "true" || tag == "null" do return data[:4], true
	}
	if len(data) >= 5 && string(data[:5]) == "false" do return data[:5], true

	return nil, false
}

extract_d_bytes :: proc(data: []byte) -> ([]byte, bool) {
	depth := 0
	in_str := false
	i := 0

	for i < len(data) {
		c := data[i]

		if in_str {
			if c == '\\' { i += 2; continue }
			if c == '"' { in_str = false }
			i += 1
			continue
		}

		if c == '"' {
			if depth == 1 && i+2 < len(data) && data[i+1] == 'd' && data[i+2] == '"' {
				j := i + 3
				for j < len(data) && (data[j] == ' ' || data[j] == '\t') { j += 1 }
				if j < len(data) && data[j] == ':' {
					j += 1
					for j < len(data) && (data[j] == ' ' || data[j] == '\t') { j += 1 }
					return extract_json_value(data[j:])
				}
			}
			in_str = true
			i += 1
			continue
		}

		if c == '{' { depth += 1 }
		if c == '}' { depth -= 1 }
		i += 1
	}

	return nil, false
}

Hello_Data :: struct {
	heartbeat_interval: int `json:"heartbeat_interval"`,
}

Heartbeat_Payload :: struct {
	op: opcodes   `json:"op"`,
	d:  Maybe(int) `json:"d"`,
}

Identify_Payload :: struct {
	op: opcodes       `json:"op"`,
	d:  Identify_Data `json:"d"`,
}

Identify_Data :: struct {
	token:      string              `json:"token"`,
	intents:    Gateway_Intents_Set `json:"intents"`,
	properties: Identify_Properties `json:"properties"`,
	shard:      [2]int              `json:"shard"`,
}

Identify_Properties :: struct {
	os:      string `json:"os"`,
	browser: string `json:"browser"`,
	device:  string `json:"device"`,
}

queue_outbound_payload :: proc(cluster: ^Client, data: $T) {
	json_bytes, err := json.marshal(data, allocator = context.temp_allocator)
	if err != nil do return

	persistent_copy := make([]byte, len(json_bytes))
	copy(persistent_copy, json_bytes)

	sync.lock(&cluster.outbound_mutex)
	append(&cluster.outbound_queue, persistent_copy)
	sync.unlock(&cluster.outbound_mutex)
}

heartbeat_pool_task :: proc(task: thread.Task) {
	data := (^Heartbeat_Task_Data)(task.data)
	cluster := data.cluster
	gen := data.gen

	if !cluster.is_running || cluster.heartbeat_gen != gen {
		free(data)
		return
	}

	sync.lock(&cluster.ack_mutex)
	if !cluster.received_ack {
		fmt.println("Missed heartbeat ack! reconnecting...")
		cluster.is_running = false
		cluster.is_reconnecting = true
		sync.unlock(&cluster.ack_mutex)
		free(data)
		return
	}
	cluster.received_ack = false
	sync.unlock(&cluster.ack_mutex)

	sync.lock(&cluster.sequence_mutex)
	current_seq := cluster.last_sequence
	sync.unlock(&cluster.sequence_mutex)

	sync.lock(&cluster.heartbeat_send_mutex)
	cluster.heartbeat_send_time = time.now()
	sync.unlock(&cluster.heartbeat_send_mutex)

	ping := Heartbeat_Payload {
		op = .OP_HEARTBEAT,
		d  = current_seq,
	}

	queue_outbound_payload(cluster, ping)

	interval_ms := cluster.heartbeat_interval > 0 ? cluster.heartbeat_interval : 45000
	time.sleep(time.Duration(interval_ms) * time.Millisecond)

	if !cluster.is_running || cluster.heartbeat_gen != gen {
		free(data)
		return
	}

	thread.pool_add_task(&cluster.worker_pool, context.allocator, heartbeat_pool_task, data)
}

process_gateway_task :: proc(task: thread.Task) {
	task_context := (^GateWay_task_Data)(task.data)
	cluster := task_context.cluster

	defer delete(task_context.raw_payload)
	defer free(task_context)

	envelope := Gateway_Meta{}
	alloc := context.temp_allocator
	if json.unmarshal(task_context.raw_payload, &envelope, allocator = alloc) != nil do return
	defer delete(envelope.t, alloc)

	if seq, has_seq := envelope.s.?; has_seq {
		sync.lock(&cluster.sequence_mutex)
		cluster.last_sequence = seq
		sync.unlock(&cluster.sequence_mutex)
	}

	d_bytes, d_ok := extract_d_bytes(task_context.raw_payload)

	switch envelope.op {
	case .OP_HELLO:
		if !d_ok do return
		var_data := Hello_Data{}
		if json.unmarshal(d_bytes, &var_data) == nil {
			fmt.printfln("Got hello. Heartbeat request every: %d ms", var_data.heartbeat_interval)

			cluster.heartbeat_interval = var_data.heartbeat_interval
			cluster.heartbeat_gen += 1
			gen := cluster.heartbeat_gen

			sync.lock(&cluster.ack_mutex)
			cluster.received_ack = true
			sync.unlock(&cluster.ack_mutex)

			init_data := new(Heartbeat_Task_Data)
			init_data.cluster = cluster
			init_data.gen = gen
			thread.pool_add_task(
				&cluster.worker_pool,
				context.allocator,
				proc(task: thread.Task) {
					data := (^Heartbeat_Task_Data)(task.data)
					cluster := data.cluster
					gen := data.gen

					interval_ms := cluster.heartbeat_interval > 0 ? cluster.heartbeat_interval : 45000
					jitter := int(f64(interval_ms) * rand.float64())
					time.sleep(time.Duration(jitter) * time.Millisecond)

					if !cluster.is_running || cluster.heartbeat_gen != gen {
						free(data)
						return
					}

					thread.pool_add_task(&cluster.worker_pool, context.allocator, heartbeat_pool_task, data)
				},
				init_data,
			)

			if cluster.session_id != "" {
				sync.lock(&cluster.sequence_mutex)
				current_seq := cluster.last_sequence.? or_else 0
				sync.unlock(&cluster.sequence_mutex)

				resume := Resume_Payload {
					op = .OP_RESUME,
					d = Resume_Data {
						token = cluster.token,
						session_id = cluster.session_id,
						seq = current_seq,
					},
				}
				queue_outbound_payload(cluster, resume)
				fmt.println("Sent resume handshake request")
			} else {
				if !identify_check(cluster) {
					fmt.eprintln("Identify rate limited, will retry on reconnect")
					cluster.is_running = false
					cluster.is_reconnecting = true
					return
				}

				handshake := Identify_Payload {
					op = .OP_IDENTIFY,
					d = Identify_Data {
						token = cluster.token,
						intents = {.GUILDS, .GUILD_MESSAGES, .MESSAGE_CONTENT, .DIRECT_MESSAGES},
						properties = Identify_Properties {
							os = "linux",
							browser = "odin-client",
							device = "odin-client",
						},
						shard = {cluster.shard_id, cluster.num_shards},
					},
				}

				sync.lock(&cluster.identify_mutex)
				append(&cluster.identify_log, time.now())
				sync.unlock(&cluster.identify_mutex)

				queue_outbound_payload(cluster, handshake)
				fmt.println("Sent identify handshake")
			}
		}
	case .OP_DISPATCH:
		if !d_ok do return
		cluster.total_events += 1
		if cluster.last_event_type != "" do delete(cluster.last_event_type, cluster.allocator)
		cluster.last_event_type = strings.clone(envelope.t, cluster.allocator)
		fmt.printfln("[Event received] type: %s", envelope.t)

		switch envelope.t {
		case "READY":
			handle_ready(cluster, d_bytes)
		case "MESSAGE_CREATE":
			handle_message_create(cluster, d_bytes)
		case "GUILD_CREATE":
			handle_guild_create(cluster, d_bytes)
		case "GUILD_DELETE":
			handle_guild_delete(cluster, d_bytes)
		case "MESSAGE_UPDATE":
			handle_message_update(cluster, d_bytes)
		case "MESSAGE_DELETE":
			handle_message_delete(cluster, d_bytes)
		case "INTERACTION_CREATE":
			handle_interaction_create(cluster, d_bytes)
		case:
			break
		}
	case .OP_HEARTBEAT:
		sync.lock(&cluster.sequence_mutex)
		current_seq := cluster.last_sequence
		sync.unlock(&cluster.sequence_mutex)

		forced_ping := Heartbeat_Payload {
			op = .OP_HEARTBEAT,
			d  = current_seq,
		}
		queue_outbound_payload(cluster, forced_ping)
		fmt.println("Forced Heartbeat sent on explicit Discord request.")
	case .OP_RECONNECT:
		fmt.println("Discord requested a reconnect. Tearing down socket loop...")
		cluster.is_running = false
		cluster.is_reconnecting = true
	case .OP_INVALID_SESSION:
		can_resume := false
		if d_ok {
			json.unmarshal(d_bytes, &can_resume)
		}
		fmt.printfln("Invalid Session received. Can resume?: %v", can_resume)
		if !can_resume {
			if cluster.session_id != "" do delete(cluster.session_id)
			if cluster.resume_url != "" do delete(cluster.resume_url)
			cluster.session_id = ""
			cluster.resume_url = ""
		}
		cluster.is_running = false
		cluster.is_reconnecting = true
	case .OP_HEARTBEAT_ACK:
		sync.lock(&cluster.ack_mutex)
		cluster.received_ack = true
		sync.unlock(&cluster.ack_mutex)

		sync.lock(&cluster.heartbeat_send_mutex)
		rtt := time.since(cluster.heartbeat_send_time)
		sync.unlock(&cluster.heartbeat_send_mutex)

		if len(cluster.latency_history) >= 100 {
			pop_front(&cluster.latency_history)
		}
		append(&cluster.latency_history, rtt)
	case .OP_IDENTIFY, .OP_RESUME:
		break
	}
}

run_network_pump :: proc(cluster: ^Client) {
	read_buffer := make([]byte, 65536)
	defer delete(read_buffer)

	frame_buffer: [dynamic]byte
	reserve(&frame_buffer, 4096)
	defer delete(frame_buffer)

	for cluster.is_running {
		had_work := false

		sync.lock(&cluster.outbound_mutex)
		for len(cluster.outbound_queue) > 0 {
			out_frame := pop_front(&cluster.outbound_queue)
			sync.unlock(&cluster.outbound_mutex)

			had_work = true
			bytes_written: uint = 0
			curl.ws_send(cluster.curl_handle, raw_data(out_frame), len(out_frame), &bytes_written, 0, {.TEXT})
			delete(out_frame)
			sync.lock(&cluster.outbound_mutex)
		}
		sync.unlock(&cluster.outbound_mutex)

		bytes_received: uint = 0
		meta: ^curl.ws_frame
		err := curl.ws_recv(cluster.curl_handle, rawptr(&read_buffer[0]), len(read_buffer), &bytes_received, &meta)
		if err == .E_OK && bytes_received > 0 {
			had_work = true
			append(&frame_buffer, ..read_buffer[:bytes_received])

			if .CLOSE in meta.flags {
				fmt.eprintln("WebSocket CLOSE frame received")
				cluster.is_running = false
				break
			}

			if meta.bytesleft == 0 {
				copy_payload := make([]byte, len(frame_buffer))
				copy(copy_payload, frame_buffer[:])
				clear(&frame_buffer)

				task_context := new(GateWay_task_Data)
				task_context.cluster = cluster
				task_context.raw_payload = copy_payload
				process_gateway_task(thread.Task{data = task_context})
			}
		}

		render_interval := time.Second
		if time.since(cluster.last_display_update) >= render_interval {
			cluster.last_display_update = time.now()
			render_dashboard(cluster)
		}

		if !had_work {
			time.sleep(5 * time.Millisecond)
		}
	}
}

Config :: struct {
	token:      string,
	shard_id:   int,
	num_shards: int,
}

connect_gateway :: proc(client: ^Client) -> bool {
	if client.curl_handle != nil {
		curl.easy_cleanup(client.curl_handle)
		client.curl_handle = nil
	}

	client.curl_handle = curl.easy_init()
	if client.curl_handle == nil do return false

	base_url := "wss://gateway.discord.gg/"
	if client.resume_url != "" {
		base_url = client.resume_url
	}
	url := fmt.tprintf("%s?v=%s&encoding=json", base_url, api.API_VERSION)
	url_cstr := strings.clone_to_cstring(url, context.temp_allocator)
	curl.easy_setopt(client.curl_handle, .URL, url_cstr)
	curl.easy_setopt(client.curl_handle, .CONNECT_ONLY, i32(2))

	res := curl.easy_perform(client.curl_handle)
	if res != .E_OK {
		fmt.eprintfln("Handshake failed: %s", curl.easy_strerror(res))
		curl.easy_cleanup(client.curl_handle)
		client.curl_handle = nil
		return false
	}

	client.is_running = true
	client.received_ack = true
	return true
}

client_init :: proc(client: ^Client, config: Config) -> bool {
	client.allocator = context.allocator
	client.token = strings.clone(config.token, client.allocator)
	client.shard_id = config.shard_id
	client.num_shards = config.num_shards

	client.message_cache = make(map[api.Snowflake]^api.Message, allocator = context.allocator)
	client.message_order = make([dynamic]api.Snowflake, allocator = context.allocator)
	client.event_handlers = make(map[string][dynamic]Event_Listener, allocator = client.allocator)
	client.command_registry = make(map[string]Command_Registration, allocator = client.allocator)
	client.known_guilds = make(map[api.Snowflake]int, allocator = client.allocator)
	client.identify_log = make([dynamic]time.Time, allocator = client.allocator)
	client.latency_history = make([dynamic]time.Duration, allocator = context.allocator)

	utime, stime := _read_process_cpu_ticks()
	client.prev_proc_ticks = utime + stime
	client.prev_sys_ticks = _read_system_cpu_ticks()
	client.start_time = time.now()

	thread_count := max(2, os.processor_core_count())
	thread.pool_init(&client.worker_pool, context.allocator, thread_count = thread_count)
	thread.pool_start(&client.worker_pool)

	if !connect_gateway(client) {
		return false
	}

	if api.discord_client_init(&client.rest_client, config.token) {
		bot_info, fetch_ok := api.discord_request(api.Gateway_Bot_Response, &client.rest_client, "/gateway/bot")
		if fetch_ok {
			client.max_concurrency = bot_info.session_start_limit.max_concurrency
			if client.num_shards == 0 {
				client.num_shards = bot_info.shards
			}
			fmt.printfln("Gateway bot info: %d shards, %d max concurrency", bot_info.shards, bot_info.session_start_limit.max_concurrency)
			delete(bot_info.url)
		} else {
			fmt.eprintln("Failed to fetch /gateway/bot, defaulting max_concurrency to 1")
			client.max_concurrency = 1
		}
	} else {
		fmt.eprintln("Failed to init REST client, defaulting max_concurrency to 1")
		client.max_concurrency = 1
	}

	client._init_done = true
	return true
}

client_destroy :: proc(client: ^Client) {
	if !client._init_done {
		if client.curl_handle != nil do curl.easy_cleanup(client.curl_handle)
		api.discord_client_destroy(&client.rest_client)
		return
	}

	client.is_running = false
	thread.pool_join(&client.worker_pool)
	thread.pool_destroy(&client.worker_pool)

	sync.lock(&client.outbound_mutex)
	for len(client.outbound_queue) > 0 {
		frame := pop_front(&client.outbound_queue)
		delete(frame)
	}
	delete(client.outbound_queue)
	sync.unlock(&client.outbound_mutex)

	if client.session_id != "" do delete(client.session_id)
	if client.resume_url != "" do delete(client.resume_url)
	if client.application_id != "" do delete(client.application_id)

	delete(client.command_registry)
	delete(client.known_guilds)

	sync.lock(&client.cache_mutex)
	for _, msg in client.message_cache {
		deep_free(msg^, client.allocator)
		free(msg)
	}
	delete(client.message_cache)
	delete(client.message_order)
	sync.unlock(&client.cache_mutex)

	for _, handlers in client.event_handlers {
		delete(handlers)
	}
	delete(client.event_handlers)

	if client.curl_handle != nil do curl.easy_cleanup(client.curl_handle)
	api.discord_client_destroy(&client.rest_client)
	delete(client.identify_log)
	delete(client.latency_history)
	delete(client.token)

	client._init_done = false
	fmt.println("Client destroyed")
}

client_run :: proc(client: ^Client) {
	backoff := time.Second
	max_backoff := 60 * time.Second

	for {
		run_network_pump(client)

		if !client.is_reconnecting {
			break
		}

		client.is_reconnecting = false
		fmt.printfln("Disconnected. Reconnecting in %v...", backoff)
		time.sleep(backoff)

		sync.lock(&client.outbound_mutex)
		for len(client.outbound_queue) > 0 {
			delete(pop_front(&client.outbound_queue))
		}
		sync.unlock(&client.outbound_mutex)

		if connect_gateway(client) {
			backoff = time.Second
		} else {
			fmt.eprintln("Gateway reconnection failed, will retry")
			if backoff < max_backoff {
				backoff *= 2
			}
		}
	}
}

Callback_Task :: struct {
	callback:  Event_Callback,
	payload:   rawptr,
	cleanup:   proc(rawptr, runtime.Allocator),
	allocator: runtime.Allocator,
}

callback_worker :: proc(task: thread.Task) {
	ctx := (^Callback_Task)(task.data)
	defer {
		ctx.cleanup(ctx.payload, ctx.allocator)
		free(ctx)
	}
	ctx.callback(ctx.payload)
}

dispatch_event :: proc(cluster: ^Client, event_name: string, payload: $T) {
	sync.lock(&cluster.event_mutex)

	listeners, exists := cluster.event_handlers[event_name]
	if !exists {
		sync.unlock(&cluster.event_mutex)
		return
	}

	local_listeners := make([]Event_Listener, len(listeners), context.temp_allocator)
	runtime.copy_slice(local_listeners, listeners[:])
	sync.unlock(&cluster.event_mutex)

	for listener in local_listeners {
		copy_payload := new(T, allocator = cluster.allocator)
		copy_payload^ = deep_clone(payload, cluster.allocator)

		task := new(Callback_Task)
		task.callback = listener.callback
		task.payload = copy_payload
		task.allocator = cluster.allocator
		task.cleanup = proc(p: rawptr, allocator: runtime.Allocator) {
			obj := (^T)(p)
			deep_free(obj^, allocator)
			free(obj)
		}

		thread.pool_add_task(&cluster.worker_pool, context.allocator, callback_worker, task)
	}
}

handle_message_create :: proc(cluster: ^Client, d_bytes: []byte) {
	cluster.total_messages += 1
	msg: api.Message = {}
	if json.unmarshal(d_bytes, &msg) != nil {
		fmt.eprintln("Failed to parse MESSAGE_CREATE")
		return
	}

	persistent := new(api.Message, allocator = cluster.allocator)
	persistent^ = deep_clone(msg, cluster.allocator)

	sync.lock(&cluster.cache_mutex)
	cluster.message_cache[persistent.id] = persistent

	if len(cluster.message_order) < MAX_CACHED_MESSAGES {
		append(&cluster.message_order, persistent.id)
		cluster.message_evict_idx = 0
	} else {
		oldest_id := cluster.message_order[cluster.message_evict_idx]
		cluster.message_order[cluster.message_evict_idx] = persistent.id
		cluster.message_evict_idx = (cluster.message_evict_idx + 1) % MAX_CACHED_MESSAGES

		if old_msg, ok := cluster.message_cache[oldest_id]; ok {
			delete_key(&cluster.message_cache, oldest_id)
			deep_free(old_msg^, cluster.allocator)
			free(old_msg)
		}
	}
	sync.unlock(&cluster.cache_mutex)

	dispatch_event(cluster, "MESSAGE_CREATE", msg)
}

handle_guild_create :: proc(cluster: ^Client, d_bytes: []byte) {
	guild: api.Guild = {}
	if json.unmarshal(d_bytes, &guild) != nil {
		fmt.eprintln("Failed to parse GUILD_CREATE")
		return
	}

	if guild.id != "" {
		sync.lock(&cluster.cache_mutex)
		count := guild.member_count
		if count == 0 {
			count = guild.approximate_member_count
		}

		if _, already_known := cluster.known_guilds[guild.id]; !already_known {
			cluster.known_guilds[guild.id] = count
			cluster.total_members += count
			register_guild_commands(cluster, guild.id)
		} else {
			// Update count if it changed
			old_count := cluster.known_guilds[guild.id]
			cluster.total_members -= old_count
			cluster.known_guilds[guild.id] = count
			cluster.total_members += count
		}
		sync.unlock(&cluster.cache_mutex)
	}

	dispatch_event(cluster, "GUILD_CREATE", guild)
}

handle_guild_delete :: proc(cluster: ^Client, d_bytes: []byte) {
	guild: api.Guild = {} // Only id and unavailable are strictly required
	if json.unmarshal(d_bytes, &guild) != nil {
		fmt.eprintln("Failed to parse GUILD_DELETE")
		return
	}

	if guild.id != "" {
		sync.lock(&cluster.cache_mutex)
		if count, known := cluster.known_guilds[guild.id]; known {
			cluster.total_members -= count
			delete_key(&cluster.known_guilds, guild.id)
		}
		sync.unlock(&cluster.cache_mutex)
	}

	dispatch_event(cluster, "GUILD_DELETE", guild)
}

handle_ready :: proc(cluster: ^Client, d_bytes: []byte) {
	ready: Ready_Event_Data = {}
	if json.unmarshal(d_bytes, &ready) != nil {
		fmt.eprintln("Failed to parse READY")
		return
	}
	defer deep_free(ready, context.allocator)

	if cluster.session_id != "" do delete(cluster.session_id, cluster.allocator)
	if cluster.resume_url != "" do delete(cluster.resume_url, cluster.allocator)

	cluster.session_id = strings.clone(ready.session_id, cluster.allocator)
	cluster.resume_url = strings.clone(ready.resume_url, cluster.allocator)
	cluster.application_id = strings.clone(ready.application.id, cluster.allocator)
	
	sync.lock(&cluster.cache_mutex)
	clear(&cluster.known_guilds)
	cluster.total_members = 0
	sync.unlock(&cluster.cache_mutex)

	fmt.printfln("Bot is ready! Session: %s | App: %s", cluster.session_id, cluster.application_id)
}

handle_message_update :: proc(cluster: ^Client, d_bytes: []byte) {
	update: api.Message = {}
	if json.unmarshal(d_bytes, &update) != nil {
		fmt.eprintln("Failed to parse MESSAGE_UPDATE")
		return
	}

	sync.lock(&cluster.cache_mutex)
	cached, exists := cluster.message_cache[update.id]
	if !exists {
		sync.unlock(&cluster.cache_mutex)
		fmt.println("Message update received uncached message")
		return
	}

	after := deep_clone(cached^, cluster.allocator)
	before := deep_clone(cached^, context.temp_allocator)
	sync.unlock(&cluster.cache_mutex)

	after.content = update.content
	after.edited_timestamp = update.edited_timestamp
	after.embeds = deep_clone(update.embeds, context.temp_allocator)
	after.attachments = deep_clone(update.attachments, context.temp_allocator)
	after.pinned = update.pinned
	after.flags = update.flags
	after.mention_everyone = update.mention_everyone
	after.tts = update.tts

	dispatch_event(cluster, "MESSAGE_UPDATE", api.MessageUpdateArgs{before = before, after = after})

	sync.lock(&cluster.cache_mutex)
	deep_free(cached^, cluster.allocator)
	cached^ = after
	sync.unlock(&cluster.cache_mutex)
}

handle_message_delete :: proc(cluster: ^Client, d_bytes: []byte) {
	event: api.MessageDeleteEvent = {}
	if json.unmarshal(d_bytes, &event) != nil {
		return
	}

	sync.lock(&cluster.cache_mutex)
	if cached, ok := cluster.message_cache[event.id]; ok {
		deep_free(cached^, cluster.allocator)
		free(cached)
		delete_key(&cluster.message_cache, event.id)
	}
	sync.unlock(&cluster.cache_mutex)
}

on_command :: proc(cluster: ^Client, name: string, description: string, handler: Command_Handler, options: ..api.ApplicationCommandOption) {
	reg := Command_Registration {
		command = api.ApplicationCommand {
			name = name,
			description = description,
			type = .CHAT_INPUT,
			options = options,
		},
		handler = handler,
	}
	cluster.command_registry[name] = reg
}

register_commands :: proc(cluster: ^Client) {
	if cluster.application_id == "" {
		fmt.eprintln("Cannot register commands: no application_id")
		return
	}

	for name, reg in cluster.command_registry {
		body, err := json.marshal(reg.command, allocator = context.temp_allocator)
		if err != nil {
			fmt.eprintfln("Failed to marshal command %q: %v", name, err)
			continue
		}

		endpoint := fmt.tprintf("/applications/%s/commands", cluster.application_id)
		resp, ok := api.discord_post(&cluster.rest_client, endpoint, body)
		if ok {
			if resp.status_code >= 200 && resp.status_code < 300 {
				fmt.printfln("Registered command /%s globally (status %d)", name, resp.status_code)
			} else {
				fmt.eprintfln("Failed to register command /%s: HTTP %d: %s", name, resp.status_code, string(resp.body))
			}
			delete(resp.body)
		} else {
			fmt.eprintfln("Failed to register command /%s: network error", name)
		}
	}
}

register_guild_commands :: proc(cluster: ^Client, guild_id: api.Snowflake) {
	if cluster.application_id == "" {
		fmt.eprintln("Cannot register commands: no application_id")
		return
	}

	for name, reg in cluster.command_registry {
		body, err := json.marshal(reg.command, allocator = context.temp_allocator)
		if err != nil {
			fmt.eprintfln("Failed to marshal command %q: %v", name, err)
			continue
		}

		endpoint := fmt.tprintf("/applications/%s/guilds/%s/commands", cluster.application_id, guild_id)
		resp, ok := api.discord_post(&cluster.rest_client, endpoint, body)
		if ok {
			if resp.status_code >= 200 && resp.status_code < 300 {
				fmt.printfln("Registered command /%s in guild %s (status %d)", name, guild_id, resp.status_code)
			} else {
				fmt.eprintfln("Failed to register command /%s in guild %s: HTTP %d: %s", name, guild_id, resp.status_code, string(resp.body))
			}
			delete(resp.body)
		} else {
			fmt.eprintfln("Failed to register command /%s in guild %s: network error", name, guild_id)
		}
	}
}

Interaction_Task :: struct {
	handler:       Command_Handler,
	cluster:       ^Client,
	raw:           []byte,
	received_at:   time.Time,
}

interaction_worker :: proc(task: thread.Task) {
	it := (^Interaction_Task)(task.data)
	defer {
		delete(it.raw)
		free(it)
	}

	started_at := time.now()

	interaction: api.Interaction = {}
	err := json.unmarshal(it.raw, &interaction)
	if err != nil {
		fmt.eprintfln("Worker re-parse failed: %v", err)
		return
	}

	parsed_at := time.now()

	cmd_data, ok := interaction.data.(api.ApplicationCommandInteractionData)
	if !ok {
		fmt.eprintln("Interaction worker: data type assertion failed")
		deep_free(interaction, context.allocator)
		return
	}

	ctx := new(Command_Context, allocator = it.cluster.allocator)
	ctx.cluster = it.cluster
	ctx.interaction = interaction
	ctx.data = cmd_data
	ctx.received_at = it.received_at
	ctx.started_at = started_at
	ctx.parsed_at = parsed_at

	it.handler(ctx)

	deep_free(ctx.interaction, context.allocator)
	free(ctx)
}

handle_interaction_create :: proc(cluster: ^Client, d_bytes: []byte) {
	cluster.total_commands += 1
	interaction: api.Interaction = {}
	if json.unmarshal(d_bytes, &interaction) != nil {
		fmt.eprintln("Failed to parse INTERACTION_CREATE")
		return
	}

	cmd_data, ok := interaction.data.(api.ApplicationCommandInteractionData)
	if !ok {
		return
	}

	reg, found := cluster.command_registry[cmd_data.name]
	if !found {
		fmt.printfln("Unknown command: %s", cmd_data.name)
		return
	}

	task_data := new(Interaction_Task, allocator = cluster.allocator)
	task_data.handler = reg.handler
	task_data.cluster = cluster
	task_data.raw = make([]byte, len(d_bytes), allocator = cluster.allocator)
	copy(task_data.raw, d_bytes)
	task_data.received_at = time.now()

	thread.pool_add_task(&cluster.worker_pool, context.allocator, interaction_worker, task_data)
}

get_string :: proc(ctx: ^Command_Context, name: string) -> string {
	for opt in ctx.data.options {
		if opt.name == name {
			if v, ok := opt.value.(string); ok {
				return v
			}
		}
	}
	return ""
}

get_integer :: proc(ctx: ^Command_Context, name: string) -> i64 {
	for opt in ctx.data.options {
		if opt.name == name {
			if v, ok := opt.value.(i64); ok {
				return v
			}
		}
	}
	return 0
}

get_number :: proc(ctx: ^Command_Context, name: string) -> f64 {
	for opt in ctx.data.options {
		if opt.name == name {
			if v, ok := opt.value.(f64); ok {
				return v
			}
		}
	}
	return 0
}

get_bool :: proc(ctx: ^Command_Context, name: string) -> bool {
	for opt in ctx.data.options {
		if opt.name == name {
			if v, ok := opt.value.(bool); ok {
				return v
			}
		}
	}
	return false
}

respond :: proc(ctx: ^Command_Context, message: string) -> bool {
	response := api.InteractionResponse {
		type = .CHANNEL_MESSAGE_WITH_SOURCE,
		data = api.InteractionCallbackData {
			content = message,
		},
	}

	body, err := json.marshal(response, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal response: %v", err)
		return false
	}

	endpoint := fmt.tprintf("/interactions/%s/%s/callback", ctx.interaction.id, ctx.interaction.token)
	resp, ok := api.discord_post(&ctx.cluster.rest_client, endpoint, body)
	if !ok do return false
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("respond got HTTP %d: %s", resp.status_code, string(resp.body))
		delete(resp.body)
		return false
	}
	delete(resp.body)
	return true
}

respond_with_embed :: proc(ctx: ^Command_Context, content: string, embeds: []api.Embed) -> bool {
	response := api.InteractionResponse {
		type = .CHANNEL_MESSAGE_WITH_SOURCE,
		data = api.InteractionCallbackData {
			content = content,
			embeds = embeds,
		},
	}

	body, err := json.marshal(response, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal response: %v", err)
		return false
	}

	endpoint := fmt.tprintf("/interactions/%s/%s/callback", ctx.interaction.id, ctx.interaction.token)
	resp, ok := api.discord_post(&ctx.cluster.rest_client, endpoint, body)
	if !ok do return false
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("respond_with_embed got HTTP %d: %s", resp.status_code, string(resp.body))
		delete(resp.body)
		return false
	}
	delete(resp.body)
	return true
}

defer_response :: proc(ctx: ^Command_Context, ephemeral: bool) -> (bool, i64) {
	data: api.InteractionCallbackData = {}
	if ephemeral {
		flags := 1 << 6
		data.flags = flags
	}

	response := api.InteractionResponse {
		type = .DEFERRED_CHANNEL_MESSAGE_WITH_SOURCE,
		data = data,
	}

	body, err := json.marshal(response, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal response: %v", err)
		return false, 0
	}

	endpoint := fmt.tprintf("/interactions/%s/%s/callback", ctx.interaction.id, ctx.interaction.token)
	resp, ok := api.discord_post(&ctx.cluster.rest_client, endpoint, body)
	if !ok do return false, 0
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("defer_response got HTTP %d: %s", resp.status_code, string(resp.body))
		delete(resp.body)
		return false, 0
	}
	net_ns := resp.perform_time_ns
	delete(resp.body)
	return true, net_ns
}

// Bulk overwrite all global commands (PUT /applications/<id>/commands)
bulk_overwrite_commands :: proc(cluster: ^Client) -> bool {
	if cluster.application_id == "" {
		fmt.eprintln("Cannot bulk overwrite commands: no application_id")
		return false
	}

	commands := make([dynamic]api.ApplicationCommand, context.temp_allocator)
	for _, reg in cluster.command_registry {
		append(&commands, reg.command)
	}

	body, err := json.marshal(commands[:], allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal commands for bulk overwrite: %v", err)
		return false
	}

	endpoint := fmt.tprintf("/applications/%s/commands", cluster.application_id)
	resp, ok := api.discord_put(&cluster.rest_client, endpoint, body)
	if ok {
		if resp.status_code >= 200 && resp.status_code < 300 {
			fmt.printfln("Bulk overwrote %d global commands (status %d)", len(commands), resp.status_code)
		} else {
			fmt.eprintfln("Failed to bulk overwrite commands: HTTP %d: %s", resp.status_code, string(resp.body))
		}
		delete(resp.body)
		return resp.status_code >= 200 && resp.status_code < 300
	}
	fmt.eprintln("Failed to bulk overwrite commands: network error")
	return false
}

bulk_overwrite_guild_commands :: proc(cluster: ^Client, guild_id: api.Snowflake) -> bool {
	if cluster.application_id == "" {
		fmt.eprintln("Cannot bulk overwrite commands: no application_id")
		return false
	}

	commands := make([dynamic]api.ApplicationCommand, context.temp_allocator)
	for _, reg in cluster.command_registry {
		append(&commands, reg.command)
	}

	body, err := json.marshal(commands[:], allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal commands for bulk overwrite: %v", err)
		return false
	}

	endpoint := fmt.tprintf("/applications/%s/guilds/%s/commands", cluster.application_id, guild_id)
	resp, ok := api.discord_put(&cluster.rest_client, endpoint, body)
	if ok {
		if resp.status_code >= 200 && resp.status_code < 300 {
			fmt.printfln("Bulk overwrote %d guild commands in %s (status %d)", len(commands), guild_id, resp.status_code)
		} else {
			fmt.eprintfln("Failed to bulk overwrite guild commands: HTTP %d: %s", resp.status_code, string(resp.body))
		}
		delete(resp.body)
		return resp.status_code >= 200 && resp.status_code < 300
	}
	fmt.eprintln("Failed to bulk overwrite guild commands: network error")
	return false
}

// Delete a global command (DELETE /applications/<id>/commands/<command_id>)
delete_global_command :: proc(cluster: ^Client, command_id: api.Snowflake) -> bool {
	if cluster.application_id == "" {
		fmt.eprintln("Cannot delete command: no application_id")
		return false
	}

	endpoint := fmt.tprintf("/applications/%s/commands/%s", cluster.application_id, command_id)
	resp, ok := api.discord_delete(&cluster.rest_client, endpoint)
	if ok {
		if resp.status_code >= 200 && resp.status_code < 300 {
			fmt.printfln("Deleted global command %s (status %d)", command_id, resp.status_code)
		} else {
			fmt.eprintfln("Failed to delete command %s: HTTP %d: %s", command_id, resp.status_code, string(resp.body))
		}
		delete(resp.body)
		return resp.status_code >= 200 && resp.status_code < 300
	}
	fmt.eprintln("Failed to delete command: network error")
	return false
}

// Delete a guild command (DELETE /applications/<id>/guilds/<guild_id>/commands/<command_id>)
delete_guild_command :: proc(cluster: ^Client, guild_id: api.Snowflake, command_id: api.Snowflake) -> bool {
	if cluster.application_id == "" {
		fmt.eprintln("Cannot delete command: no application_id")
		return false
	}

	endpoint := fmt.tprintf("/applications/%s/guilds/%s/commands/%s", cluster.application_id, guild_id, command_id)
	resp, ok := api.discord_delete(&cluster.rest_client, endpoint)
	if ok {
		if resp.status_code >= 200 && resp.status_code < 300 {
			fmt.printfln("Deleted guild command %s in guild %s (status %d)", command_id, guild_id, resp.status_code)
		} else {
			fmt.eprintfln("Failed to delete guild command: HTTP %d: %s", resp.status_code, string(resp.body))
		}
		delete(resp.body)
		return resp.status_code >= 200 && resp.status_code < 300
	}
	fmt.eprintln("Failed to delete guild command: network error")
	return false
}

// Fetch all global commands (GET /applications/<id>/commands)
get_global_commands :: proc(cluster: ^Client) -> ([]api.ApplicationCommand, bool) {
	if cluster.application_id == "" {
		fmt.eprintln("Cannot get commands: no application_id")
		return nil, false
	}

	endpoint := fmt.tprintf("/applications/%s/commands", cluster.application_id)
	commands, ok := api.discord_request([]api.ApplicationCommand, &cluster.rest_client, endpoint)
	return commands, ok
}

// Edit original interaction response (PATCH /webhooks/<app_id>/<token>/messages/@original)
edit_original_response :: proc(cluster: ^Client, interaction_token: string, content: string) -> bool {
	data := api.InteractionCallbackData {
		content = content,
	}

	body, err := json.marshal(data, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal edit: %v", err)
		return false
	}

	endpoint := fmt.tprintf("/webhooks/%s/%s/messages/@original", cluster.application_id, interaction_token)
	resp, ok := api.discord_patch(&cluster.rest_client, endpoint, body)
	if ok do delete(resp.body)
	return ok
}

// Delete original interaction response (DELETE /webhooks/<app_id>/<token>/messages/@original)
delete_original_response :: proc(cluster: ^Client, interaction_token: string) -> bool {
	endpoint := fmt.tprintf("/webhooks/%s/%s/messages/@original", cluster.application_id, interaction_token)
	resp, ok := api.discord_delete(&cluster.rest_client, endpoint)
	if ok do delete(resp.body)
	return ok
}

// Create a followup message (POST /webhooks/<app_id>/<token>)
create_followup :: proc(cluster: ^Client, interaction_token: string, content: string) -> bool {
	data := api.InteractionCallbackData {
		content = content,
	}

	body, err := json.marshal(data, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal followup: %v", err)
		return false
	}

	endpoint := fmt.tprintf("/webhooks/%s/%s", cluster.application_id, interaction_token)
	resp, ok := api.discord_post(&cluster.rest_client, endpoint, body)
	if !ok do return false
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("create_followup got HTTP %d: %s", resp.status_code, string(resp.body))
		delete(resp.body)
		return false
	}
	delete(resp.body)
	return true
}

_read_process_cpu_ticks :: proc() -> (u64, u64) {
	buf: [4096]u8
	fd, err := os.open("/proc/self/stat")
	if err != nil do return 0, 0
	defer os.close(fd)

	n, read_err := os.read(fd, buf[:])
	if read_err != nil || n <= 0 do return 0, 0

	close_paren := -1
	for i := n - 1; i >= 0; i -= 1 {
		if buf[i] == ')' {
			close_paren = i
			break
		}
	}
	if close_paren < 0 || close_paren + 1 >= n do return 0, 0

	pos := close_paren + 1
	field_idx := 0
	utime: u64 = 0
	stime: u64 = 0

	for pos < n && field_idx <= 12 {
		for pos < n && (buf[pos] == ' ' || buf[pos] == '\t') { pos += 1 }
		if pos >= n do break

		start := pos
		for pos < n && buf[pos] != ' ' && buf[pos] != '\t' { pos += 1 }

		val, _ := strconv.parse_u64(string(buf[start:pos]))
		if field_idx == 11 { utime = val }
		if field_idx == 12 { stime = val }
		field_idx += 1
	}

	return utime, stime
}

_read_system_cpu_ticks :: proc() -> u64 {
	buf: [4096]u8
	fd, err := os.open("/proc/stat")
	if err != nil do return 0
	defer os.close(fd)

	n, read_err := os.read(fd, buf[:])
	if read_err != nil || n <= 0 do return 0

	s := string(buf[:n])
	if len(s) < 4 || s[:3] != "cpu" || (len(s) > 3 && s[3] != ' ') do return 0

	pos := 4
	total: u64 = 0

	for pos < n {
		for pos < n && (buf[pos] == ' ' || buf[pos] == '\t') { pos += 1 }
		if pos >= n || buf[pos] == '\n' do break

		start := pos
		for pos < n && buf[pos] != ' ' && buf[pos] != '\t' && buf[pos] != '\n' { pos += 1 }

		val, _ := strconv.parse_u64(string(buf[start:pos]))
		total += val
	}

	return total
}

_read_memory_kb :: proc() -> int {
	buf: [4096]u8
	fd, err := os.open("/proc/self/status")
	if err != nil do return 0
	defer os.close(fd)

	n, read_err := os.read(fd, buf[:])
	if read_err != nil || n <= 0 do return 0

	s := string(buf[:n])
	target := "VmRSS:"

	for i := 0; i <= n - len(target); i += 1 {
		if s[i:i+len(target)] == target {
			j := i + len(target)
			for j < n && (buf[j] == ' ' || buf[j] == '\t') { j += 1 }
			start := j
			for j < n && buf[j] >= '0' && buf[j] <= '9' { j += 1 }
			if j > start {
				val, _ := strconv.parse_int(string(buf[start:j]))
				return val
			}
		}
	}

	return 0
}

render_dashboard :: proc(cluster: ^Client) {
	num_cores := os.processor_core_count()

	utime, stime := _read_process_cpu_ticks()
	proc_ticks := utime + stime
	sys_ticks := _read_system_cpu_ticks()

	proc_delta := proc_ticks - cluster.prev_proc_ticks
	sys_delta := sys_ticks - cluster.prev_sys_ticks

	cpu_pct: f64 = 0.0
	if cluster.prev_sys_ticks > 0 && sys_delta > 0 {
		cpu_pct = f64(proc_delta) / f64(sys_delta) * f64(num_cores) * 100.0
		if cpu_pct > 100.0 * f64(num_cores) { cpu_pct = 100.0 * f64(num_cores) }
	}

	cluster.prev_proc_ticks = proc_ticks
	cluster.prev_sys_ticks = sys_ticks

	mem_kb := _read_memory_kb()
	mem_mb := f64(mem_kb) / 1024.0

	guild_count := len(cluster.known_guilds)
	cached_messages := len(cluster.message_cache)
	registered_commands := len(cluster.command_registry)
	outbound_queue_size := len(cluster.outbound_queue)
	thread_count := len(cluster.worker_pool.threads)
	identifies_24h := len(cluster.identify_log)

	avg_latency_ms: f64 = 0.0
	if len(cluster.latency_history) > 0 {
		total: time.Duration = 0
		for lat in cluster.latency_history {
			total += lat
		}
		avg_latency_ms = f64(total / time.Duration(len(cluster.latency_history))) / f64(time.Millisecond)
	}

	last_latency_ms: f64 = 0.0
	if len(cluster.latency_history) > 0 {
		last_latency_ms = f64(cluster.latency_history[len(cluster.latency_history)-1]) / f64(time.Millisecond)
	}

	uptime := time.since(cluster.start_time)
	uptime_secs := f64(uptime) / f64(time.Second)
	
	events_per_sec: f64 = 0.0
	if uptime_secs > 0 {
		events_per_sec = f64(cluster.total_events) / uptime_secs
	}

	total_secs := i64(uptime / time.Second)
	days := total_secs / 86400
	hours := (total_secs % 86400) / 3600
	mins := (total_secs % 3600) / 60
	secs := total_secs % 60

	uptime_str: string
	if days > 0 {
		uptime_str = fmt.tprintf("%dd %02dh %02dm %02ds", days, hours, mins, secs)
	} else if hours > 0 {
		uptime_str = fmt.tprintf("%dh %02dm %02ds", hours, mins, secs)
	} else if mins > 0 {
		uptime_str = fmt.tprintf("%dm %02ds", mins, secs)
	} else {
		uptime_str = fmt.tprintf("%ds", secs)
	}

	fmt.eprint("\033[2J\033[H")
	fmt.eprintfln("")
	fmt.eprintfln("  Discord Bot Dashboard [Shard %d/%d]", cluster.shard_id, cluster.num_shards)
	fmt.eprintfln("  %s", "────────────────────────────────────────")
	fmt.eprintfln("  %-18s %d", "Servers:", guild_count)
	fmt.eprintfln("  %-18s %d", "Users:", cluster.total_members)
	fmt.eprintfln("  %-18s %s", "Uptime:", uptime_str)
	fmt.eprintfln("  %-18s %s", "Session ID:", cluster.session_id)
	fmt.eprintfln("  %s", "────────────────────────────────────────")
	fmt.eprintfln("  %-18s %d", "Total Events:", cluster.total_events)
	fmt.eprintfln("  %-18s %s", "Last Event:", cluster.last_event_type)
	fmt.eprintfln("  %-18s %.2f/s", "Event Rate:", events_per_sec)
	fmt.eprintfln("  %-18s %d", "Messages Seen:", cluster.total_messages)
	fmt.eprintfln("  %-18s %d", "Commands Run:", cluster.total_commands)
	fmt.eprintfln("  %-18s %d", "REST API Calls:", cluster.rest_client.total_requests)
	fmt.eprintfln("  %s", "────────────────────────────────────────")
	fmt.eprintfln("  %-18s %d", "Cached Messages:", cached_messages)
	fmt.eprintfln("  %-18s %d", "Reg. Commands:", registered_commands)
	fmt.eprintfln("  %-18s %d", "Outbound Queue:", outbound_queue_size)
	fmt.eprintfln("  %-18s %d/1000", "Identifies (24h):", identifies_24h)
	fmt.eprintfln("  %s", "────────────────────────────────────────")
	fmt.eprintfln("  %-18s %.1f%%  (%d cores)", "CPU:", cpu_pct, num_cores)
	fmt.eprintfln("  %-18s %.1f MB", "Memory:", mem_mb)
	fmt.eprintfln("  %-18s %d", "Worker Threads:", thread_count)
	fmt.eprintfln("  %-18s %s", "Gateway Status:", cluster.received_ack ? "OK" : "WAITING ACK")
	fmt.eprintfln("  %-18s %.1f ms", "Avg Heartbeat:", avg_latency_ms)
	fmt.eprintfln("  %-18s %.1f ms", "Last Heartbeat:", last_latency_ms)
	fmt.eprintfln("  %s", "────────────────────────────────────────")
}
