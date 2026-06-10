package discord_api

ApplicationCommandType :: enum i32 {
	CHAT_INPUT = 1,
	USER       = 2,
	MESSAGE    = 3,
}

ApplicationCommandOptionType :: enum i32 {
	SUB_COMMAND       = 1,
	SUB_COMMAND_GROUP = 2,
	STRING            = 3,
	INTEGER           = 4,
	BOOLEAN           = 5,
	USER              = 6,
	CHANNEL           = 7,
	ROLE              = 8,
	MENTIONABLE       = 9,
	NUMBER            = 10,
	ATTACHMENT        = 11,
}

ApplicationCommandOptionChoice :: struct {
	name:  string,
	value: ApplicationCommandInteractionDataOptionValue,
}

ApplicationCommandOption :: struct {
	type:                    ApplicationCommandOptionType `json:"type"`,
	name:                    string `json:"name"`,
	description:             string `json:"description"`,
	required:                Maybe(bool) `json:"required,omitempty"`,
	choices:                 []ApplicationCommandOptionChoice `json:"choices,omitempty"`,
	options:                 []ApplicationCommandOption `json:"options,omitempty"`,
	channel_types:           []ChannelType `json:"channel_types,omitempty"`,
	min_value:               Maybe(f64) `json:"min_value,omitempty"`,
	max_value:               Maybe(f64) `json:"max_value,omitempty"`,
	min_length:              Maybe(int) `json:"min_length,omitempty"`,
	max_length:              Maybe(int) `json:"max_length,omitempty"`,
	autocomplete:            Maybe(bool) `json:"autocomplete,omitempty"`,
}

ApplicationCommand :: struct {
	id:                       Snowflake `json:"id,omitempty"`,
	type:                     Maybe(ApplicationCommandType) `json:"type,omitempty"`,
	application_id:           Snowflake `json:"application_id,omitempty"`,
	guild_id:                 Maybe(Snowflake) `json:"guild_id,omitempty"`,
	name:                     string `json:"name"`,
	description:              string `json:"description"`,
	options:                  []ApplicationCommandOption `json:"options,omitempty"`,
	default_member_permissions: Maybe(string) `json:"default_member_permissions,omitempty"`,
	dm_permission:            Maybe(bool) `json:"dm_permission,omitempty"`,
	nsfw:                     Maybe(bool) `json:"nsfw,omitempty"`,
	integration_types:        []ApplicationIntegrationType `json:"integration_types,omitempty"`,
	contexts:                 Maybe([]InteractionContextType) `json:"contexts,omitempty"`,
	version:                  Snowflake `json:"version,omitempty"`,
}
