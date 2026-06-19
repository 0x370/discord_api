package dungeon

import "core:math/rand"
import "core:strings"

// --- Class ability hooks ---

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

// --- Character S-ability hooks ---

hook_revive :: proc(state: ^CombatState) {
	if state.caps.char_revive_used do return
	state.caps.char_revive_used = true
	state.player.hp = state.player.max_hp * 40 / 100
	if state.player.hp < 1 do state.player.hp = 1
	log_fmt(state, "🔥 **Phoenix Rebirth**! You rise from the ashes with **%d** HP!", state.player.hp)
}

hook_summon :: proc(state: ^CombatState) {
	dmg := combat_deal_damage(state.player.atk, state.monster.def / 2)
	state.monster.hp -= dmg
	if state.monster.hp < 0 do state.monster.hp = 0
	log_fmt(state, "🐺 **Call of the Wild**! Summoned beast attacks for **%d** damage!", dmg)
}

hook_char_midas_touch :: proc(state: ^CombatState) {
	state.reward_gold = state.reward_gold * 2
	log_fmt(state, "🪙 **Midas Touch!** Gold reward doubled!")
}

hook_char_scavenger :: proc(state: ^CombatState) {
	if rand.int_max(100) >= 25 do return
	state.reward_lootboxes += 1
	log_fmt(state, "🔍 **Scavenger!** Found an extra item lootbox!")
}

hook_char_last_stand :: proc(state: ^CombatState) {
	if state.caps.char_revive_used do return
	state.caps.char_revive_used = true
	state.player.hp = 1
	dmg := combat_deal_damage(state.player.atk * 2, state.monster.def)
	state.monster.hp -= dmg
	if state.monster.hp < 0 do state.monster.hp = 0
	log_fmt(state, "💀 **Last Stand!** You refuse to fall, dealing **%d** damage!", dmg)
}

hook_char_execute :: proc(state: ^CombatState) {
	threshold := state.monster.max_hp * 25 / 100
	if threshold < 1 do threshold = 1
	if state.monster.hp > threshold do return
	dmg := combat_deal_damage(state.player.atk * 3, state.monster.def)
	state.monster.hp -= dmg
	if state.monster.hp < 0 do state.monster.hp = 0
	state.track.last_damage_dealt = dmg
	log_fmt(state, "🗡️ **Execute!** Dealt **%d** finisher damage!", dmg)
}

hook_char_blood_money :: proc(state: ^CombatState) {
	bonus := state.monster.max_hp * 10 / 100
	if bonus < 1 do bonus = 1
	state.reward_gold += bonus
	log_fmt(state, "🩸 **Blood Money!** +%d bonus gold from %s's corpse!", bonus, state.monster.name)
}

hook_char_deep_freeze :: proc(state: ^CombatState) {
	state.buffs.monster_frozen = 2
	log_fmt(state, "❄️ **Deep Freeze!** %s is frozen solid for 2 turns!", state.monster.name)
}

// --- Item special effect hooks ---

hook_item_double_dmg :: proc(state: ^CombatState) {
	if state.caps.bonus_attack_procs >= 1 do return
	if rand.int_max(100) >= 15 do return
	dmg := combat_deal_damage(state.player.atk, state.monster.def)
	state.monster.hp -= dmg
	if state.monster.hp < 0 do state.monster.hp = 0
	state.caps.bonus_attack_procs += 1
	log_fmt(state, "⚡ **Double Damage!** Extra **%d** damage dealt!", dmg)
}

hook_item_heal_per_turn :: proc(state: ^CombatState) {
	if state.caps.heal_this_turn do return
	state.caps.heal_this_turn = true
	heal := state.player.max_hp * 3 / 100
	if heal < 1 do heal = 1
	state.player.hp += heal
	if state.player.hp > state.player.max_hp do state.player.hp = state.player.max_hp
	state.track.pending_heal += heal
}

hook_item_def_reduce :: proc(state: ^CombatState) {
	if state.caps.def_reduce_done do return
	state.caps.def_reduce_done = true
	state.monster.def = state.monster.def * 80 / 100
}

hook_item_first_strike :: proc(state: ^CombatState) {
	if !state.track.first_attack do return
	if state.caps.bonus_attack_procs >= 1 do return
	state.track.first_attack = false
	dmg := combat_deal_damage(state.player.atk, state.monster.def)
	state.monster.hp -= dmg
	if state.monster.hp < 0 do state.monster.hp = 0
	state.caps.bonus_attack_procs += 1
	log_fmt(state, "💥 **First Strike!** Extra **%d** damage!", dmg)
}

hook_item_ignore_def :: proc(state: ^CombatState) {
	bonus := state.monster.def * 20 / 100
	if bonus < 1 do bonus = 1
	state.monster.hp -= bonus
	if state.monster.hp < 0 do state.monster.hp = 0
	log_fmt(state, "🔓 **Armor Pierce!** Bypassed **%d** DEF for **%d** bonus damage!", state.monster.def, bonus)
}

