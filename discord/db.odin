package discord

import "core:c"
import "core:fmt"
import "core:math"
import "core:strings"
import sqlite3 "sqlite3"

Db :: struct {
	conn:           ^sqlite3.Connection,
	get_user_stmt:  ^sqlite3.Statement,
}

User_Stats :: struct {
	user_id:  string,
	username: string,
	xp:       i64,
	level:    i64,
}

XP_PER_LEVEL_BASE   :: 100
XP_LEVEL_MULTIPLIER :: 1.5

db_init :: proc(path: string) -> (Db, bool) {
	conn: ^sqlite3.Connection
	flags := SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
	rc := sqlite3.open_v2(strings.clone_to_cstring(path, context.temp_allocator), &conn, flags, nil)
	if rc != .Ok {
		fmt.eprintfln("Failed to open database %q: %v", path, rc)
		return {}, false
	}

	db := Db{conn = conn}

	if !_sql_exec_simple(conn, "CREATE TABLE IF NOT EXISTS guild_config (guild_id TEXT PRIMARY KEY, prefix TEXT NOT NULL DEFAULT '!', created_at TEXT NOT NULL DEFAULT (datetime('now')))") {
		return {}, false
	}
	if !_sql_exec_simple(conn, "CREATE TABLE IF NOT EXISTS user_data (user_id TEXT PRIMARY KEY, username TEXT NOT NULL DEFAULT '', xp INTEGER NOT NULL DEFAULT 0, level INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL DEFAULT (datetime('now')))") {
		return {}, false
	}
	_sql_exec_silent(conn, "ALTER TABLE user_data ADD COLUMN username TEXT NOT NULL DEFAULT ''")
	if !_sql_exec_simple(conn, "CREATE TABLE IF NOT EXISTS dungeon_players (user_id TEXT PRIMARY KEY, equipped_char_id INTEGER DEFAULT 0, gold INTEGER NOT NULL DEFAULT 0, item_lootboxes INTEGER NOT NULL DEFAULT 0, current_floor INTEGER NOT NULL DEFAULT 1, class TEXT NOT NULL DEFAULT 'attacker', weapon_id INTEGER DEFAULT 0, head_id INTEGER DEFAULT 0, chest_id INTEGER DEFAULT 0, legs_id INTEGER DEFAULT 0, boots_id INTEGER DEFAULT 0)") {
		return {}, false
	}
	if !_sql_exec_simple(conn, "CREATE TABLE IF NOT EXISTS dungeon_characters (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id TEXT NOT NULL, name TEXT NOT NULL, tier TEXT NOT NULL, class TEXT NOT NULL, weapon_compat TEXT DEFAULT 'sword', ability_name TEXT DEFAULT '', ability_desc TEXT DEFAULT '')") {
		return {}, false
	}
	if !_sql_exec_simple(conn, "CREATE TABLE IF NOT EXISTS dungeon_items (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id TEXT NOT NULL, item_type TEXT NOT NULL, tier TEXT NOT NULL, base_atk INTEGER DEFAULT 0, base_def INTEGER DEFAULT 0, bonus_hp INTEGER DEFAULT 0, bonus_atk INTEGER DEFAULT 0, bonus_def INTEGER DEFAULT 0, bonus_spd INTEGER DEFAULT 0, special TEXT DEFAULT '')") {
		return {}, false
	}
	if !_sql_exec_simple(conn, "CREATE TABLE IF NOT EXISTS dungeon_floor_progress (user_id TEXT NOT NULL, floor INTEGER NOT NULL, encounters INTEGER DEFAULT 0, PRIMARY KEY (user_id, floor))") {
		return {}, false
	}
	_sql_exec_silent(conn, "ALTER TABLE dungeon_floor_progress ADD COLUMN encounters INTEGER DEFAULT 0")
	_sql_exec_silent(conn, "ALTER TABLE dungeon_players ADD COLUMN item_lootboxes INTEGER NOT NULL DEFAULT 0")
	_sql_exec_silent(conn, "ALTER TABLE dungeon_players ADD COLUMN char_lootboxes INTEGER NOT NULL DEFAULT 0")
	_sql_exec_silent(conn, "ALTER TABLE dungeon_players ADD COLUMN daily_streak INTEGER NOT NULL DEFAULT 0")
	_sql_exec_silent(conn, "ALTER TABLE dungeon_players ADD COLUMN last_daily_claim INTEGER NOT NULL DEFAULT 0")
	_sql_exec_silent(conn, "ALTER TABLE dungeon_characters ADD COLUMN weapon_compat TEXT DEFAULT 'sword'")
	_sql_exec_silent(conn, "UPDATE dungeon_characters SET weapon_compat = CASE WHEN class = 'healer' THEN 'staff' ELSE 'sword' END")
	if !_sql_exec_simple(conn, "CREATE TABLE IF NOT EXISTS dungeon_saves (user_id TEXT PRIMARY KEY, data TEXT NOT NULL, saved_at TEXT NOT NULL DEFAULT (datetime('now')))") {
		return {}, false
	}

	get_user_sql := "SELECT xp, level FROM user_data WHERE user_id = ?1"
	rc = sqlite3.prepare_v2(conn, strings.clone_to_cstring(get_user_sql, context.temp_allocator), -1, &db.get_user_stmt, nil)
	if rc != .Ok {
		err_msg := sqlite3.errmsg(conn)
		fmt.eprintfln("Failed to prepare get_user statement: %v — %s", rc, err_msg)
		return {}, false
	}

	fmt.printfln("Database initialized: %s", path)
	return db, true
}

