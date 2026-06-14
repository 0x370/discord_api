# AGENTS.md

## Build / Run / Test Commands

```bash
# Build the project (fast, no optimizations)
odin build .

# Build with optimizations
odin build . -o:speed

# Build with minimal optimizations (good for dev)
odin build . -o:minimal

# Build with vet & strict style checks
odin build . -vet -strict-style

# Run vet/static analysis only
odin build . -vet

# Run with token file
odin run . -- --token "$(cat token)"

# Run with sharding (shard 0 of 2)
odin build . && ./discord_api --token "$(cat token)" --shard-id 0 --shards 2
```

## Testing

Odin has no built-in testing framework. Test by:
- Building and running the full project with a Discord token
- Writing separate example programs
- Adding custom commands to `main.odin` to exercise specific code paths

## Commit Message Style

From `git log`, commits use conventional commits format:
```
type: short description

Longer description if needed.
```
Types observed: `add`, `fix`, `refactor`, `update`.

## Project Structure

```
./
├── main.odin                    # Entry point, CLI flags
├── discord/
│   ├── client.odin              # Client struct, init/destroy/run, config
│   ├── gateway.odin             # WebSocket connect, network pump, outbound queue
│   ├── gateway_events.odin      # Gateway opcode & dispatch handling
│   ├── heartbeat.odin           # Heartbeat loop, identify rate limiting
│   ├── handlers.odin            # Event handlers (msg create/update/delete, guild, interaction)
│   ├── event.odin               # User-facing event registration & dispatch
│   ├── command.odin             # Slash command helpers (on_command, respond, defer, get_X)
│   ├── rest_helpers.odin        # High-level REST wrappers (bulk overwrite, edit, followup)
│   ├── dashboard.odin           # Terminal dashboard (CPU, memory, latency, stats)
│   ├── helper.odin              # deep_clone, deep_free (reflection-based)
│   └── api/                     # Discord REST API types (25 files)
│       ├── handler.odin         # HTTP client, rate limiter, bucket tracking
│       ├── snowflake.odin       # Snowflake type & parsing
│       ├── message.odin, guild.odin, channel.odin, user.odin ...
│       └── ...
├── token                        # Bot token (gitignored)
└── discord_api*                 # Compiled binary (gitignored)
```

## Package Layout

| Directory       | Package Name | Import Path               |
|-----------------|--------------|---------------------------|
| `.`             | `main`       | N/A (entry point)         |
| `discord/`      | `discord`    | `import discord "discord"` |
| `discord/api/`  | `discord_api`| `import api "discord/api"` |

## Code Style

### Imports
Group by source in order: `base:`, `core:`, `vendor:`, local. No blank lines between groups. Use aliased imports for vendor packages (`curl "vendor:curl"`).

### Formatting
- Tabs for indentation
- Align struct fields and enum values by type/name
- Trailing commas on multi-line structures
- `@(private)` attribute for file-private declarations
- Triple-underscore `---` for uninitialized sentinel values

### Naming
| Type      | Convention       | Examples                  |
|-----------|------------------|---------------------------|
| Packages  | snake_case       | `discord_api`             |
| Types     | Snake_Case       | `Gateway_Payload`         |
| Functions | snake_case       | `new_client`, `client_run`|
| Methods   | snake_case       | `handle_message_create`   |
| Variables | snake_case       | `msg`, `client`           |
| Constants | UPPER_SNAKE_CASE | `MAX_CACHED_MESSAGES`     |
| Enums     | UPPER_SNAKE_CASE | `OP_HELLO`                |
| Enum values | PascalCase    | `.CHAT_INPUT`, `.STRING`  |
| Flags     | UPPER_SNAKE_CASE | `SUPPRESS_EMBEDS`         |
| Private   | snake_case       | `_discord_request`        |

### Types
- Use `::` for type aliases and constants
- Use `string` for Snowflake (type alias: `Snowflake :: string`)
- Use `bit_set[Enum; i64]` for bit-set enums (e.g. `Gateway_Intents_Set :: bit_set[Gateway_Intent; i64]`)
- Use `distinct u64` for flag types; define values as `MyFlags(1 << N)`
- Use `Maybe(T)` for nullable/optional fields
- Use `#type proc(...)` for callback types
- Use `union` for tagged union types (e.g. `ApplicationCommandOptionChoiceValue :: union { string, i64, f64 }`)
- Use `$T` for generic/polymorphic proc parameters
- Use `bit_field u64 { ... }` for bit-level structs

