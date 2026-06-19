package dungeon

import "core:sync"
import discord "../../discord"

// --- Shared session state (package-private) ---

@(private)
combat_sessions:     map[string]CombatState
@(private)
session_owners:      map[string]string
@(private)
gallery_char_cache:  map[string][]CollectedCharacter
@(private)
gallery_item_cache:  map[string][]ItemInstance
@(private)
sell_sessions:       map[string]Sell_Session
@(private)
dungeon_mutex:        sync.Mutex

// --- Initialization ---

@(private)
init_sessions :: proc() {
	sync.lock(&dungeon_mutex)
	if combat_sessions == nil do combat_sessions = make(map[string]CombatState)
	if session_owners == nil  do session_owners  = make(map[string]string)
	if gallery_char_cache == nil do gallery_char_cache = make(map[string][]CollectedCharacter)
	if sell_sessions == nil do sell_sessions = make(map[string]Sell_Session)
	if gallery_item_cache == nil do gallery_item_cache = make(map[string][]ItemInstance)
	sync.unlock(&dungeon_mutex)
}

// --- Session cleanup ---

@(private)
_cleanup_combat_session :: proc(state: ^CombatState) {
	discord.deep_free(state^, context.allocator)
}
