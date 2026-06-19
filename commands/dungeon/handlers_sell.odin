package dungeon

import "core:fmt"
import "core:strings"
import "core:sync"
import "core:strconv"

import api "../../discord/api"
import discord "../../discord"

// --- /sell handler registration ---

@(private)
register_sell_handlers :: proc(client: ^discord.Client) {
	discord.on_command(client, "sell", "Sell items or characters for gold", handle_sell,
		{type = .STRING, name = "type", description = "item or character", required = false, choices = {
			{name = "Item",      value = "item"},
			{name = "Character", value = "character"},
		}},
		{type = .STRING, name = "tier", description = "Sell all of this tier", required = false, choices = {
			{name = "Common",    value = "Common"},
			{name = "Uncommon",  value = "Uncommon"},
			{name = "Rare",      value = "Rare"},
			{name = "Legendary", value = "Legendary"},
			{name = "Mythical",  value = "Mythical"},
		}},
		{type = .STRING, name = "ids", description = "Space-separated IDs to sell", required = false},
	)
}

// --- /sell handler ---

@(private)
handle_sell :: proc(ctx: ^discord.Command_Context) {
	user_id := get_user_id(ctx)
	db := &ctx.client.db

	_, pok := require_player(ctx, db, user_id)
	if !pok do return

	kind := discord.get_string(ctx, "type")
	tier_filter := discord.get_string(ctx, "tier")
	ids_str     := discord.get_string(ctx, "ids")

	if tier_filter == "" && ids_str == "" {
		discord.respond(ctx, "Provide a tier filter (e.g. `tier:Common`) or space-separated IDs (e.g. `ids:1 2 3`).")
		return
	}

	if kind == "character" {
		chars := db_get_characters(db, user_id)
		if len(chars) <= 1 {
			discord.respond(ctx, "You must keep at least one character! You can't sell your only character.")
			return
		}

		sell_chars := make([dynamic]CollectedCharacter, context.temp_allocator)

		if ids_str != "" {
			tokens, _ := strings.fields(ids_str, context.temp_allocator); for token in tokens {
				char_id, parsed_ok := strconv.parse_i64(token)
				if !parsed_ok do continue
				for c in chars {
					if c.id == char_id {
						append(&sell_chars, c)
						break
					}
				}
			}
		}

		if tier_filter != "" {
			target_tier: Tier = .COMMON
			for t in TIER_COLLECTION_ORDER {
				if TIER_LABELS[t] == tier_filter { target_tier = t; break }
			}
			for c in chars {
				if c.tier == target_tier {
					already := false
					for s in sell_chars do if s.id == c.id { already = true; break }
					if !already do append(&sell_chars, c)
				}
			}
		}

		if len(sell_chars) == 0 {
			discord.respond(ctx, "No matching characters found to sell.")
			return
		}

		// Enforce: can't sell ALL characters
		if len(sell_chars) >= len(chars) {
			discord.respond(ctx, "You must keep at least one character! Remove some from the sale.")
			return
		}

		total_gold := 0
		for c in sell_chars do total_gold += _sell_price_char(c)

		has_rare := false
		for c in sell_chars do if c.tier <= .LEGENDARY { has_rare = true; break }

		session := _new_sell_session_from(user_id, sell_chars[:], total_gold, true)

		discord.defer_response(ctx, false)
		embed, row := _build_sell_confirm_simple(&session)
		if has_rare {
			embed, row = _build_sell_confirm_first(&session)
		}
		data := api.InteractionCallbackData{embeds = {embed}, components = {row}}
		mid, _ := discord.patch_original_response(ctx.client, ctx.interaction.token, data)
		sync.lock(&dungeon_mutex)
		if mid != "" {
			session.message_id = strings.clone(mid)
			session_owners[strings.clone(mid)] = strings.clone(user_id)
		}
		key := strings.clone(user_id)
		sell_sessions[key] = session
		sync.unlock(&dungeon_mutex)
	} else {
		// Default: sell items
		items := db_get_items(db, user_id)
		if len(items) == 0 {
			discord.respond(ctx, "You have no items to sell.")
			return
		}

		sell_items := make([dynamic]ItemInstance, context.temp_allocator)

		if ids_str != "" {
			tokens, _ := strings.fields(ids_str, context.temp_allocator); for token in tokens {
				item_id, parsed_ok := strconv.parse_i64(token)
				if !parsed_ok do continue
				for it in items {
					if it.id == item_id {
						append(&sell_items, it)
						break
					}
				}
			}
		}

		if tier_filter != "" {
			target_tier: Tier = .COMMON
			for t in TIER_COLLECTION_ORDER {
				if TIER_LABELS[t] == tier_filter { target_tier = t; break }
			}
			for it in items {
				if it.tier == target_tier {
					already := false
					for s in sell_items do if s.id == it.id { already = true; break }
					if !already do append(&sell_items, it)
				}
			}
		}

		if len(sell_items) == 0 {
			discord.respond(ctx, "No matching items found to sell.")
			return
		}

		total_gold := 0
		for it in sell_items do total_gold += _sell_price(it)

		has_rare := false
		for it in sell_items do if it.tier <= .LEGENDARY { has_rare = true; break }

		session := _new_sell_session_from(user_id, sell_items[:], total_gold, false)

		discord.defer_response(ctx, false)
		embed, row := _build_sell_confirm_simple(&session)
		if has_rare {
			embed, row = _build_sell_confirm_first(&session)
		}
		data := api.InteractionCallbackData{embeds = {embed}, components = {row}}
		mid, _ := discord.patch_original_response(ctx.client, ctx.interaction.token, data)
		sync.lock(&dungeon_mutex)
		if mid != "" {
			session.message_id = strings.clone(mid)
			session_owners[strings.clone(mid)] = strings.clone(user_id)
		}
		key := strings.clone(user_id)
		sell_sessions[key] = session
		sync.unlock(&dungeon_mutex)
	}
}

