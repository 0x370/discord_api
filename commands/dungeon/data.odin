#+feature dynamic-literals
package dungeon

import "core:fmt"
import "core:math/rand"
import "core:strings"

TIER_COLLECTION_ORDER :: []Tier{
	.MYTHICAL,
	.LEGENDARY,
	.RARE,
	.UNCOMMON,
	.COMMON,
}

TIER_CONFIGS := [Tier]Tier_Config {
	.MYTHICAL  = {name = "Mythical",  label = "Mythical",  mult = 1.60, min_affixes = 3, max_affixes = 3, affix_min = 6,  affix_max = 12, min_specials = 1, max_specials = 2},
	.LEGENDARY = {name = "Legendary", label = "Legendary", mult = 1.40, min_affixes = 2, max_affixes = 3, affix_min = 4,  affix_max = 8,  min_specials = 2, max_specials = 3},
	.RARE      = {name = "Rare",      label = "Rare",      mult = 1.25, min_affixes = 2, max_affixes = 2, affix_min = 3,  affix_max = 6,  min_specials = 1, max_specials = 2},
	.UNCOMMON  = {name = "Uncommon",  label = "Uncommon",  mult = 1.12, min_affixes = 1, max_affixes = 1, affix_min = 2,  affix_max = 4,  min_specials = 1, max_specials = 1},
	.COMMON    = {name = "Common",    label = "Common",    mult = 1.00, min_affixes = 0, max_affixes = 1, affix_min = 1,  affix_max = 2,  min_specials = 0, max_specials = 0},
}
TIER_WEIGHTS := [Tier]int {
	.MYTHICAL  = 1,
	.LEGENDARY = 2,
	.RARE      = 7,
	.UNCOMMON  = 20,
	.COMMON    = 70,
}
TIER_LABELS := [Tier]string {
	.MYTHICAL  = "Mythical",
	.LEGENDARY = "Legendary",
	.RARE      = "Rare",
	.UNCOMMON  = "Uncommon",
	.COMMON    = "Common",
}

TIER_EMBED_COLORS := [Tier]int {
	.MYTHICAL  = 0xff4500,
	.LEGENDARY = 0xffd700,
	.RARE      = 0x3498db,
	.UNCOMMON  = 0x2ecc71,
	.COMMON    = 0x95a5a6,
}

CLASS_BASE_STATS := [Class_Type]Class_Base {
	.ATTACKER = {hp = 100, atk = 25, def = 10, mana = 50, mana_regen = 6,  ability_mana_cost = 20},
	.HEALER   = {hp = 120, atk = 15, def = 15, mana = 80, mana_regen = 10, ability_mana_cost = 25},
}

CLASS_NAMES := [Class_Type]string {
	.ATTACKER = "Attacker",
	.HEALER   = "Healer",
}

CLASS_EMOJIS := [Class_Type]string {
	.ATTACKER = "⚔️",
	.HEALER   = "💚",
}

WEAPON_COMPAT_NAMES := [Weapon_Compat]string {
	.SWORD = "Sword",
	.STAFF = "Staff",
}

WEAPON_COMPAT_EMOJIS := [Weapon_Compat]string {
	.SWORD = "🗡️",
	.STAFF = "🪄",
}

CLASS_ABILITY_DISPLAY_NAMES := [Class_Type]string {
	.ATTACKER = "Power Strike",
	.HEALER   = "Healing Light",
}

ABILITY_COOLDOWN :: 3
CHAR_ABILITY_MANA_COST :: 30

hook_class_attacker :: proc(state: ^CombatState) {
	dmg := int(f64(state.player.atk) * 1.5)
	mitigated := combat_deal_damage(dmg, state.monster.def)
	state.monster.hp -= mitigated
	if state.monster.hp < 0 do state.monster.hp = 0
	log_fmt(state, "⚡ **%s** used Power Strike on %s for **%d** damage!", state.player.name, state.monster.name, mitigated)
	emit(state, .ON_DAMAGE_DEALT)
}

hook_class_healer :: proc(state: ^CombatState) {
	heal := int(f64(state.player.max_hp) * 0.2)
	state.player.hp += heal
	if state.player.hp > state.player.max_hp do state.player.hp = state.player.max_hp
	log_fmt(state, "💚 **%s** healed for **%d** HP!", state.player.name, heal)
	emit(state, .ON_HEAL)
}

hook_item_double_dmg :: proc(state: ^CombatState) {
	logd("[hook] ON_ATTACK → double_dmg")
	if state.bonus_attack_procs >= 1 do return
	if rand.int_max(100) >= 15 do return
	dmg := combat_deal_damage(state.player.atk, state.monster.def)
	state.monster.hp -= dmg
	if state.monster.hp < 0 do state.monster.hp = 0
	state.bonus_attack_procs += 1
	log_fmt(state, "⚡ **Double Damage!** Extra **%d** damage dealt!", dmg)
}

