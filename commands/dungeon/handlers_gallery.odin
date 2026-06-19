package dungeon

import "core:slice"
import "core:strings"

import discord "../../discord"

@(private)
handle_characters :: proc(ctx: ^discord.Command_Context) {
	user_id := get_user_id(ctx)
	db := &ctx.client.db
	if _, pok := require_player(ctx, db, user_id); !pok do return

	chars := db_get_characters(db, user_id)
	if len(chars) == 0 {
		discord.respond(ctx, "No characters yet! Try `/dungeon` first.")
		return
	}
	slice.sort_by(chars, proc(a, b: CollectedCharacter) -> bool { return a.tier < b.tier })

	gallery_char_cache[strings.clone(user_id)] = chars
	if discord.get_bool(ctx, "list") {
		embed, comps := build_character_list_embed(chars, 1)
		discord.respond_with_components(ctx, "", {embed}, comps)
	} else {
		img_url := get_image_url(.Character, chars[0].tier, chars[0].weapon_compat, "", .SWORD)
		embed, comps := build_character_embed(chars[0], 1, len(chars), img_url)
		discord.respond_with_components(ctx, "", {embed}, comps)
	}
}

@(private)
handle_items :: proc(ctx: ^discord.Command_Context) {
	user_id := get_user_id(ctx)
	db := &ctx.client.db
	if _, pok := require_player(ctx, db, user_id); !pok do return

	items := db_get_items(db, user_id)
	if len(items) == 0 {
		discord.respond(ctx, "No items yet! Try `/dungeon` first.")
		return
	}
	slice.sort_by(items, proc(a, b: ItemInstance) -> bool { return a.tier < b.tier })

	gallery_item_cache[strings.clone(user_id)] = items
	if discord.get_bool(ctx, "list") {
		embed, comps := build_item_list_embed(items, 1)
		discord.respond_with_components(ctx, "", {embed}, comps)
	} else {
		img_url := get_image_url(.Item, items[0].tier, .SWORD, "", items[0].item_type)
		embed, comps := build_item_embed(items[0], 1, len(items), img_url)
		discord.respond_with_components(ctx, "", {embed}, comps)
	}
}

@(private)
register_gallery_handlers :: proc(client: ^discord.Client) {
	discord.on_command(client, "characters", "Browse your collected characters", handle_characters,
		{type = .BOOLEAN, name = "list", description = "Show as 10-per-page list", required = false},
	)
	discord.on_command(client, "items", "Browse your inventory", handle_items,
		{type = .BOOLEAN, name = "list", description = "Show as 10-per-page list", required = false},
	)
}
