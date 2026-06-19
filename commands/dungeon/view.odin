package dungeon

import "core:fmt"
import "core:strings"
import api "../../discord/api"

build_profile_embed :: proc(p: ^Player, char: CollectedCharacter, items: map[i64]ItemInstance, image_url: string = "") -> api.Embed {
	base := CLASS_BASE_STATS[p.class]
	tier_mult := TIER_CONFIGS[char.tier].mult
	weapon_match := false
	if weapon, ok := items[p.weapon_id]; ok {
		weapon_match = weapon.item_type == .SWORD && char.weapon_compat == .SWORD || weapon.item_type == .STAFF && char.weapon_compat == .STAFF
	}
	hp, atk, def, _ := calc_player_stats(base, tier_mult, items, weapon_match)

	total_spd := 0
	total_crit := 0
	for _, it in items {
		total_spd += it.bonus_spd
		total_crit += it.bonus_crit
	}
	dodge_pct := total_spd / 2
	if dodge_pct > 35 do dodge_pct = 35

	class_emoji := CLASS_EMOJIS[p.class]
	tier_label := TIER_LABELS[char.tier]
	class_name := CLASS_NAMES[p.class]

	lines: [8]string
	lines[0] = fmt.tprintf("**%s** %s", char.name, char.tier == .MYTHICAL ? "🌟" : "")
	lines[1] = fmt.tprintf("%s %s | %s Tier", class_emoji, class_name, tier_label)
	spd_str := total_spd > 0 ? fmt.tprintf(" | 👟 SPD: %d (%d%% dodge)", total_spd, dodge_pct) : ""
	crit_str := total_crit > 0 ? fmt.tprintf(" | 💢 Crit: %d%%", total_crit) : ""
	lines[2] = fmt.tprintf("❤️ HP: %d | ⚔️ ATK: %d | 🛡️ DEF: %d%s%s", hp, atk, def, spd_str, crit_str)
	lines[3] = fmt.tprintf("💰 Gold: %d | 📦 Lootboxes: %d | 🏔️ Floor: %d", p.gold, p.item_lootboxes, p.current_floor)
	if char.ability_name != "" {
		lines[4] = fmt.tprintf("✨ %s: %s", char.ability_name, char.ability_desc)
	}

	equip_parts := make([dynamic]string, context.temp_allocator)
	if p.weapon_id != 0 {
		if it, ok := items[p.weapon_id]; ok {
			append(&equip_parts, fmt.tprintf("🗡️ Weapon: %s (%s)", ITEM_NAMES[it.item_type], TIER_LABELS[it.tier]))
		}
	} else { append(&equip_parts, "🗡️ Weapon: None") }
	if p.head_id != 0 {
		if it, ok := items[p.head_id]; ok {
			append(&equip_parts, fmt.tprintf("⛑️ Head: %s (%s)", ITEM_NAMES[it.item_type], TIER_LABELS[it.tier]))
		}
	} else { append(&equip_parts, "⛑️ Head: None") }
	if p.chest_id != 0 {
		if it, ok := items[p.chest_id]; ok {
			append(&equip_parts, fmt.tprintf("🛡️ Chest: %s (%s)", ITEM_NAMES[it.item_type], TIER_LABELS[it.tier]))
		}
	} else { append(&equip_parts, "🛡️ Chest: None") }
	if p.legs_id != 0 {
		if it, ok := items[p.legs_id]; ok {
			append(&equip_parts, fmt.tprintf("👖 Legs: %s (%s)", ITEM_NAMES[it.item_type], TIER_LABELS[it.tier]))
		}
	} else { append(&equip_parts, "👖 Legs: None") }
	if p.boots_id != 0 {
		if it, ok := items[p.boots_id]; ok {
			append(&equip_parts, fmt.tprintf("👢 Boots: %s (%s)", ITEM_NAMES[it.item_type], TIER_LABELS[it.tier]))
		}
	} else { append(&equip_parts, "👢 Boots: None") }

	fields := make([]api.EmbedField, 2, context.temp_allocator)
	fields[0] = api.EmbedField{name = "Stats", value = strings.join(lines[:], "\n"), _inline = false}
	fields[1] = api.EmbedField{name = "Equipment", value = strings.join(equip_parts[:], "\n"), _inline = false}

	return api.Embed{
		title       = "⚔️ Dungeon Profile",
		color       = 0x9b59b6,
		fields      = fields,
		image       = image_url != "" ? api.EmbedImage{url = image_url} : api.EmbedImage{},
	}
}

