package commands

import "core:fmt"

import discord "../discord"

register_rank_commands :: proc(client: ^discord.Client) {
	discord.on_command(client, "rank", "Check your XP and level", proc(ctx: ^discord.Command_Context) {
		user_id := ctx.interaction.member.user.id
		if user_id == "" do user_id = ctx.interaction.user.id

		username := ctx.interaction.member.nick
		if username == "" do username = ctx.interaction.member.user.username
		if username == "" do username = ctx.interaction.user.username

		xp, level, ok := discord.db_user_get_stats(&ctx.client.db, string(user_id))
		if !ok {
			discord.respond(ctx, "You haven't earned any XP yet! Start chatting to level up.")
			return
		}

		xp_for_next := discord.xp_for_level(level + 1)
		discord.respond(ctx, fmt.tprintf("**%s** — Level %v (%v/%v XP)", username, level, xp, xp_for_next))
	})
}
