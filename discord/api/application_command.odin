package discord_api

ApplicationCommandType :: enum i32 {
	CHAT_INPUT         = 1,
	USER               = 2,
	MESSAGE            = 3,
	PRIMARY_ENTRY_POINT = 4,
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
	name:              string  `json:"name"`,
	name_localizations: Maybe( map[string]string ) `json:"name_localizations,omitempty"`,
	value:             ApplicationCommandOptionChoiceValue `json:"value"`,
}

ApplicationCommandOptionChoiceValue :: union { string, i64, f64 }

ApplicationCommandOption :: struct {
	type:                     ApplicationCommandOptionType `json:"type"`,
	name:                     string `json:"name"`,
	name_localizations:       Maybe( map[string]string ) `json:"name_localizations,omitempty"`,
	description:              string `json:"description"`,
	description_localizations: Maybe( map[string]string ) `json:"description_localizations,omitempty"`,
	required:                 Maybe(bool) `json:"required,omitempty"`,
	choices:                  []ApplicationCommandOptionChoice `json:"choices,omitempty"`,
	options:                  []ApplicationCommandOption `json:"options,omitempty"`,
	channel_types:            []ChannelType `json:"channel_types,omitempty"`,
	min_value:                Maybe(f64) `json:"min_value,omitempty"`,
	max_value:                Maybe(f64) `json:"max_value,omitempty"`,
	min_length:               Maybe(int) `json:"min_length,omitempty"`,
	max_length:               Maybe(int) `json:"max_length,omitempty"`,
	autocomplete:             Maybe(bool) `json:"autocomplete,omitempty"`,
}

EntryPointCommandHandlerType :: enum i32 {
	APP_HANDLER              = 1,
	DISCORD_LAUNCH_ACTIVITY  = 2,
}

ApplicationCommand :: struct {
	id:                        Snowflake `json:"id,omitempty"`,
	type:                      Maybe(ApplicationCommandType) `json:"type,omitempty"`,
	application_id:            Snowflake `json:"application_id,omitempty"`,
	guild_id:                  Maybe(Snowflake) `json:"guild_id,omitempty"`,
	name:                      string `json:"name"`,
	name_localizations:        Maybe( map[string]string ) `json:"name_localizations,omitempty"`,
	description:               string `json:"description"`,
	description_localizations: Maybe( map[string]string ) `json:"description_localizations,omitempty"`,
	options:                   []ApplicationCommandOption `json:"options,omitempty"`,
	default_member_permissions: Maybe(string) `json:"default_member_permissions,omitempty"`,
	default_permission:        Maybe(bool) `json:"default_permission,omitempty"`,
	dm_permission:             Maybe(bool) `json:"dm_permission,omitempty"`,
	nsfw:                      Maybe(bool) `json:"nsfw,omitempty"`,
	integration_types:         []ApplicationIntegrationType `json:"integration_types,omitempty"`,
	contexts:                  Maybe([]InteractionContextType) `json:"contexts,omitempty"`,
	version:                   Snowflake `json:"version,omitempty"`,
	handler:                   Maybe(EntryPointCommandHandlerType) `json:"handler,omitempty"`,
}