hook_item_heal_per_turn :: proc(state: ^CombatState) {
	logd("[hook] TURN_START → heal_per_turn")
	if state.heal_this_turn do return
	state.heal_this_turn = true
	heal := state.player.max_hp * 3 / 100
	if heal < 1 do heal = 1
	state.player.hp += heal
	if state.player.hp > state.player.max_hp do state.player.hp = state.player.max_hp
	state.pending_heal += heal
}

hook_item_def_reduce :: proc(state: ^CombatState) {
	logd("[hook] ON_DAMAGE_TAKEN → def_reduce")
	if state.def_reduce_done do return
	state.def_reduce_done = true
	state.monster.def = state.monster.def * 80 / 100
}

hook_revive :: proc(state: ^CombatState) {
	logd("[hook] ON_DEATH → revive (phoenix)")
	if state.char_revive_used do return
	state.char_revive_used = true
	state.player.hp = state.player.max_hp * 40 / 100
	if state.player.hp < 1 do state.player.hp = 1
	log_fmt(state, "🔥 **Phoenix Rebirth**! You rise from the ashes with **%d** HP!", state.player.hp)
}

hook_summon :: proc(state: ^CombatState) {
	logd("[hook] TURN_START → summon")
	dmg := combat_deal_damage(state.player.atk, state.monster.def / 2)
	state.monster.hp -= dmg
	if state.monster.hp < 0 do state.monster.hp = 0
	log_fmt(state, "🐺 **Call of the Wild**! Summoned beast attacks for **%d** damage!", dmg)
}

// --- Character S-ability hooks ---
hook_char_midas_touch :: proc(state: ^CombatState) {
	logd("[hook] VICTORY → midas_touch")
	state.reward_gold = state.reward_gold * 2
	log_fmt(state, "🪙 **Midas Touch!** Gold reward doubled!")
}

hook_char_scavenger :: proc(state: ^CombatState) {
	logd("[hook] VICTORY → scavenger")
	if rand.int_max(100) >= 25 do return
	state.reward_lootboxes += 1
	log_fmt(state, "🔍 **Scavenger!** Found an extra item lootbox!")
}

hook_char_last_stand :: proc(state: ^CombatState) {
	logd("[hook] ON_DEATH → last_stand")
	if state.char_revive_used do return
	state.char_revive_used = true
	state.player.hp = 1
	dmg := combat_deal_damage(state.player.atk * 2, state.monster.def)
	state.monster.hp -= dmg
	if state.monster.hp < 0 do state.monster.hp = 0
	log_fmt(state, "💀 **Last Stand!** You refuse to fall, dealing **%d** damage!", dmg)
}

hook_char_execute :: proc(state: ^CombatState) {
	logd("[hook] ON_ABILITY → execute")
	threshold := state.monster.max_hp * 25 / 100
	if threshold < 1 do threshold = 1
	if state.monster.hp > threshold do return
	dmg := combat_deal_damage(state.player.atk * 3, state.monster.def)
	state.monster.hp -= dmg
	if state.monster.hp < 0 do state.monster.hp = 0
	state.last_damage_dealt = dmg
	log_fmt(state, "🗡️ **Execute!** Dealt **%d** finisher damage!", dmg)
}

hook_char_blood_money :: proc(state: ^CombatState) {
	logd("[hook] VICTORY → blood_money")
	bonus := state.monster.max_hp * 10 / 100
	if bonus < 1 do bonus = 1
	state.reward_gold += bonus
	log_fmt(state, "🩸 **Blood Money!** +%d bonus gold from %s's corpse!", bonus, state.monster.name)
}

hook_char_deep_freeze :: proc(state: ^CombatState) {
	logd("[hook] ON_ABILITY → deep_freeze")
	state.monster_frozen = 2
	log_fmt(state, "❄️ **Deep Freeze!** %s is frozen solid for 2 turns!", state.monster.name)
}


// --- Item special effect hooks (7 existing dead + 8 new D3-inspired) ---

// Phase 1: Wire dead specials
hook_item_first_strike :: proc(state: ^CombatState) {
	logd("[hook] ON_ATTACK → first_strike")
	if !state.first_attack do return
	if state.bonus_attack_procs >= 1 do return
	state.first_attack = false
	dmg := combat_deal_damage(state.player.atk, state.monster.def)
	state.monster.hp -= dmg
	if state.monster.hp < 0 do state.monster.hp = 0
	state.bonus_attack_procs += 1
	log_fmt(state, "💥 **First Strike!** Extra **%d** damage!", dmg)
}

hook_item_ignore_def :: proc(state: ^CombatState) {
	logd("[hook] ON_ATTACK → ignore_def")
	bonus := state.monster.def * 20 / 100
	if bonus < 1 do bonus = 1
	state.monster.hp -= bonus
	if state.monster.hp < 0 do state.monster.hp = 0
	log_fmt(state, "🔓 **Armor Pierce!** Bypassed **%d** DEF for **%d** bonus damage!", state.monster.def, bonus)
}

