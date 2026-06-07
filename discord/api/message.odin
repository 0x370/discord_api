package discord_api

Message :: struct {
	id:                     Snowflake,
	channel_id:             Snowflake,
	guild_id:               Snowflake,
	author:                 User,
	member:                 GuildMember,
	content:                string,
	timestamp:              Snowflake,
	edited_timestamp:       Snowflake,
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
	type:                   int,
	activity:               MessageActivity,
	application:            Application,
	application_id:         Snowflake,
	message_reference:      MessageReference,
	referenced_message:     ^Message,
	flags:                  u64,
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
	message_snapshots:      []MessageSnapshot,
	shared_client_theme:    SharedClientTheme,
}

MessageReference :: struct {
	type:               int,
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
	type:     int,
	party_id: string,
}

MessageCall :: struct {
	participants:    []Snowflake,
	ended_timestamp: Snowflake,
}

ChannelMention :: struct {
	id:       Snowflake,
	guild_id: Snowflake,
	type:     int,
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
	triggering_interaction_metadata: ^MessageInteractionMetadata,
	target_user:                     User,
	target_message_id:               Snowflake,
}

Poll :: struct {
	question:          PollMedia,
	answers:           []PollAnswer,
	expiry:            Snowflake,
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
	primary_color:   u32,
	gradient_preset: int,
}

MessageUpdateArgs :: struct {
	before: Message,
	after: Message,
}

MessageDeleteEvent :: struct {
	id: Snowflake,
	channel_id: Snowflake,
	guild_id: Snowflake,
}