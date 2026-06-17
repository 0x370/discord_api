package commands

import "core:fmt"
import "core:strings"

import discord "../discord"

register_leaderboard_commands :: proc(client: ^discord.Client) {
	discord.on_command(client, "leaderboard", "Top 10 users by XP", proc(ctx: ^discord.Command_Context) {
		discord.defer_response(ctx, false)

		leaderboard, ok := discord.db_user_get_leaderboard(&ctx.client.db, 10, context.temp_allocator)
		if !ok || len(leaderboard) == 0 {
			discord.edit_original_response(ctx.client, ctx.interaction.token, "No leaderboard data yet! Start chatting to earn XP.")
			return
		}

		buf: strings.Builder
		strings.builder_init(&buf, context.temp_allocator)
		strings.write_string(&buf, "**Top 10 Leaderboard**\n")
		for entry, i in leaderboard {
			xp_next := discord.xp_for_level(entry.level + 1)
			name := entry.username != "" ? entry.username : entry.user_id
			strings.write_string(&buf, fmt.tprintf("%v. %s — Level %v (%v/%v XP)\n", i + 1, name, entry.level, entry.xp, xp_next))
		}
		discord.edit_original_response(ctx.client, ctx.interaction.token, strings.to_string(buf))
	})
}
