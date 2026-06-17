package dungeon

import "core:encoding/json"
import "core:fmt"
import "core:strings"
import "core:sync"

import api "../../discord/api"
import discord "../../discord"

@(private)
combat_sessions:     map[string]CombatState
@(private)
session_owners:      map[string]string
@(private)
gallery_char_cache:  map[string][]CollectedCharacter
@(private)
gallery_item_cache:  map[string][]ItemInstance
@(private)
dungeon_mutex:        sync.Mutex

register_commands :: proc(client: ^discord.Client) {
	sync.lock(&dungeon_mutex)
	if combat_sessions == nil do combat_sessions = make(map[string]CombatState)
	if session_owners == nil  do session_owners  = make(map[string]string)
	if gallery_char_cache == nil do gallery_char_cache = make(map[string][]CollectedCharacter)
	if gallery_item_cache == nil do gallery_item_cache = make(map[string][]ItemInstance)
	sync.unlock(&dungeon_mutex)

	// --- /dungeon ---
	discord.on_command(client, "dungeon", "Enter the dungeon", proc(ctx: ^discord.Command_Context) {
		user_id := ctx.interaction.member.user.id
		if user_id == "" do user_id = ctx.interaction.user.id
		db_create_player_if_new(&ctx.client.db, string(user_id), .ATTACKER)

		db := &ctx.client.db
		player, _ := db_load_player(db, string(user_id))
		chars := db_get_characters(db, string(user_id))

		if len(chars) == 0 {
			name := _random_name()
			ability_name, ability_desc := _random_s_ability()
			logd("[/dungeon] NEW PLAYER — creating starter: %s (D-Tier, %s)", name, ability_name)
			db_insert_character(db, string(user_id), name, .D, .ATTACKER, ability_name, ability_desc)
			special := _random_special_effect()
			logd("[/dungeon] starter item special: %s", special)
			db_insert_item(db, string(user_id), ItemInstance{
				user_id = string(user_id), item_type = .SWORD, tier = .D,
				base_atk = 6, bonus_hp = 2, bonus_atk = 3, special = special,
			})
			chars = db_get_characters(db, string(user_id))
			player, _ = db_load_player(db, string(user_id))
			items := db_get_items(db, string(user_id))
			if len(items) > 0 {
				player.weapon_id = items[0].id
				db_save_player(db, &player)
			}
		}

		char_id := player.equipped_char_id
		char: CollectedCharacter
		if char_id != 0 {
			for c in chars do if c.id == char_id { char = c; break }
		}
		if char.id == 0 && len(chars) > 0 {
			char = chars[0]
			player.equipped_char_id = char.id
			db_save_player(db, &player)
		}

		items := _get_equipped_items(db, &player)
		combat_player := build_combat_player(&player, &char, items)

		floor := player.current_floor
		floor_str := discord.get_string(ctx, "floor")
		if floor_str != "" {
			if f, ok := _parse_i64(floor_str); ok && f >= 1 && f <= i64(player.current_floor) {
				floor = int(f)
			}
		}
		boss_floor := floor % BOSS_FLOOR_INTERVAL == 0
		monster := generate_monster(floor, 1.0)
		logd("[/dungeon] floor=%d boss=%v monster=%s hp=%d", floor, boss_floor, monster.name, monster.hp)

		state := CombatState{
			player            = combat_player,
			monster           = monster,
			floor             = floor,
			boss_floor        = boss_floor,
			state             = .PLAYER_TURN,
			turn              = 1,
			ability_cooldown  = 0,
			char_ability_cooldown = 0,
			char_ability_name = strings.clone(char.ability_name),
			class_ability_name = strings.clone(CLASS_ABILITY_DISPLAY_NAMES[player.class]),
			reward_mult       = 1.0,
			rare_mult         = 1.0,
			active            = true,
			interaction_token = strings.clone(ctx.interaction.token),
			channel_id        = strings.clone(ctx.interaction.channel_id),
		}

		_register_all_hooks(&state, db, &player)
		logd("[/dungeon] hooks registered — item_specials=%d char_ability=%s", _count_item_hooks(db, &player), state.char_ability_name)
		emit(&state, .START)

		embed, components := build_battle_embed(&state)
		discord.defer_response(ctx, false)
		mid := _dungeon_patch_original(ctx.client, ctx.interaction.token, {embed}, components)
		if mid != "" do state.message_id = strings.clone(mid)

		sync.lock(&dungeon_mutex)
		if old, has := combat_sessions[string(user_id)]; has {
			_cleanup_combat_session(&old)
			delete_key(&combat_sessions, string(user_id))
		}
		combat_sessions[strings.clone(string(user_id))] = state
		if state.message_id != "" {
			session_owners[strings.clone(state.message_id)] = strings.clone(string(user_id))
		}
		sync.unlock(&dungeon_mutex)
	},
		{type = .STRING, name = "floor", description = "Floor to replay", required = false},
	)

	// --- /profile ---
	discord.on_command(client, "profile", "View your dungeon profile", proc(ctx: ^discord.Command_Context) {
		user_id := ctx.interaction.member.user.id
		if user_id == "" do user_id = ctx.interaction.user.id
		player, ok := db_load_player(&ctx.client.db, string(user_id))
		if !ok {
			discord.respond(ctx, "No dungeon profile found! Try `/dungeon` first.")
			return
		}
		chars := db_get_characters(&ctx.client.db, string(user_id))
		char: CollectedCharacter
		for c in chars do if c.id == player.equipped_char_id { char = c; break }
		if char.id == 0 && len(chars) == 0 {
			discord.respond(ctx, "No characters yet! Try `/dungeon` first.")
			return
		}
		if char.id == 0 { char = chars[0] }
		items := _get_equipped_items(&ctx.client.db, &player)
		embed := build_profile_embed(&player, char, items)
		discord.respond_with_embed(ctx, "", {embed})
	})

	discord.on_subcommand(client, "profile", "Manage your profile", "equip", "Equip items (space-separated IDs)",
		proc(ctx: ^discord.Command_Context) {
			user_id := ctx.interaction.member.user.id
			if user_id == "" do user_id = ctx.interaction.user.id
			db := &ctx.client.db
			player, pok := db_load_player(db, string(user_id))
			if !pok { discord.respond(ctx, "No dungeon profile found!"); return }
			ids_str := discord.get_string(ctx, "ids")
			equipped: int
			for token in _split_space(ids_str) {
				item_id, parsed_ok := _parse_i64(token)
				if !parsed_ok do continue
				item, iok := db_get_item_by_id(db, string(user_id), item_id)
				if !iok do continue
				switch ITEM_CATEGORY[item.item_type] {
				case .WEAPON: player.weapon_id = item_id
				case .HEAD:   player.head_id   = item_id
				case .CHEST:   player.chest_id  = item_id
				case .LEGS:    player.legs_id   = item_id
				case .BOOTS:   player.boots_id  = item_id
				}
				equipped += 1
			}
			db_save_player(db, &player)
			if equipped == 0 {
				discord.respond(ctx, "No valid items found to equip.")
			} else {
				discord.respond(ctx, fmt.tprintf("Equipped %d item(s)!", equipped))
			}
		},
		{type = .STRING, name = "ids", description = "Space-separated item IDs", required = true},
	)

	discord.on_subcommand(client, "profile", "Manage your profile", "set", "Set equipped character",
		proc(ctx: ^discord.Command_Context) {
			user_id := ctx.interaction.member.user.id
			if user_id == "" do user_id = ctx.interaction.user.id
			db := &ctx.client.db
			player, pok := db_load_player(db, string(user_id))
			if !pok { discord.respond(ctx, "No dungeon profile found!"); return }
			char_id_str := discord.get_string(ctx, "character_id")
			char_id, parsed_ok := _parse_i64(char_id_str)
			if !parsed_ok { discord.respond(ctx, "Invalid character ID format."); return }
			chars := db_get_characters(db, string(user_id))
			found: bool
			for c in chars do if c.id == char_id { found = true; break }
			if !found { discord.respond(ctx, "Character not found in your collection."); return }
			player.equipped_char_id = char_id
			db_save_player(db, &player)
			discord.respond(ctx, fmt.tprintf("Equipped character #%d!", char_id))
		},
		{type = .STRING, name = "character_id", description = "The character ID to equip", required = true},
	)

	// --- /class ---
	discord.on_command(client, "class", "Set your dungeon class", proc(ctx: ^discord.Command_Context) {
		user_id := ctx.interaction.member.user.id
		if user_id == "" do user_id = ctx.interaction.user.id
		choice := discord.get_string(ctx, "class")
		class: Class_Type = .ATTACKER
		if choice == "healer" do class = .HEALER
		db := &ctx.client.db
		player, pok := db_load_player(db, string(user_id))
		if !pok {
			db_create_player_if_new(db, string(user_id), class)
		} else {
			player.class = class
			db_save_player(db, &player)
		}
		discord.respond(ctx, fmt.tprintf("Class set to **%s** %s!", CLASS_NAMES[class], CLASS_EMOJIS[class]))
	},
		{type = .STRING, name = "class", description = "attacker or healer", required = true, choices = {
			{name = "Attacker", value = "attacker"},
			{name = "Healer", value = "healer"},
		}},
	)

	// --- /characters ---
	discord.on_command(client, "characters", "Browse your collected characters", proc(ctx: ^discord.Command_Context) {
		user_id := ctx.interaction.member.user.id
		if user_id == "" do user_id = ctx.interaction.user.id
		chars := db_get_characters(&ctx.client.db, string(user_id))
		if len(chars) == 0 {
			discord.respond(ctx, "No characters yet! Try `/dungeon` first.")
			return
		}
		gallery_char_cache[strings.clone(string(user_id))] = chars
		if discord.get_bool(ctx, "list") {
			embed, comps := build_character_list_embed(chars, 1)
			discord.respond_with_components(ctx, "", {embed}, comps)
		} else {
			embed, comps := build_character_embed(chars[0], 1, len(chars))
			discord.respond_with_components(ctx, "", {embed}, comps)
		}
	},
		{type = .BOOLEAN, name = "list", description = "Show as 10-per-page list", required = false},
	)

	// --- /items ---
	discord.on_command(client, "items", "Browse your inventory", proc(ctx: ^discord.Command_Context) {
		user_id := ctx.interaction.member.user.id
		if user_id == "" do user_id = ctx.interaction.user.id
		items := db_get_items(&ctx.client.db, string(user_id))
		if len(items) == 0 {
			discord.respond(ctx, "No items yet! Try `/dungeon` first.")
			return
		}
		gallery_item_cache[strings.clone(string(user_id))] = items
		if discord.get_bool(ctx, "list") {
			embed, comps := build_item_list_embed(items, 1)
			discord.respond_with_components(ctx, "", {embed}, comps)
		} else {
			embed, comps := build_item_embed(items[0], 1, len(items))
			discord.respond_with_components(ctx, "", {embed}, comps)
		}
	},
		{type = .BOOLEAN, name = "list", description = "Show as 10-per-page list", required = false},
	)

	// --- /lootbox ---
	discord.on_command(client, "lootbox", "Open a lootbox", proc(ctx: ^discord.Command_Context) {
		user_id := ctx.interaction.member.user.id
		if user_id == "" do user_id = ctx.interaction.user.id
		kind := discord.get_string(ctx, "type")

		if kind == "character" {
			discord.defer_response(ctx, false)
			results := generate_character_lootbox()
			gacha := results[:]
			logd("[lootbox] character — tier distribution: ")
			for r in gacha do logd("  %s (%s %s)", r.name, TIER_LABELS[r.tier], CLASS_NAMES[r.class])
			embed, comps := build_lootbox_result_embed(gacha, 1, LOOTBOX_CHARACTER_COUNT)
			discord.edit_original_response(ctx.client, ctx.interaction.token, "")
			_dungeon_patch_original(ctx.client, ctx.interaction.token, {embed}, comps)
			db := &ctx.client.db
			for r in gacha {
				db_insert_character(db, string(user_id), r.name, r.tier, r.class, r.ability_name, r.ability_desc)
			}
			delete_key(&gallery_char_cache, string(user_id))
		} else {
			db := &ctx.client.db
			player, pok := db_load_player(db, string(user_id))
			if !pok || player.item_lootboxes <= 0 {
				discord.respond(ctx, "You have no item lootboxes! Earn them in `/dungeon`.")
				return
			}
			count_str := discord.get_string(ctx, "count")
			count := 1
			if count_str != "" {
				if c, ok := _parse_i64(count_str); ok && c > 0 { count = int(c) }
			}
			if count > player.item_lootboxes do count = player.item_lootboxes
			player.item_lootboxes -= count
			db_save_player(db, &player)
			discord.defer_response(ctx, false)
			logd("[lootbox] item — opening %d box(es)", count)
			for _ in 0 ..< count {
				results := generate_item_lootbox()
				for r in results {
					db_insert_item(db, string(user_id), ItemInstance{
						user_id = string(user_id),
						item_type = r.item_type, tier = r.tier,
						base_atk = r.base_atk, base_def = r.base_def,
						bonus_hp = r.bonus_hp, bonus_atk = r.bonus_atk,
						bonus_def = r.bonus_def, bonus_spd = r.bonus_spd,
						special = r.special,
					})
				}
			}
			delete_key(&gallery_item_cache, string(user_id))
			items := db_get_items(db, string(user_id))
			total := len(items)
			if total == 0 {
				discord.edit_original_response(ctx.client, ctx.interaction.token, "No items in inventory.")
				return
			}
			embed, comps := build_item_embed(items[total - 1], total, total)
			discord.edit_original_response(ctx.client, ctx.interaction.token, "")
			_dungeon_patch_original(ctx.client, ctx.interaction.token, {embed}, comps)
		}
	},
		{type = .STRING, name = "type", description = "character or item", required = true, choices = {
			{name = "Character", value = "character"},
			{name = "Item", value = "item"},
		}},
		{type = .STRING, name = "count", description = "How many to open (items only)", required = false},
	)

	// --- Combat component handlers ---
	discord.on_component(client, "dungeon_attack", proc(ctx: ^discord.Component_Context) {
		_handle_combat_component(ctx, "attack")
	})
	discord.on_component(client, "dungeon_ability", proc(ctx: ^discord.Component_Context) {
		_handle_combat_component(ctx, "ability")
	})
	discord.on_component(client, "dungeon_run", proc(ctx: ^discord.Component_Context) {
		_handle_combat_component(ctx, "run")
	})
	discord.on_component(client, "dungeon_char_ability", proc(ctx: ^discord.Component_Context) {
		_handle_combat_component(ctx, "char_ability")
	})

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
	discord.on_component(client, "dungeon_lbox_char_prev", proc(ctx: ^discord.Component_Context) {
		_handle_gallery_nav(ctx, "lbox_char", false)
	})
	discord.on_component(client, "dungeon_lbox_char_next", proc(ctx: ^discord.Component_Context) {
		_handle_gallery_nav(ctx, "lbox_char", true)
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
}

@(private)
_handle_gallery_nav :: proc(ctx: ^discord.Component_Context, kind: string, next: bool) {
	user_id := ctx.interaction.member.user.id
	if user_id == "" do user_id = ctx.interaction.user.id

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
		chars, has := gallery_char_cache[string(user_id)]
		if !has { chars = db_get_characters(db, string(user_id)) }
		if new_page < 1 || new_page > len(chars) { discord.defer_component_update(ctx); return }
		char := chars[new_page - 1]
		embed, comps := build_character_embed(char, new_page, len(chars))
		discord.respond_component(ctx, {embed}, comps)
	case "item":
		items, has := gallery_item_cache[string(user_id)]
		if !has { items = db_get_items(db, string(user_id)) }
		if new_page < 1 || new_page > len(items) { discord.defer_component_update(ctx); return }
		embed, comps := build_item_embed(items[new_page - 1], new_page, len(items))
		discord.respond_component(ctx, {embed}, comps)
	case "lbox_char":
		chars, has := gallery_char_cache[string(user_id)]
		if !has { chars = db_get_characters(db, string(user_id)) }
		total_chars := len(chars)
		start := total_chars - LOOTBOX_CHARACTER_COUNT
		if start < 0 do start = 0
		lbox_total := total_chars - start
		if new_page < 1 do new_page = 1
		if new_page > lbox_total do new_page = lbox_total
		if lbox_total <= 0 { discord.defer_component_update(ctx); return }
		c := chars[start + new_page - 1]
		result := CharacterGachaResult{name = c.name, tier = c.tier, class = c.class, ability_name = c.ability_name, ability_desc = c.ability_desc}
		embed, comps := build_lootbox_result_embed_single(result, new_page, lbox_total)
		discord.respond_component(ctx, {embed}, comps)
	}
}

@(private)
_handle_list_nav :: proc(ctx: ^discord.Component_Context, kind: string, next: bool) {
	user_id := ctx.interaction.member.user.id
	if user_id == "" do user_id = ctx.interaction.user.id

	page, _ := _parse_page_from_embed(ctx)
	new_page := next ? page + 1 : page - 1
	if new_page < 1 do new_page = 1

	switch kind {
	case "char":
		chars, has := gallery_char_cache[string(user_id)]
		if !has do return
		embed, comps := build_character_list_embed(chars, new_page)
		discord.respond_component(ctx, {embed}, comps)
	case "item":
		items, has := gallery_item_cache[string(user_id)]
		if !has do return
		embed, comps := build_item_list_embed(items, new_page)
		discord.respond_component(ctx, {embed}, comps)
	}
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
		p, _ := _parse_i64(s[paren_start+1:slash_pos])
		t, _ := _parse_i64(s[slash_pos+1:paren_end])
		page = int(p); total = int(t)
	}
	if page < 1 do page = 1
	if total < 1 do total = 1
	return
}