hook_item_life_steal :: proc(state: ^CombatState) {
	logd("[hook] ON_DAMAGE_DEALT → life_steal")
	cap := state.player.atk * 15 / 100
	if cap < 1 do cap = 1
	if state.life_steal_total >= cap do return
	heal := state.player.atk * 8 / 100
	if heal < 1 do heal = 1
	state.player.hp += heal
	if state.player.hp > state.player.max_hp do state.player.hp = state.player.max_hp
	state.life_steal_total += heal
	log_fmt(state, "🩸 **Lifesteal!** Healed for **%d** HP!", heal)
}

hook_item_dodge :: proc(state: ^CombatState) {
	logd("[hook] ON_DAMAGE_TAKEN → dodge")
	if rand.int_max(100) >= 10 do return
	state.player.hp += state.last_damage_taken
	if state.player.hp > state.player.max_hp do state.player.hp = state.player.max_hp
	log_fmt(state, "💨 **Dodged!** The attack missed!")
}

hook_item_gold_bonus :: proc(state: ^CombatState) {
	logd("[hook] VICTORY → gold_bonus")
	bonus := state.reward_gold * 5 / 100
	if bonus < 1 do bonus = 1
	state.reward_gold += bonus
	log_fmt(state, "💰 **Treasure Hunter!** +%d bonus gold!", bonus)
}

hook_item_stun :: proc(state: ^CombatState) {
	logd("[hook] ON_ATTACK → stun")
	if state.stun_freeze_cooldown > 0 do return
	if rand.int_max(100) >= 12 do return
	state.monster_stunned = true
	state.stun_freeze_cooldown = 2
	log_fmt(state, "⚡ **Stunned!** %s skips its next turn!", state.monster.name)
}

hook_item_boss_resist :: proc(state: ^CombatState) {
	logd("[hook] ON_DAMAGE_TAKEN → boss_resist")
	if state.monster.kind != .Boss do return
	if state.boss_resist_used do return
	state.boss_resist_used = true
	heal := state.last_damage_taken / 4
	if heal < 1 do heal = 1
	state.player.hp += heal
	if state.player.hp > state.player.max_hp do state.player.hp = state.player.max_hp
	log_fmt(state, "🛡️ **Boss Resistance!** Reduced damage, restored **%d** HP!", heal)
}

// Phase 2: New D3-inspired specials
hook_item_thorns :: proc(state: ^CombatState) {
	logd("[hook] ON_DAMAGE_TAKEN → thorns")
	if state.thorns_used do return
	state.thorns_used = true
	reflect := state.last_damage_taken * 25 / 100
	if reflect < 1 do reflect = 1
	state.monster.hp -= reflect
	if state.monster.hp < 0 do state.monster.hp = 0
	log_fmt(state, "🛡️ **Thorns!** Reflected **%d** damage!", reflect)
}

hook_item_shield :: proc(state: ^CombatState) {
	logd("[hook] TURN_START → shield")
	if state.shield_this_turn do return
	state.shield_this_turn = true
	shield := state.player.max_hp * 8 / 100
	if shield < 1 do shield = 1
	state.shield += shield
	log_fmt(state, "🛡️ **Barrier!** Gained **%d** shield!", shield)
}

hook_item_crit :: proc(state: ^CombatState) {
	logd("[hook] ON_ATTACK → crit")
	if state.bonus_attack_procs >= 1 do return
	if rand.int_max(100) >= 15 do return
	dmg := combat_deal_damage(state.player.atk, state.monster.def)
	state.monster.hp -= dmg
	if state.monster.hp < 0 do state.monster.hp = 0
	state.bonus_attack_procs += 1
	log_fmt(state, "💢 **Critical Hit!** Extra **%d** damage!", dmg)
}

hook_item_mana_on_hit :: proc(state: ^CombatState) {
	logd("[hook] ON_ATTACK → mana_on_hit")
	state.player.mana += 5
	if state.player.mana > state.player.max_mana do state.player.mana = state.player.max_mana
}


hook_item_regen :: proc(state: ^CombatState) {
	logd("[hook] TURN_START → regen")
	if state.regen_this_turn do return
	state.regen_this_turn = true
	missing := state.player.max_hp - state.player.hp
	if missing <= 0 do return
	heal := missing * 5 / 100
	state.player.hp += heal
	if state.player.hp > state.player.max_hp do state.player.hp = state.player.max_hp
	state.pending_heal += heal
}

hook_item_magic_find :: proc(state: ^CombatState) {
	logd("[hook] VICTORY → magic_find")
	state.rare_mult += 0.10
	log_fmt(state, "✨ **Magic Find!** +10%% rare loot chance!")
}

hook_item_speed_dodge :: proc(state: ^CombatState) {
	logd("[hook] ON_DAMAGE_TAKEN → speed_dodge")
	chance := state.total_bonus_spd / 2
	if chance > 35 do chance = 35
	if chance < 1 do return
	if rand.int_max(100) >= chance do return
	state.player.hp += state.last_damage_taken
	if state.player.hp > state.player.max_hp do state.player.hp = state.player.max_hp
	log_fmt(state, "💨 **Speed Dodge!** (%d%% chance) Attack missed!", chance)
}

