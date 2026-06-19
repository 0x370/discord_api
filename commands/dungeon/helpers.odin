package dungeon

import "core:strings"
import discord "../../discord"

// --- User ID extraction ---

@(private)
get_user_id :: proc(ctx: ^discord.Command_Context) -> string {
	user_id := ctx.interaction.member.user.id
	if user_id == "" do user_id = ctx.interaction.user.id
	return string(user_id)
}

@(private)
get_component_user_id :: proc(ctx: ^discord.Component_Context) -> string {
	user_id := ctx.interaction.member.user.id
	if user_id == "" do user_id = ctx.interaction.user.id
	return string(user_id)
}

// --- Player loading ---

@(private)
require_player :: proc(ctx: ^discord.Command_Context, db: ^discord.Db, user_id: string) -> (player: Player, ok: bool) {
	p, pok := db_load_player(db, user_id)
	if !pok {
		discord.respond(ctx, "No dungeon profile found! Try `/dungeon` first.")
		return {}, false
	}
	return p, true
}

// --- Equip slot definitions ---

Equip_Slot_Def :: struct {
	slot:   Item_Slot,
	get_id: proc(p: ^Player) -> i64,
	set_id: proc(p: ^Player, id: i64),
	emoji:  string,
	name:   string,
}

@(private)
EQUIP_SLOT_DEFS := []Equip_Slot_Def{
	{
		slot   = .WEAPON,
		get_id = proc(p: ^Player) -> i64 { return p.weapon_id },
		set_id = proc(p: ^Player, id: i64) { p.weapon_id = id },
		emoji  = "🗡️",
		name   = "Weapon",
	},
	{
		slot   = .HEAD,
		get_id = proc(p: ^Player) -> i64 { return p.head_id },
		set_id = proc(p: ^Player, id: i64) { p.head_id = id },
		emoji  = "⛑️",
		name   = "Head",
	},
	{
		slot   = .CHEST,
		get_id = proc(p: ^Player) -> i64 { return p.chest_id },
		set_id = proc(p: ^Player, id: i64) { p.chest_id = id },
		emoji  = "🛡️",
		name   = "Chest",
	},
	{
		slot   = .LEGS,
		get_id = proc(p: ^Player) -> i64 { return p.legs_id },
		set_id = proc(p: ^Player, id: i64) { p.legs_id = id },
		emoji  = "👖",
		name   = "Legs",
	},
	{
		slot   = .BOOTS,
		get_id = proc(p: ^Player) -> i64 { return p.boots_id },
		set_id = proc(p: ^Player, id: i64) { p.boots_id = id },
		emoji  = "👢",
		name   = "Boots",
	},
}

@(private)
get_equipped_item_ids :: proc(p: ^Player) -> [dynamic]i64 {
	ids := make([dynamic]i64, 0, 5, context.temp_allocator)
	for def in EQUIP_SLOT_DEFS {
		id := def.get_id(p)
		if id != 0 do append(&ids, id)
	}
	return ids
}

@(private)
load_equipped_items :: proc(db: ^discord.Db, p: ^Player) -> map[i64]ItemInstance {
	items := make(map[i64]ItemInstance)
	for def in EQUIP_SLOT_DEFS {
		id := def.get_id(p)
		if id == 0 do continue
		if it, ok := db_get_item_by_id(db, p.user_id, id); ok {
			items[id] = it
		}
	}
	return items
}

@(private)
unequip_item :: proc(p: ^Player, item_id: i64) {
	for def in EQUIP_SLOT_DEFS {
		if def.get_id(p) == item_id {
			def.set_id(p, 0)
			return
		}
	}
}

@(private)
_register_all_hooks :: proc(state: ^CombatState, db: ^discord.Db, p: ^Player) {
	register_class_hooks(state, p.class)
	register_hook(state, .TURN_START, _regen_mana)
	register_char_hooks(state, state.char_ability_name)
	if state.boss_floor {
		register_boss_hooks(state, state.monster.ability_name)
	}
	ids := get_equipped_item_ids(p)
	for id in ids {
		if id == 0 do continue
		if it, ok := db_get_item_by_id(db, p.user_id, id); ok && it.special != "" {
			register_item_hooks(state, it.special)
		}
	}
}

@(private)
_count_item_hooks :: proc(db: ^discord.Db, p: ^Player) -> int {
	count := 0
	ids := get_equipped_item_ids(p)
	for id in ids {
		if id == 0 do continue
		if it, ok := db_get_item_by_id(db, p.user_id, id); ok && it.special != "" do count += 1
	}
	return count
}

@(private)
_get_or_cache :: proc(cache: ^map[string][]$T, key: string, db: ^discord.Db, loader: proc(db: ^discord.Db, user_id: string) -> []T, sorter: proc(items: []T)) -> []T {
	if cached, has := cache[key]; has do return cached
	loaded := loader(db, key)
	sorter(loaded)
	cache[strings.clone(key)] = loaded
	return loaded
}
