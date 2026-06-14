package discord_api

WebhookType :: enum i32 {
	INCOMING         = 1,
	CHANNEL_FOLLOWER = 2,
	APPLICATION      = 3,
}

Webhook :: struct {
	id:             Snowflake,
	type:           WebhookType,
	guild_id:       Snowflake,
	channel_id:     Snowflake,
	user:           User,
	name:           string,
	avatar:         string,
	token:          string,
	application_id: Snowflake,
	source_guild:   PartialGuild,
	source_channel: PartialChannel,
	url:            string,
}

PartialChannel :: struct {
	id:   Snowflake,
	name: string,
	type: ChannelType,
}
