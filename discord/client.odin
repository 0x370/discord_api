package discord

import "base:runtime"
import "core:container/lru"
import "core:container/queue"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:sync"
import "core:thread"
import "core:time"
import "vendor:curl"

import "api"

Gateway_Intent :: enum u8 {
	GUILDS                        = 0,
	GUILD_MEMBERS                 = 1,
	GUILD_MODERATION              = 2,
	GUILD_EXPRESSIONS             = 3,
	GUILD_INTEGRATIONS            = 4,
	GUILD_WEBHOOKS                = 5,
	GUILD_INVITES                 = 6,
	GUILD_VOICE_STATES            = 7,
	GUILD_PRESENCES               = 8,
	GUILD_MESSAGES                = 9,
	GUILD_MESSAGE_REACTIONS       = 10,
	GUILD_MESSAGE_TYPING          = 11,
	DIRECT_MESSAGES               = 12,
	DIRECT_MESSAGE_REACTIONS      = 13,
	DIRECT_MESSAGE_TYPING         = 14,
	MESSAGE_CONTENT               = 15,
	GUILD_SCHEDULED_EVENTS        = 16,
	AUTO_MODERATION_CONFIGURATION = 20,
	AUTO_MODERATION_EXECUTION     = 21,
	GUILD_MESSAGE_POLLS           = 24,
	DIRECT_MESSAGE_POLLS          = 25,
}
Gateway_Intents_Set :: bit_set[Gateway_Intent;i64]

Opcodes :: enum int {
	OP_DISPATCH        = 0,
	OP_HEARTBEAT       = 1,
	OP_IDENTIFY        = 2,
	OP_RESUME          = 6,
	OP_RECONNECT       = 7,
	OP_INVALID_SESSION = 9,
	OP_HELLO           = 10,
	OP_HEARTBEAT_ACK   = 11,
}

MAX_CACHED_MESSAGES :: 10000
Event_Callback :: #type proc(data: rawptr)
Event_Listener :: struct {
	callback: Event_Callback,
}

Command_Handler :: #type proc(ctx: ^Command_Context)
Component_Handler :: #type proc(ctx: ^Component_Context)

Command_Registration :: struct {
	command: api.ApplicationCommand,
	handler: Command_Handler,
}

Component_Registration :: struct {
	custom_id: string,
	handler:   Component_Handler,
}

Command_Context :: struct {
	client:      ^Client,
	interaction: api.Interaction,
	data:        api.ApplicationCommandInteractionData,
	received_at: time.Time,
	started_at:  time.Time,
	parsed_at:   time.Time,
}

Component_Context :: struct {
	client:      ^Client,
	interaction: api.Interaction,
	data:        api.MessageComponentInteractionData,
	received_at: time.Time,
	started_at:  time.Time,
}

Client :: struct {
	curl_handle:          ^curl.CURL,
	worker_pool:          thread.Pool,
	outbound_mutex:       sync.Mutex,
	outbound_queue:       queue.Queue([]byte),
	outbound_cond:        sync.Cond,
	is_running:           bool,
	is_reconnecting:      bool,
	last_sequence:        Maybe(int),
	sequence_mutex:       sync.Mutex,
	received_ack:         bool,
	ack_mutex:            sync.Mutex,
	token:                string,
	session_id:           string,
	resume_url:           string,
	heartbeat_interval:   int,
	allocator:            runtime.Allocator,
	_init_done:           bool,
	shard_id:             int,
	num_shards:           int,
	cache_mutex:          sync.Mutex,
	event_mutex:          sync.RW_Mutex,
	message_cache:        lru.Cache(api.Snowflake, ^api.Message),
	event_handlers:       map[string][dynamic]Event_Listener,
	rest_client:          api.Discord_Client,
	application_id:       api.Snowflake,
	command_registry:     map[string]Command_Registration,
	component_registry:   map[string]Component_Registration,
	known_guilds:         map[api.Snowflake]int,
	identify_log:         [dynamic]time.Time,
	identify_mutex:       sync.Mutex,
	max_concurrency:      int,
	heartbeat_gen:        u64,
	total_members:        int,
	total_events:         u64,
	total_messages:       u64,
	total_commands:       u64,
	last_event_type:      string,
	heartbeat_send_time:  time.Time,
	heartbeat_send_mutex: sync.Mutex,
	latency_history:      [dynamic]time.Duration,
	start_time:           time.Time,
	prev_proc_ticks:      u64,
	prev_sys_ticks:       u64,
	last_display_update:  time.Time,
}

Config :: struct {
	token:      string,
	shard_id:   int,
	num_shards: int,
}

