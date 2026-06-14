package main

import "core:os"
import "core:fmt"
import "core:strings"
import "core:time"
import curl "vendor:curl"
import "core:flags"

import api "discord/api"
import discord "discord"

Options :: struct {
	token:    string `args:"name=token,required" usage:"Your discord bot token"`,
	shard_id: int    `args:"name=shard-id" usage:"The shard ID of this instance"`,
	shards:   int    `args:"name=shards" usage:"The total number of shards"` ,
}

main :: proc() {
	opt: Options
	flags.parse_or_exit(&opt, os.args, .Unix)

	if curl.global_init(curl.GLOBAL_ALL) != .E_OK {
		fmt.eprintln("Failed to initialize libcurl globally")
		return
	}
	defer curl.global_cleanup()

	client: discord.Client
	if !discord.client_init(&client, {
		token      = opt.token,
		shard_id   = opt.shard_id,
		num_shards = opt.shards,
	}) {
		fmt.eprintln("Failed to initialize Discord client")
		return
	}
	defer discord.client_destroy(&client)

	discord.on_command(&client, "echo_guild", "Echo back your message", proc(ctx: ^discord.Command_Context) {
		msg := discord.get_string(ctx, "message")
		discord.respond(ctx, msg)
	},
		{type = .STRING, name = "message", description = "The message to echo back", required = true},
	)

	discord.on_command(&client, "ping", "Check bot latency", proc(ctx: ^discord.Command_Context) {
		_, net_ns := discord.defer_response(ctx, false)
		defer_end := time.now()

		queue_ns := time.diff(ctx.received_at, ctx.started_at)
		parse_ns := time.diff(ctx.started_at, ctx.parsed_at)
		total_ns := time.diff(ctx.received_at, defer_end)
		other_ns := total_ns - queue_ns - parse_ns - time.Duration(net_ns)

		reply := fmt.tprintf("Pong! `queue=%.2fms | parse=%.2fms | net=%.2fms | other=%.2fms | total=%.2fms`",
			f64(queue_ns) / f64(time.Millisecond),
			f64(parse_ns) / f64(time.Millisecond),
			f64(net_ns) / f64(time.Millisecond),
			f64(other_ns) / f64(time.Millisecond),
			f64(total_ns) / f64(time.Millisecond))

		discord.edit_original_response(ctx.client, ctx.interaction.token, reply)
	})

	discord.on_command(&client, "guild_test", "Test guild REST API getters", proc(ctx: ^discord.Command_Context) {
		guild_id := discord.get_string(ctx, "guild_id")
		discord.defer_response(ctx, false)
		rest := &ctx.client.rest_client

		buf: strings.Builder
		strings.builder_init(&buf, context.temp_allocator)
		strings.write_string(&buf, fmt.tprintf("guild_test for %s:\n", guild_id))

		_gtest(&buf, "get_guild", rest, guild_id, proc(r: ^api.Discord_Client, id: api.Snowflake) -> string {
			g, ok := api.get_guild(r, id)
			if !ok do return ""
			n := g.name; if len(n) > 20 do n = n[:20]
			return fmt.tprintf("name=%q m=%d", n, g.approximate_member_count)
		})
		_gtest(&buf, "get_guild_preview", rest, guild_id, proc(r: ^api.Discord_Client, id: api.Snowflake) -> string {
			g, ok := api.get_guild_preview(r, id)
			if !ok do return ""
			d := g.description; if len(d) > 30 do d = d[:30]
			return fmt.tprintf("desc=%q", d)
		})
		_gtest(&buf, "get_guild_channels", rest, guild_id, proc(r: ^api.Discord_Client, id: api.Snowflake) -> string {
			ch, ok := api.get_guild_channels(r, id)
			if !ok do return ""
			return fmt.tprintf("%d channels", len(ch))
		})
		_gtest(&buf, "list_active_threads", rest, guild_id, proc(r: ^api.Discord_Client, id: api.Snowflake) -> string {
			t, ok := api.list_active_guild_threads(r, id)
			if !ok do return ""
			return fmt.tprintf("%d threads", len(t.threads))
		})
		_gtest(&buf, "get_member", rest, guild_id, proc(r: ^api.Discord_Client, id: api.Snowflake) -> string {
			m, ok := api.get_current_user_guild_member(r, id)
			if !ok do return ""
			nick := m.nick; if nick == "" do nick = m.user.username
			join := m.joined_at; if len(join) > 10 do join = join[:10]
			return fmt.tprintf("nick=%q joined=%s", nick, join)
		})
		_gtest(&buf, "search_members", rest, guild_id, proc(r: ^api.Discord_Client, id: api.Snowflake) -> string {
			m, ok := api.search_guild_members(r, id, {query = "a", limit = 1})
			if !ok do return ""
			return fmt.tprintf("%d members", len(m))
		})
		_gtest(&buf, "get_guild_roles", rest, guild_id, proc(r: ^api.Discord_Client, id: api.Snowflake) -> string {
			r, ok := api.get_guild_roles(r, id)
			if !ok do return ""
			return fmt.tprintf("%d roles", len(r))
		})
		_gtest(&buf, "get_guild_bans", rest, guild_id, proc(r: ^api.Discord_Client, id: api.Snowflake) -> string {
			b, ok := api.get_guild_bans(r, id)
			if !ok do return ""
			return fmt.tprintf("%d bans", len(b))
		})
		_gtest(&buf, "get_prune_count", rest, guild_id, proc(r: ^api.Discord_Client, id: api.Snowflake) -> string {
			p, ok := api.get_guild_prune_count(r, id)
			if !ok do return ""
			return fmt.tprintf("%d prunable", p.pruned)
		})
		_gtest(&buf, "get_guild_invites", rest, guild_id, proc(r: ^api.Discord_Client, id: api.Snowflake) -> string {
			inv, ok := api.get_guild_invites(r, id)
			if !ok do return ""
			return fmt.tprintf("%d invites", len(inv))
		})
		_gtest(&buf, "get_integrations", rest, guild_id, proc(r: ^api.Discord_Client, id: api.Snowflake) -> string {
			integ, ok := api.get_guild_integrations(r, id)
			if !ok do return ""
			return fmt.tprintf("%d integrations", len(integ))
		})
		_gtest(&buf, "get_widget_settings", rest, guild_id, proc(r: ^api.Discord_Client, id: api.Snowflake) -> string {
			w, ok := api.get_guild_widget_settings(r, id)
			if !ok do return ""
			return fmt.tprintf("enabled=%v", w.enabled)
		})
		_gtest(&buf, "get_vanity_url", rest, guild_id, proc(r: ^api.Discord_Client, id: api.Snowflake) -> string {
			v, ok := api.get_guild_vanity_url(r, id)
			if !ok do return ""
			return fmt.tprintf("code=%s uses=%d", v.code, v.uses)
		})
		_gtest(&buf, "get_welcome_screen", rest, guild_id, proc(r: ^api.Discord_Client, id: api.Snowflake) -> string {
			w, ok := api.get_guild_welcome_screen(r, id)
			if !ok do return ""
			d := w.description; if len(d) > 20 do d = d[:20]
			return fmt.tprintf("desc=%q", d)
		})
		_gtest(&buf, "get_onboarding", rest, guild_id, proc(r: ^api.Discord_Client, id: api.Snowflake) -> string {
			o, ok := api.get_guild_onboarding(r, id)
			if !ok do return ""
			return fmt.tprintf("enabled=%v %d prompts", o.enabled, len(o.prompts))
		})

		reply := strings.to_string(buf)
		if len(reply) > 1900 do reply = reply[:1900]
		discord.edit_original_response(ctx.client, ctx.interaction.token, fmt.tprintf("```\n%s\n```", reply))
	},
		{type = .STRING, name = "guild_id", description = "The guild ID to test against", required = true},
	)

	discord.on_command(&client, "message_test", "Test message REST API getters", proc(ctx: ^discord.Command_Context) {
		channel_id := discord.get_string(ctx, "channel_id")
		message_id := discord.get_string(ctx, "message_id")
		discord.defer_response(ctx, false)
		rest := &ctx.client.rest_client

		buf: strings.Builder
		strings.builder_init(&buf, context.temp_allocator)
		strings.write_string(&buf, fmt.tprintf("message_test for %s:\n", channel_id))

		_mtest(&buf, "get_channel_messages", rest, channel_id, proc(r: ^api.Discord_Client, id: api.Snowflake) -> string {
			msgs, ok := api.get_channel_messages(r, id, nil)
			if !ok do return ""
			return fmt.tprintf("%d messages", len(msgs))
		})

		if message_id != "" {
			_mtest_msg(&buf, "get_channel_message", rest, channel_id, message_id, proc(r: ^api.Discord_Client, id: api.Snowflake, mid: api.Snowflake) -> string {
				msg, ok := api.get_channel_message(r, id, mid)
				if !ok do return ""
				c := msg.content; if len(c) > 20 do c = c[:20]
				return fmt.tprintf("author=%s content=%q", msg.author.id, c)
			})
		} else {
			strings.write_string(&buf, "[    ] get_channel_message          skipped (no message_id)\n")
		}

		_mtest(&buf, "get_channel_pins", rest, channel_id, proc(r: ^api.Discord_Client, id: api.Snowflake) -> string {
			pins, ok := api.get_channel_pins(r, id)
			if !ok do return ""
			return fmt.tprintf("%d pins", len(pins.items))
		})

		reply := strings.to_string(buf)
		if len(reply) > 1900 do reply = reply[:1900]
		discord.edit_original_response(ctx.client, ctx.interaction.token, fmt.tprintf("```\n%s\n```", reply))
	},
		{type = .STRING, name = "channel_id", description = "The channel ID to test against", required = true},
		{type = .STRING, name = "message_id", description = "A specific message ID (optional)", required = false},
	)

	discord.on_command(&client, "user_test", "Test user REST API getters", proc(ctx: ^discord.Command_Context) {
		user_id := discord.get_string(ctx, "user_id")
		guild_id := discord.get_string(ctx, "guild_id")
		discord.defer_response(ctx, false)
		rest := &ctx.client.rest_client

		buf: strings.Builder
		strings.builder_init(&buf, context.temp_allocator)
		strings.write_string(&buf, "user_test:\n")

		_utest(&buf, "get_current_user", rest, proc(r: ^api.Discord_Client) -> string {
			u, ok := api.get_current_user(r)
			if !ok do return ""
			return fmt.tprintf("username=%q id=%s", u.username, u.id)
		})

		if user_id != "" {
			_utest_uid(&buf, "get_user", rest, user_id, proc(r: ^api.Discord_Client, uid: api.Snowflake) -> string {
				u, ok := api.get_user(r, uid)
				if !ok do return ""
				return fmt.tprintf("username=%q global_name=%q", u.username, u.global_name)
			})
		} else {
			strings.write_string(&buf, "[    ] get_user                    skipped (no user_id)\n")
		}

		_utest(&buf, "get_current_user_guilds", rest, proc(r: ^api.Discord_Client) -> string {
			g, ok := api.get_current_user_guilds(r)
			if !ok do return ""
			return fmt.tprintf("%d guilds", len(g))
		})

		if guild_id != "" {
			_utest_gid(&buf, "get_guild_member", rest, guild_id, proc(r: ^api.Discord_Client, gid: api.Snowflake) -> string {
				m, ok := api.get_current_user_guild_member(r, gid)
				if !ok do return ""
				nick := m.nick; if nick == "" do nick = m.user.username
				return fmt.tprintf("nick=%q joined=%s", nick, m.joined_at[:10])
			})
		} else {
			strings.write_string(&buf, "[    ] get_guild_member           skipped (no guild_id)\n")
		}

		reply := strings.to_string(buf)
		if len(reply) > 1900 do reply = reply[:1900]
		discord.edit_original_response(ctx.client, ctx.interaction.token, fmt.tprintf("```\n%s\n```", reply))
	},
		{type = .STRING, name = "user_id", description = "A user ID to test get_user (optional)", required = false},
		{type = .STRING, name = "guild_id", description = "A guild ID to test get_current_user_guild_member (optional)", required = false},
	)

	register_dungeon_commands(&client)

	discord.client_run(&client)
}