build_battle_embed :: proc(state: ^CombatState, monster_image_url: string = "") -> (api.Embed, []api.Component) {
	hp_pct := 0
	if state.player.max_hp > 0 do hp_pct = state.player.hp * 10 / state.player.max_hp
	shield_str := state.buffs.shield > 0 ? fmt.tprintf(" 🛡️%d", state.buffs.shield) : ""
	hp_bar := fmt.tprintf("%s%s %d/%d HP%s", strings.repeat("█", hp_pct), strings.repeat("░", 10 - hp_pct), state.player.hp, state.player.max_hp, shield_str)

	mp_pct := 0
	if state.player.max_mana > 0 do mp_pct = state.player.mana * 10 / state.player.max_mana
	mp_bar := fmt.tprintf("%s%s %d/%d MP", strings.repeat("█", mp_pct), strings.repeat("░", 10 - mp_pct), state.player.mana, state.player.max_mana)

	m := state.monster
	mhp_pct := 0
	if m.max_hp > 0 do mhp_pct = m.hp * 10 / m.max_hp
	mhp_bar := fmt.tprintf("%s%s %d/%d HP", strings.repeat("█", mhp_pct), strings.repeat("░", 10-mhp_pct), m.hp, m.max_hp)

	mmp_pct := 0
	if m.max_mana > 0 do mmp_pct = m.mana * 10 / m.max_mana
	mmp_bar := fmt.tprintf("%s%s %d/%d MP", strings.repeat("█", mmp_pct), strings.repeat("░", 10-mmp_pct), m.mana, m.max_mana)

	rare_tag := m.kind == .Rare ? " ✨Rare" : ""
	boss_tag := m.kind == .Boss ? " 👑Boss" : ""

	log_text := ""
	if len(state.log) > 0 {
		start := len(state.log) - min(10, len(state.log))
		count := len(state.log) - start
		log_parts := make([]string, count, context.temp_allocator)
		for i in 0 ..< count do log_parts[i] = state.log[start + i]
		log_text = strings.join(log_parts[:], "\n")
	}

	fields_len := log_text != "" ? 3 : 2
	fields := make([]api.EmbedField, fields_len, context.temp_allocator)
	player_name := state.player.name != "" ? state.player.name : "Unknown"
	fields[0] = api.EmbedField{name = player_name, value = fmt.tprintf("%s\n%s", hp_bar, mp_bar), _inline = false}
	monster_value := fmt.tprintf("%s\n%s", mhp_bar, mmp_bar)
	if boss_desc := get_boss_ability_description(m.ability_name); boss_desc != "" {
		monster_value = fmt.tprintf("%s\n\n%s", monster_value, boss_desc)
	}
	fields[1] = api.EmbedField{name = fmt.tprintf("%s %s%s%s", m.emoji, m.name, rare_tag, boss_tag), value = monster_value, _inline = false}

	title := fmt.tprintf("⚔️ Dungeon — Floor %d · Turn %d", state.floor, state.turn)
	color := 0xe67e22

	if state.state == .PLAYER_WON {
		title = "🎉 Victory!"
		color = 0x2ecc71
	} else if state.state == .PLAYER_LOST {
		title = "💀 Defeat"
		color = 0xe74c3c
	}

	embed := api.Embed{title = title, color = color, fields = fields}
	if monster_image_url != "" do embed.image = api.EmbedImage{url = monster_image_url}

	if log_text != "" {
		embed.fields[len(embed.fields)-1] = api.EmbedField{name = "Combat Log", value = log_text, _inline = false}
	}

	if state.state == .PLAYER_TURN {
		buttons := make([dynamic]api.Component, 0, 4, context.temp_allocator)
		append(&buttons, api.ButtonComponent{type = .BUTTON, style = .PRIMARY,  custom_id = "dungeon_attack", label = "⚔️ Attack"})

		btn_label: string
		if state.ability_cooldown > 0 {
			btn_label = fmt.tprintf("⚡ %s (CD: %d)", state.class_ability_name, state.ability_cooldown)
		} else {
			btn_label = fmt.tprintf("⚡ %s (%d MP)", state.class_ability_name, state.ability_mana_cost)
		}
		btn_disabled := state.ability_cooldown > 0 || state.player.mana < state.ability_mana_cost
		btn_style := btn_disabled ? api.ButtonStyle.SECONDARY : api.ButtonStyle.SUCCESS
		append(&buttons, api.ButtonComponent{type = .BUTTON, style = btn_style, custom_id = "dungeon_ability", label = btn_label, disabled = btn_disabled})

		passive := _is_passive_char_ability(state.char_ability_name)
		char_ability_label := "✨ Character Ability"
		if state.char_ability_name != "" {
			if passive {
				char_ability_label = fmt.tprintf("🔒 %s (Passive)", state.char_ability_name)
			} else if state.char_ability_cooldown > 0 {
				char_ability_label = fmt.tprintf("✨ %s (CD: %d)", state.char_ability_name, state.char_ability_cooldown)
			} else {
				char_ability_label = fmt.tprintf("✨ %s (%d MP)", state.char_ability_name, state.char_ability_mana_cost)
			}
		}
		char_disabled := passive || state.char_ability_cooldown > 0 || state.char_ability_name == "" || state.player.mana < state.char_ability_mana_cost
		char_style := char_disabled ? api.ButtonStyle.SECONDARY : api.ButtonStyle.SUCCESS
		append(&buttons, api.ButtonComponent{type = .BUTTON, style = char_style, custom_id = "dungeon_char_ability", label = char_ability_label, disabled = char_disabled})

		append(&buttons, api.ButtonComponent{type = .BUTTON, style = .DANGER,   custom_id = "dungeon_run", label = "🏃 Run"})

		row := api.ActionRowComponent{type = .ACTION_ROW, components = buttons[:]}
		components := make([dynamic]api.Component, 0, 1, context.temp_allocator)
		append(&components, row)
		return embed, components[:]
	}

	return embed, {}
}

