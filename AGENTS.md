# AGENTS.md

## Build / Run

```bash
odin build . -vet -strict-style -define:SQLITE3_DYNAMIC_LIB=true -define:SQLITE3_SYSTEM_LIB=true
odin run . -- --token "$(cat token)" -define:SQLITE3_DYNAMIC_LIB=true -define:SQLITE3_SYSTEM_LIB=true
```

All builds need `-define:SQLITE3_DYNAMIC_LIB=true -define:SQLITE3_SYSTEM_LIB=true`. Add `-o:speed` for release, `-o:minimal` for fast dev builds. `-vet` alone checks without compiling.

No test framework — test by running the bot with a token, or write ad-hoc `main.odin` programs.

## Package Layout

| Dir | Package | Import |
|-----|---------|--------|
| `.` | `main` | entry point |
| `discord/` | `discord` | `import discord "discord"` |
| `discord/api/` | `discord_api` | `import api "discord/api"` |
| `discord/sqlite3/` | `sqlite3` | `import sqlite3 "sqlite3"` (relative from `discord/`) |
| `commands/` | `commands` | `import "commands"` |
| `commands/dungeon/` | `dungeon` | `import dungeon "commands/dungeon"` |

## Architecture

```
curl (ws_recv) ──► network pump ──► thread.Pool ──► op dispatch
                       │                                 │
                       ▼                                 ▼
                 outbound queue                event handlers / commands
                 (mutex + cond)                   │
                                                  ▼
                                            user callbacks
                                            (thread.Pool)
```

- **Everything** async dispatches to `client.worker_pool` (`thread.Pool`). The WebSocket pump is NEVER blocked.
- REST uses a single curl easy handle protected by `request_mutex`. Rate limits are cooperative — requests block on bucket state before performing.
- Events are deep-cloned (reflection, `helper.odin`) before fan-out to listeners.
- Discord IDs are `string`, not `u64` — JSON uses strings for snowflakes.

## Project Map

```
main.odin              CLI flags, init, register all commands, run loop
discord/
  client.odin           Client struct (ALL state), init/destroy/run, type defs
  gateway.odin          WS connect, outbound queue, network pump (ws_recv loop)
  gateway_events.odin   Opcode routing (hello, dispatch, heartbeat, reconnect, invalid session)
  heartbeat.odin        Heartbeat tick (generation-gated, missed-ack detection), identify rate limiter
  handlers.odin         Event handlers: ready, guild create/delete, message CRUD, interaction → worker
  event.odin            User-facing on(event, cb) + dispatch_event (deep-clone → pool)
  command.odin          on_command/on_subcommand registration, option getters, respond/edit/defer/delete helpers
  dashboard.odin        TUI: /proc/stat CPU, /proc/self/status memory, gateway latency ring buffer
  helper.odin           deep_clone / deep_free (reflection walker)
  db.odin               SQLite XP system: xp_for_level, level_for_xp, add_xp, leaderboard
  api/
    handler.odin        HTTP client (discord_request), rate limiter (bucket map), multipart
    snowflake.odin      Snowflake :: string, parse, time conversion
    message.odin        Message struct + REST (create, edit, delete, reactions, pins, search)
    guild.odin          Guild/Role/Member structs + REST (CRUD, bans, roles, prune)
    user.odin           User structs + REST (get, modify, DMs, connections)
    interaction.odin    Interaction structs, callback types, response types
    application_command.odin  Slash command structs + REST (CRUD, permissions)
    component.odin      Message components (buttons, selects, text inputs, modals, media, containers)
    embed.odin          Embed + sub-structs (footer, image, thumbnail, video, author, fields)
    channel.odin        Channel structs, thread/forum types + REST
    attachment.odin     Attachment struct + flags
    emoji.odin          Emoji struct + REST
    application.odin    Application/Team structs + flags
    audit_log.odin      AuditLogEvent enum (~90 variants), entry structs
    auto_moderation.odin  Rule/trigger/action structs
    sticker.odin        Sticker/StickerPack structs + REST
    invite.odin         Invite structs
    webhook.odin        Webhook structs + REST
    voice.odin          VoiceState/VoiceRegion structs
    gateway.odin        Gateway_Bot_Response, Session_Start_Limit
    entitlement.odin    Entitlement struct
    poll.odin           PollCreateRequest struct
    scheduled_event.odin  GuildScheduledEvent + recurrence rules
    stage_instance.odin StageInstance struct
    soundboard.odin     SoundboardSound struct
  sqlite3/
    sqlite3.odin        Raw SQLite3 FFI bindings (Connection, Statement, Result_Code, all C API procs)
commands/
  ping.odin             /ping — latency breakdown
  echo.odin             /echo_guild <message>
  rank.odin             /rank — XP/level display
  leaderboard.odin      /leaderboard — top 10
  dungeon/
    register.odin       Slash commands + component handlers for the RPG
    types.odin          Tier, Class, Item, Player, CombatState, Monster, Affix types
    data.odin           Static tables: tier configs, class stats, monster templates, names, abilities
    combat.odin         Stat calc, combat state machine, monster generation
    lootbox.odin        Character/item gacha generation
    view.odin           Discord embed builders (profile, gallery, combat, lootbox, sell)
    db.odin             SQLite CRUD for players/characters/items, schema migrations
    image.odin          CDN URL generation, default image fallback
    debug.odin          logd() — gated on --verbose
```

