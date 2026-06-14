package discord_api

AutoModerationTriggerType :: enum i32 {
	KEYWORD        = 1,
	SPAM           = 3,
	KEYWORD_PRESET = 4,
	MENTION_SPAM   = 5,
	MEMBER_PROFILE = 6,
}

AutoModerationEventType :: enum i32 {
	MESSAGE_SEND  = 1,
	MEMBER_UPDATE = 2,
}

AutoModerationKeywordPresetType :: enum i32 {
	PROFANITY      = 1,
	SEXUAL_CONTENT = 2,
	SLURS          = 3,
}

AutoModerationTriggerMetadata :: struct {
	keyword_filter:                  []string,
	regex_patterns:                  []string,
	presets:                         []AutoModerationKeywordPresetType,
	allow_list:                      []string,
	mention_total_limit:             int,
	mention_raid_protection_enabled: bool,
}

AutoModerationActionType :: enum i32 {
	BLOCK_MESSAGE            = 1,
	SEND_ALERT_MESSAGE       = 2,
	TIMEOUT                  = 3,
	BLOCK_MEMBER_INTERACTION = 4,
}

AutoModerationActionMetadata :: struct {
	channel_id:       Snowflake,
	duration_seconds: int,
	custom_message:   string,
}

AutoModerationAction :: struct {
	type:     AutoModerationActionType,
	metadata: AutoModerationActionMetadata,
}

AutoModerationRule :: struct {
	id:               Snowflake,
	guild_id:         Snowflake,
	name:             string,
	creator_id:       Snowflake,
	event_type:       AutoModerationEventType,
	trigger_type:     AutoModerationTriggerType,
	trigger_metadata: AutoModerationTriggerMetadata,
	actions:          []AutoModerationAction,
	enabled:          bool,
	exempt_roles:     []Snowflake,
	exempt_channels:  []Snowflake,
}
