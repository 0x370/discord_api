package main

import "core:os"
import "core:fmt"
import "core:time"
import curl "vendor:curl"
import "core:flags"

import discord "discord"

Options :: struct {
	token:    string `args:"name=token,required" usage:"Your discord bot token"`,
	shard_id: int    `args:"name=shard-id" usage:"The shard ID of this instance"`,
	shards:   int    `args:"name=shards" usage:"The total number of shards"` ,
}

main :: proc() {
	opt: Options
	flags.parse_or_exit(&opt, os.args, .Unix)

	if curl.global_init(curl.GLOBAL_ALL) != .E_OK {
		fmt.eprintln("Failed to initialize libcurl globally")
		return
	}
	defer curl.global_cleanup()

	client: discord.Client
	if !discord.client_init(&client, {
		token      = opt.token,
		shard_id   = opt.shard_id,
		num_shards = opt.shards,
	}) {
		fmt.eprintln("Failed to initialize Discord client")
		return
	}
	defer discord.client_destroy(&client)

	discord.on_command(&client, "echo_guild", "Echo back your message", proc(ctx: ^discord.Command_Context) {
		msg := discord.get_string(ctx, "message")
		discord.respond(ctx, msg)
	},
		{type = .STRING, name = "message", description = "The message to echo back", required = true},
	)

	discord.on_command(&client, "ping", "Check bot latency", proc(ctx: ^discord.Command_Context) {
		_, net_ns := discord.defer_response(ctx, false)
		defer_end := time.now()

		queue_ns := time.diff(ctx.received_at, ctx.started_at)
		parse_ns := time.diff(ctx.started_at, ctx.parsed_at)
		total_ns := time.diff(ctx.received_at, defer_end)
		other_ns := total_ns - queue_ns - parse_ns - time.Duration(net_ns)

		reply := fmt.tprintf("Pong! `queue=%.2fms | parse=%.2fms | net=%.2fms | other=%.2fms | total=%.2fms`",
			f64(queue_ns) / f64(time.Millisecond),
			f64(parse_ns) / f64(time.Millisecond),
			f64(net_ns) / f64(time.Millisecond),
			f64(other_ns) / f64(time.Millisecond),
			f64(total_ns) / f64(time.Millisecond))

		discord.edit_original_response(ctx.client, ctx.interaction.token, reply)
	})

	discord.client_run(&client)
}