client_init :: proc(client: ^Client, config: Config) -> bool {
	client.allocator = context.allocator
	client.token = strings.clone(config.token, client.allocator)
	client.shard_id = config.shard_id
	client.num_shards = config.num_shards

	lru.init(&client.message_cache, MAX_CACHED_MESSAGES, context.allocator)
	client.message_cache.on_remove = proc(
		key: api.Snowflake,
		value: ^api.Message,
		user_data: rawptr,
	) {
		alloc := (^runtime.Allocator)(user_data)
		deep_free(value^, alloc^)
		free(value, alloc^)
	}
	client.message_cache.on_remove_user_data = &client.allocator
	client.event_handlers = make(map[string][dynamic]Event_Listener, allocator = client.allocator)
	client.command_registry = make(map[string]Command_Registration, allocator = client.allocator)
	client.component_registry = make(map[string]Component_Registration, allocator = client.allocator)
	client.known_guilds = make(map[api.Snowflake]int, allocator = client.allocator)
	client.identify_log = make([dynamic]time.Time, allocator = client.allocator)
	client.latency_history = make([dynamic]time.Duration, allocator = context.allocator)
	queue.init(&client.outbound_queue, allocator = context.allocator)

	utime, stime := _read_process_cpu_ticks()
	client.prev_proc_ticks = utime + stime
	client.prev_sys_ticks = _read_system_cpu_ticks()
	client.start_time = time.now()

	thread_count := max(2, os.processor_core_count())
	thread.pool_init(&client.worker_pool, context.allocator, thread_count = thread_count)
	thread.pool_start(&client.worker_pool)

	if !connect_gateway(client) {
		return false
	}

	if api.discord_client_init(&client.rest_client, config.token) {
		bot_info, fetch_ok := api.discord_request(
			api.Gateway_Bot_Response,
			&client.rest_client,
			"/gateway/bot",
		)
		if fetch_ok {
			client.max_concurrency = bot_info.session_start_limit.max_concurrency
			if client.num_shards == 0 {
				client.num_shards = bot_info.shards
			}
			fmt.printfln(
				"Gateway bot info: %d shards, %d max concurrency",
				bot_info.shards,
				bot_info.session_start_limit.max_concurrency,
			)
			delete(bot_info.url)
		} else {
			fmt.eprintln("Failed to fetch /gateway/bot, defaulting max_concurrency to 1")
			client.max_concurrency = 1
		}
	} else {
		fmt.eprintln("Failed to init REST client, defaulting max_concurrency to 1")
		client.max_concurrency = 1
	}

	client._init_done = true
	return true
}

client_destroy :: proc(client: ^Client) {
	if !client._init_done {
		if client.curl_handle != nil do curl.easy_cleanup(client.curl_handle)
		api.discord_client_destroy(&client.rest_client)
		return
	}

	client.is_running = false
	sync.cond_broadcast(&client.outbound_cond)
	thread.pool_join(&client.worker_pool)
	thread.pool_destroy(&client.worker_pool)

	sync.lock(&client.outbound_mutex)
	for queue.len(client.outbound_queue) > 0 {
		frame := queue.pop_front(&client.outbound_queue)
		delete(frame)
	}
	queue.destroy(&client.outbound_queue)
	sync.unlock(&client.outbound_mutex)

	if client.session_id != "" do delete(client.session_id)
	if client.resume_url != "" do delete(client.resume_url)
	if client.application_id != "" do delete(client.application_id)

	delete(client.command_registry)
	delete(client.component_registry)
	delete(client.known_guilds)

	sync.lock(&client.cache_mutex)
	lru.destroy(&client.message_cache, true)
	sync.unlock(&client.cache_mutex)

	for _, handlers in client.event_handlers {
		delete(handlers)
	}
	delete(client.event_handlers)

	if client.curl_handle != nil do curl.easy_cleanup(client.curl_handle)
	api.discord_client_destroy(&client.rest_client)
	delete(client.identify_log)
	delete(client.latency_history)
	delete(client.token)

	client._init_done = false
	fmt.println("Client destroyed")
}

client_run :: proc(client: ^Client) {
	backoff := time.Second
	max_backoff := 60 * time.Second

	for {
		run_network_pump(client)

		if !client.is_reconnecting {
			break
		}

		client.is_reconnecting = false
		fmt.printfln("Disconnected. Reconnecting in %v...", backoff)
		time.sleep(backoff)

		sync.lock(&client.outbound_mutex)
		for queue.len(client.outbound_queue) > 0 {
			delete(queue.pop_front(&client.outbound_queue))
		}
		sync.unlock(&client.outbound_mutex)

		if connect_gateway(client) {
			backoff = time.Second
		} else {
			fmt.eprintln("Gateway reconnection failed, will retry")
			if backoff < max_backoff {
				backoff *= 2
			}
		}
	}
}
