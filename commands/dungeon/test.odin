package dungeon

import "core:fmt"
import "core:testing"

// 1. Pure stat computation
@(test)
test_calc_player_stats :: proc(t: ^testing.T) {
	base := Class_Base{hp = 100, atk = 25, def = 10, mana = 50, mana_regen = 6, ability_mana_cost = 20}
	tier_mult := 1.0
	items := make(map[i64]ItemInstance, context.temp_allocator)

	hp, atk, def, mana := calc_player_stats(base, tier_mult, items, false)
	testing.expect_value(t, hp, 100)
	testing.expect_value(t, atk, 25)
	testing.expect_value(t, def, 10)
	testing.expect_value(t, mana, 50)

	_, atk2, _, _ := calc_player_stats(base, tier_mult, items, true)
	testing.expect_value(t, atk2, 31)

	items[1] = ItemInstance{bonus_hp = 10, bonus_atk = 5, bonus_def = 3}
	hp3, atk3, def3, _ := calc_player_stats(base, tier_mult, items, false)
	testing.expect_value(t, hp3, 110)
	testing.expect_value(t, atk3, 30)
	testing.expect_value(t, def3, 13)
}

// 2. Damage formula
@(test)
test_combat_deal_damage :: proc(t: ^testing.T) {
	// atk=10, def=4 → base = 10 - 2 = 8, variance 0-1, so dmg = 7-8
	dmg := combat_deal_damage(10, 4)
	testing.expect(t, dmg >= 7, "damage should be at least 7 (atk=10, def=4 → base=8)")
	testing.expect(t, dmg <= 8, "damage should be at most 8 (atk=10, def=4)")

	// High def shouldn't floor below 1
	dmg2 := combat_deal_damage(5, 200)
	testing.expect_value(t, dmg2, 1)

	// atk=100, def=0 → dmg=100, var 0-24, dmg/8=12 → result = 88-112
	dmg3 := combat_deal_damage(100, 0)
	testing.expect(t, dmg3 >= 88, "damage should be at least 88 (atk=100, def=0)")
	testing.expect(t, dmg3 <= 112, "damage should be at most 112 (atk=100, def=0)")
}
// 3. Item sell prices
@(test)
test_sell_price :: proc(t: ^testing.T) {
	testing.expect_value(t, _sell_price(ItemInstance{tier = .COMMON}), 3)
	testing.expect_value(t, _sell_price(ItemInstance{tier = .UNCOMMON}), 8)
	testing.expect_value(t, _sell_price(ItemInstance{tier = .RARE}), 20)
	testing.expect_value(t, _sell_price(ItemInstance{tier = .LEGENDARY}), 50)
	testing.expect_value(t, _sell_price(ItemInstance{tier = .MYTHICAL}), 150)

	item := ItemInstance{tier = .COMMON, bonus_hp = 2, bonus_atk = 1}
	testing.expect_value(t, _sell_price(item), 9)
}

// 4. Character sell prices
@(test)
test_sell_price_char :: proc(t: ^testing.T) {
	testing.expect_value(t, _sell_price_char(CollectedCharacter{tier = .COMMON}), 25)
	testing.expect_value(t, _sell_price_char(CollectedCharacter{tier = .UNCOMMON}), 75)
	testing.expect_value(t, _sell_price_char(CollectedCharacter{tier = .RARE}), 200)
	testing.expect_value(t, _sell_price_char(CollectedCharacter{tier = .LEGENDARY}), 500)
	testing.expect_value(t, _sell_price_char(CollectedCharacter{tier = .MYTHICAL}), 1500)
}

// 5. Embed title parsing
@(test)
test_parse_page_total :: proc(t: ^testing.T) {
	page, total := _parse_page_total("Characters (3/15)")
	testing.expect_value(t, page, 3)
	testing.expect_value(t, total, 15)

	page2, total2 := _parse_page_total("Items (1/45)")
	testing.expect_value(t, page2, 1)
	testing.expect_value(t, total2, 45)

	page3, total3 := _parse_page_total("No parens here")
	testing.expect_value(t, page3, 1)
	testing.expect_value(t, total3, 1)

	page4, total4 := _parse_page_total("")
	testing.expect_value(t, page4, 1)
	testing.expect_value(t, total4, 1)
}

// 6. Passive character abilities
@(test)
test_is_passive_char_ability :: proc(t: ^testing.T) {
	testing.expect(t, _is_passive_char_ability("Phoenix Rebirth"))
	testing.expect(t, _is_passive_char_ability("Midas Touch"))
	testing.expect(t, _is_passive_char_ability("Scavenger"))
	testing.expect(t, _is_passive_char_ability("Last Stand"))
	testing.expect(t, _is_passive_char_ability("Blood Money"))

	testing.expect(t, !_is_passive_char_ability("Execute"))
	testing.expect(t, !_is_passive_char_ability("Deep Freeze"))
	testing.expect(t, !_is_passive_char_ability("Call of the Wild"))
	testing.expect(t, !_is_passive_char_ability(""))
}

