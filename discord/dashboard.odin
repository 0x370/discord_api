package discord

import "core:container/queue"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:time"

@(private)
_read_proc_file :: proc(path: string) -> ([]u8, bool) {
	buf: [4096]u8
	fd, err := os.open(path)
	if err != nil do return {}, false
	defer os.close(fd)

	n, read_err := os.read(fd, buf[:])
	if read_err != nil || n <= 0 do return {}, false

	result := make([]u8, n)
	copy(result, buf[:n])
	return result, true
}

@(private)
_read_process_cpu_ticks :: proc() -> (u64, u64) {
	data, ok := _read_proc_file("/proc/self/stat")
	if !ok do return 0, 0
	defer delete(data)

	close_paren := -1
	for i := len(data) - 1; i >= 0; i -= 1 {
		if data[i] == ')' {
			close_paren = i
			break
		}
	}
	if close_paren < 0 || close_paren + 1 >= len(data) do return 0, 0

	pos := close_paren + 1
	field_idx := 0
	utime: u64 = 0
	stime: u64 = 0

	for pos < len(data) && field_idx <= 12 {
		for pos < len(data) && (data[pos] == ' ' || data[pos] == '\t') { pos += 1 }
		if pos >= len(data) do break

		start := pos
		for pos < len(data) && data[pos] != ' ' && data[pos] != '\t' { pos += 1 }

		val, _ := strconv.parse_u64(string(data[start:pos]))
		if field_idx == 11 { utime = val }
		if field_idx == 12 { stime = val }
		field_idx += 1
	}

	return utime, stime
}

@(private)
_read_system_cpu_ticks :: proc() -> u64 {
	data, ok := _read_proc_file("/proc/stat")
	if !ok do return 0
	defer delete(data)

	s := string(data)
	if len(s) < 4 || s[:3] != "cpu" || (len(s) > 3 && s[3] != ' ') do return 0

	pos := 4
	total: u64 = 0

	for pos < len(data) {
		for pos < len(data) && (data[pos] == ' ' || data[pos] == '\t') { pos += 1 }
		if pos >= len(data) || data[pos] == '\n' do break

		start := pos
		for pos < len(data) && data[pos] != ' ' && data[pos] != '\t' && data[pos] != '\n' { pos += 1 }

		val, _ := strconv.parse_u64(string(data[start:pos]))
		total += val
	}

	return total
}

@(private)
_read_memory_kb :: proc() -> int {
	data, ok := _read_proc_file("/proc/self/status")
	if !ok do return 0
	defer delete(data)

	s := string(data)
	target := "VmRSS:"

	for i := 0; i <= len(data) - len(target); i += 1 {
		if s[i:i + len(target)] == target {
			j := i + len(target)
			for j < len(data) && (data[j] == ' ' || data[j] == '\t') { j += 1 }
			start := j
			for j < len(data) && data[j] >= '0' && data[j] <= '9' { j += 1 }
			if j > start {
				val, _ := strconv.parse_int(string(data[start:j]))
				return val
			}
		}
	}

	return 0
}