## Code Conventions

### Imports
Order: `base:`, `core:`, `vendor:`, local. No blank lines. Alias vendor packages: `curl "vendor:curl"`.

### Names
| Kind | Style | Example |
|------|-------|---------|
| Package | snake_case | `discord_api` |
| Type | Snake_Case | `Gateway_Payload` |
| Function/method | snake_case | `client_init`, `handle_message_create` |
| Variable | snake_case | `msg`, `client` |
| Constant / Enum type | UPPER_SNAKE_CASE | `MAX_CACHED_MESSAGES`, `OP_HELLO` |
| Enum value | PascalCase | `.CHAT_INPUT`, `.STRING` |
| Flags | UPPER_SNAKE_CASE | `SUPPRESS_EMBEDS` |
| Private (file or package) | snake_case prefixed `_` | `_discord_request`, `_sql_exec` |

### Type idioms
- `Snowflake :: string`
- `Maybe(T)` for optional fields — no nil pointers for nullable values
- `distinct u64` + `Flags(1 << N)` for bit flags
- `bit_set[Enum; i64]` for intent/intent-set enums
- `union { string, i64, f64 }` for tagged option values
- `#type proc(ctx: ^Command_Context)` for callbacks
- `bit_field u64 { field: u8 | 5 }` for packed bits
- `#optional_ok` on `(T, bool)` returns

### Struct tags
- `` `json:"field_name,omitempty"` `` — JSON serialization
- `` `args:"name=token,required"` `` — CLI flags (via `core:flags`)
- `` `json:"_context"` `` — C-escape reserved words

### Patterns
- `if err != nil do return` — single-line early exit
- `val.? or_else default` / `if v, has := val.?; has { … }` — Maybe unwrap
- `condition ? a : b` — ternary
- `defer free(ptr)` / `defer delete(slice)` — cleanup at allocation site
- `context.temp_allocator` for JSON marshal/unmarshal intermediates; `context.allocator` for persistent data
- Strings moving to persistent fields MUST be cloned: `strings.clone(s, allocator)`
- C interop: `strings.clone_to_cstring(s, context.temp_allocator)`
- `json.marshal(data, allocator = alloc)` → `json.unmarshal(bytes, &target, json.DEFAULT_SPECIFICATION, allocator = alloc)`
- Gateway events: unmarshal `d` as `json.Value`, marshal back to bytes, unmarshal into typed struct

### Concurrency
- `sync.lock(&m)` / `sync.unlock(&m)` with `defer sync.unlock(&m)` after lock
- `sync.shared_lock` / `sync.shared_unlock` for read-heavy paths (event dispatch)
- `sync.cond_wait_with_timeout(&cond, &mutex, duration)` for outbound queue blocking
- All handlers dispatch via `thread.pool_add_task(&client.worker_pool, allocator, proc, data)`
- Pool task signature: `proc(task: thread.Task)` — data is `task.data` cast to `^YourStruct`

### File layout
```
package declaration
imports
constants
simple types (aliases, distinct)
structs
enums
functions
```
One concern per file. Blank lines between sections. `@(private)` for file-private. `#+feature dynamic-literals` when using dynamic map/slice literals.

## Invariants & Gotchas