db_destroy :: proc(db: ^Db) {
	if db.get_user_stmt != nil {
		sqlite3.finalize(db.get_user_stmt)
		db.get_user_stmt = nil
	}
	if db.conn != nil {
		sqlite3.close(db.conn)
		db.conn = nil
	}
}

@(private)
SQLITE_OPEN_READONLY  :: c.int(0x00000001)
@(private)
SQLITE_OPEN_READWRITE :: c.int(0x00000002)
@(private)
SQLITE_OPEN_CREATE    :: c.int(0x00000004)

@(private)
_sql_exec_silent :: proc(conn: ^sqlite3.Connection, sql: string) {
	stmt: ^sqlite3.Statement
	c_sql := strings.clone_to_cstring(sql, context.temp_allocator)
	rc := sqlite3.prepare_v2(conn, c_sql, -1, &stmt, nil)
	if rc != .Ok do return
	defer sqlite3.finalize(stmt)
	sqlite3.step(stmt)
}

@(private)
_sql_exec_simple :: proc(conn: ^sqlite3.Connection, sql: string) -> bool {
	stmt: ^sqlite3.Statement
	c_sql := strings.clone_to_cstring(sql, context.temp_allocator)
	rc := sqlite3.prepare_v2(conn, c_sql, -1, &stmt, nil)
	if rc != .Ok {
		fmt.eprintfln("SQL prepare error: %v — %s", rc, sqlite3.errmsg(conn))
		return false
	}
	defer sqlite3.finalize(stmt)

	rc = sqlite3.step(stmt)
	if rc != .Done && rc != .Row {
		fmt.eprintfln("SQL step error: %v — %s", rc, sqlite3.errmsg(conn))
		return false
	}
	return true
}

xp_for_level :: proc(level: i64) -> i64 {
	if level <= 1 do return 0
	return i64(math.round(f64(XP_PER_LEVEL_BASE) * math.pow(f64(level - 1), XP_LEVEL_MULTIPLIER)))
}

level_for_xp :: proc(xp: i64) -> i64 {
	if xp <= 0 do return 1
	lvl := i64(math.floor(math.pow(f64(xp) / f64(XP_PER_LEVEL_BASE), 1.0 / XP_LEVEL_MULTIPLIER))) + 1
	return max(lvl, 1)
}

db_user_add_xp :: proc(db: ^Db, user_id: string, username: string, amount: i64) -> (xp: i64, level: i64, ok: bool) {
	old_xp := _db_user_get_xp_internal(db, user_id)
	new_xp := old_xp + amount
	new_level := level_for_xp(new_xp)

	sql := fmt.tprintf("INSERT INTO user_data (user_id, username, xp, level) VALUES ('%s', '%s', %v, %v) ON CONFLICT(user_id) DO UPDATE SET xp = %v, level = %v, username = '%s'", string(user_id), string(username), new_xp, new_level, new_xp, new_level, string(username))
	if !_sql_exec_simple(db.conn, sql) {
		return 0, 0, false
	}
	return new_xp, new_level, true
}

db_user_get_stats :: proc(db: ^Db, user_id: string) -> (xp: i64, level: i64, ok: bool) {
	if db.get_user_stmt == nil do return 0, 0, false

	sqlite3.reset(db.get_user_stmt)
	user_id_c := strings.clone_to_cstring(user_id, context.temp_allocator)
	sqlite3.bind_text(db.get_user_stmt, 1, user_id_c, c.int(len(user_id)), {behaviour = .Transient})

	rc := sqlite3.step(db.get_user_stmt)
	if rc != .Row do return 0, 0, false

	xp = sqlite3.column_int64(db.get_user_stmt, 0)
	level = sqlite3.column_int64(db.get_user_stmt, 1)
	return xp, level, true
}

db_user_get_leaderboard :: proc(db: ^Db, limit: int, allocator := context.allocator) -> ([]User_Stats, bool) {
	stmt: ^sqlite3.Statement
	rc := sqlite3.prepare_v2(db.conn, "SELECT user_id, username, xp, level FROM user_data ORDER BY xp DESC LIMIT ?1", -1, &stmt, nil)
	if rc != .Ok {
		fmt.eprintfln("Failed to prepare leaderboard query: %v", rc)
		return nil, false
	}
	defer sqlite3.finalize(stmt)

	sqlite3.bind_int64(stmt, 1, i64(limit))

	stats := make([dynamic]User_Stats, allocator)
	for {
		rc = sqlite3.step(stmt)
		if rc == .Done do break
		if rc != .Row {
			fmt.eprintfln("Leaderboard step error: %v", rc)
			delete(stats)
			return nil, false
		}
		stats_entry := get_leaderboard_row(stmt)
		append(&stats, stats_entry)
	}

	return stats[:], true
}

@(private)
get_leaderboard_row :: proc(stmt: ^sqlite3.Statement) -> User_Stats {
	raw_id := sqlite3.column_text(stmt, 0)
	stats: User_Stats
	if raw_id != nil {
		stats.user_id = strings.clone(string(raw_id))
	}
	raw_name := sqlite3.column_text(stmt, 1)
	if raw_name != nil {
		stats.username = strings.clone(string(raw_name))
	}
	stats.xp = sqlite3.column_int64(stmt, 2)
	stats.level = sqlite3.column_int64(stmt, 3)
	return stats
}

@(private)
_db_user_get_xp_internal :: proc(db: ^Db, user_id: string) -> i64 {
	xp, _, ok := db_user_get_stats(db, user_id)
	return ok ? xp : 0
}
