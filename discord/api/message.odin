package discord_api

import "core:encoding/json"
import "core:fmt"
import "core:reflect"
import "core:strings"

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
	timestamp:        string,
	edited_timestamp: string,
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
EPHEMERAL :: MessageFlags(1 << 6)
LOADING :: MessageFlags(1 << 7)
FAILED_TO_MENTION_SOME_ROLES_IN_THREAD :: MessageFlags(1 << 8)
SUPPRESS_NOTIFICATIONS :: MessageFlags(1 << 12)
IS_VOICE_MESSAGE :: MessageFlags(1 << 13)
HAS_SNAPSHOT :: MessageFlags(1 << 14)
IS_COMPONENTS_V2 :: MessageFlags(1 << 15)

MessageCreate :: struct {
	content:           Maybe(string)            `json:"content,omitempty"`,
	nonce:             Maybe(union{i64, string}) `json:"nonce,omitempty"`,
	tts:               Maybe(bool)              `json:"tts,omitempty"`,
	embeds:            []Embed                  `json:"embeds,omitempty"`,
	allowed_mentions:  Maybe(AllowedMentions)   `json:"allowed_mentions,omitempty"`,
	message_reference: Maybe(MessageReference)  `json:"message_reference,omitempty"`,
	components:        []Component              `json:"components,omitempty"`,
	sticker_ids:       []Snowflake              `json:"sticker_ids,omitempty"`,
	attachments:       []Attachment             `json:"attachments,omitempty"`,
	flags:             Maybe(int)               `json:"flags,omitempty"`,
	enforce_nonce:     Maybe(bool)              `json:"enforce_nonce,omitempty"`,
	poll:              Maybe(PollCreateRequest) `json:"poll,omitempty"`,
}

MessageEdit :: struct {
	content:          Maybe(string)           `json:"content,omitempty"`,
	embeds:           []Embed                 `json:"embeds,omitempty"`,
	flags:            Maybe(int)              `json:"flags,omitempty"`,
	allowed_mentions: Maybe(AllowedMentions)  `json:"allowed_mentions,omitempty"`,
	components:       []Component             `json:"components,omitempty"`,
	attachments:      []Attachment            `json:"attachments,omitempty"`,
}

BulkDeleteRequest :: struct {
	messages: []Snowflake `json:"messages"`,
}

GetMessagesParams :: struct {
	around: Maybe(Snowflake),
	before: Maybe(Snowflake),
	after:  Maybe(Snowflake),
	limit:  Maybe(int),
}

GetReactionsParams :: struct {
	type:  Maybe(int),
	after: Maybe(Snowflake),
	limit: Maybe(int),
}

GetPinsParams :: struct {
	before: Maybe(string),
	limit:  Maybe(int),
}

PinsResponse :: struct {
	items:    []PinsResponseItem `json:"items"`,
	has_more: bool               `json:"has_more"`,
}

PinsResponseItem :: struct {
	message_id:       Snowflake `json:"message_id"`,
	channel_id:       Snowflake `json:"channel_id"`,
	guild_id:         Snowflake `json:"guild_id,omitempty"`,
	author_id:        Snowflake `json:"author_id"`,
	created_timestamp: string   `json:"created_timestamp"`,
}

SearchMessagesResponse :: struct {
	doing_deep_historical_index: bool                `json:"doing_deep_historical_index"`,
	total_results:               int                 `json:"total_results"`,
	messages:                    [][]Message         `json:"messages"`,
	threads:                     []Channel           `json:"threads,omitempty"`,
	members:                     []GuildMember      `json:"members,omitempty"`,
}

