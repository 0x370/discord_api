package dungeon

import "core:fmt"
import "core:time"

import discord "../../discord"

@(private)
handle_daily :: proc(ctx: ^discord.Command_Context) {
	user_id := get_user_id(ctx)

	db := &ctx.client.db
	player, pok := require_player(ctx, db, user_id)
	if !pok do return

	now := time.now()
	day_ns := 24 * time.Hour

	if player.last_daily_claim != 0 {
		elapsed := time.diff(time.from_nanoseconds(player.last_daily_claim), now)
		if elapsed < day_ns {
			remaining := day_ns - elapsed
			hours := int(remaining / time.Hour)
			minutes := int((remaining % time.Hour) / time.Minute)
			discord.respond(ctx, fmt.tprintf("⏳ You already claimed your daily! Come back in **%dh %dm**.", hours, minutes))
			return
		}
		if elapsed > 48 * time.Hour {
			player.daily_streak = 0
		}
	}
	gold_reward := 30 + player.daily_streak * 10
	player.gold += gold_reward
	player.char_lootboxes += 2
	player.last_daily_claim = time.to_unix_nanoseconds(now)
	player.daily_streak += 1

	if !db_save_player(db, &player) { logd("[daily] FAILED to save player") }

	discord.respond(ctx, fmt.tprintf(
		"☀️ **Daily Reward — Day %d!**\n" +
		"+%d 💰 gold\n" +
		"+2 🎭 character lootboxes",
		player.daily_streak, gold_reward,
	))
}

@(private)
register_daily_handlers :: proc(client: ^discord.Client) {
	discord.on_command(client, "daily", "Claim your daily gold and lootboxes", handle_daily)
}
