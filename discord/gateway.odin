package discord

import "core:container/queue"
import "core:encoding/json"
import "core:fmt"
import "core:strings"
import "core:sync"
import "core:thread"
import "core:time"
import "vendor:curl"

import "api"

queue_outbound_payload :: proc(client: ^Client, data: $T) {
	json_bytes, err := json.marshal(data, allocator = context.temp_allocator)
	if err != nil do return

	persistent_copy := make([]byte, len(json_bytes))
	copy(persistent_copy, json_bytes)

	sync.lock(&client.outbound_mutex)
	queue.push_back(&client.outbound_queue, persistent_copy)
	sync.cond_signal(&client.outbound_cond)
	sync.unlock(&client.outbound_mutex)
}

@(private)
run_network_pump :: proc(client: ^Client) {
	read_buffer := make([]byte, 65536)
	defer delete(read_buffer)

	frame_buffer: [dynamic]byte
	reserve(&frame_buffer, 4096)
	defer delete(frame_buffer)

       logd("pump: entering network pump loop")
       for true {
               had_work := false

               bytes_received: uint = 0
               meta: ^curl.ws_frame
               err := curl.ws_recv(
                       client.curl_handle,
                       rawptr(&read_buffer[0]),
                       len(read_buffer),
                       &bytes_received,
                       &meta,
               )
               if err == .E_OK && bytes_received > 0 {
                       had_work = true
                       append(&frame_buffer, ..read_buffer[:bytes_received])

                       if .CLOSE in meta.flags {
                               fmt.eprintln("WebSocket CLOSE frame received, reconnecting...")
                               sync.lock(&client.state_mutex)
                               client.is_running = false
                               client.is_reconnecting = true
                               sync.unlock(&client.state_mutex)
                               break
                       }

                       if meta.bytesleft == 0 {
                               copy_payload := make([]byte, len(frame_buffer))
                               copy(copy_payload, frame_buffer[:])
                               logd("pump: frame complete, %d bytes, dispatching to pool", len(copy_payload))
                               clear(&frame_buffer)

                               task_data := new(Gateway_Task_Data)
                               task_data.client = client
                               task_data.raw_payload = copy_payload
                               thread.pool_add_task(&client.worker_pool, context.allocator, process_gateway_task, task_data)
                       }
               }

               sync.lock(&client.outbound_mutex)
               for queue.len(client.outbound_queue) > 0 {
                       out_frame := queue.pop_front(&client.outbound_queue)
                       sync.unlock(&client.outbound_mutex)

                       had_work = true
                       bytes_written: uint = 0
                       curl.ws_send(
                               client.curl_handle,
                               raw_data(out_frame),
                               len(out_frame),
                               &bytes_written,
                               0,
                               {.TEXT},
                       )
                       delete(out_frame)
                       sync.lock(&client.outbound_mutex)
               }
               sync.unlock(&client.outbound_mutex)

               if !had_work {
                       sync.lock(&client.outbound_mutex)
                       sync.lock(&client.state_mutex)
                       running := client.is_running
                       sync.unlock(&client.state_mutex)
                       if queue.len(client.outbound_queue) == 0 && running {
                               sync.cond_wait_with_timeout(
                                       &client.outbound_cond,
                                       &client.outbound_mutex,
                                       5 * time.Millisecond,
                               )
                       }
                       sync.unlock(&client.outbound_mutex)
               }

               sync.lock(&client.state_mutex)
               if !client.is_running {
                       sync.unlock(&client.state_mutex)
                       break
               }
               sync.unlock(&client.state_mutex)

               // Dashboard update every ~2s
               //if time.since(client.last_display_update) > 2 * time.Second {
               //        client.last_display_update = time.now()
               //        render_dashboard(client)
               //}
       }
}

@(private)
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
       logd("connect_gateway: connecting to %s", base_url)
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
       logd("connect_gateway: connected, session=%s", client.session_id)

       sync.lock(&client.state_mutex)
       client.is_running = true
       sync.unlock(&client.state_mutex)
       client.received_ack = true
       return true
}
