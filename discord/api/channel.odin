package discord_api

Channel :: struct {
	id:                                 Snowflake,
	type:                               ChannelType,
	guild_id:                           Snowflake,
	position:                           int,
	permission_overwrites:              []Overwrite,
	name:                               string,
	topic:                              string,
	nsfw:                               bool,
	last_message_id:                    Snowflake,
	bitrate:                            int,
	user_limit:                         int,
	rate_limit_per_user:                int,
	recipients:                         []User,
	icon:                               string,
	owner_id:                           Snowflake,
	application_id:                     Snowflake,
	parent_id:                          Snowflake,
	last_pin_timestamp:                 string,
	rtc_region:                         string,
	video_quality_mode:                 VideoQualityMode,
	message_count:                      int,
	member_count:                       int,
	thread_metadata:                    ThreadMetadata,
	member:                             ThreadMember,
	default_auto_archive_duration:      int,
	permissions:                        string,
	flags:                              ChannelFlags,
	total_message_sent:                 int,
	available_tags:                     []ForumTag,
	applied_tags:                       []Snowflake,
	default_reaction_emoji:             DefaultReaction,
	default_thread_rate_limit_per_user: int,
	default_sort_order:                 SortOrderType,
	default_forum_layout:               ForumLayoutType,
}

FollowedChannel :: struct {
	channel_id: Snowflake,
	webhook_id: Snowflake,
}

Overwrite :: struct {
	id:    Snowflake,
	type:  OverwriteType,
	allow: string,
	deny:  string,
}

ThreadMetadata :: struct {
	archived:              bool,
	auto_archive_duration: int,
	archive_timestamp:     string,
	locked:                bool,
	invitable:             bool,
	create_timestamp:      string,
}

ThreadMember :: struct {
	id:             Snowflake,
	user_id:        Snowflake,
	join_timestamp: string,
	flags:          int,
	member:         GuildMember,
}

DefaultReaction :: struct {
	emoji_id:   Snowflake,
	emoji_name: string,
}

ForumTag :: struct {
	id:         Snowflake,
	name:       string,
	moderated:  bool,
	emoji_id:   Snowflake,
	emoji_name: string,
}

ArchivedThreads :: struct {
	threads:  []Channel,
	members:  []ThreadMember,
	has_more: bool,
}

ChannelType :: enum i32 {
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

OverwriteType :: enum i32 {
	ROLE   = 0,
	MEMBER = 1,
}

VideoQualityMode :: enum i32 {
	AUTO = 1,
	FULL = 2,
}

SortOrderType :: enum i32 {
	LATEST_ACTIVITY = 0,
	CREATION_DATE   = 1,
}

ForumLayoutType :: enum i32 {
	NOT_SET      = 0,
	LIST_VIEW    = 1,
	GALLERY_VIEW = 2,
}

ChannelFlags :: distinct u64
