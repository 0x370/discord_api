package discord_api

Application :: struct {
	id:                                   Snowflake,
	name:                                 string,
	icon:                                 string,
	description:                          string,
	rpc_origins:                          []string,
	bot_public:                           bool,
	bot_require_code_grant:               bool,
	bot:                                  User,
	terms_of_service_url:                 string,
	privacy_policy_url:                   string,
	owner:                                User,
	verify_key:                           string,
	team:                                 Team,
	guild_id:                             Snowflake,
	guild:                                PartialGuild,
	primary_sku_id:                       Snowflake,
	slug:                                 string,
	cover_image:                          string,
	flags:                                ApplicationFlags,
	approximate_guild_count:              int,
	approximate_user_install_count:       int,
	approximate_user_authorization_count: int,
	redirect_uris:                        []string,
	interactions_endpoint_url:            string,
	role_connections_verification_url:    string,
	event_webhooks_url:                   string,
	event_webhooks_status:                ApplicationEventWebhookStatus,
	event_webhooks_types:                 []string,
	tags:                                 []string,
	install_params:                       InstallParams,
	integration_types_config:             map[ApplicationIntegrationType]ApplicationIntegrationTypeConfiguration,
	custom_install_url:                   string,
}

InstallParams :: struct {
	scopes:      []string,
	permissions: string,
}

ApplicationIntegrationTypeConfiguration :: struct {
	oauth2_install_params: InstallParams,
}

ApplicationIntegrationType :: enum i32 {
	GUILD_INSTALL = 0,
	USER_INSTALL  = 1,
}

ActivityInstance :: struct {
	application_id: Snowflake,
	instance_id:    string,
	launch_id:      Snowflake,
	location:       ActivityLocation,
	users:          []Snowflake,
}

ActivityLocation :: struct {
	id:         string,
	kind:       ActivityLocationKind,
	channel_id: Snowflake,
	guild_id:   Snowflake,
}

ActivityLocationKind :: enum {
	GUILD_CHANNEL,
	PRIVATE_CHANNEL,
}

Team :: struct {
	icon:          string,
	id:            Snowflake,
	members:       []TeamMember,
	name:          string,
	owner_user_id: Snowflake,
}

TeamMember :: struct {
	membership_state: TeamMembershipState,
	permissions:      []string,
	team_id:          Snowflake,
	user:             User,
	role:             string,
}

TeamMembershipState :: enum i32 {
	INVITED  = 1,
	ACCEPTED = 2,
}

PartialGuild :: struct {
	id:   Snowflake,
	name: string,
	icon: string,
}

ApplicationEventWebhookStatus :: enum i32 {
	DISABLED            = 1,
	ENABLED             = 2,
	DISABLED_BY_DISCORD = 3,
}

ApplicationFlags :: distinct u64

APPLICATION_AUTO_MODERATION_RULE_CREATE_BADGE :: ApplicationFlags(1 << 6)
APPLICATION_GATEWAY_PRESENCE :: ApplicationFlags(1 << 12)
APPLICATION_GATEWAY_PRESENCE_LIMITED :: ApplicationFlags(1 << 13)
APPLICATION_GATEWAY_GUILD_MEMBERS :: ApplicationFlags(1 << 14)
APPLICATION_GATEWAY_GUILD_MEMBERS_LIMITED :: ApplicationFlags(1 << 15)
APPLICATION_VERIFICATION_PENDING_GUILD_LIMIT :: ApplicationFlags(1 << 16)
APPLICATION_EMBEDDED :: ApplicationFlags(1 << 17)
APPLICATION_GATEWAY_MESSAGE_CONTENT :: ApplicationFlags(1 << 18)
APPLICATION_GATEWAY_MESSAGE_CONTENT_LIMITED :: ApplicationFlags(1 << 19)
APPLICATION_COMMAND_BADGE :: ApplicationFlags(1 << 23)
