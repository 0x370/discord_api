package discord

import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:strings"
import "core:sync"
import "core:thread"
import "core:time"
import "vendor:curl"

import "api"

Gateway_Intent :: enum u8 {
	GUILDS                        = 0, // 1 << 0
	GUILD_MEMBERS                 = 1, // 1 << 1  (Privileged)
	GUILD_MODERATION              = 2, // 1 << 2
	GUILD_EXPRESSIONS             = 3, // 1 << 3
	GUILD_INTEGRATIONS            = 4, // 1 << 4
	GUILD_WEBHOOKS                = 5, // 1 << 5
	GUILD_INVITES                 = 6, // 1 << 6
	GUILD_VOICE_STATES            = 7, // 1 << 7
	GUILD_PRESENCES               = 8, // 1 << 8  (Privileged)
	GUILD_MESSAGES                = 9, // 1 << 9
	GUILD_MESSAGE_REACTIONS       = 10, // 1 << 10
	GUILD_MESSAGE_TYPING          = 11, // 1 << 11
	DIRECT_MESSAGES               = 12, // 1 << 12
	DIRECT_MESSAGE_REACTIONS      = 13, // 1 << 13
	DIRECT_MESSAGE_TYPING         = 14, // 1 << 14
	MESSAGE_CONTENT               = 15, // 1 << 15 (Privileged)
	GUILD_SCHEDULED_EVENTS        = 16, // 1 << 16
	AUTO_MODERATION_CONFIGURATION = 20, // 1 << 20
	AUTO_MODERATION_EXECUTION     = 21, // 1 << 21
	GUILD_MESSAGE_POLLS           = 24, // 1 << 24
	DIRECT_MESSAGE_POLLS          = 25, // 1 << 25
}
Gateway_Intents_Set :: bit_set[Gateway_Intent;i32]

