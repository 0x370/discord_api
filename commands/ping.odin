package commands

import "core:fmt"
import "core:time"

import discord "../discord"

register_ping_commands :: proc(client: ^discord.Client) {
	discord.on_command(client, "ping", "Check bot latency", proc(ctx: ^discord.Command_Context) {
		queue_ns := time.diff(ctx.received_at, ctx.started_at)
		parse_ns := time.diff(ctx.started_at, ctx.parsed_at)

		defer_start := time.now()
		discord.defer_response(ctx, false)
		defer_end := time.now()

		net_ns := time.diff(defer_start, defer_end)
		total_ns := time.diff(ctx.received_at, defer_end)
		other_ns := total_ns - queue_ns - parse_ns - net_ns

		reply := fmt.tprintf("Pong! `queue=%.2fms | parse=%.2fms | net=%.2fms | other=%.2fms | total=%.2fms`",
			f64(queue_ns) / f64(time.Millisecond),
			f64(parse_ns) / f64(time.Millisecond),
			f64(net_ns) / f64(time.Millisecond),
			f64(other_ns) / f64(time.Millisecond),
			f64(total_ns) / f64(time.Millisecond))

		discord.edit_original_response(ctx.client, ctx.interaction.token, reply)
	})
}
