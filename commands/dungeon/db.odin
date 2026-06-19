package dungeon

import "core:fmt"
import "core:strings"
import "core:sync"
import sqlite3 "../../discord/sqlite3"
import discord "../../discord"

@(private)
_sql_exec :: proc(conn: ^sqlite3.Connection, sql: string) -> bool {
	stmt: ^sqlite3.Statement
	c_sql := strings.clone_to_cstring(sql, context.temp_allocator)
	rc := sqlite3.prepare_v2(conn, c_sql, -1, &stmt, nil)
	if rc != .Ok {
		logd("[db] _sql_exec prepare failed: rc=%v sql=%s", rc, sql)
		return false
	}
	defer sqlite3.finalize(stmt)
	rc = sqlite3.step(stmt)
	if rc != .Done && rc != .Row {
		err_msg := sqlite3.errmsg(conn)
		logd("[db] _sql_exec step failed: rc=%v err=%s sql=%s", rc, err_msg, sql)
		return false
	}
	return true
}

@(private)
_sql_prepare :: proc(conn: ^sqlite3.Connection, sql: string) -> (^sqlite3.Statement, bool) {
	stmt: ^sqlite3.Statement
	c_sql := strings.clone_to_cstring(sql, context.temp_allocator)
	rc := sqlite3.prepare_v2(conn, c_sql, -1, &stmt, nil)
	if rc != .Ok {
		logd("[db] _sql_prepare failed: rc=%v sql=%s", rc, sql)
		return nil, false
	}
	return stmt, true
}

db_load_player :: proc(db: ^discord.Db, user_id: string) -> (Player, bool) {
	sync.lock(&db.mutex); defer sync.unlock(&db.mutex)
	logd("[db] load_player: user_id=%s", user_id)
	sql := fmt.tprintf("SELECT gold, item_lootboxes, char_lootboxes, daily_streak, last_daily_claim, current_floor, class, equipped_char_id, weapon_id, head_id, chest_id, legs_id, boots_id FROM dungeon_players WHERE user_id = '%s'", string(user_id))
	stmt, ok := _sql_prepare(db.conn, sql)
	if !ok do return {}, false
	defer sqlite3.finalize(stmt)

	rc := sqlite3.step(stmt)
	if rc != .Row do return {}, false

	class_str := string(sqlite3.column_text(stmt, 6))
	class: Class_Type = .ATTACKER
	if class_str == "healer" do class = .HEALER

	p := Player {
		user_id          = user_id,
		gold             = int(sqlite3.column_int64(stmt, 0)),
		item_lootboxes   = int(sqlite3.column_int64(stmt, 1)),
		char_lootboxes   = int(sqlite3.column_int64(stmt, 2)),
		daily_streak     = int(sqlite3.column_int64(stmt, 3)),
		last_daily_claim = sqlite3.column_int64(stmt, 4),
		current_floor    = int(sqlite3.column_int64(stmt, 5)),
		class            = class,
		equipped_char_id = sqlite3.column_int64(stmt, 7),
		weapon_id        = sqlite3.column_int64(stmt, 8),
		head_id          = sqlite3.column_int64(stmt, 9),
		chest_id         = sqlite3.column_int64(stmt, 10),
		legs_id          = sqlite3.column_int64(stmt, 11),
		boots_id         = sqlite3.column_int64(stmt, 12),
	}
	return p, true
}
db_save_player :: proc(db: ^discord.Db, p: ^Player) -> bool {
	sync.lock(&db.mutex); defer sync.unlock(&db.mutex)
	logd("[db] save_player: user_id=%s", p.user_id)
	class_str := p.class == .ATTACKER ? "attacker" : "healer"
	sql := fmt.tprintf("INSERT INTO dungeon_players (user_id, gold, item_lootboxes, char_lootboxes, daily_streak, last_daily_claim, current_floor, class, equipped_char_id, weapon_id, head_id, chest_id, legs_id, boots_id) VALUES ('%s', %v, %v, %v, %v, %v, %v, '%s', %v, %v, %v, %v, %v, %v) ON CONFLICT(user_id) DO UPDATE SET gold = %v, item_lootboxes = %v, char_lootboxes = %v, daily_streak = %v, last_daily_claim = %v, current_floor = %v, class = '%s', equipped_char_id = %v, weapon_id = %v, head_id = %v, chest_id = %v, legs_id = %v, boots_id = %v",
		string(p.user_id), p.gold, p.item_lootboxes, p.char_lootboxes, p.daily_streak, p.last_daily_claim, p.current_floor, class_str, p.equipped_char_id, p.weapon_id, p.head_id, p.chest_id, p.legs_id, p.boots_id,
		p.gold, p.item_lootboxes, p.char_lootboxes, p.daily_streak, p.last_daily_claim, p.current_floor, class_str, p.equipped_char_id, p.weapon_id, p.head_id, p.chest_id, p.legs_id, p.boots_id)
	return _sql_exec(db.conn, sql)
}

