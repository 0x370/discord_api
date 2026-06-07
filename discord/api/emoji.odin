package discord_api

Emoji :: struct {
	id:             Snowflake,
	name:           string,
	roles:          []Snowflake,
	user:           User,
	require_colons: bool,
	managed:        bool,
	animated:       bool,
	available:      bool,
}

ApplicationEmojiList :: struct {
	items: []Emoji,
}
