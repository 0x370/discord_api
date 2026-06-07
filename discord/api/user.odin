package discord_api

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

	// metadata key -> stringified value
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