@(private)
_handle_combat_component :: proc(ctx: ^discord.Component_Context, action: string) {
	user_id := ctx.interaction.member.user.id
	if user_id == "" do user_id = ctx.interaction.user.id

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
			state_ptr.state = .PLAYER_TURN
		}
	case "ability":
		if state_ptr.ability_cooldown > 0 { sync.unlock(&dungeon_mutex); discord.respond_component(ctx, {}, {}); return }
		combat_use_ability(state_ptr)
		if state_ptr.state == .PLAYER_TURN {
			state_ptr.state = .MONSTER_TURN; combat_monster_turn(state_ptr)
			if state_ptr.state == .PLAYER_LOST { _handle_defeat(ctx, state_ptr); sync.unlock(&dungeon_mutex); return }
			state_ptr.state = .PLAYER_TURN
		}
	case "run":
		delete_key(&combat_sessions, string(user_id)); sync.unlock(&dungeon_mutex)
		embed := api.Embed{title = "🏃 Flee", description = "You fled from the dungeon!", color = 0x95a5a6}
		discord.respond_component(ctx, {embed}, {}); _cleanup_combat_session(state_ptr); return
	case "char_ability":
		if state_ptr.char_ability_cooldown > 0 { sync.unlock(&dungeon_mutex); discord.respond_component(ctx, {}, {}); return }
		combat_use_char_ability(state_ptr)
		if state_ptr.ability_cooldown > 0 do state_ptr.ability_cooldown -= 1
		if state_ptr.char_ability_cooldown > 0 do state_ptr.char_ability_cooldown -= 1
		if state_ptr.state == .PLAYER_TURN {
			state_ptr.state = .MONSTER_TURN; combat_monster_turn(state_ptr)
			if state_ptr.state == .PLAYER_LOST { _handle_defeat(ctx, state_ptr); sync.unlock(&dungeon_mutex); return }
			state_ptr.state = .PLAYER_TURN
		}
	}

	if state_ptr.state == .PLAYER_WON {
		logd("[combat] VICTORY floor=%d turn=%d", state_ptr.floor, state_ptr.turn)
		emit(state_ptr, .VICTORY); combat_calculate_reward(state_ptr); _save_victory(ctx, state_ptr)
		delete_key(&combat_sessions, string(user_id)); sync.unlock(&dungeon_mutex); _cleanup_combat_session(state_ptr); return
	}

	if state_ptr.state == .PLAYER_TURN { emit(state_ptr, .TURN_START) }
	embed, components := build_battle_embed(state_ptr)
	sync.unlock(&dungeon_mutex)
	discord.respond_component(ctx, {embed}, components)
}

