package discord_api

Team :: struct {}

Event_Webhook_Status :: enum i32 {
	Disabled            = 1,
	Enabled             = 2,
	Disabled_By_Discord = 3,
}

Install_Params :: struct {}
Integration_Type_Config :: struct {}

Application :: struct {
	id:                                   Snowflake,
	name:                                 string,
	icon:                                 string, // ?string (Can be empty string or pointer to string if preferred)
	description:                          string,
	rpc_origins:                          [dynamic]string, // array of strings?
	bot_public:                           bool,
	bot_require_code_grant:               bool,
	bot:                                  ^User, // partial user object?
	terms_of_service_url:                 string, // string?
	privacy_policy_url:                   string, // string?
	owner:                                ^User, // partial user object?
	verify_key:                           string,
	team:                                 ^Team, // ?team object (nil if it belongs to a user, not a team)
	guild_id:                             Snowflake, // snowflake?
	guild:                                ^Guild, // partial guild object?
	primary_sku_id:                       Snowflake, // snowflake?
	slug:                                 string, // string?
	cover_image:                          string, // string?
	flags:                                i32, // integer? (Bit flags for the app)
	approximate_guild_count:              i32, // integer?
	approximate_user_install_count:       i32, // integer?
	approximate_user_authorization_count: i32, // integer?
	redirect_uris:                        [dynamic]string, // array of strings?
	interactions_endpoint_url:            string, // ?string
	role_connections_verification_url:    string, // ?string
	event_webhooks_url:                   string, // ?string
	event_webhooks_status:                Event_Webhook_Status, // application event webhook status?
	event_webhooks_types:                 [dynamic]string, // array of strings?
	tags:                                 [dynamic]string, // array of strings? (Max 5 items)
	install_params:                       ^Install_Params, // install params object?
	integration_types_config:             map[string]Integration_Type_Config, // dictionary?
	custom_install_url:                   string, // string?
}