// --- Sell helpers ---

@(private)
_new_sell_session_from :: proc(user_id: string, items: []$T, total_gold: int, is_char: bool) -> Sell_Session {
	ids := make([]i64, len(items), context.allocator)
	for it, i in items do ids[i] = it.id
	return Sell_Session{
		user_id    = strings.clone(user_id),
		item_ids   = ids,
		item_count = len(items),
		total_gold = total_gold,
		is_char    = is_char,
	}
}

@(private)
_build_sell_confirm_simple :: proc(session: ^Sell_Session) -> (api.Embed, api.Component) {
	noun     := session.is_char ? "character" : "item"
	noun_cap := session.is_char ? "Character" : "Item"
	embed := api.Embed{
		title       = fmt.tprintf("💰 Sell %ss?", noun_cap),
		description = fmt.tprintf("Sell **%d %s(s)** for **%d gold**?", session.item_count, noun, session.total_gold),
		color       = 0xe67e22,
	}
	btns := [2]api.Component{
		api.ButtonComponent{type = .BUTTON, style = .SUCCESS, custom_id = "dungeon_sell_exec", label = "✅ Confirm Sell"},
		api.ButtonComponent{type = .BUTTON, style = .DANGER,  custom_id = "dungeon_sell_cancel", label = "❌ Cancel"},
	}
	row := api.ActionRowComponent{type = .ACTION_ROW, components = btns[:]}
	return embed, row
}

@(private)
_build_sell_confirm_first :: proc(session: ^Sell_Session) -> (api.Embed, api.Component) {
	noun     := session.is_char ? "character" : "item"
	noun_cap := session.is_char ? "Character" : "Item"
	embed := api.Embed{
		title       = fmt.tprintf("⚠️ Sell %ss?", noun_cap),
		description = fmt.tprintf("You are about to sell **%d %s(s)** for **%d gold**.\n\n🟠 **WARNING:** This batch contains **Legendary or Mythical** %ss!",
			session.item_count, noun, session.total_gold, noun),
		color       = 0xe74c3c,
	}
	btns := [2]api.Component{
		api.ButtonComponent{type = .BUTTON, style = .PRIMARY, custom_id = "dungeon_sell_confirm_first", label = "🔶 I Understand"},
		api.ButtonComponent{type = .BUTTON, style = .DANGER,  custom_id = "dungeon_sell_cancel", label = "❌ Cancel"},
	}
	row := api.ActionRowComponent{type = .ACTION_ROW, components = btns[:]}
	return embed, row
}

@(private)
_show_sell_confirm_final :: proc(ctx: ^discord.Component_Context, session: ^Sell_Session) {
	noun     := session.is_char ? "character" : "item"
	embed := api.Embed{
		title       = "🔴 FINAL WARNING",
		description = fmt.tprintf("Selling **%d %s(s)** for **%d gold**.\n\n🔴 **This cannot be undone!** The %s(s) will be deleted permanently.\n\nProceed?",
			session.item_count, noun, session.total_gold, noun),
		color       = 0xff0000,
	}
	btns := [2]api.Component{
		api.ButtonComponent{type = .BUTTON, style = .DANGER,  custom_id = "dungeon_sell_exec", label = "💀 Delete Forever"},
		api.ButtonComponent{type = .BUTTON, style = .SECONDARY, custom_id = "dungeon_sell_cancel", label = "❌ Cancel"},
	}
	row := api.ActionRowComponent{type = .ACTION_ROW, components = btns[:]}
	session.step = 1
	discord.respond_component(ctx, {embed}, {row})
}