db_get_characters :: proc(db: ^discord.Db, user_id: string) -> []CollectedCharacter {
	sync.lock(&db.mutex); defer sync.unlock(&db.mutex)
	sql := fmt.tprintf("SELECT id, name, tier, weapon_compat, ability_name, ability_desc FROM dungeon_characters WHERE user_id = '%s' ORDER BY id", string(user_id))
	stmt, ok := _sql_prepare(db.conn, sql)
	if !ok do return nil
	defer sqlite3.finalize(stmt)

	chars := make([dynamic]CollectedCharacter)
	for {
		rc := sqlite3.step(stmt)
		if rc == .Done do break
		if rc != .Row do break
		c := sqlite3_read_character_row(stmt, user_id)
		append(&chars, c)
	}
	return chars[:]
}

db_get_character_count :: proc(db: ^discord.Db, user_id: string) -> int {
	sync.lock(&db.mutex); defer sync.unlock(&db.mutex)
	sql := fmt.tprintf("SELECT COUNT(*) FROM dungeon_characters WHERE user_id = '%s'", string(user_id))
	stmt, ok := _sql_prepare(db.conn, sql)
	if !ok do return 0
	defer sqlite3.finalize(stmt)

	if sqlite3.step(stmt) == .Row {
		return int(sqlite3.column_int64(stmt, 0))
	}
	return 0
}

// db_create_player_if_new does not lock — db_load_player and db_save_player lock internally
db_create_player_if_new :: proc(db: ^discord.Db, user_id: string, class: Class_Type) {
	if _, ok := db_load_player(db, user_id); ok do return
	p := Player {
		user_id       = user_id,
		gold          = 0,
		current_floor = 1,
		class         = class,
	}
	db_save_player(db, &p)
}

db_insert_character :: proc(db: ^discord.Db, user_id: string, name: string, tier: Tier, weapon_compat: Weapon_Compat, ability_name: string, ability_desc: string) -> bool {
	sync.lock(&db.mutex); defer sync.unlock(&db.mutex)
	logd("[db] insert_character: user_id=%s name=%s", user_id, name)
	weapon_str := weapon_compat == .SWORD ? "sword" : "staff"
	tier_str   := TIER_LABELS[tier]
	sql := fmt.tprintf("INSERT INTO dungeon_characters (user_id, name, tier, class, weapon_compat, ability_name, ability_desc) VALUES ('%s', '%s', '%s', '%s', '%s', '%s', '%s')", string(user_id), string(name), tier_str, "attacker", weapon_str, ability_name, ability_desc)
	return _sql_exec(db.conn, sql)
}

db_delete_character :: proc(db: ^discord.Db, user_id: string, char_id: i64) {
	sync.lock(&db.mutex); defer sync.unlock(&db.mutex)
	sql := fmt.tprintf("DELETE FROM dungeon_characters WHERE id = %v AND user_id = '%s'", char_id, string(user_id))
	_sql_exec(db.conn, sql)
}

db_get_items :: proc(db: ^discord.Db, user_id: string) -> []ItemInstance {
	sync.lock(&db.mutex); defer sync.unlock(&db.mutex)
	sql := fmt.tprintf("SELECT id, item_type, tier, base_atk, base_def, bonus_hp, bonus_atk, bonus_def, bonus_spd, bonus_crit, special, floor FROM dungeon_items WHERE user_id = '%s' ORDER BY id", string(user_id))
	stmt, ok := _sql_prepare(db.conn, sql)
	if !ok do return nil
	defer sqlite3.finalize(stmt)

	items := make([dynamic]ItemInstance)
	for {
		rc := sqlite3.step(stmt)
		if rc == .Done do break
		if rc != .Row do break
		it := sqlite3_read_item_row(stmt, user_id)
		append(&items, it)
	}
	return items[:]
}

db_insert_item :: proc(db: ^discord.Db, user_id: string, item: ItemInstance) -> bool {
	sync.lock(&db.mutex); defer sync.unlock(&db.mutex)
	item_type_str := ITEM_TIER_NAMES[item.item_type]
	tier_str      := TIER_LABELS[item.tier]
	sql := fmt.tprintf("INSERT INTO dungeon_items (user_id, item_type, tier, base_atk, base_def, bonus_hp, bonus_atk, bonus_def, bonus_spd, bonus_crit, special, floor) VALUES ('%s', '%s', '%s', %v, %v, %v, %v, %v, %v, %v, '%s', %v)",
		string(user_id), item_type_str, tier_str, item.base_atk, item.base_def, item.bonus_hp, item.bonus_atk, item.bonus_def, item.bonus_spd, item.bonus_crit, item.special, item.floor)
	return _sql_exec(db.conn, sql)
}

db_delete_item :: proc(db: ^discord.Db, user_id: string, item_id: i64) {
	sync.lock(&db.mutex); defer sync.unlock(&db.mutex)
	sql := fmt.tprintf("DELETE FROM dungeon_items WHERE id = %v AND user_id = '%s'", item_id, string(user_id))
	_sql_exec(db.conn, sql)
}