// --- Diablo-inspired specials ---
hook_item_bleed :: proc(state: ^CombatState) {
	if rand.int_max(100) >= 15 do return
	state.monster_bleed = 3
	log_fmt(state, "🩸 **Rend!** %s bleeds for 3 turns!", state.monster.name)
}

hook_item_freeze :: proc(state: ^CombatState) {
	if state.stun_freeze_cooldown > 0 do return
	if rand.int_max(100) >= 12 do return
	state.monster_frozen = 1
	state.stun_freeze_cooldown = 2
	log_fmt(state, "❄️ **Frost Nova!** %s is frozen for %d turn!", state.monster.name, state.monster_frozen)
}

hook_item_ramp_atk :: proc(state: ^CombatState) {
	if state.player_atk_ramp >= 5 do return
	state.player_atk_ramp += 1
	bonus := state.player_base_atk * state.player_atk_ramp * 5 / 100
	state.player.atk = state.player_base_atk + bonus
	log_fmt(state, "🔥 **Wrath!** ATK +%d%% (total +%d%%)", 5, state.player_atk_ramp * 5)
}

hook_item_lightning_pulse :: proc(state: ^CombatState) {
	if state.lightning_this_turn do return
	state.lightning_this_turn = true
	dmg := state.player.atk * 12 / 100
	state.monster.hp -= dmg
	if state.monster.hp < 0 do state.monster.hp = 0
	log_fmt(state, "⚡ **Lightning Pulse!** Dealt **%d** damage!", dmg)
}

hook_item_mana_start :: proc(state: ^CombatState) {
	state.player.mana += state.player.max_mana * 25 / 100
	if state.player.mana > state.player.max_mana do state.player.mana = state.player.max_mana
	log_fmt(state, "💎 **Arcane Power!** Gained +25%% mana!")
}

hook_item_block :: proc(state: ^CombatState) {
	if state.block_cooldown > 0 do return
	if rand.int_max(100) >= 20 do return
	state.block_charges = 1
	log_fmt(state, "🛡️ **Iron Skin!** Next attack will be blocked!")
}

hook_item_weaken :: proc(state: ^CombatState) {
	if state.monster_atk_debuff do return
	state.monster_atk_debuff = true
	log_fmt(state, "💀 **Weaken!** %s's ATK reduced by 20%%!", state.monster.name)
}

Item_Special_Def :: struct {
	label:      string,
	event:      CombatEvent,
	hook:       CombatHook,
	// Slice of Item_Type values this effect can roll on.
	// nil means universal (any item type).
	item_types: []Item_Type,
}

ITEM_SPECIALS := []Item_Special_Def{
	// Weapons only
	{label = "Chance to deal double damage",             event = .ON_ATTACK,       hook = hook_item_double_dmg,      item_types = {.SWORD, .STAFF}},
	{label = "First attack each combat does 2x damage",  event = .ON_ATTACK,       hook = hook_item_first_strike,    item_types = {.SWORD, .STAFF}},
	{label = "Ignore 20% of enemy DEF",                  event = .ON_ATTACK,       hook = hook_item_ignore_def,      item_types = {.SWORD, .STAFF}},
	{label = "Heal for 8% of ATK on hit",                event = .ON_DAMAGE_DEALT, hook = hook_item_life_steal,      item_types = {.SWORD, .STAFF}},
	{label = "Your attacks have a chance to stun",       event = .ON_ATTACK,       hook = hook_item_stun,            item_types = {.SWORD, .STAFF}},
	{label = "15% chance to crit for double damage",     event = .ON_ATTACK,       hook = hook_item_crit,            item_types = {.SWORD, .STAFF}},
	{label = "Restore 5 mana on attack",                 event = .ON_ATTACK,       hook = hook_item_mana_on_hit,     item_types = {.SWORD, .STAFF}},
	{label = "Attacks have 20% chance to bleed for 3 turns", event = .ON_ATTACK,   hook = hook_item_bleed,           item_types = {.SWORD, .STAFF}},
	{label = "Freeze enemy for 1 turn",                  event = .ON_ATTACK,       hook = hook_item_freeze,          item_types = {.SWORD, .STAFF}},
	{label = "Attacks weaken enemy, reducing ATK by 20%", event = .ON_ATTACK,      hook = hook_item_weaken,          item_types = {.SWORD, .STAFF}},
	// Chest only
	{label = "Reflect 25% damage back to attacker",      event = .ON_DAMAGE_TAKEN, hook = hook_item_thorns,          item_types = {.CHEST}},
	{label = "Enemy DEF permanently reduced by 20%",     event = .ON_DAMAGE_TAKEN, hook = hook_item_def_reduce,      item_types = {.CHEST}},
	{label = "Take 25% less damage from bosses",         event = .ON_DAMAGE_TAKEN, hook = hook_item_boss_resist,     item_types = {.CHEST}},
	{label = "Gain a shield equal to 8% max HP each turn", event = .TURN_START,    hook = hook_item_shield,          item_types = {.CHEST}},
	{label = "20% chance to block the next attack",       event = .TURN_START,     hook = hook_item_block,           item_types = {.CHEST}},
	// Helm only
	{label = "Gain 5% bonus gold from monsters",         event = .VICTORY,         hook = hook_item_gold_bonus,      item_types = {.HELM}},
	{label = "10% increased magic find",                 event = .VICTORY,         hook = hook_item_magic_find,      item_types = {.HELM}},
	// Legs or Boots
	{label = "Enemies have 10% chance to miss",          event = .ON_DAMAGE_TAKEN, hook = hook_item_dodge,           item_types = {.LEGS, .BOOTS}},
	{label = "Dodge chance scales with speed",           event = .ON_DAMAGE_TAKEN, hook = hook_item_speed_dodge,     item_types = {.LEGS, .BOOTS}},
	// Universal (any item type)
	{label = "Restore 3% HP per turn",                   event = .TURN_START,      hook = hook_item_heal_per_turn,   item_types = nil},
	{label = "Restore 5% missing HP per turn",           event = .TURN_START,      hook = hook_item_regen,           item_types = nil},
	{label = "Each turn, gain 5% ATK (max 25%)",         event = .TURN_START,      hook = hook_item_ramp_atk,        item_types = nil},
	{label = "Lightning pulses deal 12% ATK each turn",  event = .TURN_START,      hook = hook_item_lightning_pulse, item_types = nil},
	{label = "Gain 25% mana at combat start",            event = .START,           hook = hook_item_mana_start,      item_types = nil},
}


