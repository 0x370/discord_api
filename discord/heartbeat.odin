package discord

import "core:fmt"
import "core:math/rand"
import "core:sync"


import "core:time"

identify_check :: proc(client: ^Client) -> bool {
	sync.lock(&client.identify_mutex)
	defer sync.unlock(&client.identify_mutex)

	now := time.now()
	cutoff_24h := time.time_add(now, -24 * time.Hour)
	cutoff_5s := time.time_add(now, -5 * time.Second)

	write_idx := 0
	recent_count := 0

	for i in 0 ..< len(client.identify_log) {
		ts := client.identify_log[i]
		if time.diff(ts, cutoff_24h) > 0 {
			// Older than 24h — discard
			continue
		}
		client.identify_log[write_idx] = ts
		write_idx += 1

		if time.diff(ts, cutoff_5s) <= 0 {
			recent_count += 1
		}
	}
	resize(&client.identify_log, write_idx)

	if write_idx >= 1000 {
		fmt.eprintln("IDENTIFY rate limit reached: 1000/24h")
		return false
	}

	if client.max_concurrency > 0 && recent_count >= client.max_concurrency {
		fmt.eprintfln("IDENTIFY concurrency limit reached: %d in last 5s", recent_count)
		return false
	}

	return true
}

heartbeat_thread_proc :: proc(data: rawptr) {
       client := (^Client)(data)
       gen := client.heartbeat_gen

       // Jitter: sleep a random fraction of the heartbeat interval on first iteration
       interval_ms := client.heartbeat_interval > 0 ? client.heartbeat_interval : 45000
       jitter := int(f64(interval_ms) * rand.float64())
       time.sleep(time.Duration(jitter) * time.Millisecond)
       logd("heartbeat: thread started, gen=%d jitter=%dms interval=%dms", gen, jitter, interval_ms)

       for {
               sync.lock(&client.state_mutex)
               if !client.is_running || client.heartbeat_gen != gen {
                       sync.unlock(&client.state_mutex)
                       return
               }
               sync.unlock(&client.state_mutex)

               interval_ms = client.heartbeat_interval > 0 ? client.heartbeat_interval : 45000
               time.sleep(time.Duration(interval_ms) * time.Millisecond)

               sync.lock(&client.state_mutex)
               if !client.is_running || client.heartbeat_gen != gen {
                       sync.unlock(&client.state_mutex)
                       return
               }
               sync.unlock(&client.state_mutex)

               sync.lock(&client.ack_mutex)
               if !client.received_ack {
                       fmt.println("Missed heartbeat ack! reconnecting...")
                       sync.lock(&client.state_mutex)
                       client.is_running = false
                       client.is_reconnecting = true
                       sync.unlock(&client.state_mutex)
                       sync.unlock(&client.ack_mutex)
                       return
               }
               client.received_ack = false
               sync.unlock(&client.ack_mutex)

               sync.lock(&client.sequence_mutex)
               current_seq := client.last_sequence
               sync.unlock(&client.sequence_mutex)

               sync.lock(&client.heartbeat_send_mutex)
               client.heartbeat_send_time = time.now()
               sync.unlock(&client.heartbeat_send_mutex)
               logd("heartbeat: sending ping seq=%v", current_seq)

               ping := Heartbeat_Payload {
                       op = .OP_HEARTBEAT,
                       d  = current_seq,
               }

               queue_outbound_payload(client, ping)
       }
}