db_get_item_by_id :: proc(db: ^discord.Db, user_id: string, item_id: i64) -> (ItemInstance, bool) {
	sync.lock(&db.mutex); defer sync.unlock(&db.mutex)
	sql := fmt.tprintf("SELECT id, item_type, tier, base_atk, base_def, bonus_hp, bonus_atk, bonus_def, bonus_spd, bonus_crit, special, floor FROM dungeon_items WHERE id = %v AND user_id = '%s'", item_id, string(user_id))
	stmt, ok := _sql_prepare(db.conn, sql)
	if !ok do return {}, false
	defer sqlite3.finalize(stmt)

	if sqlite3.step(stmt) != .Row do return {}, false
	it := sqlite3_read_item_row(stmt, user_id)
	it.id = item_id
	return it, true
}

db_get_floor_encounters :: proc(db: ^discord.Db, user_id: string, floor: int) -> int {
	sync.lock(&db.mutex); defer sync.unlock(&db.mutex)
	sql := fmt.tprintf("SELECT encounters FROM dungeon_floor_progress WHERE user_id = '%s' AND floor = %v", string(user_id), floor)
	stmt, ok := _sql_prepare(db.conn, sql)
	if !ok do return 0
	defer sqlite3.finalize(stmt)

	if sqlite3.step(stmt) == .Row {
		return int(sqlite3.column_int64(stmt, 0))
	}
	return 0
}

// db_increment_floor_encounters: partial lock — db_get_floor_encounters locks internally, then we lock for the write
db_increment_floor_encounters :: proc(db: ^discord.Db, user_id: string, floor: int) -> int {
	current := db_get_floor_encounters(db, user_id, floor) + 1
	sync.lock(&db.mutex); defer sync.unlock(&db.mutex)
	sql := fmt.tprintf("INSERT INTO dungeon_floor_progress (user_id, floor, encounters) VALUES ('%s', %v, %v) ON CONFLICT(user_id, floor) DO UPDATE SET encounters = %v", string(user_id), floor, current, current)
	_sql_exec(db.conn, sql)
	return current
}

// db_get_highest_floor does not lock — db_load_player locks internally
db_get_highest_floor :: proc(db: ^discord.Db, user_id: string) -> int {
	p, ok := db_load_player(db, user_id)
	if !ok do return 0
	return p.current_floor
}

@(private)
sqlite3_read_character_row :: proc(stmt: ^sqlite3.Statement, user_id: string) -> CollectedCharacter {
	raw_id := sqlite3.column_int64(stmt, 0)
	raw_name := string(sqlite3.column_text(stmt, 1))
	tier_str := string(sqlite3.column_text(stmt, 2))
	weapon_str := string(sqlite3.column_text(stmt, 3))
	ability_name := sqlite3.column_text(stmt, 4)
	ability_desc := sqlite3.column_text(stmt, 5)

	weapon_compat: Weapon_Compat = .SWORD
	if weapon_str == "staff" do weapon_compat = .STAFF

	tier: Tier = .COMMON
	for t in TIER_COLLECTION_ORDER {
		if TIER_LABELS[t] == tier_str {
			tier = t
			break
		}
	}

	c := CollectedCharacter {
		id   = raw_id,
		user_id = strings.clone(user_id),
		name = strings.clone(raw_name),
		tier = tier,
		weapon_compat = weapon_compat,
	}
	if ability_name != nil do c.ability_name = strings.clone(string(ability_name))
	if ability_desc != nil do c.ability_desc = strings.clone(string(ability_desc))
	return c
}

@(private)
sqlite3_read_item_row :: proc(stmt: ^sqlite3.Statement, user_id: string) -> ItemInstance {
	raw_id := sqlite3.column_int64(stmt, 0)
	item_type_str := string(sqlite3.column_text(stmt, 1))
	tier_str := string(sqlite3.column_text(stmt, 2))
	raw_special := sqlite3.column_text(stmt, 10)

	item_type: Item_Type = .SWORD
	for it in Item_Type {
		if ITEM_TIER_NAMES[it] == item_type_str {
			item_type = it
			break
		}
	}

	tier: Tier = .COMMON
	for t in TIER_COLLECTION_ORDER {
		if TIER_LABELS[t] == tier_str {
			tier = t
			break
		}
	}

	it := ItemInstance {
		id        = raw_id,
		user_id   = strings.clone(user_id),
		item_type = item_type,
		tier      = tier,
		base_atk  = int(sqlite3.column_int64(stmt, 3)),
		base_def  = int(sqlite3.column_int64(stmt, 4)),
		bonus_hp  = int(sqlite3.column_int64(stmt, 5)),
		bonus_atk = int(sqlite3.column_int64(stmt, 6)),
		bonus_def = int(sqlite3.column_int64(stmt, 7)),
		bonus_spd = int(sqlite3.column_int64(stmt, 8)),
		bonus_crit  = int(sqlite3.column_int64(stmt, 9)),
		floor     = int(sqlite3.column_int64(stmt, 11)),
	}
	if raw_special != nil do it.special = strings.clone(string(raw_special))
	return it
}