1. **NEVER block the network pump.** `run_network_pump` must not stall — all work goes to the pool.
2. **Heartbeat is generation-gated.** `client.heartbeat_gen` increments on reconnect; old heartbeat tasks self-cancel by checking `gen != client.heartbeat_gen`.
3. **Missed heartbeat ack triggers reconnect.** `client.received_ack` is set true on ack, false before each send. If false when next tick fires → reconnect.
4. **Identify rate limit.** 1000/24h hard cap, `max_concurrency`/5s soft cap. `identify_check` prunes log and enforces both.
5. **Outbound queue is blocking.** `queue_outbound_payload` marshals to temp, copies to persistent `[]byte`, pushes to queue, signals cond.
6. **Command registration is lazy.** `on_command` just stores metadata. `register_commands()` / `bulk_overwrite_commands()` actually calls the REST API. Call registration BEFORE `client_run`.
7. **Interaction tokens expire.** Deferred responses must get a real response within 15 min. Followups use the interaction token, not webhook URL.
8. **XP cooldown is per-user 5 min.** `_award_xp` checks `xp_cooldowns` map; skips if within window.
9. **Dungeon state is in-memory.** `combat_sessions`, `sell_sessions`, gallery caches are maps behind `dungeon_mutex`. Restart loses active combat.
10. **Two separate DB domains.** `discord/db.odin` (XP, `users` table) and `commands/dungeon/db.odin` (RPG, `dungeon_*` tables) share `bot.db`. Both use raw sqlite3 FFI via `discord/sqlite3`.
11. **`discord_api` package is mostly types.** Only `handler.odin` has logic (HTTP client, rate limiter). All other files are type definitions + REST wrapper procs.
12. **Rate limit buckets persist.** `discord_api.handler` stores buckets in `Discord_Client.buckets` and `route_to_bucket` maps. Buckets are keyed by canonical route (major resource ID only).

## Recipes

### Add a new slash command
1. Create `commands/mycommand.odin` with a `register_mycommand_commands :: proc(client: ^discord.Client)` that calls `discord.on_command(client, "name", "desc", handler, options...)`.
2. For options, use `{type = .STRING, name = "param", description = "...", required = true}`.
3. In handler: extract options with `discord.get_string(ctx, "name")` etc. Respond with `discord.respond(ctx, msg)` or `discord.defer_response` + `discord.edit_original_response`.
4. Import `discord "../discord"` (relative from `commands/`).
5. In `main.odin`, import the package and call its register proc BEFORE `client_run`.

### Add a new Discord API type
1. Add structs/enums to the appropriate file in `discord/api/` (or create a new file if it's a new resource).
2. Use `json:"field_name,omitempty"` tags. `Maybe(T)` for optional fields. `Snowflake` for IDs.
3. If you need REST endpoints, add wrapper procs that call `_discord_request` or the convenience wrappers (`_discord_get`, `_discord_post`, etc.) from `handler.odin`.
4. Follow the existing file patterns — types first, then REST procs at the bottom.

### Add a new event listener (userland)
```odin
discord.on(client, "MESSAGE_CREATE", proc(data: rawptr) {
    msg := (^api.Message)(data)
    // use msg
})
```
The event name matches Discord's gateway `t` field. Payload is a pointer to the typed event data — cast to the right type from `discord/api`.

### Add a component handler
```odin
discord.on_component(client, "my_custom_id", proc(ctx: ^discord.Component_Context) {
    discord.respond_component(ctx, embeds, components)
})
```
The `custom_id` must match the `custom_id` set on the button/select menu.

### Query the DB (XP)
```odin
xp, level, ok := discord.db_user_get_stats(&client.db, user_id)
leaderboard, ok := discord.db_user_get_leaderboard(&client.db, 10, allocator)
discord.db_user_add_xp(&client.db, user_id, username, amount)
```
All take `^discord.Db`. The DB is opened in `client_init`, closed in `client_destroy`.

### Query the DB (Dungeon RPG)
```odin
player, ok := dungeon.db_load_player(&client.db, user_id)
dungeon.db_save_player(&client.db, &player)
chars := dungeon.db_get_characters(&client.db, user_id)
items := dungeon.db_get_items(&client.db, user_id)
dungeon.db_insert_character(&client.db, user_id, name, tier, compat, ability_name, ability_desc)
dungeon.db_insert_item(&client.db, user_id, item_instance)
```
All use the same `^discord.Db` passed through `client.db`.

### Make a REST call directly
```odin
import api "discord/api"
response, ok := api.discord_get(client.api_client, "/users/%s", user_id)
if ok && response.status_code == 200 {
    // response.body is []byte
}
```
Convenience wrappers: `api.discord_get`, `api.discord_post`, `api.discord_put`, `api.discord_patch`, `api.discord_delete`. For multipart file uploads, use `api.discord_request` with `multipart_files` parameter.

## Commit Style
```
type: short description
```
Types: `add`, `fix`, `refactor`, `update`.

## References
- [Discord API Reference](https://docs.discord.com/developers/reference)
- [Odin Language Reference](https://odin-lang.org/docs/)