build_reward_embed :: proc(state: ^CombatState, chest_image_url: string = "", encounters: int = 0, floor_advanced: bool = false) -> api.Embed {
	lines := make([dynamic]string, context.temp_allocator)
	append(&lines, fmt.tprintf("🏔️ Floor %d cleared!", state.floor))
	append(&lines, fmt.tprintf("⚔️ Turns taken: %d", state.turn))
	append(&lines, "")
	append(&lines, "**Rewards:**")
	append(&lines, fmt.tprintf("💰 **%d** Gold", state.reward_gold))
	append(&lines, fmt.tprintf("📦 **%d** Item Lootbox(es)", state.reward_lootboxes))
	append(&lines, "")
	if floor_advanced {
		append(&lines, fmt.tprintf("⬆️ **Floor advanced to %d!**", state.floor + 1))
	} else if state.boss_floor {
		append(&lines, "⚠️ Boss floor — floor does not advance on replay.")
	} else {
		append(&lines, fmt.tprintf("📍 Encounters: **%d/3** to advance", encounters))
	}

	return api.Embed{
		title       = "🎉 Victory!",
		color       = 0xf1c40f,
		description = strings.join(lines[:], "\n"),
		thumbnail   = chest_image_url != "" ? api.EmbedThumbnail{url = chest_image_url} : api.EmbedThumbnail{},
	}
}

