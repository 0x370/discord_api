package discord_api

import "core:strconv"
import "core:time"

DISCORD_EPOCH :: 1420070400000

Snowflake :: string

Snowflake_Bits :: bit_field u64 {
	increment:  u16 | 12, // Bits 0 to 11
	process_id: u8  | 5, // Bits 12 to 16
	worker_id:  u8  | 5, // Bits 17 to 21
	timestamp:  u64 | 42, // Bits 22 to 63
}

parse_snowflake :: proc(sf: Snowflake) -> (Snowflake_Bits, bool) #optional_ok {
	val, ok := strconv.parse_u64(string(sf), 10)
	if !ok do return Snowflake_Bits{}, false
	return transmute(Snowflake_Bits)val, true
}

snowflake_to_time :: proc(sf: Snowflake) -> time.Time {
	snowflake_bits := parse_snowflake(sf)

	unix_ms := snowflake_bits.timestamp + DISCORD_EPOCH

	seconds := i64(unix_ms / 1000)
	nanoseconds := i64((unix_ms % 1000) * 1_000_000)

	return time.unix(seconds, nanoseconds)
}

time_to_snowflake :: proc(t: time.Time) -> Snowflake_Bits {
	total_ns := time.to_unix_nanoseconds(t)
	unix_ms := total_ns / 1_000_000

	sf: Snowflake_Bits
	if unix_ms >= DISCORD_EPOCH {
		sf.timestamp = u64(unix_ms - DISCORD_EPOCH)
	}
	return sf
}
