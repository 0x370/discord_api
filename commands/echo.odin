package commands

import discord "../discord"

register_echo_commands :: proc(client: ^discord.Client) {
	discord.on_command(client, "echo_guild", "Echo back your message", proc(ctx: ^discord.Command_Context) {
		msg := discord.get_string(ctx, "message")
		discord.respond(ctx, msg)
	},
		{type = .STRING, name = "message", description = "The message to echo back", required = true},
	)
}
