package discord_api

Emoji :: struct {
	id:             Snowflake   `json:"id,omitempty"`,
	name:           string      `json:"name,omitempty"`,
	roles:          []Snowflake `json:"roles,omitempty"`,
	user:           User        `json:"user,omitempty"`,
	require_colons: bool        `json:"require_colons,omitempty"`,
	managed:        bool        `json:"managed,omitempty"`,
	animated:       bool        `json:"animated,omitempty"`,
	available:      bool        `json:"available,omitempty"`,
}

ApplicationEmojiList :: struct {
	items: []Emoji,
}
