package dungeon

import "core:math/rand"
import "core:strings"

@(private)
generate_character_lootbox :: proc() -> [LOOTBOX_CHARACTER_COUNT]CharacterGachaResult {
	results: [LOOTBOX_CHARACTER_COUNT]CharacterGachaResult
	for i in 0 ..< LOOTBOX_CHARACTER_COUNT {
		tier := _roll_tier()
		name := _random_name()
		class_idx := rand.int_max(2)
		class: Class_Type = class_idx == 0 ? .ATTACKER : .HEALER

		ability_name := ""
		ability_desc := ""
		if tier == .S {
			ability_name, ability_desc = _random_s_ability()
		}

		results[i] = CharacterGachaResult{
			name         = name,
			tier         = tier,
			class        = class,
			ability_name = strings.clone(ability_name),
			ability_desc = strings.clone(ability_desc),
		}
	}
	return results
}

@(private)
generate_item_lootbox :: proc() -> [LOOTBOX_ITEM_COUNT]ItemGachaResult {
	results: [LOOTBOX_ITEM_COUNT]ItemGachaResult
	for i in 0 ..< LOOTBOX_ITEM_COUNT {
		tier := _roll_tier()
		item_type := _roll_item_type()

		cfg := TIER_CONFIGS[tier]
		base_atk := int(f64(ITEM_BASE_ATK[item_type]) * cfg.mult)
		base_def := int(f64(ITEM_BASE_DEF[item_type]) * cfg.mult)

		affixes := _generate_affixes(tier)
		special := ""
		if tier == .S {
			special = _random_special_effect()
		}

		results[i] = ItemGachaResult{
			item_type = item_type,
			tier      = tier,
			base_atk  = base_atk,
			base_def  = base_def,
			bonus_hp  = affixes.hp,
			bonus_atk = affixes.atk,
			bonus_def = affixes.def,
			bonus_spd = affixes.spd,
			special   = strings.clone(special),
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
_generate_affixes :: proc(tier: Tier) -> struct { hp, atk, def, spd: int } {
	cfg := TIER_CONFIGS[tier]
	if cfg.max_affixes == 0 do return {}

	count := cfg.min_affixes
	if cfg.max_affixes > cfg.min_affixes {
		count += rand.int_max(cfg.max_affixes - cfg.min_affixes + 1)
	}

	all_affixes := []Affix{.HP, .ATK, .DEF, .SPD}
	picked := make([dynamic]Affix, context.temp_allocator)

	for _ in 0 ..< count {
		idx := rand.int_max(len(all_affixes))
		append(&picked, all_affixes[idx])
	}

	result: struct { hp, atk, def, spd: int }
	for aff in picked {
		val := cfg.affix_min
		if cfg.affix_max > cfg.affix_min {
			val += rand.int_max(cfg.affix_max - cfg.affix_min + 1)
		}
		switch aff {
		case .HP:  result.hp += val
		case .ATK: result.atk += val
		case .DEF: result.def += val
		case .SPD: result.spd += val
		}
	}
	return result
}
