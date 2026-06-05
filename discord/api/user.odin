package discord_api

import "core:encoding/json"
import "core:fmt"

// Sub-structures embedded in or referenced by the User object
Avatar_Decoration_Data :: struct {
	asset:  string `json:"asset"`,
	sku_id: Snowflake `json:"sku_id"`,
}

Nameplate :: struct {
	sku_id:  Snowflake `json:"sku_id"`,
	asset:   string `json:"asset"`,
	label:   string `json:"label"`,
	palette: string `json:"palette"`,
}

Collectibles :: struct {
	nameplate: ^Nameplate `json:"nameplate"`,
}

User_Primary_Guild :: struct {
	identity_guild_id: ^Snowflake `json:"identity_guild_id"`,
	identity_enabled:  bool `json:"identity_enabled"`,
	tag:               string `json:"tag"`,
	badge:             string `json:"badge"`,
}

Premium_Type :: enum int {
	NONE          = 0,
	NITRO_CLASSIC = 1,
	NITRO         = 2,
	NITRO_BASIC   = 3,
}

User_Flag :: enum u8 {
	STAFF                    = 0,
	PARTNER                  = 1,
	HYPESQUAD                = 2,
	BUG_HUNTER_LEVEL_1       = 3,
	HYPESQUAD_ONLINE_HOUSE_1 = 6,
	HYPESQUAD_ONLINE_HOUSE_2 = 7,
	HYPESQUAD_ONLINE_HOUSE_3 = 8,
	PREMIUM_EARLY_SUPPORTER  = 9,
	TEAM_PSEUDO_USER         = 10,
	BUG_HUNTER_LEVEL_2       = 14,
	VERIFIED_BOT             = 16,
	VERIFIED_DEVELOPER       = 17,
	CERTIFIED_MODERATOR      = 18,
	BOT_HTTP_INTERACTIONS    = 19,
}
User_Flags_Set :: bit_set[User_Flag;i32]

User :: struct {
	id:                     Snowflake `json:"id"`,
	username:               string `json:"username"`,
	discriminator:          string `json:"discriminator"`,
	global_name:            string `json:"global_name"`,
	avatar:                 string `json:"avatar"`,
	bot:                    bool `json:"bot"`,
	system:                 bool `json:"system"`,
	mfa_enabled:            bool `json:"mfa_enabled"`,
	banner:                 string `json:"banner"`,
	accent_color:           int `json:"accent_color"`,
	locale:                 string `json:"locale"`,
	verified:               bool `json:"verified"`,
	email:                  string `json:"email"`,
	flags:                  User_Flags_Set `json:"flags"`,
	premium_type:           Premium_Type `json:"premium_type"`,
	public_flags:           User_Flags_Set `json:"public_flags"`,
	avatar_decoration_data: Avatar_Decoration_Data `json:"avatar_decoration_data"`,
	collectibles:           Collectibles `json:"collectibles"`,
	primary_guild:          User_Primary_Guild `json:"primary_guild"`,
}

Guild_Member_Flag :: enum u8 {
	DID_REJOIN                           = 0,
	COMPLETED_ONBOARDING                 = 1,
	BYPASSES_VERIFICATION                = 2,
	STARTED_ONBOARDING                   = 3,
	IS_GUEST                             = 4,
	STARTED_HOME_ACTIONS                 = 5,
	COMPLETED_HOME_ACTIONS               = 6,
	AUTOMOD_QUARANTINED_USERNAME_OR_NICK = 7,
}
Guild_Member_Flags :: bit_set[Guild_Member_Flag;i32]

Guild_Member :: struct {
	user:                         Maybe(User) `json:"user"`,
	nick:                         string `json:"nick"`,
	avatar:                       string `json:"avatar"`,
	banner:                       string `json:"banner"`,
	roles:                        [dynamic]Snowflake `json:"roles"`,
	joined_at:                    string `json:"joined_at"`,
	premium_since:                string `json:"premium_since"`,
	deaf:                         bool `json:"deaf"`,
	mute:                         bool `json:"mute"`,
	flags:                        Guild_Member_Flags `json:"flags"`,
	pending:                      Maybe(bool) `json:"pending"`,
	permissions:                  string `json:"permissions"`,
	communication_disabled_until: string `json:"communication_disabled_until"`,
	avatar_decoration_data:       Avatar_Decoration_Data `json:"avatar_decoration_data"`,
	collectibles:                 Collectibles `json:"collectibles"`,
}


get_bot :: proc(client: ^Discord_Client) -> (user: User, ok: bool) {
	return discord_fetch(User, client, "/users/@me")
}

get_user :: proc(client: ^Discord_Client, user_id: string) -> (user: User, ok: bool) {
	url := fmt.tprintf("/users/%s", user_id)
	return discord_fetch(User, client, url)
}

get_bot_guilds :: proc(client: ^Discord_Client) -> (guilds: [dynamic]Guild, ok: bool) {
	return discord_fetch([dynamic]Guild, client, "/users/@me/guilds")
}

get_bot_guild_member :: proc(client: ^Discord_Client, guild_id: string) -> (guild_member: Guild_Member, ok: bool) {
	url := fmt.tprintf("/users/@me/guilds/%s/member", guild_id)
	return discord_fetch(Guild_Member, client, url)
}