opcodes :: enum int {
	OP_DISPATCH        = 0,
	OP_HEARTBEAT       = 1,
	OP_IDENTIFY        = 2,
	OP_RESUME          = 6, // Added: Necessary for outbound reconnects
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

Cluster :: struct {
	curl_handle:        ^curl.CURL,
	worker_pool:        thread.Pool,
	outbount_mutex:     sync.Mutex,
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
	allocator: 			runtime.Allocator,

	cache_mutex: sync.Mutex,
	message_cache: map[api.Snowflake]^api.Message,
	message_order: [dynamic]api.Snowflake,
	event_handlers: map[string][dynamic]Event_Listener
}

on :: proc(cluster: ^Cluster, event_name: string, callback: Event_Callback) {
	sync.lock(&cluster.cache_mutex)

	if _, ok := cluster.event_handlers[event_name]; !ok {
		cluster.event_handlers[event_name] = make(
			[dynamic]Event_Listener,
			allocator = cluster.allocator,
		)
	}

	append(
		&cluster.event_handlers[event_name],
		Event_Listener {
			callback = callback,
		},
	)

	sync.unlock(&cluster.cache_mutex)
}

Ready_Event_Data :: struct {
	session_id: string `json:"session_id"`,
	resume_url: string `json:"resume_url"`,
}

Resume_Payload :: struct {
	op: opcodes `json:"op"`,
	d:  Resume_Data `json:"d"`,
}

Resume_Data :: struct {
	token:      string `json:"token"`,
	session_id: string `json:"session_id"`,
	seq:        int `json:"seq"`,
}

GateWay_task_Data :: struct {
	cluster:     ^Cluster,
	raw_payload: []byte,
}

Gateway_Payload :: struct {
	op: opcodes `json:"op"`,
	d:  json.Value `json:"d"`,
	s:  Maybe(int) `json:"s"`,
	t:  string `json:"t"`,
}

Hello_Data :: struct {
	heartbeat_interval: int `json:"heartbeat_interval"`,
}

Heartbeat_Payload :: struct {
	op: opcodes `json:"op"`,
	d:  Maybe(int) `json:"d"`,
}

Identify_Payload :: struct {
	op: opcodes `json:"op"`,
	d:  Identify_Data `json:"d"`,
}

Identify_Data :: struct {
	token:      string `json:"token"`,
	intents:    Gateway_Intents_Set `json:"intents"`,
	properties: Identify_Properties `json:"properties"`,
}

Identify_Properties :: struct {
	os:      string `json:"os"`,
	browser: string `json:"browser"`,
	device:  string `json:"device"`,
}

queue_outbound_payload :: proc(cluster: ^Cluster, data: $T) {
	json_bytes, err := json.marshal(data, allocator = context.temp_allocator)
	if err != nil do return

	persistent_copy := make([]byte, len(json_bytes))
	copy(persistent_copy, json_bytes)

	sync.lock(&cluster.outbount_mutex)
	append(&cluster.outbound_queue, persistent_copy)
	sync.unlock(&cluster.outbount_mutex)
}

heartbeat_pool_task :: proc(task: thread.Task) {
	cluster := (^Cluster)(task.data)

	if !cluster.is_running do return

	sync.lock(&cluster.ack_mutex)
	if !cluster.received_ack {
		fmt.println("Missed heartbeat ack! trying to reset...")
		cluster.is_running = false
		sync.unlock(&cluster.ack_mutex)
		return
	}
	cluster.received_ack = false
	sync.unlock(&cluster.ack_mutex)

	sync.lock(&cluster.sequence_mutex)
	current_seq := cluster.last_sequence
	sync.unlock(&cluster.sequence_mutex)

	ping := Heartbeat_Payload {
		op = .OP_HEARTBEAT,
		d  = current_seq,
	}

	queue_outbound_payload(cluster, ping)
	fmt.println("Sent heartbeat ping via ThreadPool")

	interval_ms := 45000
	time.sleep(time.Duration(interval_ms) * time.Millisecond)

	thread.pool_add_task(&cluster.worker_pool, context.allocator, heartbeat_pool_task, cluster)
}

process_gateway_task :: proc(task: thread.Task) {
	task_context := (^GateWay_task_Data)(task.data)
	cluster := task_context.cluster

	defer delete(task_context.raw_payload)
	defer free(task_context)

	envelope: Gateway_Payload
	alloc := context.temp_allocator
	if json.unmarshal(task_context.raw_payload, &envelope, allocator = alloc) != nil do return
	defer delete(envelope.t, alloc)
	defer json.destroy_value(envelope.d, alloc)

	if seq, has_seq := envelope.s.?; has_seq {
		sync.lock(&cluster.sequence_mutex)
		cluster.last_sequence = seq
		sync.unlock(&cluster.sequence_mutex)
	}

	switch envelope.op {
	case .OP_HELLO:
		var_data: Hello_Data
		if hello_bytes, err := json.marshal(envelope.d, allocator = context.temp_allocator);
		   err == nil {
			if json.unmarshal(hello_bytes, &var_data) == nil {
				fmt.printfln(
					"Got hello. Heartbeat request every: %d ms",
					var_data.heartbeat_interval,
				)

				cluster.heartbeat_interval = var_data.heartbeat_interval

				sync.lock(&cluster.ack_mutex)
				cluster.received_ack = true
				sync.unlock(&cluster.ack_mutex)

				thread.pool_add_task(
					&cluster.worker_pool,
					context.allocator,
					proc(task: thread.Task) {
						cluster := (^Cluster)(task.data)
						interval :=
							cluster.heartbeat_interval > 0 ? cluster.heartbeat_interval : 45000
						time.sleep(time.Duration(interval / 2) * time.Millisecond)

						thread.pool_add_task(
							&cluster.worker_pool,
							context.allocator,
							heartbeat_pool_task,
							cluster,
						)
					},
					cluster,
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
					handshake := Identify_Payload {
						op = .OP_IDENTIFY,
						d = Identify_Data {
							token = cluster.token,
							intents = {
								.GUILDS,
								.GUILD_MESSAGES,
								.MESSAGE_CONTENT,
								.DIRECT_MESSAGES,
							},
							properties = Identify_Properties {
								os = "linux",
								browser = "odin-client",
								device = "odin-client",
							},
						},
					}
					queue_outbound_payload(cluster, handshake)
					fmt.println("Sent identify handshake")
				}
			}
		}
	case .OP_DISPATCH:
		fmt.printfln("[Event received] type: %s", envelope.t)

		switch envelope.t {
		case "READY":
			handle_ready(cluster, envelope.d)

		case "MESSAGE_CREATE":
			handle_message_create(cluster, envelope.d)

		case "GUILD_CREATE":
			handle_guild_create(cluster, envelope.d)
			
		case "MESSAGE_UPDATE":
			handle_message_update(cluster, envelope.d)

		case "MESSAGE_DELETE":
			handle_message_delete(cluster, envelope.d)
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
		if resume_bytes, err := json.marshal(envelope.d, allocator = context.temp_allocator);
		   err == nil {
			json.unmarshal(resume_bytes, &can_resume, allocator = context.temp_allocator)
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
		fmt.println("Heartbeat ACK acknowledged by Discord")

	case .OP_IDENTIFY, .OP_RESUME:
		break
	}
}

run_network_pump :: proc(cluster: ^Cluster) {
	read_buffer := make([]byte, 65536)
	defer delete(read_buffer)

	bytes_received: uint = 0
	meta: ^curl.ws_frame
    
	for cluster.is_running {
		err := curl.ws_recv(
			cluster.curl_handle,
			rawptr(&read_buffer[0]),
			len(read_buffer),
			&bytes_received,
			&meta,
		)

		if err == .E_OK && bytes_received > 0 {
			copy_payload := make([]byte, bytes_received)
			copy(copy_payload, read_buffer[:bytes_received])

			task_context := new(GateWay_task_Data)
			task_context.cluster = cluster
			task_context.raw_payload = copy_payload

			process_gateway_task(thread.Task{
				data = task_context,
			})
		}

		sync.lock(&cluster.outbount_mutex)
		if len(cluster.outbound_queue) > 0 {
			out_frame := pop_front(&cluster.outbound_queue)
			sync.unlock(&cluster.outbount_mutex)

			bytes_written: uint = 0
			curl.ws_send(
				cluster.curl_handle,
				raw_data(out_frame),
				len(out_frame),
				&bytes_written,
				0,
				{.TEXT},
			)
			delete(out_frame)
		} else {
			sync.unlock(&cluster.outbount_mutex)
		}

		time.sleep(1 * time.Millisecond)
	}

	thread.pool_join(&cluster.worker_pool)
	cluster_cleanup(cluster)
}

cluster_cleanup :: proc(cluster: ^Cluster) {
	sync.lock(&cluster.outbount_mutex)
	for len(cluster.outbound_queue) > 0 {
		frame := pop_front(&cluster.outbound_queue)
		delete(frame)
	}
	delete(cluster.outbound_queue)
	sync.unlock(&cluster.outbount_mutex)

	if cluster.session_id != "" do delete(cluster.session_id)
	if cluster.resume_url != "" do delete(cluster.resume_url)

	sync.lock(&cluster.cache_mutex)

	for _, msg in cluster.message_cache {
		deep_free(msg^, cluster.allocator)
		free(msg)
	}

	delete(cluster.message_cache)
	delete(cluster.message_order)

	sync.unlock(&cluster.cache_mutex)

	fmt.println("Cleaned up cluster")
}

Config :: struct {
	token: string,
} 

new_client :: proc(config: Config) -> ^Cluster {
	cluster := new(Cluster)

	cluster.allocator = context.allocator
	cluster.token = config.token

	cluster.message_cache = make(
		map[api.Snowflake]^api.Message,
		allocator = context.allocator,
	)

	cluster.message_order = make(
		[dynamic]api.Snowflake,
		allocator = context.allocator,
	)

	cluster.event_handlers = make(
		map[string][dynamic]Event_Listener,
		allocator = context.allocator,
	)

	return cluster
}

run :: proc(cluster: ^Cluster) {
	cluster.curl_handle = curl.easy_init()
	if cluster.curl_handle == nil do return
	defer curl.easy_cleanup(cluster.curl_handle)

	url := fmt.tprintf("wss://gateway.discord.gg/?v=%s&encoding=json", api.API_VERSION)
	url_cstr := strings.clone_to_cstring(url, context.temp_allocator)
	curl.easy_setopt(cluster.curl_handle, .URL, url_cstr)
	curl.easy_setopt(cluster.curl_handle, .CONNECT_ONLY, i32(2))

	res := curl.easy_perform(cluster.curl_handle)
	if res != .E_OK {
		fmt.eprintfln("Handshake failed: %s", curl.easy_strerror(res))
		return
	}

	cluster.is_running = true
	cluster.received_ack = true

	thread.pool_init(&cluster.worker_pool, context.allocator, thread_count = 4)
	defer thread.pool_destroy(&cluster.worker_pool)

	thread.pool_start(&cluster.worker_pool)
	run_network_pump(cluster)
}

parse_dispatch_data :: proc(payload: json.Value, out: ^$T) -> bool {
	raw, err := json.marshal(payload, allocator = context.temp_allocator)
	if err != nil {
		fmt.printfln("Parse error: %s", err)
		return false
	}
	
	err1 := json.unmarshal_any(raw, out, allocator = context.temp_allocator)
	if err1 != nil {
		fmt.printfln("Parse error: %s", err1)
		return false
	}

	return true
}

Callback_Task :: struct {
	callback: Event_Callback,
	payload: rawptr,
	cleanup: proc(rawptr, runtime.Allocator),
	allocator: runtime.Allocator
}

callback_worker :: proc(task: thread.Task) {
	ctx := (^Callback_Task)(task.data)

	defer {
		ctx.cleanup(ctx.payload, ctx.allocator)
		free(ctx)
	}

	ctx.callback(ctx.payload)
}

dispatch_event :: proc(cluster: ^Cluster, event_name: string, payload: $T) {
	sync.lock(&cluster.cache_mutex)

	listeners, exists := cluster.event_handlers[event_name]

	if !exists {
		sync.unlock(&cluster.cache_mutex)
		return
	}

	local_listeners := make(
		[]Event_Listener,
		len(listeners),
		context.temp_allocator,
	)

	runtime.copy_slice(local_listeners, listeners[:])

	sync.unlock(&cluster.cache_mutex)

	for listener in local_listeners {
		copy_payload := new(T, allocator = cluster.allocator)
		copy_payload^ = deep_clone(payload, cluster.allocator)

		task := new(Callback_Task)

		task.callback = listener.callback
		task.payload = copy_payload
		task.allocator = cluster.allocator

		task.cleanup = proc(
			p: rawptr,
			allocator: runtime.Allocator,
		) {
			obj := (^T)(p)

			deep_free(obj^, allocator)

			free(obj)
		}

		thread.pool_add_task(
			&cluster.worker_pool,
			context.allocator,
			callback_worker,
			task,
		)
	}
}

handle_message_create :: proc(cluster: ^Cluster, payload: json.Value) {
	msg: api.Message

	if !parse_dispatch_data(payload, &msg) {
		fmt.eprintln("Failed to parse MESSAGE_CREATE")
		return
	}

	persistent := new(api.Message, allocator = cluster.allocator)
	persistent^ = deep_clone(msg, cluster.allocator)

	sync.lock(&cluster.cache_mutex)

	cluster.message_cache[persistent.id] = persistent
	append(&cluster.message_order, persistent.id)

	if len(cluster.message_order) > MAX_CACHED_MESSAGES {
		oldest := pop_front(&cluster.message_order)

		if old_msg, ok := cluster.message_cache[oldest]; ok {
			delete_key(&cluster.message_cache, oldest)
			deep_free(old_msg^, cluster.allocator)
			free(old_msg)
		}
	}

	sync.unlock(&cluster.cache_mutex)

	dispatch_event(cluster, "MESSAGE_CREATE", msg)
}

handle_guild_create :: proc(cluster: ^Cluster, payload: json.Value) {
	guild: api.Guild

	if !parse_dispatch_data(payload, &guild) {
		fmt.eprintln("Failed to parse GUILD_CREATE")
		return
	}

	dispatch_event(
		cluster,
		"GUILD_CREATE",
		guild,
	)
}

handle_ready :: proc(cluster: ^Cluster, payload: json.Value) {
	ready: Ready_Event_Data

	if !parse_dispatch_data(payload, &ready) {
		fmt.eprintln("Failed to parse READY")
		return
	}

	cluster.session_id = ready.session_id
	cluster.resume_url = ready.resume_url

	fmt.printfln(
		"Bot is ready! Session Cached: %s",
		cluster.session_id,
	)
}

handle_message_update :: proc(cluster: ^Cluster, payload: json.Value) {
	update: api.Message

	if !parse_dispatch_data(payload, &update) {
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

	snapshot := deep_clone(cached^, context.temp_allocator)
	sync.unlock(&cluster.cache_mutex)

	before := deep_clone(snapshot, context.temp_allocator)
	after  := deep_clone(snapshot, context.temp_allocator)

	after.content = update.content
	after.edited_timestamp = update.edited_timestamp
	after.embeds = deep_clone(update.embeds, context.temp_allocator)
	after.attachments = deep_clone(update.attachments, context.temp_allocator)
	after.pinned = update.pinned
	after.flags = update.flags
	after.mention_everyone = update.mention_everyone
	after.tts = update.tts

	sync.lock(&cluster.cache_mutex)

	deep_free(cached^, cluster.allocator)
	cached^ = deep_clone(after, cluster.allocator)

	sync.unlock(&cluster.cache_mutex)

	dispatch_event(
		cluster,
		"MESSAGE_UPDATE",
		api.MessageUpdateArgs {
			before = before,
			after  = after,
		},
	)
}

handle_message_delete :: proc(
	cluster: ^Cluster,
	payload: json.Value,
) {
	event: api.MessageDeleteEvent

	if !parse_dispatch_data(payload, &event) {
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