@(private)
_save_victory :: proc(ctx: ^discord.Component_Context, state: ^CombatState) {
	user_id := ctx.interaction.member.user.id
	if user_id == "" do user_id = ctx.interaction.user.id

	logd("[combat] save_victory gold=%d lootboxes=%d", state.reward_gold, state.reward_lootboxes)
	db := &ctx.client.db
	player, pok := db_load_player(db, string(user_id))
	if !pok do return

	player.gold += state.reward_gold
	player.item_lootboxes += state.reward_lootboxes
	encounters := db_increment_floor_encounters(db, string(user_id), state.floor)
	if state.floor == player.current_floor && (state.boss_floor || encounters >= 3) {
		player.current_floor += 1
	}
	db_save_player(db, &player)

	reward_embed := build_reward_embed(state)
	discord.respond_component(ctx, {reward_embed}, {})
}

@(private)
_handle_defeat :: proc(ctx: ^discord.Component_Context, state: ^CombatState) {
	embed := api.Embed{
		title       = "💀 Defeat",
		description = fmt.tprintf("You fell on floor %d after %d turns.\nUse `/dungeon` to try again!", state.floor, state.turn),
		color       = 0xe74c3c,
	}
	discord.respond_component(ctx, {embed}, {})
}

@(private)
_register_all_hooks :: proc(state: ^CombatState, db: ^discord.Db, p: ^Player) {
	register_class_hooks(state, p.class)
	register_char_hooks(state, state.char_ability_name)
	logd("[hooks] char ability=%s hooks_bound", state.char_ability_name)
	ids: [5]i64 = {p.weapon_id, p.head_id, p.chest_id, p.legs_id, p.boots_id}
	for id in ids {
		if id == 0 do continue
		if it, ok := db_get_item_by_id(db, p.user_id, id); ok && it.special != "" {
			logd("[hooks] item id=%d special=%s", id, it.special)
			register_item_hooks(state, it.special)
		}
	}
}