@(private)
_item_specials_validated: bool

@(private)
_validate_item_specials :: proc() {
	if _item_specials_validated do return
	_item_specials_validated = true
	for def, i in ITEM_SPECIALS {
		assert(def.hook != nil,  fmt.tprintf("ITEM_SPECIALS[%d] %q has nil hook", i, def.label))
		assert(def.label != "", fmt.tprintf("ITEM_SPECIALS[%d] has empty label", i))
	}
}


@(private)
_is_passive_char_ability :: proc(name: string) -> bool {
	switch name {
	case "Phoenix Rebirth", "Midas Touch", "Scavenger", "Last Stand", "Blood Money":
		return true
	}
	return false
}

register_item_hooks :: proc(state: ^CombatState, special: string) {
	if special == "" do return
	_validate_item_specials()
	parts := strings.split(special, "|", context.temp_allocator)
	for part in parts {
		for def in ITEM_SPECIALS {
			if def.label == part {
				register_hook(state, def.event, def.hook)
				break
			}
		}
	}
}

register_char_hooks :: proc(state: ^CombatState, ability_name: string) {
	switch ability_name {
	case "Phoenix Rebirth":
		register_hook(state, .ON_DEATH, hook_revive)
	case "Call of the Wild":
		register_hook(state, .TURN_START, hook_summon)
	case "Midas Touch":
		register_hook(state, .VICTORY, hook_char_midas_touch)
	case "Scavenger":
		register_hook(state, .VICTORY, hook_char_scavenger)
	case "Last Stand":
		register_hook(state, .ON_DEATH, hook_char_last_stand)
	case "Execute":
		register_hook(state, .ON_ABILITY, hook_char_execute)
	case "Blood Money":
		register_hook(state, .VICTORY, hook_char_blood_money)
	case "Deep Freeze":
		register_hook(state, .ON_ABILITY, hook_char_deep_freeze)
	case "Debug":
		register_test_hooks(state)
	}
}

register_class_hooks :: proc(state: ^CombatState, class: Class_Type) {
	switch class {
	case .ATTACKER:
		register_hook(state, .ON_ABILITY, hook_class_attacker)
	case .HEALER:
		register_hook(state, .ON_ABILITY, hook_class_healer)
	}
}

hook_boss_fire_breath :: proc(state: ^CombatState) {
	if state.monster.mana < 20 do return
	state.monster.mana -= 20
	dmg := combat_deal_damage(state.monster.atk * 3 / 2, state.player.def)
	state.player.hp -= dmg
	if state.player.hp < 0 do state.player.hp = 0
	log_fmt(state, "🔥 **%s** breathes fire for **%d** damage!", state.monster.name, dmg)
	emit(state, .ON_DAMAGE_TAKEN)
	if state.player.hp <= 0 {
		emit(state, .ON_DEATH)
		if state.player.hp > 0 {
			emit(state, .ON_REVIVE)
			return
		}
		state.state = .PLAYER_LOST
	}
}

register_boss_hooks :: proc(state: ^CombatState, boss_name: string) {
	switch boss_name {
	case "Dragon Whelp":
		register_hook(state, .TURN_START, hook_boss_fire_breath)
	}
}

hook_test_log :: proc(state: ^CombatState) {
	// This hook is registered for ALL events by register_test_hooks.
	// The event name is inferred from context — we just log presence.
}

register_test_hooks :: proc(state: ^CombatState) {
	all: []CombatEvent = {.START, .TURN_START, .ON_ATTACK, .ON_ABILITY, .ON_DAMAGE_DEALT, .ON_DAMAGE_TAKEN, .ON_HEAL, .ON_KILL, .ON_DEATH, .ON_REVIVE, .VICTORY, .DEFEAT}
	for event in all {
		register_hook(state, event, hook_test_log)
	}
	logd("[test] registered hooks for %d events", len(all))
}