_gtest :: proc(buf: ^strings.Builder, name: string, rest: ^api.Discord_Client, guild_id: api.Snowflake, test: proc(^api.Discord_Client, api.Snowflake) -> string) {
	detail := test(rest, guild_id)
	ok := detail != ""
	status := ok ? "OK " : "FAIL"
	strings.write_string(buf, fmt.tprintf("[%s] %-28s %s\n", status, name, ok ? detail : "---"))
}

_mtest :: proc(buf: ^strings.Builder, name: string, rest: ^api.Discord_Client, channel_id: api.Snowflake, test: proc(^api.Discord_Client, api.Snowflake) -> string) {
	detail := test(rest, channel_id)
	ok := detail != ""
	status := ok ? "OK " : "FAIL"
	strings.write_string(buf, fmt.tprintf("[%s] %-28s %s\n", status, name, ok ? detail : "---"))
}

_mtest_msg :: proc(buf: ^strings.Builder, name: string, rest: ^api.Discord_Client, channel_id: api.Snowflake, message_id: api.Snowflake, test: proc(^api.Discord_Client, api.Snowflake, api.Snowflake) -> string) {
	detail := test(rest, channel_id, message_id)
	ok := detail != ""
	status := ok ? "OK " : "FAIL"
	strings.write_string(buf, fmt.tprintf("[%s] %-28s %s\n", status, name, ok ? detail : "---"))
}

_utest :: proc(buf: ^strings.Builder, name: string, rest: ^api.Discord_Client, test: proc(^api.Discord_Client) -> string) {
	detail := test(rest)
	ok := detail != ""
	status := ok ? "OK " : "FAIL"
	strings.write_string(buf, fmt.tprintf("[%s] %-28s %s\n", status, name, ok ? detail : "---"))
}

_utest_uid :: proc(buf: ^strings.Builder, name: string, rest: ^api.Discord_Client, user_id: api.Snowflake, test: proc(^api.Discord_Client, api.Snowflake) -> string) {
	detail := test(rest, user_id)
	ok := detail != ""
	status := ok ? "OK " : "FAIL"
	strings.write_string(buf, fmt.tprintf("[%s] %-28s %s\n", status, name, ok ? detail : "---"))
}

_utest_gid :: proc(buf: ^strings.Builder, name: string, rest: ^api.Discord_Client, guild_id: api.Snowflake, test: proc(^api.Discord_Client, api.Snowflake) -> string) {
	detail := test(rest, guild_id)
	ok := detail != ""
	status := ok ? "OK " : "FAIL"
	strings.write_string(buf, fmt.tprintf("[%s] %-28s %s\n", status, name, ok ? detail : "---"))
}