### Struct Tags
- JSON: `` `json:"field_name"` `` with `,omitempty` when optional
- Args: `` `args:"name=value,required"` ``
- C JSON rename with backtick + underscore: `` `json:"_context"` ``
- Return tag: `#optional_ok` on functions returning `(T, bool)`

### Error Handling
- Use `(T, ok: bool)` pattern with `#optional_ok` tag
- Use `if err != nil do return` for early exits
- Use `if !ok do return` for bool checks
- Use `if err != nil do return false / continue / break` as single-line
- Prefer `fmt.eprintln` / `fmt.eprintfln` for errors
- Check curl results against `.E_OK`
- Use `or_else` for `Maybe` defaults: `val.? or_else 0`, `val.? or_else nil`
- Use `val.?` for `Maybe` unwrapping: `if v, has := val.?; has { ... }`
- Use `?:` ternary: `condition ? if_true : if_false`

### Memory
- Manual management with `defer` cleanup
- Pass `allocator` parameter for allocations
- Use `context.allocator` for persistent data, `context.temp_allocator` for temporary work
- `new(T)` for heap-allocated pointers, `make(T)` for dynamic types
- `delete()` for strings/slices/maps, `free()` for pointers
- Use `deep_clone` / `deep_free` for complex nested types (reflection-based, in `helper.odin`)
- Clone with `strings.clone()` when moving strings to persistent fields
- Use `strings.clone_to_cstring()` for C interop (curl)
- Use `runtime.mem_alloc` / `runtime.mem_resize` for manual byte buffers
- Use `runtime.copy_slice` for copying slice elements
- Use `clear(&slice)` / `delete_key(&map, key)` for clearing collections
- Use `resize()` to truncate dynamic arrays: `resize(&log, write_idx)`
- Use `pop_front(&dyn_array)` for queue-like behavior
- Clean up allocated strings with `delete(str, allocator)` before reassignment
- Always `defer free()` / `defer delete()` after allocation where possible
- Use `context.temp_allocator` for json marshal/unmarshal intermediate data

### Concurrency
- Use `sync.Mutex` for shared state
- Use `sync.RW_Mutex` for read-heavy state (event handlers)
- Use `thread.Pool` for background work (commands, events, heartbeats)
- Use `proc(task: thread.Task)` for pool task callbacks
- All events and interactions dispatch to the worker pool via `thread.pool_add_task`
- Lock/unlock with `sync.lock` / `sync.unlock` and `defer` for safety
- Use `sync.cond_wait_with_timeout` for blocking on empty queues
- Use `sync.shared_lock` / `sync.shared_unlock` for read locks

### Control Flow
- `if ... do return` for single-statement early returns
- `switch` with `.EnumValue` syntax
- `#partial switch` for partial variant matching (reflection)
- `or_else` for Maybe defaults
- `defer` for resource cleanup
- `for _, val in collection` for iteration
- `for i in 0 ..< count` for range loops
- Append byte slices with `append(&frame_buffer, ..read_buffer[:n])`

### Formatting Output
- `fmt.tprintf` for `string` output
- `fmt.ctprintf` for `cstring` output (curl interop)
- `fmt.printfln` / `fmt.eprintfln` for formatted output

### JSON Handling
- `json.marshal(val, allocator = alloc)` for serialization
- `json.unmarshal(bytes, &val, json.DEFAULT_SPECIFICATION, allocator = alloc)` for deserialization
- Always check `err != nil` on marshal/unmarshal
- For Discord event data: marshal the `d` value back to bytes, then unmarshal into typed struct
- Define a `Gateway_Payload` struct with typed `op`, `s`, `t`, `d: json.Value` fields for gateway message parsing

### File Organization
- One file per logical concern
- Order: constants, simple types, structs, enums, functions
- Blank lines between sections
- Package declaration on first line

### Comments
Only for non-obvious intent. Struct field comments explaining Discord API mappings are acceptable.

## References
- [Discord Developer Reference](https://docs.discord.com/developers/reference) — API docs for all objects and endpoints