ITEM_CATEGORY := [Item_Type]Item_Slot {
	.SWORD = .WEAPON,
	.STAFF = .WEAPON,
	.HELM  = .HEAD,
	.CHEST = .CHEST,
	.LEGS  = .LEGS,
	.BOOTS = .BOOTS,
}

ITEM_EMOJIS := [Item_Type]string {
	.SWORD = "🗡️",
	.STAFF = "🪄",
	.HELM  = "⛑️",
	.CHEST = "🛡️",
	.LEGS  = "👖",
	.BOOTS = "👢",
}

ITEM_NAMES := [Item_Type]string {
	.SWORD = "Sword",
	.STAFF = "Staff",
	.HELM  = "Helmet",
	.CHEST = "Chestplate",
	.LEGS  = "Leggings",
	.BOOTS = "Boots",
}

ITEM_BASE_ATK := [Item_Type]int {
	.SWORD = 10,
	.STAFF = 8,
	.HELM  = 0,
	.CHEST = 0,
	.LEGS  = 0,
	.BOOTS = 0,
}

ITEM_BASE_DEF := [Item_Type]int {
	.SWORD = 0,
	.STAFF = 0,
	.HELM  = 4,
	.CHEST = 8,
	.LEGS  = 5,
	.BOOTS = 3,
}

ITEM_TIER_NAMES := [Item_Type]string {
	.SWORD = "sword",
	.STAFF = "staff",
	.HELM  = "helm",
	.CHEST = "chest",
	.LEGS  = "legs",
	.BOOTS = "boots",
}

AFFIX_NAMES := [Affix]string {
	.HP   = "HP",
	.ATK  = "ATK",
	.DEF  = "DEF",
	.SPD  = "SPD",
	.CRIT = "Crit",
}

AFFIX_EMOJIS := [Affix]string {
	.HP   = "❤️",
	.ATK  = "⚔️",
	.DEF  = "🛡️",
	.SPD  = "💨",
	.CRIT = "💢",
}


CHARACTER_FIRST_NAMES := []string {
	"Aldric", "Brynn", "Cedric", "Dorian", "Elara", "Finn", "Gwen",  "Hadrian",
	"Isolde", "Jorah", "Kael",  "Lyra",   "Magnus", "Nova",  "Orin",  "Petra",
	"Quinn",  "Rowan", "Seren", "Thalia", "Urien",  "Vesper", "Wren",  "Xander",
	"Yara",   "Zephyr",
}

CHARACTER_LAST_NAMES := []string {
	"Ironcrest", "Shadowmere", "Dawnforge", "Ravenhold", "Starweaver",
	"Thornheart", "Brightblade", "Frostwind", "Emberfall", "Silverwood",
	"Moonshade",  "Stormrider", "Goldleaf", "Nightsong", "Hawkfield",
}

S_ABILITY_NAMES := []string {
	"Phoenix Rebirth", "Call of the Wild",
	"Midas Touch", "Scavenger", "Last Stand",
	"Execute", "Blood Money", "Deep Freeze",
}

S_ABILITY_DESCS := []string {
	"On death, revive with 40% HP once per combat",
	"Summoned beast attacks each turn for extra damage",
	"Double gold earned from this dungeon",
	"25% chance to find an extra item lootbox on victory",
	"Cheat death with 1 HP, dealing 200% ATK damage (once per combat)",
	"Deal 300% ATK to monsters below 25% HP",
	"Gain bonus gold equal to 10% of monster's max HP on victory",
	"Freeze the monster for 2 turns",
}

LOOTBOX_CHARACTER_COUNT :: 5
LOOTBOX_ITEM_COUNT      :: 5

BOSS_FLOOR_INTERVAL :: 5
RARE_MONSTER_CHANCE :: 0.15

