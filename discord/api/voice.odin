package discord_api

VoiceState :: struct {
	guild_id:                   Snowflake,
	channel_id:                 Snowflake,
	user_id:                    Snowflake,
	member:                     GuildMember,
	session_id:                 string,
	deaf:                       bool,
	mute:                       bool,
	self_deaf:                  bool,
	self_mute:                  bool,
	self_stream:                bool,
	self_video:                 bool,
	suppress:                   bool,
	request_to_speak_timestamp: string,
}

VoiceRegion :: struct {
	id:         string,
	name:       string,
	optimal:    bool,
	deprecated: bool,
	custom:     bool,
}
