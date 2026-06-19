package dungeon

import "core:fmt"
import "core:strconv"
import "core:strings"

import discord "../../discord"

@(private)
handle_profile_view :: proc(ctx: ^discord.Command_Context) {
	user_id := get_user_id(ctx)
	player, pok := require_player(ctx, &ctx.client.db, user_id)
	if !pok do return

	chars := db_get_characters(&ctx.client.db, user_id)
	char: CollectedCharacter
	for c in chars do if c.id == player.equipped_char_id { char = c; break }
	if char.id == 0 && len(chars) == 0 {
		discord.respond(ctx, "No characters yet! Try `/dungeon` first.")
		return
	}
	if char.id == 0 { char = chars[0] }
	items := load_equipped_items(&ctx.client.db, &player)
	img_url := get_image_url(.Character, char.tier, char.weapon_compat, "", .SWORD)
	embed := build_profile_embed(&player, char, items, img_url)
	discord.respond_with_embed(ctx, "", {embed})
}

@(private)
handle_profile_equip :: proc(ctx: ^discord.Command_Context) {
	user_id := get_user_id(ctx)
	db := &ctx.client.db
	player, pok := require_player(ctx, db, user_id)
	if !pok do return

	ids_str := discord.get_string(ctx, "ids")
	equipped: int
	tokens, _ := strings.fields(ids_str, context.temp_allocator)
	for token in tokens {
		item_id, parsed_ok := strconv.parse_i64(token)
		if !parsed_ok do continue
		item, iok := db_get_item_by_id(db, user_id, item_id)
		if !iok do continue
		switch ITEM_CATEGORY[item.item_type] {
		case .WEAPON: player.weapon_id = item_id
		case .HEAD:   player.head_id   = item_id
		case .CHEST:  player.chest_id  = item_id
		case .LEGS:   player.legs_id   = item_id
		case .BOOTS:  player.boots_id  = item_id
		}
		equipped += 1
	}
	if !db_save_player(db, &player) { logd("[equip] FAILED to save items") }
	if equipped == 0 {
		discord.respond(ctx, "No valid items found to equip.")
	} else {
		discord.respond(ctx, fmt.tprintf("Equipped %d item(s)!", equipped))
	}
}

@(private)
handle_profile_set :: proc(ctx: ^discord.Command_Context) {
	user_id := get_user_id(ctx)
	db := &ctx.client.db
	player, pok := require_player(ctx, db, user_id)
	if !pok do return

	char_id_str := discord.get_string(ctx, "character_id")
	char_id, parsed_ok := strconv.parse_i64(char_id_str)
	if !parsed_ok { discord.respond(ctx, "Invalid character ID format."); return }
	chars := db_get_characters(db, user_id)
	found: bool
	for c in chars do if c.id == char_id { found = true; break }
	if !found { discord.respond(ctx, "Character not found in your collection."); return }
	player.equipped_char_id = char_id
	if !db_save_player(db, &player) { logd("[profile set] FAILED to save equipped char") }
	discord.respond(ctx, fmt.tprintf("Equipped character #%d!", char_id))
}
@(private)
register_profile_handlers :: proc(client: ^discord.Client) {
	discord.on_subcommand(client, "profile", "View your dungeon profile", "view", "View your stats", handle_profile_view)
	discord.on_subcommand(client, "profile", "Manage your profile", "equip", "Equip items (space-separated IDs)", handle_profile_equip,
		{type = .STRING, name = "ids", description = "Space-separated item IDs", required = true},
	)
	discord.on_subcommand(client, "profile", "Manage your profile", "set", "Set equipped character", handle_profile_set,
		{type = .STRING, name = "character_id", description = "The character ID to equip", required = true},
	)
}
