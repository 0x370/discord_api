package discord

import "core:encoding/json"
import "core:fmt"

import "api"

bulk_overwrite_commands :: proc(client: ^Client) -> bool {
	return _bulk_overwrite(client, "/applications/%s/commands", client.application_id)
}

bulk_overwrite_guild_commands :: proc(client: ^Client, guild_id: api.Snowflake) -> bool {
	return _bulk_overwrite(
		client,
		"/applications/%s/guilds/%s/commands",
		client.application_id,
		guild_id,
	)
}

_bulk_overwrite :: proc(client: ^Client, endpoint_fmt: string, args: ..any) -> bool {
	if client.application_id == "" {
		fmt.eprintln("Cannot bulk overwrite commands: no application_id")
		return false
	}

	commands := make([dynamic]api.ApplicationCommand, context.temp_allocator)
	for _, reg in client.command_registry {
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
		fmt.eprintfln(
			"Failed to bulk overwrite commands: HTTP %d: %s",
			resp.status_code,
			string(resp.body),
		)
		return false
	}
	fmt.eprintln("Failed to bulk overwrite commands: network error")
	return false
}

delete_global_command :: proc(client: ^Client, command_id: api.Snowflake) -> bool {
	return _delete_command(
		client,
		"/applications/%s/commands/%s",
		client.application_id,
		command_id,
	)
}

delete_guild_command :: proc(
	client: ^Client,
	guild_id: api.Snowflake,
	command_id: api.Snowflake,
) -> bool {
	return _delete_command(
		client,
		"/applications/%s/guilds/%s/commands/%s",
		client.application_id,
		guild_id,
		command_id,
	)
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

edit_original_response :: proc(
	client: ^Client,
	interaction_token: string,
	content: string,
) -> bool {
	data := api.InteractionCallbackData {
		content = content,
	}
	return _patch_webhook(client, interaction_token, "/messages/@original", data)
}

delete_original_response :: proc(client: ^Client, interaction_token: string) -> bool {
	endpoint := fmt.tprintf(
		"/webhooks/%s/%s/messages/@original",
		client.application_id,
		interaction_token,
	)
	resp, ok := api.discord_delete(&client.rest_client, endpoint)
	if ok do delete(resp.body)
	return ok
}

create_followup :: proc(client: ^Client, interaction_token: string, content: string) -> bool {
	data := api.InteractionCallbackData {
		content = content,
	}
	return _post_webhook(client, interaction_token, data)
}

_patch_webhook :: proc(
	client: ^Client,
	interaction_token: string,
	suffix: string,
	data: api.InteractionCallbackData,
) -> bool {
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

_post_webhook :: proc(
	client: ^Client,
	interaction_token: string,
	data: api.InteractionCallbackData,
) -> bool {
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