build_character_embed :: proc(char: CollectedCharacter, page: int, total: int, image_url: string = "") -> (api.Embed, []api.Component) {
	tier_label := TIER_LABELS[char.tier]
	class_name := WEAPON_COMPAT_NAMES[char.weapon_compat]
	class_emoji := WEAPON_COMPAT_EMOJIS[char.weapon_compat]

	lines: [6]string
	lines[0] = fmt.tprintf("**%s**", char.name)
	lines[1] = fmt.tprintf("%s Tier — %s %s", tier_label, class_emoji, class_name)
	lines[2] = fmt.tprintf("ID: %d", char.id)
	if char.ability_name != "" {
		lines[3] = fmt.tprintf("✨ **%s**", char.ability_name)
		lines[4] = char.ability_desc
	}

	embed := api.Embed{
		title       = fmt.tprintf("📜 Character Gallery (%d/%d)", page, total),
		description = strings.join(lines[:], "\n"),
		color       = TIER_EMBED_COLORS[char.tier],
		image       = image_url != "" ? api.EmbedImage{url = image_url} : api.EmbedImage{},
	}

	if total <= 1 do return embed, {}

	prev_id := "dungeon_char_prev"
	next_id := "dungeon_char_next"
	btns := make([dynamic]api.Component, 0, 2, context.temp_allocator)
	append(&btns, api.ButtonComponent{type = .BUTTON, style = .SECONDARY, custom_id = prev_id, label = "◀ Prev", disabled = page <= 1})
	append(&btns, api.ButtonComponent{type = .BUTTON, style = .SECONDARY, custom_id = next_id, label = "Next ▶", disabled = page >= total})
	row := api.ActionRowComponent{type = .ACTION_ROW, components = btns[:]}
	comps := make([dynamic]api.Component, 0, 1, context.temp_allocator)
	append(&comps, row)
	return embed, comps[:]
}

build_item_embed :: proc(item: ItemInstance, page: int, total: int, image_url: string = "") -> (api.Embed, []api.Component) {
	tier_label := TIER_LABELS[item.tier]
	tier_name  := TIER_CONFIGS[item.tier].name
	item_emoji := ITEM_EMOJIS[item.item_type]
	item_name  := ITEM_NAMES[item.item_type]

	lines: [8]string
	lines[0] = fmt.tprintf("**%s %s**", tier_name, item_name)
	lines[1] = fmt.tprintf("%s %s Tier — ID: %d", tier_label, item_emoji, item.id)
	if item.base_atk > 0 do lines[2] = fmt.tprintf("⚔️ ATK: +%d", item.base_atk)
	if item.base_def > 0 do lines[3] = fmt.tprintf("🛡️ DEF: +%d", item.base_def)

	affix_lines := make([dynamic]string, context.temp_allocator)
	if item.bonus_hp  > 0 do append(&affix_lines, fmt.tprintf("❤️ +%d HP", item.bonus_hp))
	if item.bonus_atk > 0 do append(&affix_lines, fmt.tprintf("⚔️ +%d ATK", item.bonus_atk))
	if item.bonus_def > 0 do append(&affix_lines, fmt.tprintf("🛡️ +%d DEF", item.bonus_def))
	if item.bonus_spd > 0 do append(&affix_lines, fmt.tprintf("💨 +%d SPD", item.bonus_spd))
	if item.bonus_crit > 0 do append(&affix_lines, fmt.tprintf("💢 +%d%% Crit", item.bonus_crit))
	if len(affix_lines) > 0 {
		lines[5] = fmt.tprintf("**Affixes:** %s", strings.join(affix_lines[:], ", "))
	}
	if item.special != "" {
		lines[6] = fmt.tprintf("✨ %s", item.special)
	}

	embed := api.Embed{
		title       = fmt.tprintf("🎒 Item Inventory (%d/%d)", page, total),
		description = strings.join(lines[:], "\n"),
		color       = TIER_EMBED_COLORS[item.tier],
		image       = image_url != "" ? api.EmbedImage{url = image_url} : api.EmbedImage{},
	}

	if total <= 1 do return embed, {}

	prev_id := "dungeon_item_prev"
	next_id := "dungeon_item_next"
	btns := make([dynamic]api.Component, 0, 2, context.temp_allocator)
	append(&btns, api.ButtonComponent{type = .BUTTON, style = .SECONDARY, custom_id = prev_id, label = "◀ Prev", disabled = page <= 1})
	append(&btns, api.ButtonComponent{type = .BUTTON, style = .SECONDARY, custom_id = next_id, label = "Next ▶", disabled = page >= total})
	row := api.ActionRowComponent{type = .ACTION_ROW, components = btns[:]}
	comps := make([dynamic]api.Component, 0, 1, context.temp_allocator)
	append(&comps, row)
	return embed, comps[:]
}