SearchMessagesParams :: struct {
	content:              Maybe(string)    `args:"name=content"`,
	author_id:            []Snowflake,
	author_type:          []string,
	mentions:             []Snowflake,
	mentions_role_id:     []Snowflake,
	mention_everyone:     Maybe(bool),
	replied_to_user_id:   []Snowflake,
	replied_to_message_id: []Snowflake,
	pinned:               Maybe(bool),
	has:                  []string,
	embed_type:           []string,
	embed_provider:       []string,
	link_hostname:        []string,
	attachment_filename:  []string,
	attachment_extension: []string,
	channel_id:           []Snowflake,
	max_id:               Maybe(Snowflake),
	min_id:               Maybe(Snowflake),
	limit:                Maybe(int),
	offset:               Maybe(int),
	slop:                 Maybe(int),
	sort_by:              Maybe(string),
	sort_order:           Maybe(string),
	include_nsfw:         Maybe(bool),
}

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

// --- Message REST API Procedures ---

get_channel_messages :: proc(
	client: ^Discord_Client,
	channel_id: Snowflake,
	params: ^GetMessagesParams = nil,
) -> (
	[]Message,
	bool,
) {
	endpoint := fmt.tprintf("/channels/%s/messages", channel_id)
	endpoint = _append_query_params(endpoint, params)
	return discord_request([]Message, client, endpoint)
}

get_channel_message :: proc(
	client: ^Discord_Client,
	channel_id: Snowflake,
	message_id: Snowflake,
) -> (
	Message,
	bool,
) {
	endpoint := fmt.tprintf("/channels/%s/messages/%s", channel_id, message_id)
	return discord_request(Message, client, endpoint)
}

create_message :: proc(
	client: ^Discord_Client,
	channel_id: Snowflake,
	data: MessageCreate,
) -> (
	Message,
	bool,
) {
	body, err := json.marshal(data, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal create_message: %v", err)
		return {}, false
	}
	endpoint := fmt.tprintf("/channels/%s/messages", channel_id)
	resp, ok := discord_post(client, endpoint, body)
	if !ok do return {}, false
	defer delete(resp.body)
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("create_message got HTTP %d: %s", resp.status_code, string(resp.body))
		return {}, false
	}
	result: Message
	if err := json.unmarshal(resp.body, &result); err != nil {
		fmt.eprintfln("create_message unmarshal failed: %v", err)
		return {}, false
	}
	return result, true
}

crosspost_message :: proc(
	client: ^Discord_Client,
	channel_id: Snowflake,
	message_id: Snowflake,
) -> (
	Message,
	bool,
) {
	endpoint := fmt.tprintf("/channels/%s/messages/%s/crosspost", channel_id, message_id)
	return discord_request(Message, client, Http_Method.POST, endpoint)
}

edit_message :: proc(
	client: ^Discord_Client,
	channel_id: Snowflake,
	message_id: Snowflake,
	data: MessageEdit,
) -> (
	Message,
	bool,
) {
	body, err := json.marshal(data, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal edit_message: %v", err)
		return {}, false
	}
	endpoint := fmt.tprintf("/channels/%s/messages/%s", channel_id, message_id)
	resp, ok := discord_patch(client, endpoint, body)
	if !ok do return {}, false
	defer delete(resp.body)
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("edit_message got HTTP %d: %s", resp.status_code, string(resp.body))
		return {}, false
	}
	result: Message
	if err := json.unmarshal(resp.body, &result); err != nil {
		fmt.eprintfln("edit_message unmarshal failed: %v", err)
		return {}, false
	}
	return result, true
}

delete_message :: proc(
	client: ^Discord_Client,
	channel_id: Snowflake,
	message_id: Snowflake,
) -> bool {
	endpoint := fmt.tprintf("/channels/%s/messages/%s", channel_id, message_id)
	resp, ok := discord_delete(client, endpoint)
	if ok do delete(resp.body)
	return ok
}

bulk_delete_messages :: proc(
	client: ^Discord_Client,
	channel_id: Snowflake,
	message_ids: []Snowflake,
) -> bool {
	req := BulkDeleteRequest{messages = message_ids}
	body, err := json.marshal(req, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal bulk_delete: %v", err)
		return false
	}
	endpoint := fmt.tprintf("/channels/%s/messages/bulk-delete", channel_id)
	resp, ok := discord_post(client, endpoint, body)
	if !ok do return false
	defer delete(resp.body)
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("bulk_delete got HTTP %d: %s", resp.status_code, string(resp.body))
		return false
	}
	return true
}

