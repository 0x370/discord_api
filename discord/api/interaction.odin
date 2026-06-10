package discord_api

InteractionType :: enum i32 {
	PING                               = 1,
	APPLICATION_COMMAND                = 2,
	MESSAGE_COMPONENT                  = 3,
	APPLICATION_COMMAND_AUTOCOMPLETE   = 4,
	MODAL_SUBMIT                       = 5,
}

InteractionContextType :: enum i32 {
	GUILD            = 0,
	BOT_DM           = 1,
	PRIVATE_CHANNEL  = 2,
}

InteractionCallbackType :: enum i32 {
	PONG                                = 1,
	CHANNEL_MESSAGE_WITH_SOURCE         = 4,
	DEFERRED_CHANNEL_MESSAGE_WITH_SOURCE = 5,
	DEFERRED_UPDATE_MESSAGE             = 6,
	UPDATE_MESSAGE                      = 7,
	APPLICATION_COMMAND_AUTOCOMPLETE_RESULT = 8,
	MODAL                               = 9,
	PREMIUM_REQUIRED                    = 10,
	LAUNCH_ACTIVITY                     = 12,
}

ApplicationCommandInteractionDataOptionValue :: union { string, i64, f64, bool }

ApplicationCommandInteractionDataOption :: struct {
	name:    string,
	type:    int,
	value:   ApplicationCommandInteractionDataOptionValue,
	options: []ApplicationCommandInteractionDataOption,
	focused: bool,
}

ApplicationCommandInteractionData :: struct {
	id:        Snowflake,
	name:      string,
	type:      int,
	resolved:  ResolvedData,
	options:   []ApplicationCommandInteractionDataOption,
	guild_id:  Snowflake,
	target_id: Snowflake,
}

MessageComponentInteractionData :: struct {
	custom_id:      string,
	component_type: int,
	values:         []string,
	resolved:       ResolvedData,
}

ModalSubmitInteractionData :: struct {
	custom_id:  string,
	components: []ComponentInteractionData,
	resolved:   ResolvedData,
}

ComponentInteractionData :: struct {
	custom_id:      string,
	component_type: int,
	value:          string,
	values:         []string,
	components:     []ComponentInteractionData,
	resolved:       ResolvedData,
}

Interaction :: struct {
	id:                           Snowflake,
	application_id:               Snowflake,
	type:                         InteractionType,
	data:                         InteractionData,
	guild:                        Guild,
	guild_id:                     Snowflake,
	channel:                      Channel,
	channel_id:                   Snowflake,
	member:                       GuildMember,
	user:                         User,
	token:                        string,
	version:                      int,
	message:                      Message,
	app_permissions:              string,
	locale:                       string,
	guild_locale:                 string,
	entitlements:                 []Entitlement,
	authorizing_integration_owners: map[string]Snowflake,
	_context:                      InteractionContextType `json:"context"`,
	attachment_size_limit:        int,
}

InteractionData :: union {
	ApplicationCommandInteractionData,
	MessageComponentInteractionData,
	ModalSubmitInteractionData,
}

MessageInteraction :: struct {
	id:      Snowflake,
	type:    InteractionType,
	name:    string,
	user:    User,
	member:  GuildMember,
}

AllowedMentions :: struct {
	parse:       []string,
	roles:       []Snowflake,
	users:       []Snowflake,
	replied_user: bool,
}

InteractionCallbackData :: struct {
	tts:              bool,
	content:          string,
	embeds:           []Embed,
	allowed_mentions: AllowedMentions,
	flags:            int,
	components:       []Component,
	attachments:      []Attachment,
	poll:             PollCreateRequest,
}

InteractionResponse :: struct {
	type: InteractionCallbackType,
	data: InteractionCallbackData,
}
