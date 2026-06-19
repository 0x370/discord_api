package dungeon

import "core:fmt"
import "core:sync"

import api "../../discord/api"
import discord "../../discord"

// --- Sell confirmation flow component handlers ---

@(private)
handle_sell_confirm_first :: proc(ctx: ^discord.Component_Context) {
	user_id := get_component_user_id(ctx)

	sync.lock(&dungeon_mutex)
	if owner_id, ok := session_owners[ctx.interaction.message.id]; ok && owner_id != string(user_id) {
		sync.unlock(&dungeon_mutex); discord.defer_component_update(ctx); return
	}
	session, has := sell_sessions[string(user_id)]
	if !has { sync.unlock(&dungeon_mutex); discord.defer_component_update(ctx); return }

	_show_sell_confirm_final(ctx, &session)
	sell_sessions[string(user_id)] = session
	sync.unlock(&dungeon_mutex)
}

@(private)
handle_sell_exec :: proc(ctx: ^discord.Component_Context) {
	user_id := get_component_user_id(ctx)

	// Ownership check + extract session under mutex
	sync.lock(&dungeon_mutex)
	if owner_id, ok := session_owners[ctx.interaction.message.id]; ok && owner_id != string(user_id) {
		sync.unlock(&dungeon_mutex); discord.defer_component_update(ctx); return
	}
	session, has := sell_sessions[string(user_id)]
	if !has {
		sync.unlock(&dungeon_mutex); discord.defer_component_update(ctx); return
	}
	// Clean up maps immediately
	if session.message_id != "" {
		delete_key(&session_owners, session.message_id)
	}
	delete_key(&sell_sessions, string(user_id))
	sync.unlock(&dungeon_mutex)

	// DB operations outside mutex
	db := &ctx.client.db
	player, pok := db_load_player(db, string(user_id))
	if !pok { discord.defer_component_update(ctx); return }

	noun     := session.is_char ? "character" : "item"
	noun_cap := session.is_char ? "Character" : "Item"

	if session.is_char {
		for id in session.item_ids {
			if player.equipped_char_id == id do player.equipped_char_id = 0
			db_delete_character(db, string(user_id), id)
		}
		delete_key(&gallery_char_cache, string(user_id))
	} else {
		for id in session.item_ids {
			unequip_item(&player, id)
			db_delete_item(db, string(user_id), id)
		}
		delete_key(&gallery_item_cache, string(user_id))
	}

	player.gold += session.total_gold
	if !db_save_player(db, &player) { logd("[sell] FAILED to save player") }

	embed := api.Embed{
		title       = fmt.tprintf("✅ %ss Sold!", noun_cap),
		description = fmt.tprintf("Sold **%d %s(s)** for **%d gold**!\n💰 New balance: **%d gold**",
			session.item_count, noun, session.total_gold, player.gold),
		color       = 0x2ecc71,
	}
	discord.defer_component_update(ctx)
	discord.delete_original_response(ctx.client, ctx.interaction.token)
	discord.create_followup_with_files(ctx.client, ctx.interaction.token, {embed}, nil)
}

@(private)
handle_sell_cancel :: proc(ctx: ^discord.Component_Context) {
	user_id := get_component_user_id(ctx)

	sync.lock(&dungeon_mutex)
	if owner_id, ok := session_owners[ctx.interaction.message.id]; ok && owner_id != string(user_id) {
		sync.unlock(&dungeon_mutex); discord.defer_component_update(ctx); return
	}
	if session, has := sell_sessions[string(user_id)]; has && session.message_id != "" {
		delete_key(&session_owners, session.message_id)
	}
	delete_key(&sell_sessions, string(user_id))
	sync.unlock(&dungeon_mutex)

	embed := api.Embed{
		title       = "❌ Sale Cancelled",
		description = "Nothing was sold.",
		color       = 0x95a5a6,
	}
	discord.defer_component_update(ctx)
	discord.delete_original_response(ctx.client, ctx.interaction.token)
	discord.create_followup_with_files(ctx.client, ctx.interaction.token, {embed}, nil)
}

@(private)
register_sell_flow_handlers :: proc(client: ^discord.Client) {
	discord.on_component(client, "dungeon_sell_confirm_first", handle_sell_confirm_first)
	discord.on_component(client, "dungeon_sell_exec", handle_sell_exec)
	discord.on_component(client, "dungeon_sell_cancel", handle_sell_cancel)
}