// --- Reactions ---

create_reaction :: proc(
	client: ^Discord_Client,
	channel_id: Snowflake,
	message_id: Snowflake,
	emoji: string,
) -> bool {
	enc := _url_encode_emoji(emoji)
	endpoint := fmt.tprintf("/channels/%s/messages/%s/reactions/%s/@me", channel_id, message_id, enc)
	resp, ok := discord_put(client, endpoint, {})
	if ok do delete(resp.body)
	return ok
}

delete_own_reaction :: proc(
	client: ^Discord_Client,
	channel_id: Snowflake,
	message_id: Snowflake,
	emoji: string,
) -> bool {
	enc := _url_encode_emoji(emoji)
	endpoint := fmt.tprintf("/channels/%s/messages/%s/reactions/%s/@me", channel_id, message_id, enc)
	resp, ok := discord_delete(client, endpoint)
	if ok do delete(resp.body)
	return ok
}

delete_user_reaction :: proc(
	client: ^Discord_Client,
	channel_id: Snowflake,
	message_id: Snowflake,
	emoji: string,
	user_id: Snowflake,
) -> bool {
	enc := _url_encode_emoji(emoji)
	endpoint := fmt.tprintf("/channels/%s/messages/%s/reactions/%s/%s", channel_id, message_id, enc, user_id)
	resp, ok := discord_delete(client, endpoint)
	if ok do delete(resp.body)
	return ok
}

get_reactions :: proc(
	client: ^Discord_Client,
	channel_id: Snowflake,
	message_id: Snowflake,
	emoji: string,
	params: ^GetReactionsParams = nil,
) -> (
	[]User,
	bool,
) {
	enc := _url_encode_emoji(emoji)
	endpoint := fmt.tprintf("/channels/%s/messages/%s/reactions/%s", channel_id, message_id, enc)
	endpoint = _append_query_params(endpoint, params)
	return discord_request([]User, client, endpoint)
}

delete_all_reactions :: proc(
	client: ^Discord_Client,
	channel_id: Snowflake,
	message_id: Snowflake,
) -> bool {
	endpoint := fmt.tprintf("/channels/%s/messages/%s/reactions", channel_id, message_id)
	resp, ok := discord_delete(client, endpoint)
	if ok do delete(resp.body)
	return ok
}

delete_all_reactions_for_emoji :: proc(
	client: ^Discord_Client,
	channel_id: Snowflake,
	message_id: Snowflake,
	emoji: string,
) -> bool {
	enc := _url_encode_emoji(emoji)
	endpoint := fmt.tprintf("/channels/%s/messages/%s/reactions/%s", channel_id, message_id, enc)
	resp, ok := discord_delete(client, endpoint)
	if ok do delete(resp.body)
	return ok
}

// --- Pins ---

get_channel_pins :: proc(
	client: ^Discord_Client,
	channel_id: Snowflake,
	params: ^GetPinsParams = nil,
) -> (
	PinsResponse,
	bool,
) {
	endpoint := fmt.tprintf("/channels/%s/messages/pins", channel_id)
	endpoint = _append_query_params(endpoint, params)
	return discord_request(PinsResponse, client, endpoint)
}

pin_message :: proc(
	client: ^Discord_Client,
	channel_id: Snowflake,
	message_id: Snowflake,
) -> bool {
	endpoint := fmt.tprintf("/channels/%s/messages/pins/%s", channel_id, message_id)
	resp, ok := discord_put(client, endpoint, {})
	if ok do delete(resp.body)
	return ok
}

unpin_message :: proc(
	client: ^Discord_Client,
	channel_id: Snowflake,
	message_id: Snowflake,
) -> bool {
	endpoint := fmt.tprintf("/channels/%s/messages/pins/%s", channel_id, message_id)
	resp, ok := discord_delete(client, endpoint)
	if ok do delete(resp.body)
	return ok
}

