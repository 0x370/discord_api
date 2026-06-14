package discord_api

InteractionType :: enum i32 {
	PING                             = 1,
	APPLICATION_COMMAND              = 2,
	MESSAGE_COMPONENT                = 3,
	APPLICATION_COMMAND_AUTOCOMPLETE = 4,
	MODAL_SUBMIT                     = 5,
}

InteractionContextType :: enum i32 {
	GUILD           = 0,
	BOT_DM          = 1,
	PRIVATE_CHANNEL = 2,
}

InteractionCallbackType :: enum i32 {
	PONG                                    = 1,
	CHANNEL_MESSAGE_WITH_SOURCE             = 4,
	DEFERRED_CHANNEL_MESSAGE_WITH_SOURCE    = 5,
	DEFERRED_UPDATE_MESSAGE                 = 6,
	UPDATE_MESSAGE                          = 7,
	APPLICATION_COMMAND_AUTOCOMPLETE_RESULT = 8,
	MODAL                                   = 9,
	PREMIUM_REQUIRED                        = 10,
	LAUNCH_ACTIVITY                         = 12,
}

ApplicationCommandInteractionDataOptionValue :: union {
	string,
	i64,
	f64,
	bool,
}

ApplicationCommandInteractionDataOption :: struct {
	name:    string `json:"name,omitempty"`,
	type:    int    `json:"type,omitempty"`,
	value:   ApplicationCommandInteractionDataOptionValue `json:"value,omitempty"`,
	options: []ApplicationCommandInteractionDataOption `json:"options,omitempty"`,
	focused: bool `json:"focused,omitempty"`,
}

ApplicationCommandInteractionData :: struct {
	id:        Snowflake `json:"id,omitempty"`,
	name:      string    `json:"name,omitempty"`,
	type:      int       `json:"type,omitempty"`,
	resolved:  ResolvedData `json:"resolved,omitempty"`,
	options:   []ApplicationCommandInteractionDataOption `json:"options,omitempty"`,
	guild_id:  Snowflake `json:"guild_id,omitempty"`,
	target_id: Snowflake `json:"target_id,omitempty"`,
}

MessageComponentInteractionData :: struct {
	custom_id:      string     `json:"custom_id,omitempty"`,
	component_type: int        `json:"component_type,omitempty"`,
	values:         []string   `json:"values,omitempty"`,
	resolved:       ResolvedData `json:"resolved,omitempty"`,
}

ModalSubmitInteractionData :: struct {
	custom_id:  string                  `json:"custom_id,omitempty"`,
	components: []ComponentInteractionData `json:"components,omitempty"`,
	resolved:   ResolvedData            `json:"resolved,omitempty"`,
}

ComponentInteractionData :: struct {
	custom_id:      string                    `json:"custom_id,omitempty"`,
	component_type: int                       `json:"component_type,omitempty"`,
	value:          string                    `json:"value,omitempty"`,
	values:         []string                  `json:"values,omitempty"`,
	components:     []ComponentInteractionData `json:"components,omitempty"`,
	resolved:       ResolvedData              `json:"resolved,omitempty"`,
}

Interaction :: struct {
	id:                             Snowflake                   `json:"id,omitempty"`,
	application_id:                 Snowflake                   `json:"application_id,omitempty"`,
	type:                           InteractionType              `json:"type,omitempty"`,
	data:                           InteractionData              `json:"data,omitempty"`,
	guild:                          Guild                       `json:"guild,omitempty"`,
	guild_id:                       Snowflake                   `json:"guild_id,omitempty"`,
	channel:                        Channel                     `json:"channel,omitempty"`,
	channel_id:                     Snowflake                   `json:"channel_id,omitempty"`,
	member:                         GuildMember                 `json:"member,omitempty"`,
	user:                           User                        `json:"user,omitempty"`,
	token:                          string                      `json:"token,omitempty"`,
	version:                        int                         `json:"version,omitempty"`,
	message:                        Message                     `json:"message,omitempty"`,
	app_permissions:                string                      `json:"app_permissions,omitempty"`,
	locale:                         string                      `json:"locale,omitempty"`,
	guild_locale:                   string                      `json:"guild_locale,omitempty"`,
	entitlements:                   []Entitlement               `json:"entitlements,omitempty"`,
	authorizing_integration_owners: map[string]Snowflake         `json:"authorizing_integration_owners,omitempty"`,
	_context:                       InteractionContextType       `json:"context,omitempty"`,
	attachment_size_limit:          int                         `json:"attachment_size_limit,omitempty"`,
}

InteractionData :: union {
	ApplicationCommandInteractionData,
	MessageComponentInteractionData,
	ModalSubmitInteractionData,
}

MessageInteraction :: struct {
	id:     Snowflake       `json:"id,omitempty"`,
	type:   InteractionType `json:"type,omitempty"`,
	name:   string          `json:"name,omitempty"`,
	user:   User            `json:"user,omitempty"`,
	member: GuildMember     `json:"member,omitempty"`,
}

AllowedMentions :: struct {
	parse:        []string   `json:"parse,omitempty"`,
	roles:        []Snowflake `json:"roles,omitempty"`,
	users:        []Snowflake `json:"users,omitempty"`,
	replied_user: bool       `json:"replied_user,omitempty"`,
}

InteractionCallbackData :: struct {
	tts:              Maybe(bool)        `json:"tts,omitempty"`,
	content:          Maybe(string)      `json:"content,omitempty"`,
	embeds:           []Embed            `json:"embeds,omitempty"`,
	allowed_mentions: Maybe(AllowedMentions) `json:"allowed_mentions,omitempty"`,
	flags:            Maybe(int)         `json:"flags,omitempty"`,
	components:       []Component        `json:"components,omitempty"`,
	attachments:      []Attachment       `json:"attachments,omitempty"`,
	poll:             Maybe(PollCreateRequest) `json:"poll,omitempty"`,
}

InteractionResponse :: struct {
	type: InteractionCallbackType `json:"type"`,
	data: InteractionCallbackData `json:"data,omitempty"`,
}