build_lootbox_result_embed :: proc(results: []CharacterGachaResult, image_url: string = "") -> (api.Embed, []api.Component) {
	best_tier := results[0].tier
	for r in results do if r.tier < best_tier do best_tier = r.tier

	lines := make([dynamic]string, context.temp_allocator)
	for r, i in results {
		weapon_emoji := WEAPON_COMPAT_EMOJIS[r.weapon_compat]
		weapon_name := WEAPON_COMPAT_NAMES[r.weapon_compat]
		tier_label := TIER_LABELS[r.tier]
		append(&lines, fmt.tprintf("%d. **%s** — %s Tier %s %s", i + 1, r.name, tier_label, weapon_emoji, weapon_name))
		if r.ability_name != "" {
			append(&lines, fmt.tprintf("   ✨ %s: %s", r.ability_name, r.ability_desc))
		}
		if r.tier == .MYTHICAL do append(&lines, "   🌟 **MYTHICAL!**")
	}

	embed := api.Embed{
		title       = fmt.tprintf("📦 Lootbox Results (%d)", len(results)),
		description = strings.join(lines[:], "\n"),
		color       = TIER_EMBED_COLORS[best_tier],
		thumbnail   = image_url != "" ? api.EmbedThumbnail{url = image_url} : api.EmbedThumbnail{},
	}
	return embed, {}
}

build_lootbox_item_embed :: proc(items: []ItemGachaResult, image_url: string = "") -> api.Embed {
	best_tier := items[0].tier
	for it in items do if it.tier < best_tier do best_tier = it.tier

	lines := make([dynamic]string, context.temp_allocator)
	for it, i in items {
		tier_label := TIER_LABELS[it.tier]
		item_emoji := ITEM_EMOJIS[it.item_type]
		item_name := ITEM_NAMES[it.item_type]
		append(&lines, fmt.tprintf("%d. %s %s — %s Tier", i + 1, item_emoji, item_name, tier_label))
		stat_parts := make([dynamic]string, context.temp_allocator)
		if it.base_atk > 0 do append(&stat_parts, fmt.tprintf("⚔️ ATK:%+d", it.base_atk))
		if it.base_def > 0 do append(&stat_parts, fmt.tprintf("🛡️ DEF:%+d", it.base_def))
		if it.bonus_hp > 0 do append(&stat_parts, fmt.tprintf("❤️+%d", it.bonus_hp))
		if it.bonus_atk > 0 do append(&stat_parts, fmt.tprintf("⚔️+%d", it.bonus_atk))
		if it.bonus_def > 0 do append(&stat_parts, fmt.tprintf("🛡️+%d", it.bonus_def))
		if it.bonus_spd > 0 do append(&stat_parts, fmt.tprintf("💨+%d", it.bonus_spd))
		if it.bonus_crit > 0 do append(&stat_parts, fmt.tprintf("💢+%d", it.bonus_crit))
		if it.special != "" do append(&stat_parts, fmt.tprintf("✨ %s", it.special))
		if len(stat_parts) > 0 do append(&lines, fmt.tprintf("   %s", strings.join(stat_parts[:], " ")))
	}

	return api.Embed{
		title       = fmt.tprintf("🎒 Lootbox Results (%d)", len(items)),
		description = strings.join(lines[:], "\n"),
		color       = TIER_EMBED_COLORS[best_tier],
		thumbnail   = image_url != "" ? api.EmbedThumbnail{url = image_url} : api.EmbedThumbnail{},
	}
}