MONSTER_TEMPLATES := []MonsterTemplate {
	{name = "Goblin",        emoji = "👺", kind = .Normal, base_hp = 30,  base_atk = 8,  base_def = 3,  scale_hp = 10, scale_atk = 3, scale_def = 1, base_mana = 20,  mana_regen = 3, gold_min = 5,  gold_max = 15,  lootbox_chance = 0.15},
	{name = "Wolf",          emoji = "🐺", kind = .Normal, base_hp = 40,  base_atk = 10, base_def = 4,  scale_hp = 13, scale_atk = 4, scale_def = 1, base_mana = 20,  mana_regen = 3, gold_min = 8,  gold_max = 18,  lootbox_chance = 0.18},
	{name = "Slime",         emoji = "🟢", kind = .Normal, base_hp = 25,  base_atk = 6,  base_def = 5,  scale_hp = 8,  scale_atk = 3, scale_def = 2, base_mana = 20,  mana_regen = 3, gold_min = 3,  gold_max = 10,  lootbox_chance = 0.12},
	{name = "Skeleton",      emoji = "💀", kind = .Normal, base_hp = 35,  base_atk = 9,  base_def = 4,  scale_hp = 12, scale_atk = 3, scale_def = 1, base_mana = 20,  mana_regen = 3, gold_min = 6,  gold_max = 16,  lootbox_chance = 0.16},
	{name = "Zombie",        emoji = "🧟", kind = .Normal, base_hp = 45,  base_atk = 7,  base_def = 3,  scale_hp = 15, scale_atk = 3, scale_def = 1, base_mana = 20,  mana_regen = 3, gold_min = 7,  gold_max = 14,  lootbox_chance = 0.14},
	{name = "Bat Swarm",     emoji = "🦇", kind = .Normal, base_hp = 20,  base_atk = 11, base_def = 2,  scale_hp = 7,  scale_atk = 4, scale_def = 1, base_mana = 20,  mana_regen = 3, gold_min = 4,  gold_max = 12,  lootbox_chance = 0.13},
	{name = "Spider",        emoji = "🕷️", kind = .Normal, base_hp = 32,  base_atk = 10, base_def = 3,  scale_hp = 10, scale_atk = 4, scale_def = 1, base_mana = 20,  mana_regen = 3, gold_min = 6,  gold_max = 15,  lootbox_chance = 0.15},
	{name = "Wraith",        emoji = "👻", kind = .Rare,   base_hp = 50,  base_atk = 14, base_def = 6,  scale_hp = 15, scale_atk = 5, scale_def = 2, base_mana = 40,  mana_regen = 5, gold_min = 15, gold_max = 30,  lootbox_chance = 0.30},
	{name = "Crystal Golem", emoji = "💎", kind = .Rare,   base_hp = 70,  base_atk = 12, base_def = 10, scale_hp = 19, scale_atk = 4, scale_def = 3, base_mana = 40,  mana_regen = 5, gold_min = 18, gold_max = 35,  lootbox_chance = 0.35},
	{name = "Shadow Assassin", emoji = "🗡️", kind = .Rare, base_hp = 45, base_atk = 18, base_def = 4, scale_hp = 13, scale_atk = 6, scale_def = 1, base_mana = 40,  mana_regen = 5, gold_min = 20, gold_max = 40,  lootbox_chance = 0.32},
	{name = "Phantom Wolf",  emoji = "🌑", kind = .Rare,   base_hp = 55,  base_atk = 16, base_def = 5,  scale_hp = 17, scale_atk = 5, scale_def = 2, base_mana = 40,  mana_regen = 5, gold_min = 16, gold_max = 32,  lootbox_chance = 0.30},
}

BOSS_TEMPLATES := []MonsterTemplate {
	{name = "Goblin King",    emoji = "👑", kind = .Boss, base_hp = 120, base_atk = 16, base_def = 8,  scale_hp = 25, scale_atk = 5, scale_def = 2, base_mana = 80,  mana_regen = 8, gold_min = 28,  gold_max = 56,  lootbox_chance = 1.0},
	{name = "Dragon Whelp",   emoji = "🐉", kind = .Boss, base_hp = 150, base_atk = 20, base_def = 10, scale_hp = 32, scale_atk = 6, scale_def = 3, base_mana = 80,  mana_regen = 8, gold_min = 35,  gold_max = 70,  lootbox_chance = 1.0},
	{name = "Lich Lord",      emoji = "☠️", kind = .Boss, base_hp = 140, base_atk = 22, base_def = 9,  scale_hp = 28, scale_atk = 7, scale_def = 2, base_mana = 80,  mana_regen = 8, gold_min = 38,  gold_max = 77,  lootbox_chance = 1.0},
	{name = "Hydra",          emoji = "🐍", kind = .Boss, base_hp = 200, base_atk = 18, base_def = 12, scale_hp = 38, scale_atk = 5, scale_def = 3, base_mana = 80,  mana_regen = 8, gold_min = 42,  gold_max = 84,  lootbox_chance = 1.0},
	{name = "Dark Knight",    emoji = "🛡️", kind = .Boss, base_hp = 160, base_atk = 24, base_def = 14, scale_hp = 30, scale_atk = 6, scale_def = 3, base_mana = 80,  mana_regen = 8, gold_min = 45,  gold_max = 91,  lootbox_chance = 1.0},
	{name = "Ancient Dragon", emoji = "🐲", kind = .Boss, base_hp = 250, base_atk = 26, base_def = 15, scale_hp = 44, scale_atk = 7, scale_def = 4, base_mana = 80,  mana_regen = 8, gold_min = 56,  gold_max = 112, lootbox_chance = 1.0},
	{name = "Demon Lord",     emoji = "😈", kind = .Boss, base_hp = 220, base_atk = 28, base_def = 12, scale_hp = 35, scale_atk = 9, scale_def = 3, base_mana = 80,  mana_regen = 8, gold_min = 63,  gold_max = 126, lootbox_chance = 1.0},
	{name = "Elder Titan",    emoji = "🗿", kind = .Boss, base_hp = 300, base_atk = 20, base_def = 18, scale_hp = 50, scale_atk = 5, scale_def = 4, base_mana = 80,  mana_regen = 8, gold_min = 70,  gold_max = 140, lootbox_chance = 1.0},
	{name = "Phoenix",        emoji = "🔥", kind = .Boss, base_hp = 180, base_atk = 30, base_def = 10, scale_hp = 25, scale_atk = 10, scale_def = 2, base_mana = 80,  mana_regen = 8, gold_min = 49,  gold_max = 98,  lootbox_chance = 1.0},
	{name = "Voidwalker",     emoji = "🌀", kind = .Boss, base_hp = 170, base_atk = 25, base_def = 13, scale_hp = 32, scale_atk = 7, scale_def = 3, base_mana = 80,  mana_regen = 8, gold_min = 52,  gold_max = 105, lootbox_chance = 1.0},
}

