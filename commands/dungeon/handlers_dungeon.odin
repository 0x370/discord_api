package dungeon

import "core:strings"
import "core:sync"
import "core:strconv"

import api "../../discord/api"
import discord "../../discord"

@(private)
handle_dungeon :: proc(ctx: ^discord.Command_Context) {
	user_id := get_user_id(ctx)
	db_create_player_if_new(&ctx.client.db, user_id, .ATTACKER)

	db := &ctx.client.db
	player, _ := db_load_player(db, user_id)
	chars := db_get_characters(db, user_id)

	if len(chars) == 0 {
		name := _random_name()
		logd("[/dungeon] NEW PLAYER — creating starter: %s (Common)", name)
		if !db_insert_character(db, user_id, name, .COMMON, .SWORD, "", "") {
			logd("[/dungeon] FAILED to insert starter character")
		}
		sword_special := _random_specials(.SWORD, .COMMON, 1)
		logd("[/dungeon] starter sword special: %s", sword_special)
		if !db_insert_item(db, user_id, ItemInstance{
			user_id = user_id, item_type = .SWORD, tier = .COMMON,
			base_atk = 6, bonus_hp = 1, bonus_atk = 2, special = sword_special,
		}) { logd("[/dungeon] FAILED to insert starter sword") }
		if !db_insert_item(db, user_id, ItemInstance{
			user_id = user_id, item_type = .HELM, tier = .COMMON,
			base_def = 4, bonus_hp = 1, bonus_def = 1, special = "",
		}) { logd("[/dungeon] FAILED to insert starter helm") }
		if !db_insert_item(db, user_id, ItemInstance{
			user_id = user_id, item_type = .CHEST, tier = .COMMON,
			base_def = 8, bonus_hp = 2, bonus_def = 1, special = "",
		}) { logd("[/dungeon] FAILED to insert starter chest") }
		if !db_insert_item(db, user_id, ItemInstance{
			user_id = user_id, item_type = .LEGS, tier = .COMMON,
			base_def = 5, bonus_hp = 1, bonus_def = 1, special = "",
		}) { logd("[/dungeon] FAILED to insert starter legs") }
		if !db_insert_item(db, user_id, ItemInstance{
			user_id = user_id, item_type = .BOOTS, tier = .COMMON,
			base_def = 3, bonus_hp = 1, bonus_def = 1, special = "",
		}) { logd("[/dungeon] FAILED to insert starter boots") }
		chars = db_get_characters(db, user_id)
		player, _ = db_load_player(db, user_id)
		items := db_get_items(db, user_id)
		for item in items {
			if item.item_type == .SWORD do player.weapon_id = item.id
			if item.item_type == .HELM  do player.head_id   = item.id
			if item.item_type == .CHEST do player.chest_id  = item.id
			if item.item_type == .LEGS  do player.legs_id   = item.id
			if item.item_type == .BOOTS do player.boots_id  = item.id
		}
		if !db_save_player(db, &player) {
			logd("[/dungeon] FAILED to save starter player")
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
		if !db_save_player(db, &player) { logd("[/dungeon] FAILED to save equipped char id") }
	}

	items := load_equipped_items(db, &player)
	combat_player := build_combat_player(&player, &char, items)

	floor := player.current_floor
	floor_str := discord.get_string(ctx, "floor")
	if floor_str != "" {
		if f, ok := strconv.parse_i64(floor_str); ok && f >= 1 && f <= i64(player.current_floor) {
			floor = int(f)
		}
	}
	boss_floor := floor % BOSS_FLOOR_INTERVAL == 0
	monster := generate_monster(floor, 1.0)
	logd("[/dungeon] floor=%d boss=%v monster=%s hp=%d", floor, boss_floor, monster.name, monster.hp)

	// Compute total bonus SPD and Crit from equipped items
	total_spd := 0
	total_crit := 0
	for _, it in items {
		total_spd += it.bonus_spd
		total_crit += it.bonus_crit
	}
	state := CombatState{
		player               = combat_player,
		monster              = monster,
		floor                = floor,
		boss_floor           = boss_floor,
		state                = .PLAYER_TURN,
		turn                 = 1,
		buffs = CombatBuffs{
			total_bonus_spd = total_spd,
			crit_chance     = total_crit,
		},
		track = CombatTracking{
			first_attack        = true,
			player_base_atk     = combat_player.atk,
			monster_original_atk = monster.atk,
		},
		ability_cooldown     = 0,
		char_ability_cooldown = 0,
		char_ability_name    = strings.clone(char.ability_name),
		class_ability_name   = strings.clone(CLASS_ABILITY_DISPLAY_NAMES[player.class]),
		ability_mana_cost    = CLASS_BASE_STATS[player.class].ability_mana_cost,
		char_ability_mana_cost = _is_passive_char_ability(char.ability_name) ? 0 : CHAR_ABILITY_MANA_COST,
		reward_mult          = 1.0,
		rare_mult            = 1.0,
		active               = true,
		interaction_token    = strings.clone(ctx.interaction.token),
		channel_id           = strings.clone(ctx.interaction.channel_id),
	}

	_register_all_hooks(&state, db, &player)
	logd("[/dungeon] hooks registered — item_specials=%d char_ability=%s", _count_item_hooks(db, &player), state.char_ability_name)
	emit(&state, .START)

	mon_img_url := get_image_url(state.monster.kind == .Boss ? .Boss : .Monster, .COMMON, .SWORD, state.monster.name, .SWORD)
	embed, components := build_battle_embed(&state, mon_img_url)
	discord.defer_response(ctx, false)
	data := api.InteractionCallbackData{embeds = {embed}, components = components}
	mid, pok := discord.patch_original_response(ctx.client, ctx.interaction.token, data)
	if pok && mid != "" do state.message_id = strings.clone(mid)
	sync.lock(&dungeon_mutex)
	if old, has := combat_sessions[user_id]; has {
		_cleanup_combat_session(&old)
		delete_key(&combat_sessions, user_id)
	}
	combat_sessions[strings.clone(user_id)] = state
	if state.message_id != "" {
		session_owners[strings.clone(state.message_id)] = strings.clone(user_id)
	}
	sync.unlock(&dungeon_mutex)
}

@(private)
register_dungeon_handlers :: proc(client: ^discord.Client) {
	discord.on_command(client, "dungeon", "Enter the dungeon", handle_dungeon,
		{type = .STRING, name = "floor", description = "Floor to replay", required = false},
	)
}
