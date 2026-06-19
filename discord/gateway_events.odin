package discord

import "core:encoding/json"
import "core:fmt"

import "core:strings"
import "core:sync"
import "core:thread"
import "core:time"

import "api"

Ready_Application :: struct {
	id: api.Snowflake `json:"id"`,
}

Ready_Event_Data :: struct {
	session_id:  string `json:"session_id"`,
	resume_url:  string `json:"resume_url"`,
	application: Ready_Application `json:"application"`,
}

Gateway_Payload :: struct {
	op: Opcodes `json:"op"`,
	d:  json.Value `json:"d"`,
	s:  Maybe(int) `json:"s"`,
	t:  Maybe(string) `json:"t"`,
}

Resume_Payload :: struct {
	op: Opcodes `json:"op"`,
	d:  Resume_Data `json:"d"`,
}

Resume_Data :: struct {
	token:      string `json:"token"`,
	session_id: string `json:"session_id"`,
	seq:        int `json:"seq"`,
}

Gateway_Task_Data :: struct {
	client:      ^Client,
	raw_payload: []byte,
}

Hello_Data :: struct {
	heartbeat_interval: int `json:"heartbeat_interval"`,
}

Heartbeat_Payload :: struct {
	op: Opcodes `json:"op"`,
	d:  Maybe(int) `json:"d"`,
}

Identify_Payload :: struct {
	op: Opcodes `json:"op"`,
	d:  Identify_Data `json:"d"`,
}

Identify_Data :: struct {
	token:      string `json:"token"`,
	intents:    Gateway_Intents_Set `json:"intents"`,
	properties: Identify_Properties `json:"properties"`,
	shard:      [2]int `json:"shard"`,
}

Identify_Properties :: struct {
	os:      string `json:"os"`,
	browser: string `json:"browser"`,
	device:  string `json:"device"`,
}

process_gateway_task :: proc(task: thread.Task) {
	task_data := (^Gateway_Task_Data)(task.data)
	client := task_data.client
	defer delete(task_data.raw_payload)
	defer free(task_data)

	payload: Gateway_Payload
	err := json.unmarshal(
		task_data.raw_payload,
		&payload,
		json.DEFAULT_SPECIFICATION,
		allocator = context.temp_allocator,
	)
	if err != nil {
		fmt.eprintfln("Failed to parse gateway payload: %v", err)
		return
	}

	if seq, has := payload.s.?; has {
		sync.lock(&client.sequence_mutex)
		client.last_sequence = seq
		sync.unlock(&client.sequence_mutex)
	}

	event_type := payload.t.? or_else ""

	d_bytes, marshal_err := json.marshal(payload.d, allocator = context.temp_allocator)
	if marshal_err != nil {
		fmt.eprintfln("Failed to marshal gateway d field: %v", marshal_err)
		return
	}
       logd("gateway: op=%v t=%s d_len=%d", payload.op, event_type, len(d_bytes))

	switch payload.op {
	case .OP_HELLO:
		handle_op_hello(client, d_bytes)
	case .OP_DISPATCH:
		handle_op_dispatch(client, event_type, d_bytes)
	case .OP_HEARTBEAT:
		handle_op_heartbeat(client)
	case .OP_RECONNECT:
		handle_op_reconnect(client)
	case .OP_INVALID_SESSION:
		handle_op_invalid_session(client, payload.d)
	case .OP_HEARTBEAT_ACK:
		handle_op_heartbeat_ack(client)
	case .OP_IDENTIFY, .OP_RESUME:
	// no-op: we sent these, discord doesn't reply to them with data
	}
}

@(private)
handle_op_hello :: proc(client: ^Client, d_bytes: []byte) {
       var_data: Hello_Data
       if json.unmarshal(d_bytes, &var_data) != nil {
               fmt.eprintln("Failed to parse HELLO data")
               return
       }

       fmt.printfln("Got hello. Heartbeat interval: %d ms", var_data.heartbeat_interval)
       client.heartbeat_interval = var_data.heartbeat_interval
       logd("hello: interval=%dms", var_data.heartbeat_interval)
       client.heartbeat_gen += 1

       sync.lock(&client.ack_mutex)
       client.received_ack = true
       sync.unlock(&client.ack_mutex)

       start_heartbeat_with_jitter(client)

       sync.lock(&client.state_mutex)
       defer sync.unlock(&client.state_mutex)

       if client.session_id != "" {
               send_resume(client)
       } else {
               if !identify_check(client) {
                       fmt.eprintln("Identify rate limited, will retry on reconnect")
                       client.is_running = false
                       client.is_reconnecting = true
                       return
               }
               send_identify(client)
       }
}

