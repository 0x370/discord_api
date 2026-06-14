package discord

import "core:container/lru"
import "core:encoding/json"
import "core:fmt"
import "core:strings"
import "core:sync"
import "core:thread"
import "core:time"

import "api"

Interaction_Task_Data :: struct {
	client:      ^Client,
	raw:         []byte,
	received_at: time.Time,
}

handle_message_create :: proc(client: ^Client, d_bytes: []byte) {
	client.total_messages += 1

	msg: api.Message
	if json.unmarshal(d_bytes, &msg) != nil {
		fmt.eprintln("Failed to parse MESSAGE_CREATE")
		return
	}
	defer deep_free(msg, context.allocator)

	persistent := new(api.Message, allocator = client.allocator)
	persistent^ = deep_clone(msg, client.allocator)

	sync.lock(&client.cache_mutex)
	lru.set(&client.message_cache, persistent.id, persistent)
	sync.unlock(&client.cache_mutex)

	dispatch_event(client, "MESSAGE_CREATE", msg)
}

handle_guild_create :: proc(client: ^Client, d_bytes: []byte) {
	guild: api.Guild
	if json.unmarshal(d_bytes, &guild) != nil {
		fmt.eprintln("Failed to parse GUILD_CREATE")
		return
	}
	defer deep_free(guild, context.allocator)

	if guild.id == "" {
		dispatch_event(client, "GUILD_CREATE", guild)
		return
	}

	sync.lock(&client.cache_mutex)
	defer sync.unlock(&client.cache_mutex)

	count := guild.member_count
	if count == 0 {
		count = guild.approximate_member_count
	}

	if _, already_known := client.known_guilds[guild.id]; !already_known {
		client.known_guilds[guild.id] = count
		client.total_members += count
		register_guild_commands(client, guild.id)
	} else {
		old_count := client.known_guilds[guild.id]
		client.total_members -= old_count
		client.known_guilds[guild.id] = count
		client.total_members += count
	}

	dispatch_event(client, "GUILD_CREATE", guild)
}

handle_guild_delete :: proc(client: ^Client, d_bytes: []byte) {
	guild: api.Guild
	if json.unmarshal(d_bytes, &guild) != nil {
		fmt.eprintln("Failed to parse GUILD_DELETE")
		return
	}
	defer deep_free(guild, context.allocator)

	if guild.id != "" {
		sync.lock(&client.cache_mutex)
		if count, known := client.known_guilds[guild.id]; known {
			client.total_members -= count
			delete_key(&client.known_guilds, guild.id)
		}
		sync.unlock(&client.cache_mutex)
	}

	dispatch_event(client, "GUILD_DELETE", guild)
}

handle_ready :: proc(client: ^Client, d_bytes: []byte) {
	ready: Ready_Event_Data
	if json.unmarshal(d_bytes, &ready) != nil {
		fmt.eprintln("Failed to parse READY")
		return
	}
	defer deep_free(ready, context.allocator)

	if client.session_id != "" do delete(client.session_id, client.allocator)
	if client.resume_url != "" do delete(client.resume_url, client.allocator)

	client.session_id    = strings.clone(ready.session_id, client.allocator)
	client.resume_url    = strings.clone(ready.resume_url, client.allocator)
	client.application_id = strings.clone(ready.application.id, client.allocator)

	sync.lock(&client.cache_mutex)
	clear(&client.known_guilds)
	client.total_members = 0
	sync.unlock(&client.cache_mutex)

	fmt.printfln("Bot is ready! Session: %s | App: %s", client.session_id, client.application_id)
}

handle_message_update :: proc(client: ^Client, d_bytes: []byte) {
	update: api.Message
	if json.unmarshal(d_bytes, &update) != nil {
		fmt.eprintln("Failed to parse MESSAGE_UPDATE")
		return
	}
	defer deep_free(update, context.allocator)

	sync.lock(&client.cache_mutex)
	cached, exists := lru.get(&client.message_cache, update.id)
	if !exists {
		sync.unlock(&client.cache_mutex)
		fmt.println("Message update received uncached message")
		return
	}

	before := deep_clone(cached^, context.temp_allocator)
	after  := deep_clone(cached^, client.allocator)

	after.content = strings.clone(update.content, client.allocator)
	after.edited_timestamp = strings.clone(update.edited_timestamp, client.allocator)
	after.embeds = deep_clone(update.embeds, client.allocator)
	after.attachments = deep_clone(update.attachments, client.allocator)
	after.pinned = update.pinned
	after.flags = update.flags
	after.mention_everyone = update.mention_everyone
	after.tts = update.tts

	dispatch_event(client, "MESSAGE_UPDATE", api.MessageUpdateArgs{before = before, after = after})

	deep_free(cached^, client.allocator)
	cached^ = after
	sync.unlock(&client.cache_mutex)
}

handle_message_delete :: proc(client: ^Client, d_bytes: []byte) {
	event: api.MessageDeleteEvent
	if json.unmarshal(d_bytes, &event) != nil {
		return
	}
	defer {
		if event.id != "" do delete(event.id)
		if event.channel_id != "" do delete(event.channel_id)
		if event.guild_id != "" do delete(event.guild_id)
	}

	sync.lock(&client.cache_mutex)
	lru.remove(&client.message_cache, event.id)
	sync.unlock(&client.cache_mutex)
}

handle_interaction_create :: proc(client: ^Client, d_bytes: []byte) {
	client.total_commands += 1

	task_data := new(Interaction_Task_Data, allocator = client.allocator)
	task_data.client = client
	task_data.raw = make([]byte, len(d_bytes), allocator = client.allocator)
	copy(task_data.raw, d_bytes)
	task_data.received_at = time.now()

	thread.pool_add_task(&client.worker_pool, context.allocator, interaction_worker, task_data)
}

@(private)
interaction_worker :: proc(task: thread.Task) {
	it := (^Interaction_Task_Data)(task.data)
	defer {
		delete(it.raw)
		free(it)
	}

	started_at := time.now()

	interaction: api.Interaction
	err := json.unmarshal(it.raw, &interaction)
	if err != nil {
		fmt.eprintfln("Worker failed to parse interaction: %v", err)
		return
	}

	cmd_data, ok := interaction.data.(api.ApplicationCommandInteractionData)
	if !ok {
		fmt.eprintln("Interaction worker: data type assertion failed")
		deep_free(interaction, context.allocator)
		return
	}

	parsed_at := time.now()

	reg, found := it.client.command_registry[cmd_data.name]
	if !found {
		fmt.printfln("Unknown command: %s", cmd_data.name)
		deep_free(interaction, context.allocator)
		return
	}

	ctx := new(Command_Context, allocator = it.client.allocator)
	ctx.client = it.client
	ctx.interaction = interaction
	ctx.data = cmd_data
	ctx.received_at = it.received_at
	ctx.started_at = started_at
	ctx.parsed_at = parsed_at

	reg.handler(ctx)

	deep_free(ctx.interaction, context.allocator)
	free(ctx)
}
