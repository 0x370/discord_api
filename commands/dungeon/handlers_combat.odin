package dungeon

import "core:fmt"
import "core:sync"

import api "../../discord/api"
import discord "../../discord"

@(private)
register_combat_handlers :: proc(client: ^discord.Client) {
	discord.on_component(client, "dungeon_attack", proc(ctx: ^discord.Component_Context) {
		handle_combat_component(ctx, "attack")
	})
	discord.on_component(client, "dungeon_ability", proc(ctx: ^discord.Component_Context) {
		handle_combat_component(ctx, "ability")
	})
	discord.on_component(client, "dungeon_run", proc(ctx: ^discord.Component_Context) {
		handle_combat_component(ctx, "run")
	})
	discord.on_component(client, "dungeon_char_ability", proc(ctx: ^discord.Component_Context) {
		handle_combat_component(ctx, "char_ability")
	})
}

@(private)
handle_combat_component :: proc(ctx: ^discord.Component_Context, action: string) {
	user_id := get_component_user_id(ctx)

	sync.lock(&dungeon_mutex)
	if owner_id, ok := session_owners[ctx.interaction.message.id]; ok && owner_id != string(user_id) {
		sync.unlock(&dungeon_mutex); discord.defer_component_update(ctx); return
	}
	_, has := combat_sessions[string(user_id)]
	if !has { sync.unlock(&dungeon_mutex); discord.defer_component_update(ctx); return }
	state_ptr := &combat_sessions[string(user_id)]

	logd("[combat] action=%s turn=%d hp=%d/%d", action, state_ptr.turn, state_ptr.player.hp, state_ptr.player.max_hp)
	switch action {
	case "attack":
		combat_basic_attack(state_ptr)
		if state_ptr.ability_cooldown > 0 do state_ptr.ability_cooldown -= 1
		if state_ptr.char_ability_cooldown > 0 do state_ptr.char_ability_cooldown -= 1
		if state_ptr.state == .PLAYER_TURN {
			state_ptr.state = .MONSTER_TURN; combat_monster_turn(state_ptr)
			if state_ptr.state == .PLAYER_LOST { _handle_defeat(ctx, state_ptr); sync.unlock(&dungeon_mutex); return }
			if state_ptr.state == .MONSTER_TURN do state_ptr.state = .PLAYER_TURN
		}
	case "ability":
		if state_ptr.ability_cooldown > 0 || state_ptr.player.mana < state_ptr.ability_mana_cost { sync.unlock(&dungeon_mutex); discord.respond_component(ctx, {}, {}); return }
		combat_use_ability(state_ptr)
		if state_ptr.state == .PLAYER_TURN {
			state_ptr.state = .MONSTER_TURN; combat_monster_turn(state_ptr)
			if state_ptr.state == .PLAYER_LOST { _handle_defeat(ctx, state_ptr); sync.unlock(&dungeon_mutex); return }
			if state_ptr.state == .MONSTER_TURN do state_ptr.state = .PLAYER_TURN
		}
	case "run":
		delete_key(&combat_sessions, string(user_id)); sync.unlock(&dungeon_mutex)
		embed := api.Embed{title = "🏃 Flee", description = "You fled from the dungeon!", color = 0x95a5a6}
		discord.defer_component_update(ctx)
		discord.delete_original_response(ctx.client, ctx.interaction.token)
		discord.create_followup_with_files(ctx.client, ctx.interaction.token, {embed}, nil)
		_cleanup_combat_session(state_ptr)
		return
	case "char_ability":
		if state_ptr.char_ability_cooldown > 0 || state_ptr.player.mana < state_ptr.char_ability_mana_cost { sync.unlock(&dungeon_mutex); discord.respond_component(ctx, {}, {}); return }
		combat_use_char_ability(state_ptr)
		if state_ptr.ability_cooldown > 0 do state_ptr.ability_cooldown -= 1
		if state_ptr.char_ability_cooldown > 0 do state_ptr.char_ability_cooldown -= 1
		if state_ptr.state == .PLAYER_TURN {
			state_ptr.state = .MONSTER_TURN; combat_monster_turn(state_ptr)
			if state_ptr.state == .PLAYER_LOST { _handle_defeat(ctx, state_ptr); sync.unlock(&dungeon_mutex); return }
			if state_ptr.state == .MONSTER_TURN do state_ptr.state = .PLAYER_TURN
		}
	}

	if state_ptr.state == .PLAYER_TURN {
		state_ptr.track.pending_heal = 0
		state_ptr.caps.shield_this_turn = false
		state_ptr.caps.heal_this_turn = false
		state_ptr.caps.regen_this_turn = false
		state_ptr.caps.lightning_this_turn = false
		emit(state_ptr, .TURN_START)
		if state_ptr.track.pending_heal > 0 {
			log_fmt(state_ptr, "💚 Healed **%d** HP from abilities and equipment!", state_ptr.track.pending_heal)
		}
		if state_ptr.monster.hp <= 0 {
			emit(state_ptr, .ON_KILL)
			state_ptr.state = .PLAYER_WON
		}
	}

	if state_ptr.state == .PLAYER_WON {
		logd("[combat] VICTORY floor=%d turn=%d", state_ptr.floor, state_ptr.turn)
		combat_calculate_reward(state_ptr); emit(state_ptr, .VICTORY); _save_victory(ctx, state_ptr)
		delete_key(&combat_sessions, string(user_id)); sync.unlock(&dungeon_mutex); _cleanup_combat_session(state_ptr); return
	}
	if state_ptr.state == .PLAYER_LOST { _handle_defeat(ctx, state_ptr); sync.unlock(&dungeon_mutex); return }
	mon_img_url := get_image_url(state_ptr.monster.kind == .Boss ? .Boss : .Monster, .COMMON, .SWORD, state_ptr.monster.name, .SWORD)
	embed, components := build_battle_embed(state_ptr, mon_img_url)
	sync.unlock(&dungeon_mutex)
	discord.respond_component(ctx, {embed}, components)
}

