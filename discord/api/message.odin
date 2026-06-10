package discord_api

AllowedMentions :: struct {
	parse:       []string,
	roles:       []Snowflake,
	users:       []Snowflake,
	replied_user: bool,
}

Message :: struct {
	id:                     Snowflake,
	channel_id:             Snowflake,
	guild_id:               Snowflake,
	author:                 User,
	member:                 GuildMember,
	content:                string,
	timestamp:              string,
	edited_timestamp:       string,
	tts:                    bool,
	mention_everyone:       bool,
	mentions:               []User,
	mention_roles:          []Snowflake,
	mention_channels:       []ChannelMention,
	attachments:            []Attachment,
	embeds:                 []Embed,
	reactions:              []Reaction,
	nonce:                  string,
	pinned:                 bool,
	webhook_id:             Snowflake,
	type:                   MessageTypes,
	activity:               MessageActivity,
	application:            Application,
	application_id:         Snowflake,
	flags:                  MessageFlags,
	message_reference:      MessageReference,
	message_snapshots:      []MessageSnapshot,
	referenced_message:     []Message,
	interaction_metadata:   MessageInteractionMetadata,
	thread:                 Channel,
	components:             []MessageComponent,
	sticker_items:          []StickerItem,
	stickers:               []Sticker,
	position:               i64,
	role_subscription_data: RoleSubscriptionData,
	resolved:               ResolvedData,
	poll:                   Poll,
	call:                   MessageCall,
	shared_client_theme:    SharedClientTheme,
}

MessageReference :: struct {
	type:               MessageReferenceTypes,
	message_id:         Snowflake,
	channel_id:         Snowflake,
	guild_id:           Snowflake,
	fail_if_not_exists: bool,
}

MessageSnapshot :: struct {
	message: ForwardedMessage,
}

ForwardedMessage :: struct {
	type:             int,
	content:          string,
	embeds:           []Embed,
	attachments:      []Attachment,
	timestamp:        Snowflake,
	edited_timestamp: Snowflake,
	flags:            u64,
	mentions:         []User,
	mention_roles:    []Snowflake,
	sticker_items:    []StickerItem,
	components:       []MessageComponent,
}

Reaction :: struct {
	count:         int,
	count_details: ReactionCountDetails,
	me:            bool,
	me_burst:      bool,
	emoji:         Emoji,
	burst_colors:  []string,
}

ReactionCountDetails :: struct {
	burst:  int,
	normal: int,
}

MessageActivity :: struct {
	type:     MessageActivityTypes,
	party_id: string,
}

MessageCall :: struct {
	participants:    []Snowflake,
	ended_timestamp: Snowflake,
}

ChannelMention :: struct {
	id:       Snowflake,
	guild_id: Snowflake,
	type:     ChannelType,
	name:     string,
}

RoleSubscriptionData :: struct {
	role_subscription_listing_id: Snowflake,
	tier_name:                    string,
	total_months_subscribed:      int,
	is_renewal:                   bool,
}

MessageInteractionMetadata :: struct {
	id:                              Snowflake,
	type:                            int,
	user:                            User,
	authorizing_integration_owners:  map[string]Snowflake,
	original_response_message_id:    Snowflake,
	interacted_message_id:           Snowflake,
	triggering_interaction_metadata: []MessageInteractionMetadata,
	target_user:                     User,
	target_message_id:               Snowflake,
}

Poll :: struct {
	question:          PollMedia,
	answers:           []PollAnswer,
	expiry:            string,
	allow_multiselect: bool,
	layout_type:       int,
	results:           PollResults,
}

PollMedia :: struct {
	text:  string,
	emoji: Emoji,
}

PollAnswer :: struct {
	answer_id:  int,
	poll_media: PollMedia,
}

PollResults :: struct {
	is_finalized:  bool,
	answer_counts: []PollAnswerCount,
}

PollAnswerCount :: struct {
	id:       int,
	count:    int,
	me_voted: bool,
}

