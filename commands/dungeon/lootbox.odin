package dungeon

import "core:math/rand"
import "core:strings"

@(private)
generate_character_lootbox :: proc() -> [LOOTBOX_CHARACTER_COUNT]CharacterGachaResult {
	results: [LOOTBOX_CHARACTER_COUNT]CharacterGachaResult
	for i in 0 ..< LOOTBOX_CHARACTER_COUNT {
		tier := _roll_tier()
		name := _random_name()
		compat_idx := rand.int_max(2)
		weapon_compat: Weapon_Compat = compat_idx == 0 ? .SWORD : .STAFF

		ability_name := ""
		ability_desc := ""
		if tier == .MYTHICAL {
			ability_name, ability_desc = _random_s_ability()
		}

		results[i] = CharacterGachaResult{
			name         = name,
			tier         = tier,
			weapon_compat = weapon_compat,
			ability_name = strings.clone(ability_name),
			ability_desc = strings.clone(ability_desc),
		}
	}
	return results
}

@(private)
generate_item_lootbox :: proc(floor: int) -> [LOOTBOX_ITEM_COUNT]ItemGachaResult {
	results: [LOOTBOX_ITEM_COUNT]ItemGachaResult
	for i in 0 ..< LOOTBOX_ITEM_COUNT {
		tier := _roll_tier()
		item_type := _roll_item_type()

		cfg := TIER_CONFIGS[tier]
		base_atk := int(f64(ITEM_BASE_ATK[item_type]) * cfg.mult)
		base_def := int(f64(ITEM_BASE_DEF[item_type]) * cfg.mult)

		affixes := _generate_affixes(tier, floor)
		special := _random_specials(item_type, tier, floor)

		results[i] = ItemGachaResult{
			item_type = item_type,
			tier      = tier,
			base_atk  = base_atk,
			base_def  = base_def,
			bonus_hp  = affixes.hp,
			bonus_atk = affixes.atk,
			bonus_def = affixes.def,
			bonus_spd = affixes.spd,
			bonus_crit = affixes.crit,
			special   = strings.clone(special),
			floor     = floor,
		}
	}
	return results
}

@(private)
_roll_item_type :: proc() -> Item_Type {
	all := []Item_Type{.SWORD, .STAFF, .HELM, .CHEST, .LEGS, .BOOTS}
	return all[rand.int_max(len(all))]
}

@(private)
_generate_affixes :: proc(tier: Tier, floor: int) -> struct { hp, atk, def, spd, crit: int } {
	cfg := TIER_CONFIGS[tier]
	if cfg.max_affixes == 0 do return {}

	count := cfg.min_affixes
	if cfg.max_affixes > cfg.min_affixes {
		count += rand.int_max(cfg.max_affixes - cfg.min_affixes + 1)
	}

	all_affixes := []Affix{.HP, .ATK, .DEF, .SPD, .CRIT}
	picked := make([dynamic]Affix, context.temp_allocator)

	for _ in 0 ..< count {
		idx := rand.int_max(len(all_affixes))
		append(&picked, all_affixes[idx])
	}

	result: struct { hp, atk, def, spd, crit: int }
	for aff in picked {
		val := cfg.affix_min
		if cfg.affix_max > cfg.affix_min {
			val += rand.int_max(cfg.affix_max - cfg.affix_min + 1)
		}
		floor_mult := 1.0 + f64(floor) * 0.03
		val = int(f64(val) * floor_mult)
		if val < 1 do val = 1
		switch aff {
		case .HP:  result.hp += val
		case .ATK: result.atk += val
		case .DEF: result.def += val
		case .SPD: result.spd += val
		case .CRIT: result.crit += val
		}
	}
	return result
}