render_dashboard :: proc(client: ^Client) {
	num_cores := os.processor_core_count()

	utime, stime := _read_process_cpu_ticks()
	proc_ticks := utime + stime
	sys_ticks := _read_system_cpu_ticks()

	proc_delta := proc_ticks - client.prev_proc_ticks
	sys_delta := sys_ticks - client.prev_sys_ticks

	cpu_pct: f64 = 0.0
	if client.prev_sys_ticks > 0 && sys_delta > 0 {
		cpu_pct = f64(proc_delta) / f64(sys_delta) * f64(num_cores) * 100.0
		if cpu_pct > 100.0 * f64(num_cores) { cpu_pct = 100.0 * f64(num_cores) }
	}

	client.prev_proc_ticks = proc_ticks
	client.prev_sys_ticks = sys_ticks

	mem_kb := _read_memory_kb()
	mem_mb := f64(mem_kb) / 1024.0

	guild_count := len(client.known_guilds)
	cached_messages := client.message_cache.count
	registered_commands := len(client.command_registry)
	outbound_queue_size := queue.len(client.outbound_queue)
	thread_count := len(client.worker_pool.threads)
	identifies_24h := len(client.identify_log)

	avg_latency_ms, last_latency_ms := _compute_latency_stats(client)

	uptime := time.since(client.start_time)
	uptime_secs := f64(uptime) / f64(time.Second)

	events_per_sec: f64 = 0.0
	if uptime_secs > 0 {
		events_per_sec = f64(client.total_events) / uptime_secs
	}

	uptime_str := _format_uptime(uptime)

	fmt.eprint("\033[2J\033[H")
	fmt.eprintfln("")
	fmt.eprintfln("  Discord Bot Dashboard [Shard %d/%d]", client.shard_id, client.num_shards)
	fmt.eprintfln("  %s", "────────────────────────────────────────")
	fmt.eprintfln("  %-18s %d", "Servers:", guild_count)
	fmt.eprintfln("  %-18s %d", "Users:", client.total_members)
	fmt.eprintfln("  %-18s %s", "Uptime:", uptime_str)
	fmt.eprintfln("  %-18s %s", "Session ID:", client.session_id)
	fmt.eprintfln("  %s", "────────────────────────────────────────")
	fmt.eprintfln("  %-18s %d", "Total Events:", client.total_events)
	fmt.eprintfln("  %-18s %s", "Last Event:", client.last_event_type)
	fmt.eprintfln("  %-18s %.2f/s", "Event Rate:", events_per_sec)
	fmt.eprintfln("  %-18s %d", "Messages Seen:", client.total_messages)
	fmt.eprintfln("  %-18s %d", "Commands Run:", client.total_commands)
	fmt.eprintfln("  %-18s %d", "REST API Calls:", client.rest_client.total_requests)
	fmt.eprintfln("  %s", "────────────────────────────────────────")
	fmt.eprintfln("  %-18s %d", "Cached Messages:", cached_messages)
	fmt.eprintfln("  %-18s %d", "Reg. Commands:", registered_commands)
	fmt.eprintfln("  %-18s %d", "Outbound Queue:", outbound_queue_size)
	fmt.eprintfln("  %-18s %d/1000", "Identifies (24h):", identifies_24h)
	fmt.eprintfln("  %s", "────────────────────────────────────────")
	fmt.eprintfln("  %-18s %.1f%%  (%d cores)", "CPU:", cpu_pct, num_cores)
	fmt.eprintfln("  %-18s %.1f MB", "Memory:", mem_mb)
	fmt.eprintfln("  %-18s %d", "Worker Threads:", thread_count)
	fmt.eprintfln("  %-18s %s", "Gateway Status:", client.received_ack ? "OK" : "WAITING ACK")
	fmt.eprintfln("  %-18s %.1f ms", "Avg Heartbeat:", avg_latency_ms)
	fmt.eprintfln("  %-18s %.1f ms", "Last Heartbeat:", last_latency_ms)
	fmt.eprintfln("  %s", "────────────────────────────────────────")
}

@(private)
_compute_latency_stats :: proc(client: ^Client) -> (f64, f64) {
	avg_ms: f64 = 0.0
	last_ms: f64 = 0.0
	if len(client.latency_history) > 0 {
		total: time.Duration = 0
		for lat in client.latency_history {
			total += lat
		}
		avg_ms = f64(total / time.Duration(len(client.latency_history))) / f64(time.Millisecond)
		last_ms = f64(client.latency_history[len(client.latency_history) - 1]) / f64(time.Millisecond)
	}
	return avg_ms, last_ms
}

@(private)
_format_uptime :: proc(uptime: time.Duration) -> string {
	total_secs := i64(uptime / time.Second)
	days := total_secs / 86400
	hours := (total_secs % 86400) / 3600
	mins := (total_secs % 3600) / 60
	secs := total_secs % 60

	if days > 0 {
		return fmt.tprintf("%dd %02dh %02dm %02ds", days, hours, mins, secs)
	} else if hours > 0 {
		return fmt.tprintf("%dh %02dm %02ds", hours, mins, secs)
	} else if mins > 0 {
		return fmt.tprintf("%dm %02ds", mins, secs)
	}
	return fmt.tprintf("%ds", secs)
}