LIST_PAGE_SIZE :: 10

build_character_list_embed :: proc(chars: []CollectedCharacter, page: int) -> (api.Embed, []api.Component) {
	total := len(chars)
	total_pages := (total + LIST_PAGE_SIZE - 1) / LIST_PAGE_SIZE
	if total_pages < 1 do total_pages = 1

	start := (page - 1) * LIST_PAGE_SIZE
	end := start + LIST_PAGE_SIZE
	if end > total do end = total

	lines := make([dynamic]string, context.temp_allocator)
	append(&lines, fmt.tprintf("**Characters (%d-%d of %d)**", start + 1, end, total))
	for i in start ..< end {
		c := chars[i]
		ability_tag := ""
		if c.ability_name != "" {
			ability_tag = fmt.tprintf(" ✨ %s", c.ability_name)
		}
		append(&lines, fmt.tprintf("%d. %s — %s Tier %s%s — ID: %d",
			i + 1, c.name, TIER_LABELS[c.tier], WEAPON_COMPAT_NAMES[c.weapon_compat], ability_tag, c.id))
	}

	embed := api.Embed{
		title       = fmt.tprintf("📜 Character List (%d/%d)", page, total_pages),
		description = strings.join(lines[:], "\n"),
		color       = 0x9b59b6,
	}

	if total_pages <= 1 do return embed, {}

	btns := make([dynamic]api.Component, 0, 2, context.temp_allocator)
	append(&btns, api.ButtonComponent{type = .BUTTON, style = .SECONDARY, custom_id = "dungeon_char_list_prev", label = "◀ Prev", disabled = page <= 1})
	append(&btns, api.ButtonComponent{type = .BUTTON, style = .SECONDARY, custom_id = "dungeon_char_list_next", label = "Next ▶", disabled = page >= total_pages})
	row := api.ActionRowComponent{type = .ACTION_ROW, components = btns[:]}
	comps := make([dynamic]api.Component, 0, 1, context.temp_allocator)
	append(&comps, row)
	return embed, comps[:]
}