@(private)
_save_victory :: proc(ctx: ^discord.Component_Context, state: ^CombatState) {
	user_id := get_component_user_id(ctx)

	logd("[combat] save_victory gold=%d lootboxes=%d", state.reward_gold, state.reward_lootboxes)
	db := &ctx.client.db
	player, pok := db_load_player(db, string(user_id))
	if !pok do return

	player.gold += state.reward_gold
	player.item_lootboxes += state.reward_lootboxes
	xp_earned := i64(state.floor * 2 + 4)
	if _, _, ok := discord.db_user_add_xp(db, string(user_id), "", xp_earned); !ok {
		logd("[victory] FAILED to add XP")
	}
	encounters := db_increment_floor_encounters(db, string(user_id), state.floor)
	floor_advanced := false
	if state.floor == player.current_floor && (state.boss_floor || encounters >= 3) {
		player.current_floor += 1
		floor_advanced = true
	}
	if !db_save_player(db, &player) { logd("[victory] FAILED to save player") }

	reward_embed := build_reward_embed(state, chest_image_url(), encounters, floor_advanced)
	discord.defer_component_update(ctx)
	discord.delete_original_response(ctx.client, ctx.interaction.token)
	discord.create_followup_with_files(ctx.client, ctx.interaction.token, {reward_embed}, nil)
}

@(private)
_handle_defeat :: proc(ctx: ^discord.Component_Context, state: ^CombatState) {
	mon_img_url := get_image_url(state.monster.kind == .Boss ? .Boss : .Monster, .COMMON, .SWORD, state.monster.name, .SWORD)
	embed := api.Embed{
		title       = "💀 Defeat",
		description = fmt.tprintf("You fell on floor %d after %d turns.\nUse `/dungeon` to try again!", state.floor, state.turn),
		color       = 0xe74c3c,
		thumbnail   = api.EmbedThumbnail{url = mon_img_url},
	}
	discord.defer_component_update(ctx)
	discord.delete_original_response(ctx.client, ctx.interaction.token)
	discord.create_followup_with_files(ctx.client, ctx.interaction.token, {embed}, nil)
}
