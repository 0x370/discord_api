# AGENTS.md

## Build / Run / Test Commands

```bash
# Build the project
odin build .

# Build with optimizations
odin build . -o:speed

# Run the project (requires a token file)
odin run . -- --token "$(cat token)"

# Run with sharding (e.g., shard 0 of 2)
./discord_api --token "$(cat token)" --shard-id 0 --shards 2

# Test the bot from the repo root using the local 'token' file
cd "$(git rev-parse --show-toplevel)" && odin run . -- --token "$(cat token)"

# Check for compilation errors (no output = success)
odin build . -vet -strict-style

# Run vet/static analysis
odin build . -vet

# Check with strict style enforcement
odin build . -strict-style

# Run a single file (for quick tests)
odin run /path/to/file.odin

# Get help on Odin commands
odin help
```

## Bot Invite

The bot requires the `applications.commands` OAuth2 scope for slash commands to work.
When generating an invite URL in the Discord Developer Portal, ensure this scope is selected
along with the necessary bot permissions.

```bash
# Example invite URL format (replace CLIENT_ID):
# https://discord.com/api/oauth2/authorize?client_id=CLIENT_ID&scope=bot+applications.commands&permissions=0
```

## Token Limits

Long conversations may run out of tokens. To avoid losing progress:
- **Commit early, commit often**: `git add -A && git commit -m "message"`
- Push only when explicitly asked
- If you see a warning about tokens running out, commit everything immediately and tell the user
- The AGENTS.md file is the canonical source of truth — update it as the conversation evolves

## Project Structure

```
./
├── main.odin              # Entry point & CLI flag parsing
├── discord/               # Core library package
│   ├── handler.odin       # Gateway connection, event dispatch, session resuming
│   ├── helper.odin        # deep_clone, deep_free (reflection-based)
│   └── api/               # Discord API types package
│       ├── handler.odin   # REST client with bucket-based rate limiting
│       ├── message.odin
│       ├── guild.odin     # Includes member_count for accurate dashboard
│       ├── channel.odin
│       ├── user.odin
│       ├── embed.odin
│       ├── component.odin
│       ├── application.odin
│       ├── snowflake.odin
│       └── gateway.odin   # Gateway response types (sharding info, etc.)
├── token                  # Bot token file (gitignored)
└── discord_api*           # Compiled binary (gitignored)
```

## Features

### Dashboard
A real-time terminal dashboard that renders every second, providing:
- **Health**: CPU/Memory usage, Worker threads, Heartbeat latency (Avg/Last).
- **Gateway**: Shard ID, Gateway Status (OK/ACK), Session ID, Reconnection status.
- **Metrics**: Servers, Users (total member count), Event Rate, Messages Seen, Commands Run, REST API Calls.
- **Resources**: Message Cache size, Outbound Queue, Identify rate limit (24h).

### Sharding
Supports internal sharding configuration via CLI:
- `--shard-id`: The ID of the current instance.
- `--shards`: The total number of shards.
- Automatic fetching of recommended shard count from Discord if `--shards` is omitted.

### Resilience
- **Rate Limiting**: Preemptive bucket-based rate limiter for REST requests.
- **Session Resuming**: Automatically saves `session_id` and `last_sequence` to resume sessions (`OP_RESUME`) after disconnects.
- **Exponential Backoff**: Gradual reconnection attempts when the Gateway is unreachable.

## Package Layout

| Directory   | Package Name   | Import Path           |
|-------------|----------------|-----------------------|
| `.`         | `main`         | N/A (entry point)     |
| `discord/`  | `discord`      | `import discord "discord"` |
| `discord/api/` | `discord_api` | `import api "discord/api"` |

## Code Style Guidelines

### Imports

- Group by package source: `base:` first, `core:` second, `vendor:` third, local last.
- No blank lines between import groups.
- Use aliased imports for vendor and local packages.

```odin
import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:strings"
import "core:sync"
import "core:thread"
import "core:time"
import "vendor:curl"
import api "discord/api"
```

### Formatting

- Use tabs for indentation (Odin standard).
- Align struct fields and enum values by type/name when practical.
- Trailing commas on multi-line struct/compound literals.