// --- Search ---

search_guild_messages :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	params: ^SearchMessagesParams,
) -> (
	SearchMessagesResponse,
	bool,
) {
	endpoint := fmt.tprintf("/guilds/%s/messages/search", guild_id)
	endpoint = _append_query_params(endpoint, params)
	return discord_request(SearchMessagesResponse, client, endpoint)
}

// --- Internal Helpers ---

@(private)
_url_encode_emoji :: proc(emoji: string, allocator := context.temp_allocator) -> string {
	b := strings.Builder{}
	strings.builder_init(&b, allocator)
	for byte_val in emoji {
		ch := byte(byte_val)
		if (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9') || ch == ':' || ch == '-' || ch == '_' {
			strings.write_byte(&b, ch)
		} else {
			fmt.sbprintf(&b, "%%%02X", ch)
		}
	}
	return strings.to_string(b)
}

@(private)
_append_query_params :: proc(endpoint: string, params: ^$T) -> string {
	if params == nil do return endpoint

	ti := type_info_of(T)
	info := reflect.type_info_base(ti)
	struct_info, is_struct := info.variant.(reflect.Type_Info_Struct)
	if !is_struct || struct_info.field_count == 0 do return endpoint

	b := strings.Builder{}
	strings.builder_init(&b, context.temp_allocator)
	strings.write_string(&b, endpoint)

	first := true

	for field_idx in 0 ..< struct_info.field_count {
		field_ptr := rawptr(uintptr(params) + struct_info.offsets[field_idx])
		field_name := struct_info.names[field_idx]
		field_ti := struct_info.types[field_idx]

		if field_ti.id == typeid_of(Maybe(string)) {
			val := (^Maybe(string))(field_ptr)
			if v, ok := val.?; ok {
				if first {
					strings.write_byte(&b, '?')
					first = false
				} else {
					strings.write_byte(&b, '&')
				}
				fmt.sbprintf(&b, "%s=%s", field_name, v)
			}
		} else if field_ti.id == typeid_of(Maybe(int)) {
			val := (^Maybe(int))(field_ptr)
			if v, ok := val.?; ok {
				if first {
					strings.write_byte(&b, '?')
					first = false
				} else {
					strings.write_byte(&b, '&')
				}
				fmt.sbprintf(&b, "%s=%d", field_name, v)
			}
		} else if field_ti.id == typeid_of(Maybe(bool)) {
			val := (^Maybe(bool))(field_ptr)
			if v, ok := val.?; ok {
				if first {
					strings.write_byte(&b, '?')
					first = false
				} else {
					strings.write_byte(&b, '&')
				}
				fmt.sbprintf(&b, "%s=%v", field_name, v)
			}
		} else if field_ti.id == typeid_of(Maybe(Snowflake)) {
			val := (^Maybe(Snowflake))(field_ptr)
			if v, ok := val.?; ok && v != "" {
				if first {
					strings.write_byte(&b, '?')
					first = false
				} else {
					strings.write_byte(&b, '&')
				}
				fmt.sbprintf(&b, "%s=%s", field_name, v)
			}
		} else if field_ti.id == typeid_of([]Snowflake) {
			slice := (^[]Snowflake)(field_ptr)
			for _, id in slice {
				if first {
					strings.write_byte(&b, '?')
					first = false
				} else {
					strings.write_byte(&b, '&')
				}
				fmt.sbprintf(&b, "%s=%s", field_name, id)
			}
		} else if field_ti.id == typeid_of([]string) {
			slice := (^[]string)(field_ptr)
			for _, s in slice {
				if first {
					strings.write_byte(&b, '?')
					first = false
				} else {
					strings.write_byte(&b, '&')
				}
				fmt.sbprintf(&b, "%s=%s", field_name, s)
			}
		}
	}

	return strings.to_string(b)
}
