#+feature dynamic-literals
package dungeon

import "core:fmt"
import "core:math/rand"

TIER_COLLECTION_ORDER :: []Tier{
	.S,
	.A,
	.B,
	.C,
	.D,
	.F,
}

TIER_CONFIGS := [Tier]Tier_Config {
	.S = {name = "S", label = "⭐⭐⭐⭐⭐", mult = 1.75, min_affixes = 3, max_affixes = 3, affix_min = 8, affix_max = 15},
	.A = {name = "A", label = "⭐⭐⭐⭐",   mult = 1.50, min_affixes = 2, max_affixes = 2, affix_min = 6, affix_max = 12},
	.B = {name = "B", label = "⭐⭐⭐",     mult = 1.35, min_affixes = 2, max_affixes = 2, affix_min = 4, affix_max = 9},
	.C = {name = "C", label = "⭐⭐",       mult = 1.20, min_affixes = 1, max_affixes = 1, affix_min = 3, affix_max = 7},
	.D = {name = "D", label = "⭐",         mult = 1.10, min_affixes = 1, max_affixes = 1, affix_min = 1, affix_max = 4},
	.F = {name = "F", label = "⚪",        mult = 1.00, min_affixes = 0, max_affixes = 0, affix_min = 0, affix_max = 0},
}

TIER_WEIGHTS := [Tier]int {
	.S = 3,
	.A = 7,
	.B = 12,
	.C = 18,
	.D = 25,
	.F = 35,
}

TIER_LABELS := [Tier]string {
	.S = "S",
	.A = "A",
	.B = "B",
	.C = "C",
	.D = "D",
	.F = "F",
}

TIER_EMBED_COLORS := [Tier]int {
	.S = 0xffd700,
	.A = 0xe74c3c,
	.B = 0x3498db,
	.C = 0x2ecc71,
	.D = 0xe67e22,
	.F = 0x95a5a6,
}

CLASS_BASE_STATS := [Class_Type]Class_Base {
	.ATTACKER = {hp = 100, atk = 25, def = 10},
	.HEALER   = {hp = 120, atk = 15, def = 15},
}

CLASS_NAMES := [Class_Type]string {
	.ATTACKER = "Attacker",
	.HEALER   = "Healer",
}

CLASS_EMOJIS := [Class_Type]string {
	.ATTACKER = "⚔️",
	.HEALER   = "💚",
}

CLASS_ABILITY_DISPLAY_NAMES := [Class_Type]string {
	.ATTACKER = "Power Strike",
	.HEALER   = "Healing Light",
}

ABILITY_COOLDOWN :: 3

hook_class_attacker :: proc(state: ^CombatState) {
	dmg := int(f64(state.player.atk) * 1.5)
	mitigated := combat_deal_damage(dmg, state.monster.def)
	state.monster.hp -= mitigated
	if state.monster.hp < 0 do state.monster.hp = 0
	log_fmt(state, "⚡ **%s** used Power Strike on %s for **%d** damage!", state.player.name, state.monster.name, mitigated)
	emit(state, .ON_DAMAGE_DEALT)
}

hook_class_healer :: proc(state: ^CombatState) {
	heal := int(f64(state.player.max_hp) * 0.3)
	state.player.hp += heal
	if state.player.hp > state.player.max_hp do state.player.hp = state.player.max_hp
	log_fmt(state, "💚 **%s** healed for **%d** HP!", state.player.name, heal)
	emit(state, .ON_HEAL)
}

hook_item_double_dmg :: proc(state: ^CombatState) {
	logd("[hook] ON_ATTACK → double_dmg")
	if rand.int_max(100) >= 20 do return
	dmg := combat_deal_damage(state.player.atk, state.monster.def)
	state.monster.hp -= dmg
	if state.monster.hp < 0 do state.monster.hp = 0
	log_fmt(state, "⚡ **Double Damage!** Extra **%d** damage dealt!", dmg)
}

hook_item_heal_per_turn :: proc(state: ^CombatState) {
	logd("[hook] TURN_START → heal_per_turn")
	heal := state.player.max_hp * 5 / 100
	if heal < 1 do heal = 1
	state.player.hp += heal
	if state.player.hp > state.player.max_hp do state.player.hp = state.player.max_hp
	log_fmt(state, "💚 Healed **%d** HP from equipment!", heal)
}

hook_item_def_reduce :: proc(state: ^CombatState) {
	logd("[hook] ON_DAMAGE_TAKEN → def_reduce")
	state.monster.def = state.monster.def * 80 / 100
}