hook_item_life_steal :: proc(state: ^CombatState) {
	cap := state.player.atk * 15 / 100
	if cap < 1 do cap = 1
	if state.caps.life_steal_total >= cap do return
	heal := state.player.atk * 8 / 100
	if heal < 1 do heal = 1
	state.player.hp += heal
	if state.player.hp > state.player.max_hp do state.player.hp = state.player.max_hp
	state.caps.life_steal_total += heal
	log_fmt(state, "🩸 **Lifesteal!** Healed for **%d** HP!", heal)
}

hook_item_dodge :: proc(state: ^CombatState) {
	if rand.int_max(100) >= 10 do return
	state.player.hp += state.track.last_damage_taken
	if state.player.hp > state.player.max_hp do state.player.hp = state.player.max_hp
	log_fmt(state, "💨 **Dodged!** The attack missed!")
}

hook_item_gold_bonus :: proc(state: ^CombatState) {
	bonus := state.reward_gold * 5 / 100
	if bonus < 1 do bonus = 1
	state.reward_gold += bonus
	log_fmt(state, "💰 **Treasure Hunter!** +%d bonus gold!", bonus)
}

hook_item_stun :: proc(state: ^CombatState) {
	if state.buffs.stun_freeze_cooldown > 0 do return
	if rand.int_max(100) >= 12 do return
	state.track.monster_stunned = true
	state.buffs.stun_freeze_cooldown = 2
	log_fmt(state, "⚡ **Stunned!** %s skips its next turn!", state.monster.name)
}

hook_item_boss_resist :: proc(state: ^CombatState) {
	if state.monster.kind != .Boss do return
	if state.caps.boss_resist_used do return
	state.caps.boss_resist_used = true
	heal := state.track.last_damage_taken / 4
	if heal < 1 do heal = 1
	state.player.hp += heal
	if state.player.hp > state.player.max_hp do state.player.hp = state.player.max_hp
	log_fmt(state, "🛡️ **Boss Resistance!** Reduced damage, restored **%d** HP!", heal)
}

hook_item_thorns :: proc(state: ^CombatState) {
	if state.caps.thorns_used do return
	state.caps.thorns_used = true
	reflect := state.track.last_damage_taken * 25 / 100
	if reflect < 1 do reflect = 1
	state.monster.hp -= reflect
	if state.monster.hp < 0 do state.monster.hp = 0
	log_fmt(state, "🛡️ **Thorns!** Reflected **%d** damage!", reflect)
}

hook_item_shield :: proc(state: ^CombatState) {
	if state.caps.shield_this_turn do return
	state.caps.shield_this_turn = true
	shield := state.player.max_hp * 8 / 100
	if shield < 1 do shield = 1
	state.buffs.shield += shield
	log_fmt(state, "🛡️ **Barrier!** Gained **%d** shield!", shield)
}

hook_item_crit :: proc(state: ^CombatState) {
	if state.caps.bonus_attack_procs >= 1 do return
	if rand.int_max(100) >= 15 do return
	dmg := combat_deal_damage(state.player.atk, state.monster.def)
	state.monster.hp -= dmg
	if state.monster.hp < 0 do state.monster.hp = 0
	state.caps.bonus_attack_procs += 1
	log_fmt(state, "💢 **Critical Hit!** Extra **%d** damage!", dmg)
}

hook_item_mana_on_hit :: proc(state: ^CombatState) {
	state.player.mana += 5
	if state.player.mana > state.player.max_mana do state.player.mana = state.player.max_mana
}

hook_item_regen :: proc(state: ^CombatState) {
	if state.caps.regen_this_turn do return
	state.caps.regen_this_turn = true
	missing := state.player.max_hp - state.player.hp
	if missing <= 0 do return
	heal := missing * 5 / 100
	state.player.hp += heal
	if state.player.hp > state.player.max_hp do state.player.hp = state.player.max_hp
	state.track.pending_heal += heal
}

hook_item_magic_find :: proc(state: ^CombatState) {
	state.rare_mult += 0.10
	log_fmt(state, "✨ **Magic Find!** +10%% rare loot chance!")
}

hook_item_speed_dodge :: proc(state: ^CombatState) {
	chance := state.buffs.total_bonus_spd / 2
	if chance > 35 do chance = 35
	if chance < 1 do return
	if rand.int_max(100) >= chance do return
	state.player.hp += state.track.last_damage_taken
	if state.player.hp > state.player.max_hp do state.player.hp = state.player.max_hp
	log_fmt(state, "💨 **Speed Dodge!** (%d%% chance) Attack missed!", chance)
}

// --- Diablo-inspired specials ---

hook_item_bleed :: proc(state: ^CombatState) {
	if rand.int_max(100) >= 15 do return
	state.buffs.monster_bleed = 3
	log_fmt(state, "🩸 **Rend!** %s bleeds for 3 turns!", state.monster.name)
}

hook_item_freeze :: proc(state: ^CombatState) {
	if state.buffs.stun_freeze_cooldown > 0 do return
	if rand.int_max(100) >= 12 do return
	state.buffs.monster_frozen = 1
	state.buffs.stun_freeze_cooldown = 2
	log_fmt(state, "❄️ **Frost Nova!** %s is frozen for %d turn!", state.monster.name, state.buffs.monster_frozen)
}

