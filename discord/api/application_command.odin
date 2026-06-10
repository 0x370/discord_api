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
	type:                    ApplicationCommandOptionType,
	name:                    string,
	description:             string,
	required:                bool,
	choices:                 []ApplicationCommandOptionChoice,
	options:                 []ApplicationCommandOption,
	channel_types:           []ChannelType,
	min_value:               f64,
	max_value:               f64,
	min_length:              int,
	max_length:              int,
	autocomplete:            bool,
}

ApplicationCommand :: struct {
	id:                       Snowflake,
	type:                     ApplicationCommandType,
	application_id:           Snowflake,
	name:                     string,
	description:              string,
	options:                  []ApplicationCommandOption,
	default_member_permissions: string,
	dm_permission:            bool,
	nsfw:                     bool,
	integration_types:        []ApplicationIntegrationType,
	contexts:                 []InteractionContextType,
	version:                  Snowflake,
}
