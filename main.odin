package main

import "core:os"
import "core:fmt"
import curl "vendor:curl"
import "core:flags"

import discord "discord"
import api "discord/api"

Options :: struct {
	token: string `args:"name=token,required" usage:"Your discord bot token"`
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
	if !discord.client_init(&client, {token = opt.token}) {
		fmt.eprintln("Failed to initialize Discord client")
		return
	}
	defer discord.client_destroy(&client)

	discord.on_command(&client, "echo", "Echo back your message", proc(ctx: ^discord.Command_Context) {
		msg := discord.get_string(ctx, "message")
		discord.respond(ctx, msg)
	},
		{type = .STRING, name = "message", description = "The message to echo back", required = true},
	)

	discord.client_run(&client)
}