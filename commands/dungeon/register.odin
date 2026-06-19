package dungeon

import discord "../../discord"

register_commands :: proc(client: ^discord.Client) {
	init_sessions()

	// Run DB migrations (tier rename etc.)
	db_run_migrations(&client.db)

	// Register all command and component handlers
	register_dungeon_handlers(client)
	register_profile_handlers(client)
	register_class_handlers(client)
	register_gallery_handlers(client)
	register_lootbox_handlers(client)
	register_sell_handlers(client)
	register_daily_handlers(client)
	register_rates_handlers(client)
	register_combat_handlers(client)
	register_nav_handlers(client)
	register_sell_flow_handlers(client)
}