build_item_list_embed :: proc(items: []ItemInstance, page: int) -> (api.Embed, []api.Component) {
	total := len(items)
	total_pages := (total + LIST_PAGE_SIZE - 1) / LIST_PAGE_SIZE
	if total_pages < 1 do total_pages = 1

	start := (page - 1) * LIST_PAGE_SIZE
	end := start + LIST_PAGE_SIZE
	if end > total do end = total

	lines := make([dynamic]string, context.temp_allocator)
	append(&lines, fmt.tprintf("**Items (%d-%d of %d)**", start + 1, end, total))
	for i in start ..< end {
		it := items[i]
		affix_str := ""
		if it.bonus_hp > 0 || it.bonus_atk > 0 || it.bonus_def > 0 || it.bonus_spd > 0 {
			affix_parts := make([dynamic]string, context.temp_allocator)
			if it.bonus_hp  > 0 do append(&affix_parts, fmt.tprintf("❤️+%d", it.bonus_hp))
			if it.bonus_atk > 0 do append(&affix_parts, fmt.tprintf("⚔️+%d", it.bonus_atk))
			if it.bonus_crit > 0 do append(&affix_parts, fmt.tprintf("💢+%d", it.bonus_crit))
			if it.bonus_def > 0 do append(&affix_parts, fmt.tprintf("🛡️+%d", it.bonus_def))
			if it.bonus_spd > 0 do append(&affix_parts, fmt.tprintf("💨+%d", it.bonus_spd))
			affix_str = strings.join(affix_parts[:], " ")
		}
		special_tag := ""
		if it.special != "" do special_tag = fmt.tprintf(" ✨ %s", it.special)
		append(&lines, fmt.tprintf("%d. %s %s — %s Tier — ID: %d%s",
			i + 1, ITEM_EMOJIS[it.item_type], ITEM_NAMES[it.item_type], TIER_LABELS[it.tier], it.id, special_tag))
		if affix_str != "" || it.base_atk > 0 || it.base_def > 0 {
			stat_line := fmt.tprintf("     ⚔️ ATK:%+d 🛡️ DEF:%+d | %s", it.base_atk, it.base_def, affix_str)
			append(&lines, stat_line)
		}
	}

	embed := api.Embed{
		title       = fmt.tprintf("🎒 Item List (%d/%d)", page, total_pages),
		description = strings.join(lines[:], "\n"),
		color       = 0x3498db,
	}

	if total_pages <= 1 do return embed, {}

	btns := make([dynamic]api.Component, 0, 2, context.temp_allocator)
	append(&btns, api.ButtonComponent{type = .BUTTON, style = .SECONDARY, custom_id = "dungeon_item_list_prev", label = "◀ Prev", disabled = page <= 1})
	append(&btns, api.ButtonComponent{type = .BUTTON, style = .SECONDARY, custom_id = "dungeon_item_list_next", label = "Next ▶", disabled = page >= total_pages})
	row := api.ActionRowComponent{type = .ACTION_ROW, components = btns[:]}
	comps := make([dynamic]api.Component, 0, 1, context.temp_allocator)
	append(&comps, row)
	return embed, comps[:]
}

build_lootbox_result_embed_single :: proc(r: CharacterGachaResult, page: int, total: int, image_url: string = "") -> (api.Embed, []api.Component) {
	tier_label := TIER_LABELS[r.tier]
	weapon_emoji := WEAPON_COMPAT_EMOJIS[r.weapon_compat]
	weapon_name := WEAPON_COMPAT_NAMES[r.weapon_compat]

	lines: [5]string
	lines[0] = fmt.tprintf("**%s**", r.name)
	lines[1] = fmt.tprintf("%s Tier — %s %s", tier_label, weapon_emoji, weapon_name)
	if r.ability_name != "" {
		lines[2] = fmt.tprintf("✨ **%s**", r.ability_name)
		lines[3] = r.ability_desc
	}
	lines[4] = r.tier == .MYTHICAL ? "🌟 **MYTHICAL PULL!**" : ""

	embed := api.Embed{
		title       = fmt.tprintf("📦 Lootbox Results (%d/%d)", page, total),
		description = strings.join(lines[:], "\n"),
		color       = TIER_EMBED_COLORS[r.tier],
		thumbnail   = image_url != "" ? api.EmbedThumbnail{url = image_url} : api.EmbedThumbnail{},
	}

	if total <= 1 do return embed, {}

	prev_id := "dungeon_lbox_char_prev"
	next_id := "dungeon_lbox_char_next"
	btns := make([dynamic]api.Component, 0, 2, context.temp_allocator)
	append(&btns, api.ButtonComponent{type = .BUTTON, style = .SECONDARY, custom_id = prev_id, label = "◀ Prev", disabled = page <= 1})
	append(&btns, api.ButtonComponent{type = .BUTTON, style = .SECONDARY, custom_id = next_id, label = "Next ▶", disabled = page >= total})
	row := api.ActionRowComponent{type = .ACTION_ROW, components = btns[:]}
	comps := make([dynamic]api.Component, 0, 1, context.temp_allocator)
	append(&comps, row)
	return embed, comps[:]
}
