package discord_api

import "core:time"

Channel_Mention :: struct {} 
Attachment      :: struct {} 
Embed           :: struct {} 
Reaction        :: struct {} 
Message_Snapshot :: struct {} 
Message_Interaction_Metadata :: struct {} 
Message_Interaction :: struct {} 
Message_Components  :: struct {} 
Message_Sticker_Item :: struct {} 
Role_Subscription_Data :: struct {} 
Resolved        :: struct {} 
Poll            :: struct {} 
Message_Call    :: struct {} 
Shared_Client_Theme :: struct {} 

Message_Activity_Type :: enum int {
	UNKNOWN      = 0,
	JOIN         = 1,
	SPECTATE     = 2,
	LISTEN       = 3,
	JOIN_REQUEST = 5,
}

Message_Activity :: struct {
	type:     Message_Activity_Type `json:"type"`,
	party_id: string                `json:"party_id"`,
}

Message_Reference_Type :: enum int {
	DEFAULT = 0,
	FORWARD = 1,
}

Message_Reference :: struct {
	type:               Maybe(Message_Reference_Type) `json:"type"`,
	message_id:         Maybe(Snowflake)              `json:"message_id"`,
	channel_id:         Maybe(Snowflake)              `json:"channel_id"`,
	guild_id:           Maybe(Snowflake)              `json:"guild_id"`,
	fail_if_not_exists: Maybe(bool)                   `json:"fail_if_not_exists"`,
}

Message_Type :: enum int {
	DEFAULT                                      = 0,
	RECIPIENT_ADD                                = 1,
	RECIPIENT_REMOVE                             = 2,
	CALL                                         = 3,
	CHANNEL_NAME_CHANGE                          = 4,
	CHANNEL_ICON_CHANGE                          = 5,
	CHANNEL_PINNED_MESSAGE                       = 6,
	USER_JOIN                                    = 7,
	GUILD_BOOST                                  = 8,
	GUILD_BOOST_TIER_1                           = 9,
	GUILD_BOOST_TIER_2                           = 10,
	GUILD_BOOST_TIER_3                           = 11,
	CHANNEL_FOLLOW_ADD                           = 12,
	GUILD_DISCOVERY_DISQUALIFIED                 = 14,
	GUILD_DISCOVERY_REQUALIFIED                  = 15,
	GUILD_DISCOVERY_GRACE_PERIOD_INITIAL_WARNING = 16,
	GUILD_DISCOVERY_GRACE_PERIOD_FINAL_WARNING   = 17,
	THREAD_CREATED                               = 18,
	REPLY                                        = 19,
	CHAT_INPUT_COMMAND                           = 20,
	THREAD_STARTER_MESSAGE                       = 21,
	GUILD_INVITE_REMINDER                        = 22,
	CONTEXT_MENU_COMMAND                         = 23,
	AUTO_MODERATION_ACTION                       = 24,
	ROLE_SUBSCRIPTION_PURCHASE                   = 25,
	INTERACTION_PREMIUM_UPSELL                   = 26,
	STAGE_START                                  = 27,
	STAGE_END                                    = 28,
	STAGE_SPEAKER                                = 29,
	STAGE_TOPIC                                  = 31,
	GUILD_APPLICATION_PREMIUM_SUBSCRIPTION       = 32,
	GUILD_INCIDENT_ALERT_MODE_ENABLED            = 36,
	GUILD_INCIDENT_ALERT_MODE_DISABLED           = 37,
	GUILD_INCIDENT_REPORT_RAID                   = 38,
	GUILD_INCIDENT_REPORT_FALSE_ALARM            = 39,
	PURCHASE_NOTIFICATION                        = 44,
	POLL_RESULT                                  = 46,
}