// 7. Item-type gating
@(test)
test_get_allowed_specials :: proc(t: ^testing.T) {
	sword_specials := _get_allowed_specials(.SWORD, context.temp_allocator)
	testing.expect(t, len(sword_specials) > 0, "SWORD should have specials")

	helm_specials := _get_allowed_specials(.HELM, context.temp_allocator)
	testing.expect(t, len(helm_specials) > 0, "HELM should have specials")

	boots_specials := _get_allowed_specials(.BOOTS, context.temp_allocator)
	testing.expect(t, len(boots_specials) > 0, "BOOTS should have specials")
}

// 8. ITEM_SPECIALS table integrity
@(test)
test_validate_item_specials :: proc(t: ^testing.T) {
	_validate_item_specials()
	testing.expect(t, true, "validate completed without assertion failure")
}

// 9. Class hook registration
@(test)
test_class_hooks_registered :: proc(t: ^testing.T) {
	{
		def := CLASS_ABILITY_HOOKS[.ATTACKER]
		testing.expect(t, def.hook != nil, "ATTACKER should have a non-nil hook")
		testing.expect_value(t, def.event, CombatEvent.ON_ABILITY)
	}
	{
		def := CLASS_ABILITY_HOOKS[.HEALER]
		testing.expect(t, def.hook != nil, "HEALER should have a non-nil hook")
		testing.expect_value(t, def.event, CombatEvent.ON_ABILITY)
	}
}

@(test)
test_char_hooks_registered :: proc(t: ^testing.T) {
	for def in S_ABILITIES {
		testing.expect(t, def.hook != nil,
			fmt.tprintf("char ability %q should have a non-nil hook", def.name))
		testing.expect(t, def.name != "", "char ability should have a name")
		testing.expect(t, def.description != "", fmt.tprintf("char ability %q should have a description", def.name))
	}
	testing.expect(t, len(S_ABILITIES) == 8, "should be exactly 8 S-ability characters")
}

// 11. Item special hook mappings
@(test)
test_item_hooks_registered :: proc(t: ^testing.T) {
	_validate_item_specials()
	for def in ITEM_SPECIALS {
		testing.expect(t, def.label != "", "special should have a label")
		testing.expect(t, def.hook != nil,
			fmt.tprintf("special %q should have a non-nil hook", def.label))
	}
	testing.expect(t, len(ITEM_SPECIALS) > 0, "should have item specials defined")
}

// 11b. Boss ability hook mappings
@(test)
test_boss_hooks_registered :: proc(t: ^testing.T) {
	for def in BOSS_ABILITIES {
		testing.expect(t, def.hook != nil,
			fmt.tprintf("boss ability %q should have a non-nil hook", def.name))
		testing.expect(t, def.name != "", "boss ability should have a name")
		testing.expect(t, def.description != "", fmt.tprintf("boss ability %q should have a description", def.name))
	}
	testing.expect(t, len(BOSS_ABILITIES) >= 1, "should have at least 1 boss ability defined")
}

// 12. Generic sell session constructor
@(test)
test_generic_sell_session :: proc(t: ^testing.T) {
	items := []ItemInstance{{id = 5, tier = .COMMON}, {id = 7, tier = .RARE}}
	session := _new_sell_session_from("user1", items, 100, false)
	testing.expect_value(t, session.item_count, 2)
	testing.expect_value(t, session.total_gold, 100)
	testing.expect(t, !session.is_char, "should not be character session")
	testing.expect_value(t, session.item_ids[0], i64(5))
	testing.expect_value(t, session.item_ids[1], i64(7))

	chars := []CollectedCharacter{{id = 3, tier = .COMMON}, {id = 9, tier = .LEGENDARY}}
	session2 := _new_sell_session_from("user1", chars, 200, true)
	testing.expect(t, session2.is_char, "should be character session")
	testing.expect_value(t, session2.item_count, 2)
	testing.expect_value(t, session2.total_gold, 200)
	testing.expect_value(t, session2.item_ids[0], i64(3))
	testing.expect_value(t, session2.item_ids[1], i64(9))
}

// 13. Equip slot definitions
@(test)
test_equip_slot_defs :: proc(t: ^testing.T) {
	p: Player
	ids := get_equipped_item_ids(&p)
	testing.expect_value(t, len(ids), 0)

	p.weapon_id = 42
	ids2 := get_equipped_item_ids(&p)
	testing.expect_value(t, len(ids2), 1)
	testing.expect_value(t, ids2[0], i64(42))

	p.head_id = 17
	p.chest_id = 3
	ids3 := get_equipped_item_ids(&p)
	testing.expect_value(t, len(ids3), 3)

	unequip_item(&p, 42)
	testing.expect_value(t, p.weapon_id, i64(0))
	testing.expect_value(t, p.head_id, i64(17))
	testing.expect_value(t, p.chest_id, i64(3))
}
