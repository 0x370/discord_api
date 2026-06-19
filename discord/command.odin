package discord

import "core:encoding/json"
import "core:fmt"
import "core:strings"

import "api"

on_command :: proc(
	client: ^Client,
	name: string,
	description: string,
	handler: Command_Handler,
	options: ..api.ApplicationCommandOption,
) {
	cloned_options := deep_clone(options, client.allocator)
	reg := Command_Registration {
		command = api.ApplicationCommand {
			name = name,
			description = description,
			type = .CHAT_INPUT,
			options = cloned_options,
		},
		handler = handler,
	}
	client.command_registry[name] = reg
}

on_subcommand :: proc(
	client: ^Client,
	root_name: string,
	root_desc: string,
	sub_name: string,
	sub_desc: string,
	handler: Command_Handler,
	options: ..api.ApplicationCommandOption,
) {
	sub_opt := api.ApplicationCommandOption{
		type        = .SUB_COMMAND,
		name        = sub_name,
		description = sub_desc,
		options     = deep_clone(options, client.allocator),
	}

	if existing, has := client.command_registry[root_name]; has {
		if existing.command.options == nil || len(existing.command.options) == 0 {
			existing.command.options = []api.ApplicationCommandOption{sub_opt}
		} else {
			cloned := deep_clone(existing.command.options, client.allocator)
			dyn := make([dynamic]api.ApplicationCommandOption, client.allocator)
			for o in cloned do append(&dyn, o)
			append(&dyn, sub_opt)
			existing.command.options = dyn[:]
		}
		client.command_registry[root_name] = existing
	} else {
		reg := Command_Registration {
			command = api.ApplicationCommand{
				name = root_name,
				description = root_desc,
				type = .CHAT_INPUT,
				options = []api.ApplicationCommandOption{sub_opt},
			},
		}
		client.command_registry[root_name] = reg
	}
	client.command_registry[fmt.tprintf("%s.%s", root_name, sub_name)] = Command_Registration{
		handler = handler,
	}
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
		if reg.command.name == "" do continue
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

bulk_overwrite_commands :: proc(client: ^Client) -> bool {
	return _bulk_overwrite(client, "/applications/%s/commands", client.application_id)
}

bulk_overwrite_guild_commands :: proc(client: ^Client, guild_id: api.Snowflake) -> bool {
	return _bulk_overwrite(client, "/applications/%s/guilds/%s/commands", client.application_id, guild_id)
}

_bulk_overwrite :: proc(client: ^Client, endpoint_fmt: string, args: ..any) -> bool {
	if client.application_id == "" {
		fmt.eprintln("Cannot bulk overwrite commands: no application_id")
		return false
	}

	commands := make([dynamic]api.ApplicationCommand, context.temp_allocator)
	for _, reg in client.command_registry {
		if reg.command.name == "" do continue
		append(&commands, reg.command)
	}

	body, err := json.marshal(commands[:], allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal commands for bulk overwrite: %v", err)
		return false
	}

	endpoint := fmt.tprintf(endpoint_fmt, ..args)
	resp, ok := api.discord_put(&client.rest_client, endpoint, body)
	if ok {
		defer delete(resp.body)
		if resp.status_code >= 200 && resp.status_code < 300 {
			fmt.printfln("Bulk overwrote %d commands (status %d)", len(commands), resp.status_code)
			return true
		}
		fmt.eprintfln("Failed to bulk overwrite commands: HTTP %d: %s", resp.status_code, string(resp.body))
		return false
	}
	fmt.eprintln("Failed to bulk overwrite commands: network error")
	return false
}

delete_global_command :: proc(client: ^Client, command_id: api.Snowflake) -> bool {
	return _delete_command(client, "/applications/%s/commands/%s", client.application_id, command_id)
}

delete_guild_command :: proc(client: ^Client, guild_id: api.Snowflake, command_id: api.Snowflake) -> bool {
	return _delete_command(client, "/applications/%s/guilds/%s/commands/%s", client.application_id, guild_id, command_id)
}

_delete_command :: proc(client: ^Client, endpoint_fmt: string, args: ..any) -> bool {
	if client.application_id == "" {
		fmt.eprintln("Cannot delete command: no application_id")
		return false
	}
	endpoint := fmt.tprintf(endpoint_fmt, ..args)
	resp, ok := api.discord_delete(&client.rest_client, endpoint)
	if ok {
		defer delete(resp.body)
		if resp.status_code >= 200 && resp.status_code < 300 {
			fmt.printfln("Deleted command (status %d)", resp.status_code)
			return true
		}
		fmt.eprintfln("Failed to delete command: HTTP %d: %s", resp.status_code, string(resp.body))
		return false
	}
	fmt.eprintln("Failed to delete command: network error")
	return false
}

get_global_commands :: proc(client: ^Client) -> ([]api.ApplicationCommand, bool) {
	if client.application_id == "" {
		fmt.eprintln("Cannot get commands: no application_id")
		return nil, false
	}
	endpoint := fmt.tprintf("/applications/%s/commands", client.application_id)
	return api.discord_request([]api.ApplicationCommand, &client.rest_client, endpoint)
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
	opts := ctx.data.options
	if len(opts) > 0 && int(opts[0].type) == 1 {
		for sub_opt in opts[0].options {
			if sub_opt.name == name {
				if v, ok := sub_opt.value.(T); ok { return v }
			}
		}
		return T{}
	}
	for opt in opts {
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

respond_with_components :: proc(ctx: ^Command_Context, content: string, embeds: []api.Embed, components: []api.Component) -> bool {
	response := api.InteractionResponse {
		type = .CHANNEL_MESSAGE_WITH_SOURCE,
		data = api.InteractionCallbackData{content = content, embeds = embeds, components = components},
	}

	_, ok := _post_interaction_callback(ctx, response)
	return ok
}

respond_with_embed_and_files :: proc(
	ctx: ^Command_Context,
	content: string,
	embeds: []api.Embed,
	components: []api.Component,
	files: []api.MultipartFile,
) -> bool {
	data := api.InteractionCallbackData{
		content = content,
		embeds = embeds,
		components = components,
	}
	if len(files) > 0 {
		attachments := make([]api.Attachment, len(files), context.temp_allocator)
		for f, i in files {
			attachments[i] = api.Attachment{
				id = api.Snowflake(fmt.tprintf("%d", i)),
				filename = f.filename,
			}
		}
		data.attachments = attachments
	}
	response := api.InteractionResponse{
		type = .CHANNEL_MESSAGE_WITH_SOURCE,
		data = data,
	}
	payload, err := json.marshal(response, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal interaction response with files: %v", err)
		return false
	}
	endpoint := fmt.tprintf("/interactions/%s/%s/callback", ctx.interaction.id, ctx.interaction.token)
	resp, ok := api.discord_post_multipart(&ctx.client.rest_client, endpoint, payload, files)
	if ok {
		if resp.status_code < 200 || resp.status_code >= 300 {
			fmt.eprintfln("respond_with_embed_and_files got HTTP %d: %s", resp.status_code, string(resp.body))
		}
		delete(resp.body)
		return resp.status_code >= 200 && resp.status_code < 300
	}
	return false
}

edit_original_response_with_files :: proc(
	client: ^Client,
	interaction_token: string,
	embeds: []api.Embed,
	components: []api.Component,
	files: []api.MultipartFile,
) -> (message_id: string, ok: bool) {
	data := api.InteractionCallbackData{
		embeds = embeds,
		components = components,
	}
	if len(files) > 0 {
		attachments := make([]api.Attachment, len(files), context.temp_allocator)
		for f, i in files {
			attachments[i] = api.Attachment{
				id = api.Snowflake(fmt.tprintf("%d", i)),
				filename = f.filename,
			}
		}
		data.attachments = attachments
	}
	payload, err := json.marshal(data, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal edit payload: %v", err)
		return "", false
	}
	endpoint := fmt.tprintf("/webhooks/%s/%s/messages/@original", client.application_id, interaction_token)
	resp, rok := api.discord_patch_multipart(&client.rest_client, endpoint, payload, files)
	if !rok {
		fmt.eprintfln("edit_original_response_with_files PATCH failed")
		return "", false
	}
	defer delete(resp.body)
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("edit_original_response_with_files PATCH status=%d body: %s", resp.status_code, string(resp.body))
		return "", false
	}
	msg: api.Message
	if json.unmarshal(resp.body, &msg, allocator = context.temp_allocator) == nil && msg.id != "" {
		return strings.clone(msg.id), true
	}
	return "", true
}

create_followup_with_files :: proc(
	client: ^Client,
	interaction_token: string,
	embeds: []api.Embed,
	files: []api.MultipartFile,
) -> bool {
	data := api.InteractionCallbackData{embeds = embeds}
	if len(files) > 0 {
		attachments := make([]api.Attachment, len(files), context.temp_allocator)
		for f, i in files {
			attachments[i] = api.Attachment{
				id = api.Snowflake(fmt.tprintf("%d", i)),
				filename = f.filename,
			}
		}
		data.attachments = attachments
	}
	payload, err := json.marshal(data, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal followup payload: %v", err)
		return false
	}
	endpoint := fmt.tprintf("/webhooks/%s/%s", client.application_id, interaction_token)
	resp, ok := api.discord_post_multipart(&client.rest_client, endpoint, payload, files)
	if !ok { fmt.eprintfln("create_followup_with_files POST failed"); return false }
	defer delete(resp.body)
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("create_followup_with_files got HTTP %d: %s", resp.status_code, string(resp.body))
		return false
	}
	return true
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

respond_component :: proc(ctx: ^Component_Context, embeds: []api.Embed, components: []api.Component) -> bool {
	response := api.InteractionResponse {
		type = .UPDATE_MESSAGE,
		data = api.InteractionCallbackData{embeds = embeds, components = components},
	}
	body, err := json.marshal(response, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal respond_component: %v", err)
		return false
	}
	endpoint := fmt.tprintf("/interactions/%s/%s/callback", ctx.interaction.id, ctx.interaction.token)
	resp, ok := api.discord_post(&ctx.client.rest_client, endpoint, body)
	if !ok { return false }
	defer delete(resp.body)
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("[respond_component] HTTP %d: %s", resp.status_code, string(resp.body))
		return false
	}
	return true
}

defer_component_update :: proc(ctx: ^Component_Context) -> bool {
	response := api.InteractionResponse {
		type = .DEFERRED_UPDATE_MESSAGE,
	}
	body, err := json.marshal(response, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal defer_component_update: %v", err)
		return false
	}
	endpoint := fmt.tprintf("/interactions/%s/%s/callback", ctx.interaction.id, ctx.interaction.token)
	resp, ok := api.discord_post(&ctx.client.rest_client, endpoint, body)
	if ok do delete(resp.body)
	return ok
}

edit_original_response :: proc(client: ^Client, interaction_token: string, content: string) -> bool {
	data := api.InteractionCallbackData{content = content}
	return _patch_webhook(client, interaction_token, "/messages/@original", data)
}

delete_original_response :: proc(client: ^Client, interaction_token: string) -> bool {
	endpoint := fmt.tprintf("/webhooks/%s/%s/messages/@original", client.application_id, interaction_token)
	resp, ok := api.discord_delete(&client.rest_client, endpoint)
	if ok do delete(resp.body)
	return ok
}

create_followup :: proc(client: ^Client, interaction_token: string, content: string) -> bool {
	data := api.InteractionCallbackData{content = content}
	return _post_webhook(client, interaction_token, data)
}

_patch_webhook :: proc(client: ^Client, interaction_token: string, suffix: string, data: api.InteractionCallbackData) -> bool {
	body, err := json.marshal(data, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal webhook payload: %v", err)
		return false
	}
	endpoint := fmt.tprintf("/webhooks/%s/%s%s", client.application_id, interaction_token, suffix)
	resp, ok := api.discord_patch(&client.rest_client, endpoint, body)
	if ok do delete(resp.body)
	return ok
}

_post_webhook :: proc(client: ^Client, interaction_token: string, data: api.InteractionCallbackData) -> bool {
	body, err := json.marshal(data, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal webhook payload: %v", err)
		return false
	}
	endpoint := fmt.tprintf("/webhooks/%s/%s", client.application_id, interaction_token)
	resp, ok := api.discord_post(&client.rest_client, endpoint, body)
	if !ok do return false
	defer delete(resp.body)
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("Webhook post got HTTP %d: %s", resp.status_code, string(resp.body))
		return false
	}
	return true
}