_roll_tier :: proc() -> Tier {
	total := 0
	for w in TIER_WEIGHTS do total += w
	roll := rand.int_max(total)
	cumulative := 0
	for t in TIER_COLLECTION_ORDER {
		cumulative += TIER_WEIGHTS[t]
		if roll < cumulative do return t
	}
	return .COMMON
}

_get_boss_for_floor :: proc(floor: int) -> MonsterTemplate {
	idx := ((floor / BOSS_FLOOR_INTERVAL) - 1) % len(BOSS_TEMPLATES)
	return BOSS_TEMPLATES[idx]
}

_roll_random_monster :: proc() -> MonsterTemplate {
	normal := _get_normal_monsters()
	idx := rand.int_max(len(normal))
	return normal[idx]
}

_roll_rare_monster :: proc() -> MonsterTemplate {
	rare := _get_rare_monsters()
	idx := rand.int_max(len(rare))
	return rare[idx]
}

_get_normal_monsters :: proc() -> []MonsterTemplate {
	normal := make([dynamic]MonsterTemplate, 0, len(MONSTER_TEMPLATES), context.temp_allocator)
	for tmpl in MONSTER_TEMPLATES {
		if tmpl.kind == .Normal do append(&normal, tmpl)
	}
	return normal[:]
}

_get_rare_monsters :: proc() -> []MonsterTemplate {
	rare := make([dynamic]MonsterTemplate, 0, len(MONSTER_TEMPLATES), context.temp_allocator)
	for tmpl in MONSTER_TEMPLATES {
		if tmpl.kind == .Rare do append(&rare, tmpl)
	}
	return rare[:]
}

_random_name :: proc() -> string {
	first := CHARACTER_FIRST_NAMES[rand.int_max(len(CHARACTER_FIRST_NAMES))]
	last  := CHARACTER_LAST_NAMES[rand.int_max(len(CHARACTER_LAST_NAMES))]
	return fmt.tprintf("%s %s", first, last)
}

_random_s_ability :: proc() -> (string, string) {
	idx := rand.int_max(len(S_ABILITY_NAMES))
	return S_ABILITY_NAMES[idx], S_ABILITY_DESCS[idx]
}

@(private)
_get_allowed_specials :: proc(item_type: Item_Type, allocator := context.temp_allocator) -> []string {
	result := make([dynamic]string, allocator)
	for def in ITEM_SPECIALS {
		allowed := def.item_types == nil  // universal
		if !allowed {
			for t in def.item_types {
				if t == item_type { allowed = true; break }
			}
		}
		if allowed {
			append(&result, def.label)
		}
	}
	return result[:]
}

_random_specials :: proc(item_type: Item_Type, tier: Tier, floor: int, allocator := context.temp_allocator) -> string {
	cfg := TIER_CONFIGS[tier]
	count := cfg.min_specials
	if cfg.max_specials > cfg.min_specials {
		count += rand.int_max(cfg.max_specials - cfg.min_specials + 1)
	}
	if count <= 0 do return ""

	allowed := _get_allowed_specials(item_type, allocator)
	if len(allowed) == 0 do return ""

	picked := make([dynamic]string, allocator)
	available := make([dynamic]string, allocator)
	append(&available, ..allowed)
	max_pick := min(count, len(available))
	for _ in 0 ..< max_pick {
		idx := rand.int_max(len(available))
		append(&picked, available[idx])
		unordered_remove(&available, idx)
	}
	return strings.join(picked[:], "|", allocator)
}

_sell_price :: proc(item: ItemInstance) -> int {
	base := 0
	switch item.tier {
	case .COMMON:    base = 3
	case .UNCOMMON:  base = 8
	case .RARE:      base = 20
	case .LEGENDARY: base = 50
	case .MYTHICAL:  base = 150
	}
	affix_bonus := (item.bonus_hp + item.bonus_atk + item.bonus_def + item.bonus_spd + item.bonus_crit) * 2
	return base + affix_bonus
}

_sell_price_char :: proc(char: CollectedCharacter) -> int {
	base := 0
	switch char.tier {
	case .COMMON:    base = 25
	case .UNCOMMON:  base = 75
	case .RARE:      base = 200
	case .LEGENDARY: base = 500
	case .MYTHICAL:  base = 1500
	}
	return base
}