### Naming Conventions

| Category       | Convention              | Example                     |
|----------------|-------------------------|-----------------------------|
| Packages       | `snake_case`            | `discord_api`               |
| Types          | `Snake_Case`            | `Gateway_Payload`, `User`   |
| Functions      | `snake_case`            | `new_client`, `deep_clone`  |
| Variables      | `snake_case`            | `msg`, `auth_header`        |
| Constants      | `UPPER_SNAKE_CASE`      | `MAX_CACHED_MESSAGES`, `DISCORD_EPOCH` |
| Enum values    | `UPPER_SNAKE_CASE`      | `GUILD_MESSAGES`, `OP_HELLO` |
| Bitfield flags | `UPPER_SNAKE_CASE`      | `SUPPRESS_EMBEDS`, `GUILD_TEXT` |
| Private procs  | `snake_case`            | `queue_outbound_payload`    |

### Types

- Use `::` for type aliases and constants.
- Use `string` as Snowflake type (`Snowflake :: string`).
- Use `bit_set` for Discord intents (`Gateway_Intents_Set :: bit_set[Gateway_Intent;i32]`).
- Use `distinct u64` for flags (`MessageFlags :: distinct u64`, then `const` values).
- Use `Maybe(T)` for optional/nullable fields.
- Use `#type proc(...)` for callback type aliases.
- Use `union` for tagged component types (`Component :: union { ... }`).

### Struct Tags

- JSON tags use `json:"field_name"` with backtick syntax.
- Flag/argument tags use `args:"name=value,required"`.
- Helper tags like `#optional_ok` on function return types.

```odin
field: string `json:"field_name"`
```

### Error Handling

- Use the Odin multi-return `(result: T, ok: bool)` pattern.
- Tag with `#optional_ok` when the function returns an optional result.
- Use `if err != nil do return` for early returns.
- Use `if !ok do return` for fallible operations.
- Prefer `fmt.eprintln` / `fmt.eprintfln` for error output.
- Check `curl` results with `.E_OK` comparison.

```odin
my_func :: proc(arg: string) -> (result: T, ok: bool) #optional_ok {
    val, err := something_fallible()
    if err != nil do return {}, false
    return val, true
}
```

### Memory Management

- Manual memory management (no GC). Use `defer` for cleanup.
- Always pass `allocator` parameter when making dynamic allocations.
- Use `context.allocator` by default, `context.temp_allocator` for temporary work.
- For persistent data in the cluster, use `cluster.allocator`.
- Use `new(T)` for heap-allocated structs, `make(T, ...)` for dynamic types.
- Free with `delete()` for strings/slices/maps, `free()` for pointers.
- Use `deep_clone` / `deep_free` (reflection-based from `helper.odin`) for complex nested types.
- **Cloning**: Use `strings.clone()` when moving Gateway strings to persistent fields in the `Client` struct.

### Concurrency

- Use `sync.Mutex` (from `core:sync`) for shared state.
- Lock/unlock pairs: lock at start, unlock before function exit.
- Use `thread.Pool` (`core:thread`) for background work.
- Use `proc(task: thread.Task)` as thread pool task signature.
- **Worker Pool**: All Gateway events and Interactions are dispatched to a thread pool to keep the Gateway loop responsive.

### Control Flow

- `if ... do return` for single-statement conditionals.
- `switch` with `.EnumValue` syntax for enum switching.
- Use `#partial switch` to match only some variants.
- Use `or_else` for Maybe defaults: `val.? or_else 0`.
- Use `defer` for resource cleanup right after acquisition.

### File Organization

- One file per logical concern (e.g., `message.odin` for Message types).
- Constants and simple types first, then structs, then enums/flags, then functions.
- Discriminators between sections: blank lines separating groups.
- Package declaration is line 1.

### Comments

- Only use comments for non-obvious intent, not for what the code does.
- Struct field comments explaining Discord API mapping are acceptable.
- Avoid trailing comments on code lines.

## References

- [Discord Developer Reference](https://docs.discord.com/developers/reference) — canonical API docs for all gateway events, REST endpoints, and object schemas. Refer to this when implementing or modifying Discord API types and behavior.
