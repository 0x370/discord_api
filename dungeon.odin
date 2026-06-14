package main

import "core:encoding/json"
import "core:fmt"
import "core:math/rand"
import "core:strings"
import "core:sync"

import api "discord/api"
import discord "discord"

DungeonSession :: struct {
	user_id:           api.Snowflake,
	goblin_hp:         int,
	goblin_max_hp:     int,
	player_hp:         int,
	player_max_hp:     int,
	turn:              int,
	interaction_token: string,
	player_name:       string,
	log:               [dynamic]string,
	channel_id:        api.Snowflake,
	message_id:        api.Snowflake,
}

@(private)
dungeon_sessions: map[string]^DungeonSession
@(private)
message_owners:  map[string]string
@(private)
dungeon_mutex: sync.Mutex

_dungeon_init :: proc() {
	if dungeon_sessions == nil {
		dungeon_sessions = make(map[string]^DungeonSession)
		message_owners  = make(map[string]string)
	}
}

register_dungeon_commands :: proc(client: ^discord.Client) {
	_dungeon_init()

	discord.on_command(client, "dungeon", "Fight a goblin in a turn-based battle!", proc(ctx: ^discord.Command_Context) {
		user_id := ctx.interaction.member.user.id
		if user_id == "" do user_id = ctx.interaction.user.id

		player_name := ctx.interaction.member.nick
		if player_name == "" do player_name = ctx.interaction.member.user.username
		if player_name == "" do player_name = ctx.interaction.user.username

		session := new(DungeonSession)
		session^ = DungeonSession{
			user_id       = user_id,
			player_name   = strings.clone(player_name),
			channel_id    = strings.clone(ctx.interaction.channel_id),
			goblin_hp     = 30,
			goblin_max_hp = 30,
			player_hp     = 50,
			player_max_hp = 50,
			turn          = 1,
		}

		discord.defer_response(ctx, false)
		session.interaction_token = strings.clone(ctx.interaction.token)

		embed, components := _build_dungeon_view(session)
		mid := _dungeon_patch_original(ctx.client, ctx.interaction.token, {embed}, components)
		if mid != "" {
			session.message_id = mid
		}

		sync.lock(&dungeon_mutex)
		if old, has := dungeon_sessions[user_id]; has {
			delete_key(&dungeon_sessions, user_id)
			_dungeon_cleanup(old)
		}
		dungeon_sessions[strings.clone(user_id)] = session
		if session.message_id != "" {
			message_owners[strings.clone(session.message_id)] = strings.clone(user_id)
		}
		sync.unlock(&dungeon_mutex)
	})

	discord.on_component(client, "dungeon_attack", proc(ctx: ^discord.Component_Context) {
		_handle_dungeon_action(ctx, "attack")
	})
	discord.on_component(client, "dungeon_run", proc(ctx: ^discord.Component_Context) {
		_handle_dungeon_action(ctx, "run")
	})
}

@(private)
_handle_dungeon_action :: proc(ctx: ^discord.Component_Context, action: string) {
	user_id := ctx.interaction.member.user.id
	if user_id == "" do user_id = ctx.interaction.user.id

	sync.lock(&dungeon_mutex)

	if owner_id, has_owner := message_owners[ctx.interaction.message.id]; has_owner && owner_id != user_id {
		sync.unlock(&dungeon_mutex)
		discord.defer_component_update(ctx)
		return
	}

	session, has := dungeon_sessions[user_id]
	if !has {
		sync.unlock(&dungeon_mutex)
		_dungeon_send_expired(ctx)
		return
	}

	switch action {
	case "attack":
		dmg := 3 + int(rand.int31_max(6))
		session.goblin_hp -= dmg
		if session.goblin_hp < 0 do session.goblin_hp = 0
		_dungeon_log(session, "**T%d** — %s attacked for %d", session.turn, session.player_name, dmg)

		if session.goblin_hp <= 0 {
			delete_key(&dungeon_sessions, user_id)
			embed, _ := _build_dungeon_view(session)
			sync.unlock(&dungeon_mutex)
			discord.respond_component(ctx, {embed}, {})
			_dungeon_cleanup(session)
			return
		}

		goblin_dmg := 2 + int(rand.int31_max(5))
		session.player_hp -= goblin_dmg
		if session.player_hp < 0 do session.player_hp = 0
		_dungeon_log(session, "**T%d** — Goblin attacked for %d", session.turn, goblin_dmg)

		if session.player_hp <= 0 {
			delete_key(&dungeon_sessions, user_id)
			embed, _ := _build_dungeon_view(session)
			sync.unlock(&dungeon_mutex)
			discord.respond_component(ctx, {embed}, {})
			_dungeon_cleanup(session)
			return
		}

		session.turn += 1
		embed, components := _build_dungeon_view(session)
		sync.unlock(&dungeon_mutex)
		discord.respond_component(ctx, {embed}, components)

	case "run":
		delete_key(&dungeon_sessions, user_id)
		sync.unlock(&dungeon_mutex)
		embed := api.Embed{
			title       = "⚔️ Dungeon Battle!",
			description = fmt.tprintf("**Fled!** You ran away from the goblin on turn %d.\nUse `/dungeon` to start a new battle.", session.turn),
			color       = 0x95a5a6,
		}
		discord.respond_component(ctx, {embed}, {})
		_dungeon_cleanup(session)
	}
}