hook_revive :: proc(state: ^CombatState) {
	logd("[hook] ON_DEATH → revive (phoenix)")
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

register_item_hooks :: proc(state: ^CombatState, special: string) {
	switch special {
	case "Chance to deal double damage":
		register_hook(state, .ON_ATTACK, hook_item_double_dmg)
	case "Restore 5% HP per turn":
		register_hook(state, .TURN_START, hook_item_heal_per_turn)
	case "Damage taken reduced by 15%":
		register_hook(state, .ON_DAMAGE_TAKEN, hook_item_def_reduce)
	}
}

register_char_hooks :: proc(state: ^CombatState, ability_name: string) {
	switch ability_name {
	case "Phoenix Rebirth":
		register_hook(state, .ON_DEATH, hook_revive)
	case "Call of the Wild":
		register_hook(state, .TURN_START, hook_summon)
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
	.HP  = "HP",
	.ATK = "ATK",
	.DEF = "DEF",
	.SPD = "SPD",
}

AFFIX_EMOJIS := [Affix]string {
	.HP  = "❤️",
	.ATK = "⚔️",
	.DEF = "🛡️",
	.SPD = "💨",
}

ITEM_SPECIAL_EFFECTS := []string {
	"Chance to deal double damage",
	"Restore 5% HP per turn",
	"Damage taken reduced by 15%",
	"First attack each combat does 2x damage",
	"Ignore 20% of enemy DEF",
	"You heal for 10% of damage dealt",
	"Enemies have 10% chance to miss",
	"Gain 5% bonus gold from monsters",
	"Your attacks have a chance to stun",
	"Take 50% less damage from bosses",
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
	"Cataclysm", "Divine Judgment", "Soul Rend",   "Tempest Fury",
	"Abyssal Strike", "Phoenix Rebirth", "Frozen Calamity",
	"Arcane Apocalypse", "Shadow Dominion", "Light's Vengeance",
}

S_ABILITY_DESCS := []string {
	"Deal 200% ATK damage and ignore DEF",
	"Heal to full HP and gain 50% ATK for 2 turns",
	"Deal massive damage and life-steal 30%",
	"Strike all enemies for 120% ATK damage",
	"Deal 180% damage with a chance to execute low-HP targets",
	"On death, revive with 40% HP once per combat",
	"Deal 150% damage and freeze target for 1 turn",
	"Gain +100% ATK and hit all enemies for 2 turns",
	"Enter stealth, next attack does 300% damage",
	"Deal 250% damage to bosses, ignore cooldowns for 1 turn",
}

LOOTBOX_CHARACTER_COUNT :: 5
LOOTBOX_ITEM_COUNT      :: 5

BOSS_FLOOR_INTERVAL :: 5
RARE_MONSTER_CHANCE :: 0.15

MONSTER_TEMPLATES := []MonsterTemplate {
	{name = "Goblin",        emoji = "👺", boss = false, rare = false, base_hp = 30,  base_atk = 8,  base_def = 3,  scale_hp = 8,  scale_atk = 2, scale_def = 1, gold_min = 5,  gold_max = 15,  lootbox_chance = 0.15},
	{name = "Wolf",          emoji = "🐺", boss = false, rare = false, base_hp = 40,  base_atk = 10, base_def = 4,  scale_hp = 10, scale_atk = 3, scale_def = 1, gold_min = 8,  gold_max = 18,  lootbox_chance = 0.18},
	{name = "Slime",         emoji = "🟢", boss = false, rare = false, base_hp = 25,  base_atk = 6,  base_def = 5,  scale_hp = 6,  scale_atk = 2, scale_def = 2, gold_min = 3,  gold_max = 10,  lootbox_chance = 0.12},
	{name = "Skeleton",      emoji = "💀", boss = false, rare = false, base_hp = 35,  base_atk = 9,  base_def = 4,  scale_hp = 9,  scale_atk = 2, scale_def = 1, gold_min = 6,  gold_max = 16,  lootbox_chance = 0.16},
	{name = "Zombie",        emoji = "🧟", boss = false, rare = false, base_hp = 45,  base_atk = 7,  base_def = 3,  scale_hp = 12, scale_atk = 2, scale_def = 1, gold_min = 7,  gold_max = 14,  lootbox_chance = 0.14},
	{name = "Bat Swarm",     emoji = "🦇", boss = false, rare = false, base_hp = 20,  base_atk = 11, base_def = 2,  scale_hp = 5,  scale_atk = 3, scale_def = 1, gold_min = 4,  gold_max = 12,  lootbox_chance = 0.13},
	{name = "Spider",        emoji = "🕷️", boss = false, rare = false, base_hp = 32,  base_atk = 10, base_def = 3,  scale_hp = 8,  scale_atk = 3, scale_def = 1, gold_min = 6,  gold_max = 15,  lootbox_chance = 0.15},
	{name = "Wraith",        emoji = "👻", boss = false, rare = true,  base_hp = 50,  base_atk = 14, base_def = 6,  scale_hp = 12, scale_atk = 4, scale_def = 2, gold_min = 15, gold_max = 30,  lootbox_chance = 0.30},
	{name = "Crystal Golem", emoji = "💎", boss = false, rare = true,  base_hp = 70,  base_atk = 12, base_def = 10, scale_hp = 15, scale_atk = 3, scale_def = 3, gold_min = 18, gold_max = 35,  lootbox_chance = 0.35},
	{name = "Shadow Assassin", emoji = "🗡️", boss = false, rare = true, base_hp = 45, base_atk = 18, base_def = 4, scale_hp = 10, scale_atk = 5, scale_def = 1, gold_min = 20, gold_max = 40,  lootbox_chance = 0.32},
	{name = "Phantom Wolf",  emoji = "🌑", boss = false, rare = true,  base_hp = 55,  base_atk = 16, base_def = 5,  scale_hp = 13, scale_atk = 4, scale_def = 2, gold_min = 16, gold_max = 32,  lootbox_chance = 0.30},
}

BOSS_TEMPLATES := []MonsterTemplate {
	{name = "Goblin King",    emoji = "👑", boss = true, rare = false, base_hp = 120, base_atk = 16, base_def = 8,  scale_hp = 20, scale_atk = 4, scale_def = 2, gold_min = 40,  gold_max = 80,  lootbox_chance = 1.0},
	{name = "Dragon Whelp",   emoji = "🐉", boss = true, rare = false, base_hp = 150, base_atk = 20, base_def = 10, scale_hp = 25, scale_atk = 5, scale_def = 3, gold_min = 50,  gold_max = 100, lootbox_chance = 1.0},
	{name = "Lich Lord",      emoji = "☠️", boss = true, rare = false, base_hp = 140, base_atk = 22, base_def = 9,  scale_hp = 22, scale_atk = 6, scale_def = 2, gold_min = 55,  gold_max = 110, lootbox_chance = 1.0},
	{name = "Hydra",          emoji = "🐍", boss = true, rare = false, base_hp = 200, base_atk = 18, base_def = 12, scale_hp = 30, scale_atk = 4, scale_def = 3, gold_min = 60,  gold_max = 120, lootbox_chance = 1.0},
	{name = "Dark Knight",    emoji = "🛡️", boss = true, rare = false, base_hp = 160, base_atk = 24, base_def = 14, scale_hp = 24, scale_atk = 5, scale_def = 3, gold_min = 65,  gold_max = 130, lootbox_chance = 1.0},
	{name = "Ancient Dragon", emoji = "🐲", boss = true, rare = false, base_hp = 250, base_atk = 26, base_def = 15, scale_hp = 35, scale_atk = 6, scale_def = 4, gold_min = 80,  gold_max = 160, lootbox_chance = 1.0},
	{name = "Demon Lord",     emoji = "😈", boss = true, rare = false, base_hp = 220, base_atk = 28, base_def = 12, scale_hp = 28, scale_atk = 7, scale_def = 3, gold_min = 90,  gold_max = 180, lootbox_chance = 1.0},
	{name = "Elder Titan",    emoji = "🗿", boss = true, rare = false, base_hp = 300, base_atk = 20, base_def = 18, scale_hp = 40, scale_atk = 4, scale_def = 4, gold_min = 100, gold_max = 200, lootbox_chance = 1.0},
	{name = "Phoenix",        emoji = "🔥", boss = true, rare = false, base_hp = 180, base_atk = 30, base_def = 10, scale_hp = 20, scale_atk = 8, scale_def = 2, gold_min = 70,  gold_max = 140, lootbox_chance = 1.0},
	{name = "Voidwalker",     emoji = "🌀", boss = true, rare = false, base_hp = 170, base_atk = 25, base_def = 13, scale_hp = 25, scale_atk = 6, scale_def = 3, gold_min = 75,  gold_max = 150, lootbox_chance = 1.0},
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
	return .F
}

_roll_random_boss :: proc() -> MonsterTemplate {
	idx := rand.int_max(len(BOSS_TEMPLATES))
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
		if !tmpl.rare do append(&normal, tmpl)
	}
	return normal[:]
}

_get_rare_monsters :: proc() -> []MonsterTemplate {
	rare := make([dynamic]MonsterTemplate, 0, len(MONSTER_TEMPLATES), context.temp_allocator)
	for tmpl in MONSTER_TEMPLATES {
		if tmpl.rare do append(&rare, tmpl)
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

_random_special_effect :: proc() -> string {
	idx := rand.int_max(len(ITEM_SPECIAL_EFFECTS))
	return ITEM_SPECIAL_EFFECTS[idx]
}