@(private)
start_heartbeat_with_jitter :: proc(client: ^Client) {
       client.heartbeat_thread = thread.create_and_start_with_data(client, heartbeat_thread_proc)
}

@(private)
send_resume :: proc(client: ^Client) {
	sync.lock(&client.sequence_mutex)
	current_seq := client.last_sequence.? or_else 0
	sync.unlock(&client.sequence_mutex)

	resume := Resume_Payload {
		op = .OP_RESUME,
		d = Resume_Data{token = client.token, session_id = client.session_id, seq = current_seq},
	}
	queue_outbound_payload(client, resume)
	fmt.println("Sent resume handshake")
}

@(private)
send_identify :: proc(client: ^Client) {
	handshake := Identify_Payload {
		op = .OP_IDENTIFY,
		d = Identify_Data {
			token = client.token,
			intents = {.GUILDS, .GUILD_MESSAGES, .MESSAGE_CONTENT, .DIRECT_MESSAGES},
			properties = Identify_Properties {
				os = "linux",
				browser = "odin-client",
				device = "odin-client",
			},
			shard = {client.shard_id, client.num_shards},
		},
	}

	sync.lock(&client.identify_mutex)
	append(&client.identify_log, time.now())
	sync.unlock(&client.identify_mutex)

	queue_outbound_payload(client, handshake)
	fmt.println("Sent identify handshake")
}

@(private)
handle_op_dispatch :: proc(client: ^Client, event_type: string, d_bytes: []byte) {
       logd("dispatch: type=%s d_len=%d", event_type, len(d_bytes))
	if event_type == "" do return

	client.total_events += 1
	if client.last_event_type != "" do delete(client.last_event_type, client.allocator)
	client.last_event_type = strings.clone(event_type, client.allocator)
	fmt.printfln("[Event received] type: %s", event_type)

	switch event_type {
	case "READY":
		handle_ready(client, d_bytes)
	case "MESSAGE_CREATE":
		handle_message_create(client, d_bytes)
	case "GUILD_CREATE":
		handle_guild_create(client, d_bytes)
	case "GUILD_DELETE":
		handle_guild_delete(client, d_bytes)
	case "MESSAGE_UPDATE":
		handle_message_update(client, d_bytes)
	case "MESSAGE_DELETE":
		handle_message_delete(client, d_bytes)
	case "INTERACTION_CREATE":
		handle_interaction_create(client, d_bytes)
	}
}

@(private)
handle_op_heartbeat :: proc(client: ^Client) {
       logd("heartbeat: forced by server")
	sync.lock(&client.sequence_mutex)
	current_seq := client.last_sequence
	sync.unlock(&client.sequence_mutex)

	forced_ping := Heartbeat_Payload {
		op = .OP_HEARTBEAT,
		d  = current_seq,
	}
	queue_outbound_payload(client, forced_ping)
	fmt.println("Forced heartbeat sent on explicit Discord request")
}

@(private)
handle_op_reconnect :: proc(client: ^Client) {
       fmt.println("Discord requested a reconnect. Tearing down socket loop...")
       sync.lock(&client.state_mutex)
       client.is_running = false
       client.is_reconnecting = true
       logd("reconnect: requested by server")
       sync.unlock(&client.state_mutex)
}

@(private)
handle_op_invalid_session :: proc(client: ^Client, d: json.Value) {
       can_resume := false
       if _, is_null := d.(json.Null); !is_null {
               if d_bool, is_bool := d.(bool); is_bool {
                       can_resume = d_bool
               }
       }
       fmt.printfln("Invalid Session received. Can resume?: %v", can_resume)
       logd("invalid_session: can_resume=%v", can_resume)

       sync.lock(&client.state_mutex)
       if !can_resume {
               if client.session_id != "" do delete(client.session_id)
               if client.resume_url != "" do delete(client.resume_url)
               client.session_id = ""
               client.resume_url = ""
       }
       client.is_running = false
       client.is_reconnecting = true
       sync.unlock(&client.state_mutex)
}

@(private)
handle_op_heartbeat_ack :: proc(client: ^Client) {
       sync.lock(&client.ack_mutex)
       client.received_ack = true
       sync.unlock(&client.ack_mutex)

       sync.lock(&client.heartbeat_send_mutex)
       rtt := time.since(client.heartbeat_send_time)
       logd("heartbeat_ack: rtt=%v", rtt)
       sync.unlock(&client.heartbeat_send_mutex)

       sync.lock(&client.latency_mutex)
       if len(client.latency_history) >= 100 {
               pop_front(&client.latency_history)
       }
       append(&client.latency_history, rtt)
       sync.unlock(&client.latency_mutex)
}
