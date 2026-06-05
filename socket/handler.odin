package discord

import "core:encoding/json"
import "core:sync"
import "core:thread"
import "core:time"
import "core:fmt"
import "vendor:curl"
import "core:strings"

Gateway_Intent :: enum u8 {
	GUILDS                        = 0,  // 1 << 0
	GUILD_MEMBERS                 = 1,  // 1 << 1  (Privileged)
	GUILD_MODERATION              = 2,  // 1 << 2
	GUILD_EXPRESSIONS             = 3,  // 1 << 3
	GUILD_INTEGRATIONS            = 4,  // 1 << 4
	GUILD_WEBHOOKS                = 5,  // 1 << 5
	GUILD_INVITES                 = 6,  // 1 << 6
	GUILD_VOICE_STATES            = 7,  // 1 << 7
	GUILD_PRESENCES               = 8,  // 1 << 8  (Privileged)
	GUILD_MESSAGES                = 9,  // 1 << 9
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
Gateway_Intents_Set :: bit_set[Gateway_Intent; i32]

opcodes :: enum int {
    OP_DISPATCH = 0,
    OP_HEARTBEAT = 1,
    OP_IDENTIFY = 2,
    OP_RESUME = 6, // Added: Necessary for outbound reconnects
    OP_RECONNECT = 7,
    OP_INVALID_SESSION = 9,
    OP_HELLO = 10,
    OP_HEARTBEAT_ACK = 11,
}

Cluster :: struct {
    curl_handle:     ^curl.CURL,
    worker_pool:     thread.Pool,

    outbount_mutex:  sync.Mutex,
    outbound_queue:  [dynamic][]byte,

    is_running:      bool,
    is_reconnecting: bool,

    last_sequence: Maybe(int),
    sequence_mutex: sync.Mutex,
    received_ack: bool,
    ack_mutex: sync.Mutex,
    token: string,
    session_id: string,
    resume_url: string
}

Ready_Event_Data :: struct {
    session_id: string `json:"session_id"`,
    resume_url: string `json:"resume_url"`,
}

Resume_Payload :: struct {
	op: opcodes       `json:"op"`,
	d:  Resume_Data   `json:"d"`,
}

Resume_Data :: struct {
	token:      string `json:"token"`,
	session_id: string `json:"session_id"`,
	seq:        int    `json:"seq"`,
}

GateWay_task_Data :: struct {
    cluster:     ^Cluster,
    raw_payload: []byte,
}

Gateway_Payload :: struct {
	op: opcodes         `json:"op"`,
	d:  json.Value      `json:"d"`,
	s:  Maybe(int)      `json:"s"`,
	t:  string          `json:"t"`,
}

Hello_Data :: struct {
    heartbeat_interval: int `json:"heartbeat_interval"`,
}

Heartbeat_Payload :: struct {
    op: opcodes `json:"op"`,
    d: Maybe(int) `json:"d"`
}

Identify_Payload :: struct {
    op: opcodes `json:"op"`,
    d: Identify_Data `json:"d"`
}

Identify_Data :: struct {
    token: string `json:"token"`,
    intents: Gateway_Intents_Set `json:"intents"`,
    properties: Identify_Properties `json:"properties"`
}

Identify_Properties :: struct {
    os: string `json:"os"`,
    browser: string `json:"browser"`,
    device: string `json:"device"`
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

heartbeat_loop :: proc(t: ^thread.Thread) {
    cluster := (^Cluster)(t.data)

    interval_ms := 45000

    time.sleep(time.Duration(interval_ms / 2) * time.Millisecond)

    for cluster.is_running {
        sync.lock(&cluster.ack_mutex)
        if !cluster.received_ack {
            fmt.println("Missed heartbeat ack! trying to reset...")
            cluster.is_running = false
            sync.unlock(&cluster.ack_mutex)
            break
        }

        cluster.received_ack = false
        sync.unlock(&cluster.ack_mutex)

        sync.lock(&cluster.sequence_mutex)
        current_seq := cluster.last_sequence
        sync.unlock(&cluster.sequence_mutex)

        ping := Heartbeat_Payload {
            op = .OP_HEARTBEAT,
            d = current_seq
        }

        queue_outbound_payload(cluster, ping)
        fmt.println("Sent heartbeat ping")

        time.sleep(time.Duration(interval_ms) * time.Millisecond)
    }
}

process_gateway_task :: proc(task: thread.Task) {
    task_context := (^GateWay_task_Data)(task.data)
    cluster := task_context.cluster

    envelope: Gateway_Payload
    if json.unmarshal(task_context.raw_payload, &envelope) != nil do return

    if seq, has_seq := envelope.s.?; has_seq {
        sync.lock(&cluster.sequence_mutex)
        cluster.last_sequence = seq
        sync.unlock(&cluster.sequence_mutex)
    }

    switch envelope.op {
    case .OP_HELLO:
        var_data: Hello_Data
        if hello_bytes, err := json.marshal(envelope.d, allocator = context.temp_allocator); err == nil {
            if json.unmarshal(hello_bytes, &var_data) == nil {
                fmt.printfln("Got hello. Heartbeat request every: %d ms", var_data.heartbeat_interval)

                hb_thread := thread.create(heartbeat_loop)
                hb_thread.data = cluster
                thread.start(hb_thread)

                if cluster.session_id != "" {
                    sync.lock(&cluster.sequence_mutex)
                    current_seq := cluster.last_sequence.? or_else 0
                    sync.unlock(&cluster.sequence_mutex)

                    resume := Resume_Payload{
                        op = .OP_RESUME,
                        d = Resume_Data{
                            token      = cluster.token,
                            session_id = cluster.session_id,
                            seq        = current_seq,
                        },
                    }
                    queue_outbound_payload(cluster, resume)
                    fmt.println("Sent Resume Handshake Request")
                } else {
                    handshake := Identify_Payload{
                        op = .OP_IDENTIFY,
                        d = Identify_Data{
                            token = cluster.token,
                            intents = {.GUILDS, .GUILD_MESSAGES, .MESSAGE_CONTENT, .DIRECT_MESSAGES},
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
            ready_data: Ready_Event_Data
            if ready_bytes, err := json.marshal(envelope.d, allocator = context.temp_allocator); err == nil {
                if json.unmarshal(ready_bytes, &ready_data) == nil {
                    cluster.session_id = strings.clone(ready_data.session_id)
                    cluster.resume_url = strings.clone(ready_data.resume_url)
                    fmt.printfln("Bot is ready! Session Cached: %s", cluster.session_id)
                }
            }
        case "MESSAGE_CREATE":
            on_message_create(cluster, envelope.d)
        case "GUILD_CREATE":
            on_guild_create(cluster, envelope.d)
        case:
            fmt.printfln("unimplemented case: %s", envelope.t)
            break
        }
    case .OP_HEARTBEAT:
        sync.lock(&cluster.sequence_mutex)
        current_seq := cluster.last_sequence
        sync.unlock(&cluster.sequence_mutex)

        forced_ping := Heartbeat_Payload{
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
        if resume_bytes, err := json.marshal(envelope.d, allocator = context.temp_allocator); err == nil {
            json.unmarshal(resume_bytes, &can_resume)
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

    delete(task_context.raw_payload)
    free(task_context)
}

run_network_pump :: proc(cluster: ^Cluster) {
    read_buffer := make([]byte, 65536)
    defer delete(read_buffer)

    bytes_received: uint = 0
    meta: ^curl.ws_frame 

    for cluster.is_running {
        err := curl.ws_recv(cluster.curl_handle, rawptr(&read_buffer[0]), len(read_buffer), &bytes_received, &meta)

        if err == .E_OK && bytes_received > 0 {
            copy_payload := make([]byte, bytes_received)
            copy(copy_payload, read_buffer[:bytes_received])

            task_context := new(GateWay_task_Data)
            task_context.cluster = cluster
            task_context.raw_payload = copy_payload

            thread.pool_add_task(
                &cluster.worker_pool,
                context.allocator,
                process_gateway_task,
                task_context,
            )
        }

        sync.lock(&cluster.outbount_mutex)
        if len(cluster.outbound_queue) > 0 {
            out_frame := pop_front(&cluster.outbound_queue)
            sync.unlock(&cluster.outbount_mutex)

            bytes_written: uint = 0
            curl.ws_send(cluster.curl_handle, raw_data(out_frame), len(out_frame), &bytes_written, 0, {.TEXT})
            delete(out_frame)
        } else {
            sync.unlock(&cluster.outbount_mutex)
        }

        time.sleep(1 * time.Millisecond)
    }
}

run_socket :: proc(handle: ^curl.CURL, token: string) {
    url := strings.clone_to_cstring("wss://gateway.discord.gg/?v=10&encoding=json", context.temp_allocator)
    curl.easy_setopt(handle, .URL, url)
    curl.easy_setopt(handle, .CONNECT_ONLY, i32(2))

    res := curl.easy_perform(handle)
    if res != .E_OK {
        fmt.eprintfln("Handshake failed: %s", curl.easy_strerror(res))
        return
    }

    cluster: Cluster
    cluster.curl_handle = handle
    cluster.is_running = true
    cluster.received_ack = true
    cluster.token = token

    thread.pool_init(&cluster.worker_pool, context.allocator, thread_count = 4)
    defer thread.pool_destroy(&cluster.worker_pool)
    thread.pool_start(&cluster.worker_pool)

    fmt.println("Connected to discord")
    run_network_pump(&cluster)
}