Message_Flag :: enum u8 {
	CROSSPOSTED                            = 0, // Bit position 0 (1 << 0)
	IS_CROSSPOST                           = 1, // Bit position 1 (1 << 1)
	SUPPRESS_EMBEDS                        = 2, // Bit position 2 (1 << 2)
	SOURCE_MESSAGE_DELETED                 = 3, // Bit position 3 (1 << 3)
	URGENT                                 = 4, // Bit position 4 (1 << 4)
	HAS_THREAD                             = 5, // Bit position 5 (1 << 5)
	EPHEMERAL                              = 6, // Bit position 6 (1 << 6)
	LOADING                                = 7, // Bit position 7 (1 << 7)
	FAILED_TO_MENTION_SOME_ROLES_IN_THREAD = 8, // Bit position 8 (1 << 8)
	SUPPRESS_NOTIFICATIONS                 = 12,// Bit position 12 (1 << 12)
	IS_VOICE_MESSAGE                       = 13,// Bit position 13 (1 << 13)
	HAS_SNAPSHOT                           = 14,// Bit position 14 (1 << 14)
	IS_COMPONENTS_V2                       = 15,// Bit position 15 (1 << 15)
}
Message_Flags_Set :: bit_set[Message_Flag; i32]

Message :: struct {
	id:                     Snowflake                     `json:"id"`,
	channel_id:             Snowflake                     `json:"channel_id"`,
	author:                 User                          `json:"author"`, 
	content:                string                        `json:"content"`,
	timestamp:              string                        `json:"timestamp"`,
	edited_timestamp:       Maybe(string)                 `json:"edited_timestamp"`, // FIXED
	tts:                    bool                          `json:"tts"`,
	mention_everyone:       bool                          `json:"mention_everyone"`,
	mentions:               [dynamic]User                 `json:"mentions"`, 
	mention_roles:          [dynamic]Snowflake            `json:"mention_roles"`,
	mention_channels:       [dynamic]Channel_Mention      `json:"mention_channels"`,
	attachments:            [dynamic]Attachment           `json:"attachments"`,
	embeds:                 [dynamic]Embed                `json:"embeds"`,
	reactions:              [dynamic]Reaction             `json:"reactions"`,
	nonce:                  string                        `json:"nonce"`,
	pinned:                 bool                          `json:"pinned"`,
	webhook_id:             Maybe(Snowflake)              `json:"webhook_id"`, 
	type:                   Message_Type                  `json:"type"`,
	activity:               Maybe(Message_Activity)       `json:"activity"`,          // FIXED
	application:            Maybe(Application)            `json:"application"`,       // FIXED
	application_id:         Maybe(Snowflake)              `json:"application_id"`,
	flags:                  Message_Flags_Set             `json:"flags"`,
	message_reference:      Maybe(Message_Reference)      `json:"message_reference"`, // FIXED
	message_snapshots:      [dynamic]Message_Snapshot     `json:"message_snapshots"`,
	referenced_message:     [dynamic]Message              `json:"referenced_message"`,
	interaction_metadata:   Maybe(Message_Interaction_Metadata) `json:"interaction_metadata"`, // FIXED
	interaction:            Maybe(Message_Interaction)    `json:"interaction"`,       // FIXED
	thread:                 Maybe(Channel)                `json:"thread"`,            // FIXED
	components:             [dynamic]Message_Components   `json:"components"`,
	sticker_items:          [dynamic]Message_Sticker_Item `json:"sticker_items"`,
	stickers:               [dynamic]Sticker              `json:"stickers"`,
	position:               Maybe(int)                    `json:"position"`,          // FIXED
	role_subscription_data: Maybe(Role_Subscription_Data) `json:"role_subscription_data"`, // FIXED
	resolved:               Maybe(Resolved)               `json:"resolved"`,          // FIXED
	poll:                   Maybe(Poll)                   `json:"poll"`,              // FIXED
	call:                   Maybe(Message_Call)           `json:"call"`,              // FIXED
	shared_client_theme:    Maybe(Shared_Client_Theme)    `json:"shared_client_theme"`, // FIXED
}
