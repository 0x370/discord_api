package discord_api

SoundboardSound :: struct {
	name:       string,
	sound_id:   Snowflake,
	volume:     f64,
	emoji_id:   Snowflake,
	emoji_name: string,
	guild_id:   Snowflake,
	available:  bool,
	user:       User,
}
