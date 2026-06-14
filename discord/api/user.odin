package discord_api

import "core:encoding/json"
import "core:fmt"

User :: struct {
	id:                     Snowflake,
	username:               string,
	discriminator:          string,
	global_name:            string,
	avatar:                 string,
	bot:                    bool,
	system:                 bool,
	mfa_enabled:            bool,
	banner:                 string,
	accent_color:           int,
	locale:                 string,
	verified:               bool,
	email:                  string,
	flags:                  UserFlags,
	premium_type:           PremiumType,
	public_flags:           UserFlags,
	avatar_decoration_data: AvatarDecorationData,
	collectibles:           Collectibles,
	primary_guild:          UserPrimaryGuild,
}

AvatarDecorationData :: struct {
	asset:  string,
	sku_id: Snowflake,
}

Collectibles :: struct {
	nameplate: Nameplate,
}

Nameplate :: struct {
	sku_id:  Snowflake,
	asset:   string,
	label:   string,
	palette: string,
}

UserPrimaryGuild :: struct {
	identity_guild_id: Snowflake,
	identity_enabled:  bool,
	tag:               string,
	badge:             string,
}

Connection :: struct {
	id:            string,
	name:          string,
	type:          string,
	revoked:       bool,
	integrations:  []PartialIntegration,
	verified:      bool,
	friend_sync:   bool,
	show_activity: bool,
	two_way_link:  bool,
	visibility:    ConnectionVisibility,
}

PartialIntegration :: struct {
	id:   Snowflake,
	name: string,
	type: string,
}

ApplicationRoleConnection :: struct {
	platform_name: string,
	metadata:      map[string]string,
}

PremiumType :: enum i32 {
	NONE          = 0,
	NITRO_CLASSIC = 1,
	NITRO         = 2,
	NITRO_BASIC   = 3,
}

ConnectionVisibility :: enum i32 {
	NONE     = 0,
	EVERYONE = 1,
}

UserFlags :: distinct u64

USER_FLAG_STAFF :: UserFlags(1 << 0)
USER_FLAG_PARTNER :: UserFlags(1 << 1)
USER_FLAG_HYPESQUAD :: UserFlags(1 << 2)
USER_FLAG_BUG_HUNTER_LEVEL_1 :: UserFlags(1 << 3)
USER_FLAG_HOUSE_BRAVERY :: UserFlags(1 << 6)
USER_FLAG_HOUSE_BRILLIANCE :: UserFlags(1 << 7)
USER_FLAG_HOUSE_BALANCE :: UserFlags(1 << 8)
USER_FLAG_PREMIUM_EARLY_SUPPORTER :: UserFlags(1 << 9)
USER_FLAG_TEAM_PSEUDO_USER :: UserFlags(1 << 10)
USER_FLAG_BUG_HUNTER_LEVEL_2 :: UserFlags(1 << 14)
USER_FLAG_VERIFIED_BOT :: UserFlags(1 << 16)
USER_FLAG_VERIFIED_DEVELOPER :: UserFlags(1 << 17)
USER_FLAG_CERTIFIED_MODERATOR :: UserFlags(1 << 18)
USER_FLAG_BOT_HTTP_INTERACTIONS :: UserFlags(1 << 19)

// --- Request/Response Types ---

ModifyCurrentUserParams :: struct {
	username: Maybe(string) `json:"username,omitempty"`,
	avatar:   Maybe(string) `json:"avatar,omitempty"`,
	banner:   Maybe(string) `json:"banner,omitempty"`,
}

UserGuild :: struct {
	id:                        Snowflake `json:"id"`,
	name:                      string    `json:"name"`,
	icon:                      string    `json:"icon"`,
	banner:                    string    `json:"banner,omitempty"`,
	owner:                     bool      `json:"owner"`,
	permissions:               string    `json:"permissions"`,
	features:                  []string  `json:"features"`,
	approximate_member_count:  int       `json:"approximate_member_count,omitempty"`,
	approximate_presence_count: int      `json:"approximate_presence_count,omitempty"`,
}

GetCurrentUserGuildsParams :: struct {
	before:      Maybe(Snowflake),
	after:       Maybe(Snowflake),
	limit:       Maybe(int),
	with_counts: Maybe(bool),
}

CreateDMRequest :: struct {
	recipient_id: Snowflake `json:"recipient_id"`,
}

CreateGroupDMRequest :: struct {
	access_tokens: []string            `json:"access_tokens"`,
	nicks:         map[string]string   `json:"nicks"`,
}

UpdateRoleConnectionParams :: struct {
	platform_name:     Maybe(string)         `json:"platform_name,omitempty"`,
	platform_username:  Maybe(string)         `json:"platform_username,omitempty"`,
	metadata:          Maybe(map[string]string) `json:"metadata,omitempty"`,
}

// --- User REST API Procedures ---

get_current_user :: proc(client: ^Discord_Client) -> (User, bool) {
	return discord_request(User, client, "/users/@me")
}

