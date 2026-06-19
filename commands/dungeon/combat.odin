package dungeon

import "core:fmt"
import "core:math/rand"
import "core:strings"

calc_player_stats :: proc(base: Class_Base, tier_mult: f64, items: map[i64]ItemInstance, weapon_match: bool) -> (hp, atk, def, mana: int) {
	hp   = int(f64(base.hp) * tier_mult)
	atk  = int(f64(base.atk) * tier_mult)
	def  = int(f64(base.def) * tier_mult)
	mana = int(f64(base.mana) * tier_mult)
	for _, item in items {
		hp  += item.bonus_hp
		atk += item.base_atk + item.bonus_atk
		def += item.base_def + item.bonus_def
	}
	if weapon_match do atk = atk * 125 / 100
	return
}

build_combat_player :: proc(p: ^Player, char: ^CollectedCharacter, items: map[i64]ItemInstance) -> CombatPlayer {
	base := CLASS_BASE_STATS[p.class]
	tier_mult := TIER_CONFIGS[char.tier].mult

	weapon_match := false
	if weapon, ok := items[p.weapon_id]; ok {
		weapon_match = weapon.item_type == .SWORD && char.weapon_compat == .SWORD || weapon.item_type == .STAFF && char.weapon_compat == .STAFF
	}

	hp, atk, def, mana := calc_player_stats(base, tier_mult, items, weapon_match)

	return CombatPlayer{
		name       = char.name,
		class      = p.class,
		max_hp     = hp,
		hp         = hp,
		atk        = atk,
		def        = def,
		max_mana   = mana,
		mana       = 0,
		mana_regen = base.mana_regen,
	}
}

generate_monster :: proc(floor: int, rare_mult: f64) -> CombatMonster {
	boss_floor := floor % BOSS_FLOOR_INTERVAL == 0

	if boss_floor {
		tmpl := _get_boss_for_floor(floor)
		level := floor
		hp  := tmpl.base_hp + tmpl.scale_hp * level
		atk := tmpl.base_atk + tmpl.scale_atk * level
		def := tmpl.base_def + tmpl.scale_def * level
		return CombatMonster{name = tmpl.name, emoji = tmpl.emoji, kind = .Boss, hp = hp, max_hp = hp, atk = atk, def = def, max_mana = tmpl.base_mana, mana = 0, mana_regen = tmpl.mana_regen, ability_name = tmpl.boss_ability}
	}

	is_rare := rand.float64() < RARE_MONSTER_CHANCE * rare_mult
	tmpl: MonsterTemplate
	if is_rare {
		tmpl = _roll_rare_monster()
	} else {
		tmpl = _roll_random_monster()
	}

	level := floor
	hp  := tmpl.base_hp + tmpl.scale_hp * level
	atk := tmpl.base_atk + tmpl.scale_atk * level
	def := tmpl.base_def + tmpl.scale_def * level
	return CombatMonster{name = tmpl.name, emoji = tmpl.emoji, kind = is_rare ? .Rare : .Normal, hp = hp, max_hp = hp, atk = atk, def = def, max_mana = tmpl.base_mana, mana = 0, mana_regen = tmpl.mana_regen}
}

emit :: proc(state: ^CombatState, event: CombatEvent) {
	listeners, has := state.hooks[event]
	logd("[emit] %v — %d listener(s)", event, has ? len(listeners) : 0)
	if !has do return
	for listener in listeners {
		listener(state)
	}
}

combat_deal_damage :: proc(atk: int, def: int) -> int {
	dmg := atk - def / 2
	if dmg < 1 do dmg = 1
	variance := rand.int_max(max(1, dmg / 4))
	return max(1, dmg + variance - dmg / 8)
}

@(private)
_advance_turn :: proc(state: ^CombatState) {
	state.turn += 1
	state.caps.bonus_attack_procs = 0
	state.caps.life_steal_total = 0
	state.caps.boss_resist_used = false
	state.caps.thorns_used = false
	if state.buffs.stun_freeze_cooldown > 0 do state.buffs.stun_freeze_cooldown -= 1
	if state.buffs.block_cooldown > 0 do state.buffs.block_cooldown -= 1
	if state.monster.hp <= 0 {
		emit(state, .ON_KILL)
		state.state = .PLAYER_WON
	}
}

combat_use_ability :: proc(state: ^CombatState) {
	if state.player.mana < state.ability_mana_cost do return
	state.player.mana -= state.ability_mana_cost
	state.ability_cooldown = ABILITY_COOLDOWN
	emit(state, .ON_ABILITY)
	_advance_turn(state)
}

combat_use_char_ability :: proc(state: ^CombatState) {
	if state.player.mana < state.char_ability_mana_cost do return
	state.player.mana -= state.char_ability_mana_cost
	state.char_ability_cooldown = ABILITY_COOLDOWN
	emit(state, .ON_ABILITY)
	emit(state, .ON_DAMAGE_DEALT)
	_advance_turn(state)
}

