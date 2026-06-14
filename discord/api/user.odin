package discord_api

import "core:encoding/json"
import "core:fmt"

User :: struct {
	id:                     Snowflake         `json:"id,omitempty"`,
	username:               string            `json:"username,omitempty"`,
	discriminator:          string            `json:"discriminator,omitempty"`,
	global_name:            string            `json:"global_name,omitempty"`,
	avatar:                 string            `json:"avatar,omitempty"`,
	bot:                    bool              `json:"bot,omitempty"`,
	system:                 bool              `json:"system,omitempty"`,
	mfa_enabled:            bool              `json:"mfa_enabled,omitempty"`,
	banner:                 string            `json:"banner,omitempty"`,
	accent_color:           int               `json:"accent_color,omitempty"`,
	locale:                 string            `json:"locale,omitempty"`,
	verified:               bool              `json:"verified,omitempty"`,
	email:                  string            `json:"email,omitempty"`,
	flags:                  UserFlags         `json:"flags,omitempty"`,
	premium_type:           PremiumType       `json:"premium_type,omitempty"`,
	public_flags:           UserFlags         `json:"public_flags,omitempty"`,
	avatar_decoration_data: AvatarDecorationData `json:"avatar_decoration_data,omitempty"`,
	collectibles:           Collectibles      `json:"collectibles,omitempty"`,
	primary_guild:          UserPrimaryGuild  `json:"primary_guild,omitempty"`,
}

AvatarDecorationData :: struct {
	asset:  string    `json:"asset,omitempty"`,
	sku_id: Snowflake `json:"sku_id,omitempty"`,
}

Collectibles :: struct {
	nameplate: Nameplate `json:"nameplate,omitempty"`,
}

Nameplate :: struct {
	sku_id:  Snowflake `json:"sku_id,omitempty"`,
	asset:   string    `json:"asset,omitempty"`,
	label:   string    `json:"label,omitempty"`,
	palette: string    `json:"palette,omitempty"`,
}

UserPrimaryGuild :: struct {
	identity_guild_id: Snowflake `json:"identity_guild_id,omitempty"`,
	identity_enabled:  bool      `json:"identity_enabled,omitempty"`,
	tag:               string    `json:"tag,omitempty"`,
	badge:             string    `json:"badge,omitempty"`,
}

Connection :: struct {
	id:            string               `json:"id,omitempty"`,
	name:          string               `json:"name,omitempty"`,
	type:          string               `json:"type,omitempty"`,
	revoked:       bool                 `json:"revoked,omitempty"`,
	integrations:  []PartialIntegration `json:"integrations,omitempty"`,
	verified:      bool                 `json:"verified,omitempty"`,
	friend_sync:   bool                 `json:"friend_sync,omitempty"`,
	show_activity: bool                 `json:"show_activity,omitempty"`,
	two_way_link:  bool                 `json:"two_way_link,omitempty"`,
	visibility:    ConnectionVisibility `json:"visibility,omitempty"`,
}

PartialIntegration :: struct {
	id:   Snowflake `json:"id,omitempty"`,
	name: string    `json:"name,omitempty"`,
	type: string    `json:"type,omitempty"`,
}

ApplicationRoleConnection :: struct {
	platform_name: string            `json:"platform_name,omitempty"`,
	metadata:      map[string]string `json:"metadata,omitempty"`,
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