@(private)
_dungeon_send_expired :: proc(ctx: ^discord.Component_Context) {
	embed := api.Embed{
		title       = "Dungeon Battle!",
		description = "This dungeon has expired. Run `/dungeon` to start a new battle.",
		color       = 0x95a5a6,
	}
	discord.respond_component(ctx, {embed}, {})
}

@(private)
_dungeon_log :: proc(session: ^DungeonSession, fmt_str: string, args: ..any) {
	entry := fmt.tprintf(fmt_str, ..args)
	append(&session.log, strings.clone(entry))
}

@(private)
_dungeon_cleanup :: proc(session: ^DungeonSession) {
	for entry in session.log do delete(entry)
	delete(session.log)
	if session.interaction_token != "" do delete(session.interaction_token)
	if session.player_name != "" do delete(session.player_name)
	if session.channel_id != "" do delete(session.channel_id)
	if session.message_id != "" {
		delete_key(&message_owners, session.message_id)
		delete(session.message_id)
	}
	free(session)
}

@(private)
_dungeon_hp_bar :: proc(current, max: int) -> string {
	filled := current * 10 / max
	if filled < 0 do filled = 0
	if filled > 10 do filled = 10
	empty := 10 - filled
	return fmt.tprintf("%s%s %d/%d", strings.repeat("█", filled), strings.repeat("░", empty), current, max)
}

@(private)
_build_dungeon_view :: proc(session: ^DungeonSession) -> (api.Embed, []api.Component) {
	title := "⚔️ Dungeon Battle!"
	desc: string
	color: int
	battle_over := false

	if session.player_hp <= 0 {
		desc = fmt.tprintf("**Defeat!** You were slain by the goblin on turn %d.\nUse `/dungeon` to try again.", session.turn)
		color = 0xe74c3c
		battle_over = true
	} else if session.goblin_hp <= 0 {
		desc = fmt.tprintf("**Victory!** You defeated the goblin in %d turns!\nUse `/dungeon` for another battle.", session.turn)
		color = 0x2ecc71
		battle_over = true
	} else {
		desc = fmt.tprintf("**Turn %d** — Fight the goblin!", session.turn)
		color = 0xe67e22
	}

	log_text: string
	if len(session.log) > 0 {
		start := len(session.log) - min(5, len(session.log))
		count := len(session.log) - start
		log_parts := make([]string, count)
		for i in 0 ..< count {
			log_parts[i] = session.log[start + i]
		}
		log_text = strings.join(log_parts[:], "\n")
		delete(log_parts)
	}

	num_fields := log_text != "" ? 3 : 2
	fields := make([]api.EmbedField, num_fields, context.temp_allocator)
	fields[0] = api.EmbedField{name = "Goblin", value = _dungeon_hp_bar(session.goblin_hp, session.goblin_max_hp), _inline = false}
	fields[1] = api.EmbedField{name = session.player_name, value = _dungeon_hp_bar(session.player_hp, session.player_max_hp), _inline = false}
	if log_text != "" {
		fields[2] = api.EmbedField{name = "Combat Log", value = log_text, _inline = false}
	}

	embed := api.Embed{
		title       = title,
		color       = color,
		description = desc,
		fields      = fields,
	}

	if battle_over {
		return embed, {}
	}

	btns := make([]api.Component, 2, context.temp_allocator)
	btns[0] = api.ButtonComponent{type = .BUTTON, style = .PRIMARY, custom_id = "dungeon_attack", label = "Attack"}
	btns[1] = api.ButtonComponent{type = .BUTTON, style = .DANGER,  custom_id = "dungeon_run",    label = "Run"}

	rows := make([]api.Component, 1, context.temp_allocator)
	rows[0] = api.ActionRowComponent{type = .ACTION_ROW, components = btns}

	return embed, rows
}

@(private)
_dungeon_patch_original :: proc(client: ^discord.Client, token: string, embeds: []api.Embed, components: []api.Component) -> string {
	data := api.InteractionCallbackData{
		embeds     = embeds,
		components = components,
	}
	body, err := json.marshal(data, allocator = context.temp_allocator)
	if err != nil {
		return ""
	}
	endpoint := fmt.tprintf("/webhooks/%s/%s/messages/@original", client.application_id, token)
	resp, ok := api.discord_patch(&client.rest_client, endpoint, body)
	if ok {
		defer delete(resp.body)
		msg: api.Message
		if json.unmarshal(resp.body, &msg) == nil && msg.id != "" {
			return strings.clone(msg.id)
		}
	}
	return ""
}