combat_basic_attack :: proc(state: ^CombatState) {
	dmg := combat_deal_damage(state.player.atk, state.monster.def)

	// Crit check
	if state.buffs.crit_chance > 0 && rand.int_max(100) < state.buffs.crit_chance {
		dmg = dmg * 2
		log_fmt(state, "💢 **Critical Hit!**")
	}

	state.monster.hp -= dmg
	if state.monster.hp < 0 do state.monster.hp = 0
	state.track.last_damage_dealt = dmg
	logd("[combat] basic_attack dmg=%d monster_hp=%d/%d", dmg, state.monster.hp, state.monster.max_hp)
	log_fmt(state, "⚔️ **%s** attacked %s for **%d** damage!", state.player.name, state.monster.name, dmg)
	emit(state, .ON_ATTACK)
	emit(state, .ON_DAMAGE_DEALT)
	_advance_turn(state)
}
combat_monster_turn :: proc(state: ^CombatState) {
	if state.monster.hp <= 0 do return

	// Bleed tick
	if state.buffs.monster_bleed > 0 {
		bleed_dmg := state.monster.max_hp * 5 / 100
		if bleed_dmg < 1 do bleed_dmg = 1
		state.monster.hp -= bleed_dmg
		if state.monster.hp < 0 do state.monster.hp = 0
		state.buffs.monster_bleed -= 1
		log_fmt(state, "🩸 **Bleed** ticked for **%d** damage! (%d turns left)", bleed_dmg, state.buffs.monster_bleed)
		if state.monster.hp <= 0 {
			_advance_turn(state)
			return
		}
	}

	// Freeze check
	if state.buffs.monster_frozen > 0 {
		state.buffs.monster_frozen -= 1
		log_fmt(state, "❄️ %s is frozen and cannot act! (%d turns left)", state.monster.name, state.buffs.monster_frozen)
		return
	}

	// Stun check
	if state.track.monster_stunned {
		state.track.monster_stunned = false
		log_fmt(state, "😵 %s is stunned and cannot act!", state.monster.name)
		return
	}

	// Compute monster ATK with debuff
	monster_atk := state.monster.atk
	if state.buffs.monster_atk_debuff {
		monster_atk = state.track.monster_original_atk * 80 / 100
	}

	dmg := combat_deal_damage(monster_atk, state.player.def)
	state.track.last_damage_taken = dmg

	// Shield absorbs damage before HP
	if state.buffs.shield > 0 {
		if dmg <= state.buffs.shield {
			state.buffs.shield -= dmg
			log_fmt(state, "🛡️ **Shield** absorbed **%d** damage! (%d remaining)", dmg, state.buffs.shield)
			return
		} else {
			dmg -= state.buffs.shield
			log_fmt(state, "🛡️ **Shield** broke after absorbing **%d** damage!", state.buffs.shield)
			state.buffs.shield = 0
		}
	}

	// Block — negate entire hit
	if state.buffs.block_charges > 0 {
		state.buffs.block_charges -= 1
		state.buffs.block_cooldown = 2
		log_fmt(state, "🛡️ **Blocked!** The attack was negated!")
		return
	}

	state.player.hp -= dmg
	if state.player.hp < 0 do state.player.hp = 0
	log_fmt(state, "%s %s attacked you for **%d** damage!", state.monster.emoji, state.monster.name, dmg)
	logd("[combat] monster_turn dmg=%d player_hp=%d/%d", dmg, state.player.hp, state.player.max_hp)
	emit(state, .ON_DAMAGE_TAKEN)

	if state.monster.hp <= 0 {
		emit(state, .ON_KILL)
		state.state = .PLAYER_WON
		return
	}

	if state.player.hp <= 0 {
		emit(state, .ON_DEATH)
		if state.player.hp > 0 {
			emit(state, .ON_REVIVE)
			return
		}
		state.state = .PLAYER_LOST
	}
}

combat_calculate_reward :: proc(state: ^CombatState) {
	logd("[combat] calculate_reward reward_mult=%v", state.reward_mult)
	if state.monster.kind == .Boss {
		tmpl := _find_boss_template(state.monster.name)
		gold := int(f64(tmpl.gold_min + rand.int_max(tmpl.gold_max - tmpl.gold_min + 1)) * state.reward_mult)
		state.reward_gold = gold
		state.reward_lootboxes = 2
	} else {
		state.reward_gold = int(f64(2 + rand.int_max(3) + state.floor / 2) * state.reward_mult)
		if rand.float64() < 0.08 * state.reward_mult do state.reward_lootboxes = 1
	}
}

@(private)
_regen_mana :: proc(state: ^CombatState) {
	p := &state.player
	p.mana += p.mana_regen
	if p.mana > p.max_mana do p.mana = p.max_mana

	m := &state.monster
	m.mana += m.mana_regen
	if m.mana > m.max_mana do m.mana = m.max_mana
}

register_hook :: proc(state: ^CombatState, event: CombatEvent, hook: CombatHook) {
	if state.hooks == nil do state.hooks = make(map[CombatEvent][dynamic]CombatHook)
	list := state.hooks[event]
	append(&list, hook)
	state.hooks[event] = list
}

_find_boss_template :: proc(name: string) -> MonsterTemplate {
	for tmpl in BOSS_TEMPLATES {
		if tmpl.name == name do return tmpl
	}
	return MonsterTemplate{gold_min = 10, gold_max = 20}
}

log_fmt :: proc(state: ^CombatState, fmt_str: string, args: ..any) {
	entry := fmt.tprintf(fmt_str, ..args)
	append(&state.log, strings.clone(entry))
}
