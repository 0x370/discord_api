package dungeon

import "core:slice"
import "core:strconv"

import discord "../../discord"
register_nav_handlers :: proc(client: ^discord.Client) {
	// --- Gallery navigation ---
	discord.on_component(client, "dungeon_char_prev", proc(ctx: ^discord.Component_Context) {
		_handle_gallery_nav(ctx, "char", false)
	})
	discord.on_component(client, "dungeon_char_next", proc(ctx: ^discord.Component_Context) {
		_handle_gallery_nav(ctx, "char", true)
	})
	discord.on_component(client, "dungeon_item_prev", proc(ctx: ^discord.Component_Context) {
		_handle_gallery_nav(ctx, "item", false)
	})
	discord.on_component(client, "dungeon_item_next", proc(ctx: ^discord.Component_Context) {
		_handle_gallery_nav(ctx, "item", true)
	})

	// --- List navigation ---
	discord.on_component(client, "dungeon_char_list_prev", proc(ctx: ^discord.Component_Context) {
		_handle_list_nav(ctx, "char", false)
	})
	discord.on_component(client, "dungeon_char_list_next", proc(ctx: ^discord.Component_Context) {
		_handle_list_nav(ctx, "char", true)
	})
	discord.on_component(client, "dungeon_item_list_prev", proc(ctx: ^discord.Component_Context) {
		_handle_list_nav(ctx, "item", false)
	})
	discord.on_component(client, "dungeon_item_list_next", proc(ctx: ^discord.Component_Context) {
		_handle_list_nav(ctx, "item", true)
	})

	// --- Lootbox results navigation ---
	discord.on_component(client, "dungeon_lootbox_prev", proc(ctx: ^discord.Component_Context) {
		_handle_lootbox_nav(ctx, false)
	})
	discord.on_component(client, "dungeon_lootbox_next", proc(ctx: ^discord.Component_Context) {
		_handle_lootbox_nav(ctx, true)
	})
}

@(private)
_handle_gallery_nav :: proc(ctx: ^discord.Component_Context, kind: string, next: bool) {
	user_id := get_component_user_id(ctx)

	page, total := _parse_page_from_embed(ctx)
	if total <= 1 {
		discord.defer_component_update(ctx)
		return
	}

	new_page := next ? page + 1 : page - 1
	if new_page < 1 do new_page = 1
	if new_page > total do new_page = total

	db := &ctx.client.db
	switch kind {
	case "char":
		chars := _get_or_cache(&gallery_char_cache, user_id, db, db_get_characters,
			proc(items: []CollectedCharacter) { slice.sort_by(items, proc(a, b: CollectedCharacter) -> bool { return a.tier < b.tier }) })
		char := chars[new_page - 1]
		img_url := get_image_url(.Character, char.tier, char.weapon_compat, "", .SWORD)
		embed, comps := build_character_embed(char, new_page, len(chars), img_url)
		discord.respond_component(ctx, {embed}, comps)
	case "item":
		items := _get_or_cache(&gallery_item_cache, user_id, db, db_get_items,
			proc(itms: []ItemInstance) { slice.sort_by(itms, proc(a, b: ItemInstance) -> bool { return a.tier < b.tier }) })
		if new_page < 1 || new_page > len(items) {
			discord.defer_component_update(ctx); return
		}
		img_url := get_image_url(.Item, items[new_page - 1].tier, .SWORD, "", items[new_page - 1].item_type)
		embed, comps := build_item_embed(items[new_page - 1], new_page, len(items), img_url)
		discord.respond_component(ctx, {embed}, comps)
	}
}

@(private)
_handle_list_nav :: proc(ctx: ^discord.Component_Context, kind: string, next: bool) {
	user_id := get_component_user_id(ctx)

	page, _ := _parse_page_from_embed(ctx)
	new_page := next ? page + 1 : page - 1
	if new_page < 1 do new_page = 1

	switch kind {
	case "char":
		chars, has := gallery_char_cache[user_id]
		if !has do return
		embed, comps := build_character_list_embed(chars, new_page)
		discord.respond_component(ctx, {embed}, comps)
	case "item":
		items, has := gallery_item_cache[user_id]
		if !has do return
		embed, comps := build_item_list_embed(items, new_page)
		discord.respond_component(ctx, {embed}, comps)
	}
}

@(private)
_handle_lootbox_nav :: proc(ctx: ^discord.Component_Context, next: bool) {
	user_id := get_component_user_id(ctx)

	page, _ := _parse_page_from_embed(ctx)
	new_page := next ? page + 1 : page - 1
	if new_page < 1 do new_page = 1

	items, has := lootbox_item_cache[user_id]
	if !has do return

	best := items[0]
	for it in items do if it.tier < best.tier do best = it
	img_url := get_image_url(.Item, best.tier, .SWORD, "", best.item_type)
	embed, comps := build_lootbox_item_embed(items, new_page, img_url)
	discord.respond_component(ctx, {embed}, comps)
}

@(private)
_parse_page_from_embed :: proc(ctx: ^discord.Component_Context) -> (page: int, total: int) {
	if len(ctx.interaction.message.embeds) == 0 do return 1, 1
	title := ctx.interaction.message.embeds[0].title
	if title == "" do return 1, 1
	return _parse_page_total(title)
}

@(private)
_parse_page_total :: proc(s: string) -> (page: int, total: int) {
	paren_start := -1; slash_pos := -1; paren_end := -1
	for ch, i in s {
		if ch == '(' do paren_start = i
		if ch == '/' && paren_start >= 0 do slash_pos = i
		if ch == ')' && slash_pos >= 0 { paren_end = i; break }
	}
	if paren_start >= 0 && slash_pos > paren_start && paren_end > slash_pos {
		p, _ := strconv.parse_i64(s[paren_start+1:slash_pos])
		t, _ := strconv.parse_i64(s[slash_pos+1:paren_end])
		page = int(p); total = int(t)
	}
	if page < 1 do page = 1
	if total < 1 do total = 1
	return
}
