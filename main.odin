package main

import "core:os"
import "core:fmt"
import curl "vendor:curl"
import "core:flags"

import "commands"
import dungeon "commands/dungeon"
import discord "discord"

Options :: struct {
	token:    string `args:"name=token,required" usage:"Your discord bot token"`,
	shard_id: int    `args:"name=shard-id" usage:"The shard ID of this instance"`,
	shards:   int    `args:"name=shards" usage:"The total number of shards"` ,
	db_path:  string `args:"name=db-path" usage:"Path to the SQLite database file"`,
	verbose:  bool   `args:"name=verbose" usage:"Enable verbose debug logging"`,
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
	db_path := opt.db_path
	if db_path == "" do db_path = "bot.db"

	if !discord.client_init(&client, {
		token      = opt.token,
		shard_id   = opt.shard_id,
		num_shards = opt.shards,
		db_path    = db_path,
	}) {
		fmt.eprintln("Failed to initialize Discord client")
		return
	}
	defer discord.client_destroy(&client)

	commands.register_echo_commands(&client)
	commands.register_ping_commands(&client)
	commands.register_rank_commands(&client)
	commands.register_leaderboard_commands(&client)
	dungeon.set_debug(opt.verbose)
	dungeon.register_commands(&client)

	discord.client_run(&client)
}
