package discord

import "core:encoding/json"
import "core:fmt"

import "api"

on_command :: proc(
	client: ^Client,
	name: string,
	description: string,
	handler: Command_Handler,
	options: ..api.ApplicationCommandOption,
) {
	reg := Command_Registration {
		command = api.ApplicationCommand {
			name = name,
			description = description,
			type = .CHAT_INPUT,
			options = options,
		},
		handler = handler,
	}
	client.command_registry[name] = reg
}

register_commands :: proc(client: ^Client) {
	_register_on_endpoint(client, "/applications/%s/commands", "global", client.application_id)
}

register_guild_commands :: proc(client: ^Client, guild_id: api.Snowflake) {
	_register_on_endpoint(
		client,
		"/applications/%s/guilds/%s/commands",
		"guild",
		client.application_id,
		guild_id,
	)
}

_register_on_endpoint :: proc(client: ^Client, endpoint_fmt: string, scope: string, args: ..any) {
	if client.application_id == "" {
		fmt.eprintln("Cannot register commands: no application_id")
		return
	}

	for name, reg in client.command_registry {
		body, err := json.marshal(reg.command, allocator = context.temp_allocator)
		if err != nil {
			fmt.eprintfln("Failed to marshal command %q: %v", name, err)
			continue
		}

		endpoint := fmt.tprintf(endpoint_fmt, ..args)
		resp, ok := api.discord_post(&client.rest_client, endpoint, body)
		if ok {
			if resp.status_code >= 200 && resp.status_code < 300 {
				fmt.printfln(
					"Registered command /%s as %s (status %d)",
					name,
					scope,
					resp.status_code,
				)
			} else {
				fmt.eprintfln(
					"Failed to register command /%s: HTTP %d: %s",
					name,
					resp.status_code,
					string(resp.body),
				)
			}
			delete(resp.body)
		} else {
			fmt.eprintfln("Failed to register command /%s: network error", name)
		}
	}
}

get_string :: proc(ctx: ^Command_Context, name: string) -> string {return _get_option_value(
		ctx,
		name,
		string,
	)}
get_integer :: proc(ctx: ^Command_Context, name: string) -> i64 {return _get_option_value(
		ctx,
		name,
		i64,
	)}
get_number :: proc(ctx: ^Command_Context, name: string) -> f64 {return _get_option_value(
		ctx,
		name,
		f64,
	)}
get_bool :: proc(ctx: ^Command_Context, name: string) -> bool {return _get_option_value(
		ctx,
		name,
		bool,
	)}

_get_option_value :: proc(ctx: ^Command_Context, name: string, $T: typeid) -> T {
	for opt in ctx.data.options {
		if opt.name == name {
			if v, ok := opt.value.(T); ok {
				return v
			}
		}
	}
	return T{}
}

respond :: proc(ctx: ^Command_Context, message: string) -> bool {
	return respond_with_embed(ctx, message, {})
}

respond_with_embed :: proc(ctx: ^Command_Context, content: string, embeds: []api.Embed) -> bool {
	response := api.InteractionResponse {
		type = .CHANNEL_MESSAGE_WITH_SOURCE,
		data = api.InteractionCallbackData{content = content, embeds = embeds},
	}

	_, ok := _post_interaction_callback(ctx, response)
	return ok
}

defer_response :: proc(ctx: ^Command_Context, ephemeral: bool) -> (bool, i64) {
	data: api.InteractionCallbackData
	if ephemeral {
		data.flags = int(api.EPHEMERAL)
	}

	response := api.InteractionResponse {
		type = .DEFERRED_CHANNEL_MESSAGE_WITH_SOURCE,
		data = data,
	}

	resp, ok := _post_interaction_callback(ctx, response)
	if !ok do return false, 0
	net_ns := resp.perform_time_ns
	delete(resp.body)
	return true, net_ns
}

_post_interaction_callback :: proc(
	ctx: ^Command_Context,
	response: api.InteractionResponse,
) -> (
	api.Http_Response,
	bool,
) {
	body, err := json.marshal(response, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal interaction response: %v", err)
		return {}, false
	}
	endpoint := fmt.tprintf(
		"/interactions/%s/%s/callback",
		ctx.interaction.id,
		ctx.interaction.token,
	)
	return api.discord_post(&ctx.client.rest_client, endpoint, body)
}
