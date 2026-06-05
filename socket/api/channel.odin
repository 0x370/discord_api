package discord_api

import "core:fmt"
Channel_Type :: enum int {
	GUILD_TEXT          = 0,
	DM                  = 1,
	GUILD_VOICE         = 2,
	GROUP_DM            = 3,
	GUILD_CATEGORY      = 4,
	GUILD_ANNOUNCEMENT  = 5,
	ANNOUNCEMENT_THREAD = 10,
	PUBLIC_THREAD       = 11,
	PRIVATE_THREAD      = 12,
	GUILD_STAGE_VOICE   = 13,
	GUILD_DIRECTORY     = 14,
	GUILD_FORUM         = 15,
	GUILD_MEDIA         = 16,
}

Video_Quality_Mode :: enum int {
	AUTO = 1,
	FULL = 2,
}

Sort_Order_Type :: enum int {
	LATEST_ACTIVITY = 0,
	CREATION_DATE   = 1,
}

Forum_Layout_Type :: enum int {
	NOT_SET      = 0,
	LIST_VIEW    = 1,
	GALLERY_VIEW = 2,
}

Overwrite :: struct {
	id:    Snowflake `json:"id"`,
	type:  int       `json:"type"`,
	allow: string    `json:"allow"`,
	deny:  string    `json:"deny"`,
}

Thread_Metadata :: struct {
	archived:              bool        `json:"archived"`,
	auto_archive_duration: int         `json:"auto_archive_duration"`,
	archive_timestamp:     string      `json:"archive_timestamp"`, 
	locked:                bool        `json:"locked"`,
	invitable:             Maybe(bool) `json:"invitable"`,
	create_timestamp:      string      `json:"create_timestamp"`,  
}

Tag :: struct {
	id:         Snowflake        `json:"id"`,
	name:       string           `json:"name"`,
	moderated:  bool             `json:"moderated"`,
	emoji_id:   Maybe(Snowflake) `json:"emoji_id"`,
	emoji_name: Maybe(string)    `json:"emoji_name"`,
}

Default_Reaction :: struct {
	emoji_id:   Maybe(Snowflake) `json:"emoji_id"`,
	emoji_name: Maybe(string)    `json:"emoji_name"`,
}

Thread_Member :: struct {} // Stub

Channel :: struct {
	id:                                 Snowflake          `json:"id"`,
	type:                               Channel_Type       `json:"type"`,
	guild_id:                           Snowflake          `json:"guild_id"`,
	position:                           int                `json:"position"`,
	permission_overwrites:              [dynamic]Overwrite `json:"permission_overwrites"`,
	name:                               string             `json:"name"`,
	topic:                              string             `json:"topic"`,
	nsfw:                               bool               `json:"nsfw"`,
	last_message_id:                    Snowflake          `json:"last_message_id"`,
	bitrate:                            int                `json:"bitrate"`,
	user_limit:                         int                `json:"user_limit"`,
	rate_limit_per_user:                int                `json:"rate_limit_per_user"`,
	recipients:                         [dynamic]User      `json:"recipients"`,
	icon:                               string             `json:"icon"`,
	owner_id:                           Snowflake          `json:"owner_id"`,
	application_id:                     Snowflake          `json:"application_id"`,
	managed:                            bool               `json:"managed"`,
	parent_id:                          Snowflake          `json:"parent_id"`,
	last_pin_timestamp:                 string             `json:"last_pin_timestamp"`, // FIXED: string
	rtc_region:                         string             `json:"rtc_region"`,
	video_quality_mode:                 Video_Quality_Mode `json:"video_quality_mode"`,
	message_count:                      int                `json:"message_count"`,
	member_count:                       int                `json:"member_count"`,
	thread_metadata:                    Thread_Metadata    `json:"thread_metadata"`,     // FIXED: Concrete Value
	member:                             Thread_Member      `json:"member"`,              // FIXED: Concrete Value
	default_auto_archive_duration:      int                `json:"default_auto_archive_duration"`,
	permissions:                        string             `json:"permissions"`,
	flags:                              int                `json:"flags"`,
	total_message_sent:                 int                `json:"total_message_sent"`,
	available_tags:                     [dynamic]Tag       `json:"available_tags"`,
	applied_tags:                       [dynamic]Snowflake `json:"applied_tags"`,
	default_reaction_emoji:             Default_Reaction   `json:"default_reaction_emoji"`, // FIXED: Concrete Value
	default_thread_rate_limit_per_user: int                `json:"default_thread_rate_limit_per_user"`,
	default_sort_order:                 Sort_Order_Type    `json:"default_sort_order"`,
	default_forum_layout:               Forum_Layout_Type  `json:"default_forum_layout"`,
}

get_channel :: proc(client: ^Discord_Client, channel_id: string) -> (channel: Channel, ok: bool) {
	url := fmt.tprintf("/channels/%s", channel_id)
	return discord_fetch(Channel, client, url)
}