get_user :: proc(client: ^Discord_Client, user_id: Snowflake) -> (User, bool) {
	endpoint := fmt.tprintf("/users/%s", user_id)
	return discord_request(User, client, endpoint)
}

modify_current_user :: proc(
	client: ^Discord_Client,
	params: ModifyCurrentUserParams,
) -> (
	User,
	bool,
) {
	body, err := json.marshal(params, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal modify_current_user: %v", err)
		return {}, false
	}
	endpoint := "/users/@me"
	resp, ok := discord_patch(client, endpoint, body)
	if !ok do return {}, false
	defer delete(resp.body)
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("modify_current_user got HTTP %d: %s", resp.status_code, string(resp.body))
		return {}, false
	}
	result: User
	if err := json.unmarshal(resp.body, &result); err != nil {
		fmt.eprintfln("modify_current_user unmarshal failed: %v", err)
		return {}, false
	}
	return result, true
}

get_current_user_guilds :: proc(
	client: ^Discord_Client,
	params: ^GetCurrentUserGuildsParams = nil,
) -> (
	[]UserGuild,
	bool,
) {
	endpoint := "/users/@me/guilds"
	endpoint = _append_query_params(endpoint, params)
	return discord_request([]UserGuild, client, endpoint)
}

get_current_user_guild_member :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
) -> (
	GuildMember,
	bool,
) {
	endpoint := fmt.tprintf("/users/@me/guilds/%s/member", guild_id)
	return discord_request(GuildMember, client, endpoint)
}

leave_guild :: proc(client: ^Discord_Client, guild_id: Snowflake) -> bool {
	endpoint := fmt.tprintf("/users/@me/guilds/%s", guild_id)
	resp, ok := discord_delete(client, endpoint)
	if ok do delete(resp.body)
	return ok
}

create_dm :: proc(
	client: ^Discord_Client,
	recipient_id: Snowflake,
) -> (
	Channel,
	bool,
) {
	req := CreateDMRequest{recipient_id = recipient_id}
	body, err := json.marshal(req, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal create_dm: %v", err)
		return {}, false
	}
	resp, ok := discord_post(client, "/users/@me/channels", body)
	if !ok do return {}, false
	defer delete(resp.body)
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("create_dm got HTTP %d: %s", resp.status_code, string(resp.body))
		return {}, false
	}
	result: Channel
	if err := json.unmarshal(resp.body, &result); err != nil {
		fmt.eprintfln("create_dm unmarshal failed: %v", err)
		return {}, false
	}
	return result, true
}

create_group_dm :: proc(
	client: ^Discord_Client,
	params: CreateGroupDMRequest,
) -> (
	Channel,
	bool,
) {
	body, err := json.marshal(params, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal create_group_dm: %v", err)
		return {}, false
	}
	resp, ok := discord_post(client, "/users/@me/channels", body)
	if !ok do return {}, false
	defer delete(resp.body)
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("create_group_dm got HTTP %d: %s", resp.status_code, string(resp.body))
		return {}, false
	}
	result: Channel
	if err := json.unmarshal(resp.body, &result); err != nil {
		fmt.eprintfln("create_group_dm unmarshal failed: %v", err)
		return {}, false
	}
	return result, true
}

get_current_user_connections :: proc(
	client: ^Discord_Client,
) -> (
	[]Connection,
	bool,
) {
	return discord_request([]Connection, client, "/users/@me/connections")
}

get_application_role_connection :: proc(
	client: ^Discord_Client,
	application_id: Snowflake,
) -> (
	ApplicationRoleConnection,
	bool,
) {
	endpoint := fmt.tprintf("/users/@me/applications/%s/role-connection", application_id)
	return discord_request(ApplicationRoleConnection, client, endpoint)
}

update_application_role_connection :: proc(
	client: ^Discord_Client,
	application_id: Snowflake,
	params: UpdateRoleConnectionParams,
) -> (
	ApplicationRoleConnection,
	bool,
) {
	body, err := json.marshal(params, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal update_role_connection: %v", err)
		return {}, false
	}
	endpoint := fmt.tprintf("/users/@me/applications/%s/role-connection", application_id)
	resp, ok := discord_put(client, endpoint, body)
	if !ok do return {}, false
	defer delete(resp.body)
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("update_role_connection got HTTP %d: %s", resp.status_code, string(resp.body))
		return {}, false
	}
	result: ApplicationRoleConnection
	if err := json.unmarshal(resp.body, &result); err != nil {
		fmt.eprintfln("update_role_connection unmarshal failed: %v", err)
		return {}, false
	}
	return result, true
}

delete_application_role_connection :: proc(
	client: ^Discord_Client,
	application_id: Snowflake,
) -> bool {
	endpoint := fmt.tprintf("/users/@me/applications/%s/role-connection", application_id)
	resp, ok := discord_delete(client, endpoint)
	if ok do delete(resp.body)
	return ok
}