ResolvedData :: struct {
	users:       map[Snowflake]User,
	members:     map[Snowflake]GuildMember,
	roles:       map[Snowflake]Role,
	channels:    map[Snowflake]Channel,
	messages:    map[Snowflake]Message,
	attachments: map[Snowflake]Attachment,
}

SharedClientTheme :: struct {
	colors:         []string,
	gradient_angle: int,
	base_mix:       int,
	base_theme:     BaseThemeTypes,
}

BaseThemeTypes :: enum i32 {
	UNSET = 0,
	DARK,
	LIGHT,
	DARKER,
	MIDNIGHT,
}

MessageUpdateArgs :: struct {
	before: Message,
	after:  Message,
}

MessageDeleteEvent :: struct {
	id:         Snowflake,
	channel_id: Snowflake,
	guild_id:   Snowflake,
}

MessageActivityTypes :: enum i32 {
	JOIN = 1,
	SPECTATE,
	LISTEN,
	JOIN_REQUEST,
}

MessageFlags :: distinct u64
CROSSPOSTED :: MessageFlags(1 << 0)
IS_CROSSPOST :: MessageFlags(1 << 1)
SUPPRESS_EMBEDS :: MessageFlags(1 << 2)
SOURCE_MESSAGE_DELETED :: MessageFlags(1 << 3)
URGENT :: MessageFlags(1 << 4)
HAS_THREAD :: MessageFlags(1 << 5)
EMPHEMERAL :: MessageFlags(1 << 6)
LOADING :: MessageFlags(1 << 7)
FAILED_TO_MENTION_SOME_ROLES_IN_THREAD :: MessageFlags(1 << 8)
SUPPRESS_NOTIFICATIONS :: MessageFlags(1 << 12)
IS_VOICE_MESSAGE :: MessageFlags(1 << 13)
HAS_SNAPSHOT :: MessageFlags(1 << 14)
IS_COMPONENTS_V2 :: MessageFlags(1 << 15)

MessageTypes :: enum {
	DEFAULT = 0,
	RECIPIENT_ADD,
	RECIPIENT_REMOVE,
	CALL,
	CHANNEL_NAME_CHANGE,
	CHANNEL_ICON_CHANGE,
	CHANNEL_PINNED_MESSAGE,
	USER_JOIN,
	GUILD_BOOST,
	GUILD_BOOST_TIER_1,
	GUILD_BOOST_TIER_2,
	GUILD_BOOST_TIER_3,
	CHANNEL_FOLLOW_ADD,
	GUILD_DISCOVERY_DISQUALIFIED,
	GUILD_DISCOVERY_REQUALIFIED,
	GUILD_DISCOVERY_GRACE_PERIOD_INITIAL_WARNING,
	GUILD_DISCOVERY_GRACE_PERIOD_FINAL_WARNING,
	THREAD_CREATED,
	REPLY,
	CHAT_INPUT_COMMAND,
	THREAD_STARTER_MESSAGE,
	GUILD_INVITE_REMINDER,
	CONTEXT_MENU_COMMAND,
	AUTO_MODERATION_ACTION,
	ROLE_SUBSCRIPTION_PURCHASE,
	INTERACTION_PREMIUM_UPSELL,
	STAGE_START,
	STAGE_END,
	STAGE_SPEAKER,
	STAGE_TOPIC = 31,
	GUILD_APPLICATION_PREMIUM_SUBSCRIPTION,
	GUILD_INCIDENT_ALERT_MODE_ENABLED = 36,
	GUILD_INCIDENT_ALERT_MODE_DISABLED,
	GUILD_INCIDENT_REPORT_RAID,
	GUILD_INCIDENT_REPORT_FALSE_ALARM,
	PURCHASE_NOTIFICATION = 44,
	POLL_RESULT = 46,
}

MessageReferenceTypes :: enum i32 {
	DEFAULT = 0,
	FORWARD,
}