hook_item_ramp_atk :: proc(state: ^CombatState) {
	if state.buffs.player_atk_ramp >= 5 do return
	state.buffs.player_atk_ramp += 1
	bonus := state.track.player_base_atk * state.buffs.player_atk_ramp * 5 / 100
	state.player.atk = state.track.player_base_atk + bonus
	log_fmt(state, "🔥 **Wrath!** ATK +%d%% (total +%d%%)", 5, state.buffs.player_atk_ramp * 5)
}

hook_item_lightning_pulse :: proc(state: ^CombatState) {
	if state.caps.lightning_this_turn do return
	state.caps.lightning_this_turn = true
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
	if state.buffs.block_cooldown > 0 do return
	if rand.int_max(100) >= 20 do return
	state.buffs.block_charges = 1
	log_fmt(state, "🛡️ **Iron Skin!** Next attack will be blocked!")
}

hook_item_weaken :: proc(state: ^CombatState) {
	if state.buffs.monster_atk_debuff do return
	state.buffs.monster_atk_debuff = true
	log_fmt(state, "💀 **Weaken!** %s's ATK reduced by 20%%!", state.monster.name)
}

// --- Boss hooks ---

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

// --- Test hooks ---

hook_test_log :: proc(state: ^CombatState) {
	// This hook is registered for ALL events by register_test_hooks.
	// The event name is inferred from context — we just log presence.
}

register_test_hooks :: proc(state: ^CombatState) {
	all: []CombatEvent = {.START, .TURN_START, .ON_ATTACK, .ON_ABILITY, .ON_DAMAGE_DEALT, .ON_DAMAGE_TAKEN, .ON_HEAL, .ON_KILL, .ON_DEATH, .ON_REVIVE, .VICTORY, .DEFEAT}
	for event in all {
		register_hook(state, event, hook_test_log)
	}
}

// --- Data tables for hook registration ---

S_Ability_Def :: struct {
	name:        string,
	description: string,
	event:       CombatEvent,
	hook:        CombatHook,
	is_passive:  bool,
}

S_ABILITIES := []S_Ability_Def{
	{"Phoenix Rebirth",  "On death, revive with 40% HP once per combat",                   .ON_DEATH,   hook_revive,            true},
	{"Call of the Wild", "Summoned beast attacks each turn for extra damage",               .TURN_START, hook_summon,            false},
	{"Midas Touch",      "Double gold earned from this dungeon",                            .VICTORY,    hook_char_midas_touch,  true},
	{"Scavenger",        "25% chance to find an extra item lootbox on victory",             .VICTORY,    hook_char_scavenger,   true},
	{"Last Stand",       "Cheat death with 1 HP, dealing 200% ATK damage (once)",           .ON_DEATH,   hook_char_last_stand,  true},
	{"Execute",          "Deal 300% ATK to monsters below 25% HP",                          .ON_ABILITY, hook_char_execute,      false},
	{"Blood Money",      "Gain bonus gold equal to 10% of monster's max HP on victory",     .VICTORY,    hook_char_blood_money, true},
	{"Deep Freeze",      "Freeze the monster for 2 turns",                                  .ON_ABILITY, hook_char_deep_freeze,  false},
}

CLASS_ABILITY_HOOKS := [Class_Type]struct {
	event: CombatEvent,
	hook:  CombatHook,
}{
	.ATTACKER = {.ON_ABILITY, hook_class_attacker},
	.HEALER   = {.ON_ABILITY, hook_class_healer},
}

Boss_Ability_Def :: struct {
	name:        string,
	description: string,
	event:       CombatEvent,
	hook:        CombatHook,
}

BOSS_ABILITIES := []Boss_Ability_Def{
	{"Dragon Whelp", "Breathes fire dealing 150% ATK damage (costs 20 MP)", .TURN_START, hook_boss_fire_breath},
}

// --- Hook registration (item, char, class, boss) ---

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
	if ability_name == "Debug" {
		register_test_hooks(state)
		return
	}
	for def in S_ABILITIES {
		if def.name == ability_name {
			register_hook(state, def.event, def.hook)
			return
		}
	}
}

register_class_hooks :: proc(state: ^CombatState, class: Class_Type) {
	def := CLASS_ABILITY_HOOKS[class]
	register_hook(state, def.event, def.hook)
}

register_boss_hooks :: proc(state: ^CombatState, ability_name: string) {
	if ability_name == "" do return
	for def in BOSS_ABILITIES {
		if def.name == ability_name {
			register_hook(state, def.event, def.hook)
			return
		}
	}
}

@(private)
_is_passive_char_ability :: proc(name: string) -> bool {
	for def in S_ABILITIES {
		if def.name == name do return def.is_passive
	}
	return false
}

@(private)
get_boss_ability_description :: proc(name: string) -> string {
	if name == "" do return ""
	for def in BOSS_ABILITIES {
		if def.name == name do return def.description
	}
	return ""
}
