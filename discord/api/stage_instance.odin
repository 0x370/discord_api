package discord_api

StageInstancePrivacyLevel :: enum i32 {
	PUBLIC     = 1,
	GUILD_ONLY = 2,
}

StageInstance :: struct {
	id:                          Snowflake,
	guild_id:                    Snowflake,
	channel_id:                  Snowflake,
	topic:                       string,
	privacy_level:               StageInstancePrivacyLevel,
	discoverable_disabled:       bool,
	guild_scheduled_event_id:    Snowflake,
}
