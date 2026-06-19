package dungeon

import "core:strconv"
import "core:strings"
import "core:sync"
import api "../../discord/api"
import discord "../../discord"

@(private)
handle_lootbox :: proc(ctx: ^discord.Command_Context) {
	user_id := get_user_id(ctx)
	kind := discord.get_string(ctx, "type")

	if kind == "character" {
		db := &ctx.client.db
		player, pok := require_player(ctx, db, user_id)
		if !pok do return
		if player.char_lootboxes <= 0 {
			discord.respond(ctx, "You have no character lootboxes! Use `/daily` to earn them.")
			return
		}
		player.char_lootboxes -= 1
		if !db_save_player(db, &player) {
			logd("[lootbox] FAILED to save player after deducting char lootbox")
		}
		discord.defer_response(ctx, false)
		results := generate_character_lootbox()
		gacha := results[:]
		logd("[lootbox] character — tier distribution: ")
		for r in gacha do logd("  %s (%s %s)", r.name, TIER_LABELS[r.tier], WEAPON_COMPAT_NAMES[r.weapon_compat])
		// Find best character for thumbnail
		best := gacha[0]
		for r in gacha do if r.tier < best.tier do best = r
		img_url := get_image_url(.Character, best.tier, best.weapon_compat, "", .SWORD)
		embed, _ := build_lootbox_result_embed(gacha, img_url)
		discord.edit_original_response(ctx.client, ctx.interaction.token, "")
		discord.patch_original_response(ctx.client, ctx.interaction.token, api.InteractionCallbackData{embeds = {embed}})
		for r in gacha {
			if !db_insert_character(db, user_id, r.name, r.tier, r.weapon_compat, r.ability_name, r.ability_desc) {
				logd("[lootbox] FAILED to insert character: %s", r.name)
			}
		}
		delete_key(&gallery_char_cache, user_id)
	} else {
		db := &ctx.client.db
		player, pok := require_player(ctx, db, user_id)
		if !pok do return
		if player.item_lootboxes <= 0 {
			discord.respond(ctx, "You have no item lootboxes! Earn them in `/dungeon`.")
			return
		}
		count_str := discord.get_string(ctx, "count")
		count := 1
		if count_str != "" {
			if c, ok := strconv.parse_i64(count_str); ok && c > 0 { count = int(c) }
		}
		if count > player.item_lootboxes do count = player.item_lootboxes
		player.item_lootboxes -= count
		if !db_save_player(db, &player) {
			logd("[lootbox] FAILED to save player after deducting item lootbox")
		}
		discord.defer_response(ctx, false)
		logd("[lootbox] item — opening %d box(es)", count)
		all_items := make([dynamic]ItemGachaResult, context.temp_allocator)
		for _ in 0 ..< count {
			results := generate_item_lootbox(player.current_floor)
			for r in results do append(&all_items, r)
			for r in results {
				if !db_insert_item(db, user_id, ItemInstance{
					user_id = user_id,
					item_type = r.item_type, tier = r.tier,
					base_atk = r.base_atk, base_def = r.base_def,
					bonus_hp = r.bonus_hp, bonus_atk = r.bonus_atk,
					bonus_def = r.bonus_def, bonus_spd = r.bonus_spd,
					bonus_crit = r.bonus_crit,
					special = r.special,
					floor = r.floor,
				}) {
					logd("[lootbox] FAILED to insert item: %s", ITEM_NAMES[r.item_type])
				}
			}
		}
		sync.lock(&dungeon_mutex)
		lootbox_item_cache[strings.clone(user_id)] = all_items[:]
		sync.unlock(&dungeon_mutex)
		// Find best item for thumbnail
		best := all_items[0]
		for it in all_items do if it.tier < best.tier do best = it
		img_url := get_image_url(.Item, best.tier, .SWORD, "", best.item_type)
		embed, comps := build_lootbox_item_embed(all_items[:], 1, img_url)
		discord.edit_original_response(ctx.client, ctx.interaction.token, "")
		discord.patch_original_response(ctx.client, ctx.interaction.token, api.InteractionCallbackData{embeds = {embed}, components = comps})
	}
}

@(private)
register_lootbox_handlers :: proc(client: ^discord.Client) {
	discord.on_command(client, "lootbox", "Open a lootbox", handle_lootbox,
		{type = .STRING, name = "type", description = "character or item", required = true, choices = {
			{name = "Character", value = "character"},
			{name = "Item", value = "item"},
		}},
		{type = .STRING, name = "count", description = "How many to open (items only)", required = false},
	)
}
