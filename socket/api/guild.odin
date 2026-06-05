package discord_api

import "core:fmt"

// Helper definitions
Role           :: struct {}
Emoji          :: struct {}
Welcome_Screen :: struct {}
Sticker        :: struct {}
Incidents_Data :: struct {}

Default_Message_Notification_Level :: enum int {
	ALL_MESSAGES  = 0,
	ONLY_MENTIONS = 1,
}

Explicit_Content_Filter_Level :: enum int {
	DISABLED              = 0,
	MEMBERS_WITHOUT_ROLES = 1,
	ALL_MEMBERS           = 2,
}

MFA_Level :: enum int {
	NONE     = 0,
	ELEVATED = 1,
}

Verification_Level :: enum int {
	NONE      = 0,
	LOW       = 1,
	MEDIUM    = 2,
	HIGH      = 3,
	VERY_HIGH = 4,
}

Guild_Age_Restriction_Level :: enum int {
	DEFAULT        = 0,
	EXPLICIT       = 1,
	SAFE           = 2,
	AGE_RESTRICTED = 3,
}

Premium_Tier :: enum int {
	NONE   = 0,
	TIER_1 = 1,
	TIER_2 = 2,
	TIER_3 = 3,
}

System_Channel_Flag :: enum u8 {
	SUPPRESS_JOIN_NOTIFICATIONS                              = 0,
	SUPPRESS_PREMIUM_SUBSCRIPTIONS                           = 1,
	SUPPRESS_GUILD_REMINDER_NOTIFICATIONS                    = 2,
	SUPPRESS_JOIN_NOTIFICATION_REPLIES                       = 3,
	SUPPRESS_ROLE_SUBSCRIPTION_PURCHASE_NOTIFICATIONS        = 4,
	SUPPRESS_ROLE_SUBSCRIPTION_PURCHASE_NOTIFICATION_REPLIES = 5,
}
System_Channel_Flags :: bit_set[System_Channel_Flag; i32]

// FIXED: Converted all pointers to value types or 'maybe' containers
Guild :: struct {
	id:                            Snowflake,
	name:                          string,
	icon:                          string, 
	icon_hash:                     string, 
	splash:                        string, 
	discovery_splash:              string, 
	owner:                         Maybe(bool), // FIXED
	owner_id:                      Snowflake,
	permissions:                   string, 
	region:                        string, 
	afk_channel_id:                Maybe(Snowflake), // FIXED
	afk_timeout:                   int,
	widget_enabled:                Maybe(bool), // FIXED
	widget_channel_id:             Maybe(Snowflake), // FIXED
	verification_level:            Verification_Level,
	default_message_notifications: Default_Message_Notification_Level,
	explicit_content_filter:       Explicit_Content_Filter_Level,
	roles:                         [dynamic]Role, // FIXED
	emojis:                        [dynamic]Emoji, // FIXED
	features:                      [dynamic]string, // FIXED
	mfa_level:                     MFA_Level,
	application_id:                Maybe(Snowflake), // FIXED
	system_channel_id:             Maybe(Snowflake), // FIXED
	system_channel_flags:          System_Channel_Flags, 
	rules_channel_id:              Maybe(Snowflake), // FIXED
	max_presences:                 Maybe(int), // FIXED
	max_members:                   Maybe(int), // FIXED
	vanity_url_code:               string, 
	description:                   string, 
	banner:                        string, 
	premium_tier:                  Premium_Tier,
	premium_subscription_count:    Maybe(int), // FIXED
	preferred_locale:              string,
	public_updates_channel_id:     Maybe(Snowflake), // FIXED
	max_video_channel_users:       Maybe(int), // FIXED
	max_stage_video_channel_users: Maybe(int), // FIXED
	approximate_member_count:      Maybe(int), // FIXED
	approximate_presence_count:    Maybe(int), // FIXED
	welcome_screen:                Welcome_Screen, // FIXED
	nsfw_level:                    Guild_Age_Restriction_Level,
	stickers:                      [dynamic]Sticker, // FIXED
	premium_progress_bar_enabled:  bool,
	safety_alerts_channel_id:      Maybe(Snowflake), // FIXED
	incidents_data:                Incidents_Data, // FIXED
}

get_guild :: proc(client: ^Discord_Client, guild_id: string) -> (guild: Guild, ok: bool) {
	url := fmt.tprintf("/guilds/%s", guild_id)
	return discord_fetch(Guild, client, url)
}
