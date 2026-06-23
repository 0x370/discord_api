A Discord bot framework and RPG bot written in [Odin](https://odin-lang.org/).

## Features

### Core Framework
- **Gateway client** — WebSocket pump with heartbeat, generation-gated reconnect, missed-ack detection, identify rate limiting
- **Event system** — deep-cloned payload dispatch via thread pool to user callbacks
- **Slash commands** — registration, guild/global bulk overwrite, option getters, defer/respond/edit/delete helpers
- **Component handlers** — buttons, select menus, modals with custom-id routing
- **REST API client** — rate-limited HTTP client covering 25+ API resources (messages, guilds, users, channels, interactions, embeds, webhooks, voice, etc.)
- **Dashboard** — CPU, memory, gateway latency ring buffer

### Built-in Commands

| Command | Description |
|---|---|
| `/ping` | Round-trip latency breakdown (queue, parse, network, total) |
| `/echo_guild` | Echo a message back |
| `/rank` | Check your XP and level |
| `/leaderboard` | Top 10 users by XP |

### Dungeon RPG

A gacha-style RPG with turn-based combat, character collection, and item gearing.

- **Character gacha** — roll for characters across 6 tiers with class types, weapon compatibility, and S-rank abilities
- **Item gacha** — collect equipment with affixes, special effects, and slot types
- **Turn-based combat** — hook-driven battle system with 25+ special effects (bleed, freeze, lifesteal, thorns, lightning pulse, etc.)
- **3 classes** — Attacker, Healer with distinct combat hooks
- **Floor progression** — infinite dungeon floors with scaling monsters; boss encounters every 5 floors
- **Daily rewards** — character and item lootboxes
- **Profile & gallery** — view your collection with paginated navigation
- **Sell system** — sell duplicate characters and items for gold

## Build

```bash
odin build . -vet -strict-style \
  -define:SQLITE3_DYNAMIC_LIB=true \
  -define:SQLITE3_SYSTEM_LIB=true
```

Add `-o:speed` for release, `-o:minimal` for fast dev builds.

**Dependencies:** [Odin compiler](https://odin-lang.org/docs/install/), libcurl, libsqlite3.

## Run

```bash
odin run . -- --token "$(cat token)" \
  -define:SQLITE3_DYNAMIC_LIB=true \
  -define:SQLITE3_SYSTEM_LIB=true
```

| Flag | Default | Description |
|---|---|---|
| `--token` | *(required)* | Discord bot token |
| `--shard-id` | `0` | Shard ID for this instance |
| `--shards` | `1` | Total shard count |
| `--db-path` | `bot.db` | SQLite database file path |
| `--verbose` | `false` | Enable debug logging |

## Architecture

```
curl (ws_recv) ──► network pump ──► thread.Pool ──► op dispatch
                       │                                │
                       ▼                                ▼
                 outbound queue               event handlers / commands
                 (mutex + cond)                   │
                                                  ▼
                                            user callbacks
                                            (thread.Pool)
```

- **Never blocks the WebSocket pump** — all work dispatches to a thread pool
- **Rate-limited REST** — cooperative bucket-state tracking, single curl easy handle behind a mutex
- **Deep-cloned events** — reflection-based clone before fan-out to listeners
- **SQLite persistence** — XP system and dungeon RPG share `bot.db`

## Packages

| Package | Import | Purpose |
|---|---|---|
| `discord` | `import discord "../discord"` | Client, gateway, events, commands, XP DB |
| `discord/api` | `import api "discord/api"` | Discord API types + REST client |
| `discord/sqlite3` | `import sqlite3 "sqlite3"` | Raw SQLite3 FFI bindings |
| `commands` | `import "commands"` | Built-in commands (ping, echo, rank, leaderboard) |
| `commands/dungeon` | `import dungeon "commands/dungeon"` | Dungeon RPG |

## Example: Adding a Slash Command

```odin
package mycommands

import discord "../discord"

register_hello :: proc(client: ^discord.Client) {
    discord.on_command(client, "hello", "Say hello", proc(ctx: ^discord.Command_Context) {
        name := discord.get_string(ctx, "name")
        discord.respond(ctx, fmt.tprintf("Hello, %s!", name))
    },
        {type = .STRING, name = "name", description = "Your name", required = true},
    )
}
```

## Example: Listening to Events

```odin
discord.on(client, "MESSAGE_CREATE", proc(data: rawptr) {
    msg := (^api.Message)(data)
    // handle message
})
```

## License

MIT