@(private)
_count_item_hooks :: proc(db: ^discord.Db, p: ^Player) -> int {
	count := 0
	ids: [5]i64 = {p.weapon_id, p.head_id, p.chest_id, p.legs_id, p.boots_id}
	for id in ids {
		if id == 0 do continue
		if it, ok := db_get_item_by_id(db, p.user_id, id); ok && it.special != "" do count += 1
	}
	return count
}

@(private)
_get_equipped_items :: proc(db: ^discord.Db, p: ^Player) -> map[i64]ItemInstance {
	items := make(map[i64]ItemInstance)
	ids: [5]i64 = {p.weapon_id, p.head_id, p.chest_id, p.legs_id, p.boots_id}
	for id in ids {
		if id == 0 do continue
		if it, ok := db_get_item_by_id(db, p.user_id, id); ok { items[id] = it }
	}
	return items
}

@(private)
_cleanup_combat_session :: proc(state: ^CombatState) {
	if state.log != nil {
		for entry in state.log do delete(entry)
		delete(state.log); state.log = nil
	}
	if state.interaction_token != "" do delete(state.interaction_token)
	if state.message_id != "" do delete(state.message_id)
	if state.channel_id != "" do delete(state.channel_id)
}

@(private)
_split_space :: proc(s: string) -> []string {
	if len(s) == 0 do return nil
	parts := make([dynamic]string, context.temp_allocator)
	start := 0
	for i in 0 ..< len(s) {
		if s[i] == ' ' { if i > start { append(&parts, s[start:i]) }; start = i + 1 }
	}
	if start < len(s) { append(&parts, s[start:]) }
	return parts[:]
}

@(private)
_parse_i64 :: proc(s: string) -> (i64, bool) {
	if len(s) == 0 do return 0, false
	val: i64 = 0
	for ch in s { if ch < '0' || ch > '9' do return 0, false; val = val * 10 + i64(ch - '0') }
	return val, true
}

@(private)
_dungeon_patch_original :: proc(client: ^discord.Client, token: string, embeds: []api.Embed, components: []api.Component) -> string {
	data := api.InteractionCallbackData{embeds = embeds, components = components}
	body, err := json.marshal(data, allocator = context.temp_allocator)
	if err != nil { fmt.eprintfln("[patch_original] marshal error: %v", err); return "" }
	endpoint := fmt.tprintf("/webhooks/%s/%s/messages/@original", client.application_id, token)
	resp, ok := api.discord_patch(&client.rest_client, endpoint, body)
	if !ok { fmt.eprintfln("[patch_original] PATCH failed"); return "" }
	defer delete(resp.body)
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("[patch_original] PATCH status=%d body: %s", resp.status_code, string(resp.body))
		return ""
	}
	msg: api.Message
	if json.unmarshal(resp.body, &msg) == nil && msg.id != "" { return strings.clone(msg.id) }
	return ""
}
