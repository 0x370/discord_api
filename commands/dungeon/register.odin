package dungeon

import "core:encoding/json"
import "core:fmt"
import "core:slice"
import "core:strings"
import "core:sync"
import "core:strconv"
import "core:time"

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
@(private)
sell_sessions:       map[string]Sell_Session

register_commands :: proc(client: ^discord.Client) {
	sync.lock(&dungeon_mutex)
	if combat_sessions == nil do combat_sessions = make(map[string]CombatState)
	if session_owners == nil  do session_owners  = make(map[string]string)
	if gallery_char_cache == nil do gallery_char_cache = make(map[string][]CollectedCharacter)
	if sell_sessions == nil do sell_sessions = make(map[string]Sell_Session)
	if gallery_item_cache == nil do gallery_item_cache = make(map[string][]ItemInstance)
	sync.unlock(&dungeon_mutex)

	// Run DB migrations (tier rename etc.)
	db_run_migrations(&client.db)

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
			logd("[/dungeon] NEW PLAYER — creating starter: %s (Common)", name)
			if !db_insert_character(db, string(user_id), name, .COMMON, .SWORD, "", "") {
				logd("[/dungeon] FAILED to insert starter character")
			}
			sword_special := _random_specials(.SWORD, .COMMON, 1)
			logd("[/dungeon] starter sword special: %s", sword_special)
			if !db_insert_item(db, string(user_id), ItemInstance{
				user_id = string(user_id), item_type = .SWORD, tier = .COMMON,
				base_atk = 6, bonus_hp = 1, bonus_atk = 2, special = sword_special,
			}) { logd("[/dungeon] FAILED to insert starter sword") }
			if !db_insert_item(db, string(user_id), ItemInstance{
				user_id = string(user_id), item_type = .HELM, tier = .COMMON,
				base_def = 4, bonus_hp = 1, bonus_def = 1, special = "",
			}) { logd("[/dungeon] FAILED to insert starter helm") }
			if !db_insert_item(db, string(user_id), ItemInstance{
				user_id = string(user_id), item_type = .CHEST, tier = .COMMON,
				base_def = 8, bonus_hp = 2, bonus_def = 1, special = "",
			}) { logd("[/dungeon] FAILED to insert starter chest") }
			if !db_insert_item(db, string(user_id), ItemInstance{
				user_id = string(user_id), item_type = .LEGS, tier = .COMMON,
				base_def = 5, bonus_hp = 1, bonus_def = 1, special = "",
			}) { logd("[/dungeon] FAILED to insert starter legs") }
			if !db_insert_item(db, string(user_id), ItemInstance{
				user_id = string(user_id), item_type = .BOOTS, tier = .COMMON,
				base_def = 3, bonus_hp = 1, bonus_def = 1, special = "",
			}) { logd("[/dungeon] FAILED to insert starter boots") }
			chars = db_get_characters(db, string(user_id))
			player, _ = db_load_player(db, string(user_id))
			items := db_get_items(db, string(user_id))
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

		items := _get_equipped_items(db, &player)
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
			first_attack         = true,
			total_bonus_spd      = total_spd,
			crit_chance           = total_crit,
			player_base_atk       = combat_player.atk,
			monster_original_atk  = monster.atk,
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
	discord.on_subcommand(client, "profile", "View your dungeon profile", "view", "View your stats",
		proc(ctx: ^discord.Command_Context) {
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
			img_url := get_image_url(.Character, char.tier, char.weapon_compat, "", .SWORD)
			embed := build_profile_embed(&player, char, items, img_url)
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
			tokens, _ := strings.fields(ids_str, context.temp_allocator); for token in tokens {
				item_id, parsed_ok := strconv.parse_i64(token)
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
			if !db_save_player(db, &player) { logd("[equip] FAILED to save items") }
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
			char_id, parsed_ok := strconv.parse_i64(char_id_str)
			if !parsed_ok { discord.respond(ctx, "Invalid character ID format."); return }
			chars := db_get_characters(db, string(user_id))
			found: bool
			for c in chars do if c.id == char_id { found = true; break }
			if !found { discord.respond(ctx, "Character not found in your collection."); return }
			player.equipped_char_id = char_id
			if !db_save_player(db, &player) { logd("[profile set] FAILED to save equipped char") }
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
			discord.respond(ctx, "You haven't entered the dungeon yet! Run `/dungeon` first.")
			return
		}
		player.class = class
		if !db_save_player(db, &player) { logd("[class] FAILED to save class change") }
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
		if _, pok := db_load_player(&ctx.client.db, string(user_id)); !pok {
			discord.respond(ctx, "You haven't entered the dungeon yet! Run `/dungeon` first.")
			return
		}
		chars := db_get_characters(&ctx.client.db, string(user_id))
		if len(chars) == 0 {
			discord.respond(ctx, "No characters yet! Try `/dungeon` first.")
			return
		}
		slice.sort_by(chars, proc(a, b: CollectedCharacter) -> bool { return a.tier < b.tier })

		gallery_char_cache[strings.clone(string(user_id))] = chars
		if discord.get_bool(ctx, "list") {
			embed, comps := build_character_list_embed(chars, 1)
			discord.respond_with_components(ctx, "", {embed}, comps)
		} else {
			img_url := get_image_url(.Character, chars[0].tier, chars[0].weapon_compat, "", .SWORD)
			embed, comps := build_character_embed(chars[0], 1, len(chars), img_url)
			discord.respond_with_components(ctx, "", {embed}, comps)
		}
	},
		{type = .BOOLEAN, name = "list", description = "Show as 10-per-page list", required = false},
	)

	discord.on_command(client, "items", "Browse your inventory", proc(ctx: ^discord.Command_Context) {
		user_id := ctx.interaction.member.user.id
		if user_id == "" do user_id = ctx.interaction.user.id
		if _, pok := db_load_player(&ctx.client.db, string(user_id)); !pok {
			discord.respond(ctx, "You haven't entered the dungeon yet! Run `/dungeon` first.")
			return
		}
		items := db_get_items(&ctx.client.db, string(user_id))
		if len(items) == 0 {
			discord.respond(ctx, "No items yet! Try `/dungeon` first.")
			return
		}
		slice.sort_by(items, proc(a, b: ItemInstance) -> bool { return a.tier < b.tier })

		gallery_item_cache[strings.clone(string(user_id))] = items
		if discord.get_bool(ctx, "list") {
			embed, comps := build_item_list_embed(items, 1)
			discord.respond_with_components(ctx, "", {embed}, comps)
		} else {
			img_url := get_image_url(.Item, items[0].tier, .SWORD, "", items[0].item_type)
			embed, comps := build_item_embed(items[0], 1, len(items), img_url)
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
			db := &ctx.client.db
			player, pok := db_load_player(db, string(user_id))
			if !pok || player.char_lootboxes <= 0 {
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
			_dungeon_patch_original(ctx.client, ctx.interaction.token, {embed}, {})
			for r in gacha {
				if !db_insert_character(db, string(user_id), r.name, r.tier, r.weapon_compat, r.ability_name, r.ability_desc) {
					logd("[lootbox] FAILED to insert character: %s", r.name)
				}
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
					if !db_insert_item(db, string(user_id), ItemInstance{
						user_id = string(user_id),
						item_type = r.item_type, tier = r.tier,
						base_atk = r.base_atk, base_def = r.base_def,
						bonus_hp = r.bonus_hp, bonus_atk = r.bonus_atk,
						bonus_def = r.bonus_def, bonus_spd = r.bonus_spd,
						special = r.special,
					}) {
						logd("[lootbox] FAILED to insert item: %s", ITEM_NAMES[r.item_type])
					}
				}
			}
			delete_key(&gallery_item_cache, string(user_id))
			// Find best item for thumbnail
			best := all_items[0]
			for it in all_items do if it.tier < best.tier do best = it
			img_url := get_image_url(.Item, best.tier, .SWORD, "", best.item_type)
			embed := build_lootbox_item_embed(all_items[:], img_url)
			discord.edit_original_response(ctx.client, ctx.interaction.token, "")
			_dungeon_patch_original(ctx.client, ctx.interaction.token, {embed}, {})
		}
	},
		{type = .STRING, name = "type", description = "character or item", required = true, choices = {
			{name = "Character", value = "character"},
			{name = "Item", value = "item"},
		}},
		{type = .STRING, name = "count", description = "How many to open (items only)", required = false},
	)

	// --- /sell ---
	discord.on_command(client, "sell", "Sell items or characters for gold", proc(ctx: ^discord.Command_Context) {
		user_id := ctx.interaction.member.user.id
		if user_id == "" do user_id = ctx.interaction.user.id

		db := &ctx.client.db
		_, pok := db_load_player(db, string(user_id))
		if !pok {
			discord.respond(ctx, "You haven't entered the dungeon yet! Run `/dungeon` first.")
			return
		}

		kind := discord.get_string(ctx, "type")
		tier_filter := discord.get_string(ctx, "tier")
		ids_str     := discord.get_string(ctx, "ids")

		if tier_filter == "" && ids_str == "" {
			discord.respond(ctx, "Provide a tier filter (e.g. `tier:Common`) or space-separated IDs (e.g. `ids:1 2 3`).")
			return
		}

		if kind == "character" {
			chars := db_get_characters(db, string(user_id))
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

			session := _new_sell_session_chars(user_id, sell_chars[:], total_gold)

			discord.defer_response(ctx, false)
			embed, row := _build_sell_confirm_simple(&session)
			if has_rare {
				embed, row = _build_sell_confirm_first(&session)
			}
			mid := _dungeon_patch_original(ctx.client, ctx.interaction.token, {embed}, {row})
			sync.lock(&dungeon_mutex)
			if mid != "" {
				session.message_id = strings.clone(mid)
				session_owners[strings.clone(mid)] = strings.clone(string(user_id))
			}
			key := strings.clone(string(user_id))
			sell_sessions[key] = session
			sync.unlock(&dungeon_mutex)
		} else {
			// Default: sell items
			items := db_get_items(db, string(user_id))
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

			session := _new_sell_session(user_id, sell_items[:], total_gold)

			discord.defer_response(ctx, false)
			embed, row := _build_sell_confirm_simple(&session)
			if has_rare {
				embed, row = _build_sell_confirm_first(&session)
			}
			mid := _dungeon_patch_original(ctx.client, ctx.interaction.token, {embed}, {row})
			sync.lock(&dungeon_mutex)
			if mid != "" {
				session.message_id = strings.clone(mid)
				session_owners[strings.clone(mid)] = strings.clone(string(user_id))
			}
			key := strings.clone(string(user_id))
			sell_sessions[key] = session
			sync.unlock(&dungeon_mutex)
		}
	},
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

	// --- /daily ---
	discord.on_command(client, "daily", "Claim your daily gold and lootboxes", proc(ctx: ^discord.Command_Context) {
		user_id := ctx.interaction.member.user.id
		if user_id == "" do user_id = ctx.interaction.user.id

		db := &ctx.client.db
		player, pok := db_load_player(db, string(user_id))
		if !pok {
			discord.respond(ctx, "You haven't entered the dungeon yet! Run `/dungeon` first.")
			return
		}

		now := time.now()
		day_ns := 24 * time.Hour

		if player.last_daily_claim != 0 {
			elapsed := time.diff(time.from_nanoseconds(player.last_daily_claim), now)
			if elapsed < day_ns {
				remaining := day_ns - elapsed
				hours := int(remaining / time.Hour)
				minutes := int((remaining % time.Hour) / time.Minute)
				discord.respond(ctx, fmt.tprintf("⏳ You already claimed your daily! Come back in **%dh %dm**.", hours, minutes))
				return
			}
			if elapsed > 48 * time.Hour {
				player.daily_streak = 0
			}
		}

		gold_reward := 30 + player.daily_streak * 10
		player.gold += gold_reward
		player.char_lootboxes += 2

		if !db_save_player(db, &player) { logd("[daily] FAILED to save player") }

		discord.respond(ctx, fmt.tprintf(
			"☀️ **Daily Reward — Day %d!**\n" +
			"+%d 💰 gold\n" +
			"+2 🎭 character lootboxes",
			player.daily_streak, gold_reward,
		))
	})


	// --- /rates ---
	discord.on_command(client, "rates", "Show dungeon drop rates and tier info", proc(ctx: ^discord.Command_Context) {
		total_weight := 0
		for w in TIER_WEIGHTS do total_weight += w

		lines := make([dynamic]string, context.temp_allocator)
		append(&lines, "**Tier Drop Rates** (per roll, 5 rolls per lootbox)")
		append(&lines, "```")
		for t in TIER_COLLECTION_ORDER {
			w := TIER_WEIGHTS[t]
			pct := f64(w) * 100.0 / f64(total_weight)
			append(&lines, fmt.tprintf("%-12s %2d/%d = %5.1f%%", TIER_LABELS[t], w, total_weight, pct))
		}
		append(&lines, "```")
		append(&lines, fmt.tprintf("Expected per 5-pull: ~%.1f Mythical, ~%.1f Legendary, ~%.1f Rare, ~%.1f Uncommon, ~%.1f Common",
			f64(TIER_WEIGHTS[.MYTHICAL])*5.0/f64(total_weight),
			f64(TIER_WEIGHTS[.LEGENDARY])*5.0/f64(total_weight),
			f64(TIER_WEIGHTS[.RARE])*5.0/f64(total_weight),
			f64(TIER_WEIGHTS[.UNCOMMON])*5.0/f64(total_weight),
			f64(TIER_WEIGHTS[.COMMON])*5.0/f64(total_weight),
		))

		append(&lines, "")
		append(&lines, "**Combat Lootbox Drops**")
		append(&lines, "```")
		append(&lines, "Normal victory: 8% chance for 1 item lootbox")
		append(&lines, "Boss victory:    2 guaranteed item lootboxes")
		append(&lines, "Daily:           +2 character lootboxes")
		append(&lines, "```")

		append(&lines, "")
		append(&lines, "**Tier Item Stats**")
		append(&lines, "```")
		append(&lines, "            Mult  Affixes  Affix Range  Specials")
		for t in TIER_COLLECTION_ORDER {
			cfg := TIER_CONFIGS[t]
			affix_str := cfg.max_affixes == 0 ? "0" : fmt.tprintf("%d-%d", cfg.min_affixes, cfg.max_affixes)
			spec_str  := cfg.max_specials == 0 ? "0" : fmt.tprintf("%d-%d", cfg.min_specials, cfg.max_specials)
			append(&lines, fmt.tprintf("%-12s x%-4.2f %-7s %d-%-10d %s",
				TIER_LABELS[t], cfg.mult, affix_str, cfg.affix_min, cfg.affix_max, spec_str))
		}
		append(&lines, "```")

		append(&lines, fmt.tprintf("💰 Sell prices: Common=%d  Uncommon=%d  Rare=%d  Legendary=%d  Mythical=%d + affix bonus",
			_sell_price(ItemInstance{tier=.COMMON}),
			_sell_price(ItemInstance{tier=.UNCOMMON}),
			_sell_price(ItemInstance{tier=.RARE}),
			_sell_price(ItemInstance{tier=.LEGENDARY}),
			_sell_price(ItemInstance{tier=.MYTHICAL}),
		))
		append(&lines, fmt.tprintf("🎭 Mythical chars get an S-ability | Weapon: 50%% Sword / 50%% Staff"))
		append(&lines, fmt.tprintf("🗡️ Item type: equal 1/6 chance each | Specials: no duplicates per item"))

		discord.respond(ctx, strings.join(lines[:], "\n", context.temp_allocator))
	})

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

	// --- Sell confirmation flow ---
	discord.on_component(client, "dungeon_sell_confirm_first", proc(ctx: ^discord.Component_Context) {
		user_id := ctx.interaction.member.user.id
		if user_id == "" do user_id = ctx.interaction.user.id

		sync.lock(&dungeon_mutex)
		if owner_id, ok := session_owners[ctx.interaction.message.id]; ok && owner_id != string(user_id) {
			sync.unlock(&dungeon_mutex); discord.defer_component_update(ctx); return
		}
		session, has := sell_sessions[string(user_id)]
		if !has { sync.unlock(&dungeon_mutex); discord.defer_component_update(ctx); return }

		_show_sell_confirm_final(ctx, &session)
		sell_sessions[string(user_id)] = session
		sync.unlock(&dungeon_mutex)
	})

	discord.on_component(client, "dungeon_sell_exec", proc(ctx: ^discord.Component_Context) {
		user_id := ctx.interaction.member.user.id
		if user_id == "" do user_id = ctx.interaction.user.id

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
				if player.weapon_id == id do player.weapon_id = 0
				if player.head_id   == id do player.head_id   = 0
				if player.chest_id  == id do player.chest_id  = 0
				if player.legs_id   == id do player.legs_id   = 0
				if player.boots_id  == id do player.boots_id  = 0
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
	})
	discord.on_component(client, "dungeon_sell_cancel", proc(ctx: ^discord.Component_Context) {
		user_id := ctx.interaction.member.user.id
		if user_id == "" do user_id = ctx.interaction.user.id

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
		if !has { chars = db_get_characters(db, string(user_id)); slice.sort_by(chars, proc(a, b: CollectedCharacter) -> bool { return a.tier < b.tier }) }
		char := chars[new_page - 1]
		img_url := get_image_url(.Character, char.tier, char.weapon_compat, "", .SWORD)
		embed, comps := build_character_embed(char, new_page, len(chars), img_url)
		discord.respond_component(ctx, {embed}, comps)
	case "item":
		items, has := gallery_item_cache[string(user_id)]
		if !has { items = db_get_items(db, string(user_id)); slice.sort_by(items, proc(a, b: ItemInstance) -> bool { return a.tier < b.tier }) }
		if new_page < 1 || new_page > len(items) { discord.defer_component_update(ctx); return }
		img_url := get_image_url(.Item, items[new_page - 1].tier, .SWORD, "", items[new_page - 1].item_type)
		embed, comps := build_item_embed(items[new_page - 1], new_page, len(items), img_url)
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
		p, _ := strconv.parse_i64(s[paren_start+1:slash_pos])
		t, _ := strconv.parse_i64(s[slash_pos+1:paren_end])
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
		state_ptr.pending_heal = 0
		state_ptr.shield_this_turn = false
		state_ptr.heal_this_turn = false
		state_ptr.regen_this_turn = false
		state_ptr.lightning_this_turn = false
		emit(state_ptr, .TURN_START)
		if state_ptr.pending_heal > 0 {
			log_fmt(state_ptr, "💚 Healed **%d** HP from abilities and equipment!", state_ptr.pending_heal)
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
	user_id := ctx.interaction.member.user.id
	if user_id == "" do user_id = ctx.interaction.user.id

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

_register_all_hooks :: proc(state: ^CombatState, db: ^discord.Db, p: ^Player) {
	register_class_hooks(state, p.class)
	register_hook(state, .TURN_START, _regen_mana)
	register_char_hooks(state, state.char_ability_name)
	logd("[hooks] char ability=%s hooks_bound", state.char_ability_name)
	if state.boss_floor {
		register_boss_hooks(state, state.monster.name)
	}
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
_dungeon_patch_original :: proc(client: ^discord.Client, token: string, embeds: []api.Embed, components: []api.Component, loc := #caller_location) -> string {
	data := api.InteractionCallbackData{embeds = embeds, components = components}
	body, err := json.marshal(data, allocator = context.temp_allocator)
	if err != nil { fmt.eprintfln("[patch_original] %s:%d: marshal error: %v", loc.procedure, loc.line, err); return "" }
	logd("[patch_original] %s:%d: PATCH body=%s", loc.procedure, loc.line, string(body))
	endpoint := fmt.tprintf("/webhooks/%s/%s/messages/@original", client.application_id, token)
	resp, ok := api.discord_patch(&client.rest_client, endpoint, body)
	if !ok { fmt.eprintfln("[patch_original] %s:%d: PATCH failed", loc.procedure, loc.line); return "" }
	defer delete(resp.body)
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("[patch_original] %s:%d: PATCH status=%d body: %s", loc.procedure, loc.line, resp.status_code, string(resp.body))
		return ""
	}
	msg: api.Message
	if json.unmarshal(resp.body, &msg) == nil && msg.id != "" { return strings.clone(msg.id) }
	return ""
}

// --- Sell helpers ---

@(private)
_new_sell_session :: proc(user_id: string, items: []ItemInstance, total_gold: int) -> Sell_Session {
	ids := make([]i64, len(items), context.allocator)
	for it, i in items do ids[i] = it.id
	return Sell_Session{
		user_id    = strings.clone(user_id),
		item_ids   = ids,
		item_count = len(items),
		total_gold = total_gold,
	}
}

@(private)
_new_sell_session_chars :: proc(user_id: string, chars: []CollectedCharacter, total_gold: int) -> Sell_Session {
	ids := make([]i64, len(chars), context.allocator)
	for c, i in chars do ids[i] = c.id
	return Sell_Session{
		user_id    = strings.clone(user_id),
		item_ids   = ids,
		item_count = len(chars),
		total_gold = total_gold,
		is_char    = true,
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
