package dungeon

import "core:fmt"
import "core:math/rand"
import "core:strings"

build_combat_player :: proc(p: ^Player, char: ^CollectedCharacter, items: map[i64]ItemInstance) -> CombatPlayer {
	base := CLASS_BASE_STATS[p.class]
	tier_mult := TIER_CONFIGS[char.tier].mult

	hp  := int(f64(base.hp) * tier_mult)
	atk := int(f64(base.atk) * tier_mult)
	def := int(f64(base.def) * tier_mult)

	for _, item in items {
		hp  += item.bonus_hp
		atk += item.base_atk + item.bonus_atk
		def += item.base_def + item.bonus_def
	}

	return CombatPlayer{
		name   = char.name,
		class  = p.class,
		max_hp = hp,
		hp     = hp,
		atk    = atk,
		def    = def,
	}
}

generate_monster :: proc(floor: int, rare_mult: f64) -> CombatMonster {
	boss_floor := floor % BOSS_FLOOR_INTERVAL == 0

	if boss_floor {
		tmpl := _roll_random_boss()
		level := floor
		hp  := tmpl.base_hp + tmpl.scale_hp * level
		atk := tmpl.base_atk + tmpl.scale_atk * level
		def := tmpl.base_def + tmpl.scale_def * level
		return CombatMonster{name = tmpl.name, emoji = tmpl.emoji, boss = true, rare = false, hp = hp, max_hp = hp, atk = atk, def = def}
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
	return CombatMonster{name = tmpl.name, emoji = tmpl.emoji, boss = false, rare = is_rare, hp = hp, max_hp = hp, atk = atk, def = def}
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

combat_use_ability :: proc(state: ^CombatState) {
	state.ability_cooldown = ABILITY_COOLDOWN
	emit(state, .ON_ABILITY)

	state.turn += 1
	if state.monster.hp <= 0 {
		emit(state, .ON_KILL)
		state.state = .PLAYER_WON
	}
}

combat_use_char_ability :: proc(state: ^CombatState) {
	state.char_ability_cooldown = ABILITY_COOLDOWN
	emit(state, .ON_DAMAGE_DEALT)
	emit(state, .ON_ABILITY)

	state.turn += 1
	if state.monster.hp <= 0 {
		emit(state, .ON_KILL)
		state.state = .PLAYER_WON
	}
}

combat_basic_attack :: proc(state: ^CombatState) {
	dmg := combat_deal_damage(state.player.atk, state.monster.def)
	state.monster.hp -= dmg
	if state.monster.hp < 0 do state.monster.hp = 0
	logd("[combat] basic_attack dmg=%d monster_hp=%d/%d", dmg, state.monster.hp, state.monster.max_hp)
	log_fmt(state, "⚔️ **%s** attacked %s for **%d** damage!", state.player.name, state.monster.name, dmg)
	emit(state, .ON_ATTACK)
	emit(state, .ON_DAMAGE_DEALT)

	state.turn += 1
	if state.monster.hp <= 0 {
		emit(state, .ON_KILL)
		state.state = .PLAYER_WON
	}
}

combat_monster_turn :: proc(state: ^CombatState) {
	if state.monster.hp <= 0 do return
	dmg := combat_deal_damage(state.monster.atk, state.player.def)
	state.player.hp -= dmg
	if state.player.hp < 0 do state.player.hp = 0
	log_fmt(state, "%s %s attacked you for **%d** damage!", state.monster.emoji, state.monster.name, dmg)
	logd("[combat] monster_turn dmg=%d player_hp=%d/%d", dmg, state.player.hp, state.player.max_hp)
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

combat_calculate_reward :: proc(state: ^CombatState) {
	logd("[combat] calculate_reward reward_mult=%v", state.reward_mult)
	if state.monster.boss {
		tmpl := _find_boss_template(state.monster.name)
		gold := int(f64(tmpl.gold_min + rand.int_max(tmpl.gold_max - tmpl.gold_min + 1)) * state.reward_mult)
		state.reward_gold = gold
		state.reward_lootboxes = 2
	} else {
		state.reward_gold = int(f64(3 + rand.int_max(5) + state.floor) * state.reward_mult)
		if rand.float64() < 0.15 * state.reward_mult do state.reward_lootboxes = 1
	}
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
