package dungeon

import "core:fmt"
import discord "../../discord"

@(private)
handle_class :: proc(ctx: ^discord.Command_Context) {
	user_id := get_user_id(ctx)
	choice := discord.get_string(ctx, "class")
	class: Class_Type = .ATTACKER
	if choice == "healer" do class = .HEALER
	db := &ctx.client.db
	player, pok := require_player(ctx, db, user_id)
	if !pok do return
	player.class = class
	if !db_save_player(db, &player) { logd("[class] FAILED to save class change") }
	discord.respond(ctx, fmt.tprintf("Class set to **%s** %s!", CLASS_NAMES[class], CLASS_EMOJIS[class]))
}

@(private)
register_class_handlers :: proc(client: ^discord.Client) {
	discord.on_command(client, "class", "Set your dungeon class", handle_class,
		{type = .STRING, name = "class", description = "attacker or healer", required = true, choices = {
			{name = "Attacker", value = "attacker"},
			{name = "Healer", value = "healer"},
		}},
	)
}
