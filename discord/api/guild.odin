package discord_api

import "core:encoding/json"
import "core:fmt"

VerificationLevel :: enum i32 {
	NONE,
	LOW,
	MEDIUM,
	HIGH,
	VERY_HIGH,
}

DefaultMessageNotificationLevel :: enum i32 {
	ALL_MESSAGES,
	ONLY_MENTIONS,
}

ExplicitContentFilterLevel :: enum i32 {
	DISABLED,
	MEMBERS_WITHOUT_ROLES,
	ALL_MEMBERS,
}

MFALevel :: enum i32 {
	NONE,
	ELEVATED,
}

NSFWLevel :: enum i32 {
	DEFAULT,
	EXPLICIT,
	SAFE,
	AGE_RESTRICTED,
}

PremiumTier :: enum i32 {
	NONE,
	TIER_1,
	TIER_2,
	TIER_3,
}

Guild :: struct {
	id:                            Snowflake,
	name:                          string,
	icon:                          string,
	icon_hash:                     string,
	splash:                        string,
	discovery_splash:              string,
	owner:                         bool,
	owner_id:                      Snowflake,
	permissions:                   string,
	region:                        string,
	afk_channel_id:                Snowflake,
	afk_timeout:                   int,
	widget_enabled:                bool,
	widget_channel_id:             Snowflake,
	verification_level:            VerificationLevel,
	default_message_notifications: DefaultMessageNotificationLevel,
	explicit_content_filter:       ExplicitContentFilterLevel,
	roles:                         []Role,
	emojis:                        []Emoji,
	features:                      []string,
	mfa_level:                     MFALevel,
	application_id:                Snowflake,
	system_channel_id:             Snowflake,
	system_channel_flags:          u32,
	rules_channel_id:              Snowflake,
	max_presences:                 int,
	max_members:                   int,
	vanity_url_code:               string,
	description:                   string,
	banner:                        string,
	premium_tier:                  PremiumTier,
	premium_subscription_count:    int,
	preferred_locale:              string,
	public_updates_channel_id:     Snowflake,
	max_video_channel_users:       int,
	max_stage_video_channel_users: int,
	member_count:                  int,
	approximate_member_count:      int,
	approximate_presence_count:    int,
	welcome_screen:                WelcomeScreen,
	nsfw_level:                    NSFWLevel,
	stickers:                      []Sticker,
	premium_progress_bar_enabled:  bool,
	safety_alerts_channel_id:      Snowflake,
	incidents_data:                IncidentsData,
}

IncidentsData :: struct {
	invites_disabled_until: string,
	dms_disabled_until:     string,
	dm_spam_detected_at:    string,
	raid_detected_at:       string,
}

GuildPreview :: struct {
	id:                         Snowflake,
	name:                       string,
	icon:                       string,
	splash:                     string,
	discovery_splash:           string,
	emojis:                     []Emoji,
	features:                   []string,
	approximate_member_count:   int,
	approximate_presence_count: int,
	description:                string,
	stickers:                   []Sticker,
}

GuildMember :: struct {
	user:                         User,
	nick:                         string,
	avatar:                       string,
	banner:                       string,
	roles:                        []Snowflake,
	joined_at:                    string,
	premium_since:                string,
	deaf:                         bool,
	mute:                         bool,
	flags:                        GuildMemberFlags,
	pending:                      bool,
	permissions:                  string,
	communication_disabled_until: string,
	avatar_decoration_data:       AvatarDecorationData,
	collectibles:                 Collectibles,
}

RoleColors :: struct {
	primary_color:   int,
	secondary_color: int,
	tertiary_color:  int,
}

Role :: struct {
	id:            Snowflake,
	name:          string,
	color:         int,
	colors:        RoleColors,
	hoist:         bool,
	icon:          string,
	unicode_emoji: string,
	position:      int,
	permissions:   string,
	managed:       bool,
	mentionable:   bool,
	tags:          RoleTags,
	flags:         RoleFlags,
}

RoleTags :: struct {
	bot_id:                  Snowflake,
	integration_id:          Snowflake,
	subscription_listing_id: Snowflake,
	available_for_purchase:  bool,
	guild_connections:       bool,
}

WelcomeScreen :: struct {
	description:      string,
	welcome_channels: []WelcomeScreenChannel,
}

WelcomeScreenChannel :: struct {
	channel_id:  Snowflake,
	description: string,
	emoji_id:    Snowflake,
	emoji_name:  string,
}

GuildWidgetSettings :: struct {
	enabled:    bool,
	channel_id: Snowflake,
}

GuildWidget :: struct {
	id:             Snowflake,
	name:           string,
	instant_invite: string,
	channels:       []WidgetChannel,
	members:        []WidgetMember,
	presence_count: int,
}

WidgetChannel :: struct {
	id:       Snowflake,
	name:     string,
	position: int,
}

WidgetMember :: struct {
	id:            Snowflake,
	username:      string,
	discriminator: string,
	avatar:        string,
	status:        string,
	avatar_url:    string,
}

Ban :: struct {
	reason: string,
	user:   User,
}

BulkBanResponse :: struct {
	banned_users: []Snowflake,
	failed_users: []Snowflake,
}

Integration :: struct {
	id:                  Snowflake,
	name:                string,
	type:                string,
	enabled:             bool,
	syncing:             bool,
	role_id:             Snowflake,
	enable_emoticons:    bool,
	expire_behavior:     IntegrationExpireBehavior,
	expire_grace_period: int,
	user:                User,
	account:             IntegrationAccount,
	synced_at:           string,
	subscriber_count:    int,
	revoked:             bool,
	application:         IntegrationApplication,
	scopes:              []string,
}

IntegrationAccount :: struct {
	id:   string,
	name: string,
}

IntegrationApplication :: struct {
	id:          Snowflake,
	name:        string,
	icon:        string,
	description: string,
	bot:         User,
}

GuildOnboarding :: struct {
	guild_id:            Snowflake,
	prompts:             []OnboardingPrompt,
	default_channel_ids: []Snowflake,
	enabled:             bool,
	mode:                OnboardingMode,
}

OnboardingPrompt :: struct {
	id:            Snowflake,
	type:          OnboardingPromptType,
	options:       []OnboardingPromptOption,
	title:         string,
	single_select: bool,
	required:      bool,
	in_onboarding: bool,
}

OnboardingPromptOption :: struct {
	id:              Snowflake,
	channel_ids:     []Snowflake,
	role_ids:        []Snowflake,
	emoji:           Emoji,
	emoji_id:        Snowflake,
	emoji_name:      string,
	emoji_animatied: bool,
	title:           string,
	description:     string,
}

PartialUser :: struct {
	id:                Snowflake,
	username:          string,
	discriminator:     string,
	global_name:       string,
	avatar:            string,
	bot:               bool,
	system:            bool,
	mfa_enabled:       bool,
	banner:            string,
	accent_color:      int,
	locale:            string,
	verified:          bool,
	email:             string,
	flags:             int,
	premium_type:      int,
	public_flags:      int,
	avatar_decoration: string,
}

IntegrationExpireBehavior :: enum i32 {
	REMOVE_ROLE,
	KICK,
}

OnboardingMode :: enum i32 {
	ONBOARDING_DEFAULT,
	ONBOARDING_ADVANCED,
}

OnboardingPromptType :: enum i32 {
	MULTIPLE_CHOICE,
	DROPDOWN,
}

SystemChannelFlags :: distinct u64
GuildMemberFlags :: distinct u64
RoleFlags :: distinct u64

IN_PROMPT :: RoleFlags(1 << 0)

SUPPRESS_JOIN_NOTIFICATIONS :: SystemChannelFlags(1 << 0)
SUPPRESS_PREMIUM_SUBSCRIPTIONS :: SystemChannelFlags(1 << 1)
SUPPRESS_GUILD_REMINDER_NOTIFICATIONS :: SystemChannelFlags(1 << 2)
SUPPRESS_JOIN_NOTIFICATION_REPLIES :: SystemChannelFlags(1 << 3)
SUPPRESS_ROLE_SUBSCRIPTION_PURCHASE_NOTIFICATIONS :: SystemChannelFlags(1 << 4)
SUPPRESS_ROLE_SUBSCRIPTION_PURCHASE_NOTIFICATION_REPLIES :: SystemChannelFlags(1 << 5)

DID_REJOIN :: GuildMemberFlags(1 << 0)
COMPLETED_ONBOARDING :: GuildMemberFlags(1 << 1)
BYPASSES_VERIFICATION :: GuildMemberFlags(1 << 2)
STARTED_ONBOARDING :: GuildMemberFlags(1 << 3)
IS_GUEST :: GuildMemberFlags(1 << 4)
STARTED_HOME_ACTIONS :: GuildMemberFlags(1 << 5)
COMPLETED_HOME_ACTIONS :: GuildMemberFlags(1 << 6)
AUTOMOD_QUARANTINED_USERNAME :: GuildMemberFlags(1 << 7)
DM_SETTINGS_UPSELL_ACKNOWLEDGED :: GuildMemberFlags(1 << 9)
AUTOMOD_QUARANTINED_GUILD_TAG :: GuildMemberFlags(1 << 10)

// --- Request/Response Types ---

GetGuildParams :: struct {
	with_counts: Maybe(bool),
}

ModifyGuildParams :: struct {
	name:                       Maybe(string)               `json:"name,omitempty"`,
	verification_level:         Maybe(VerificationLevel)    `json:"verification_level,omitempty"`,
	default_message_notifications: Maybe(DefaultMessageNotificationLevel) `json:"default_message_notifications,omitempty"`,
	explicit_content_filter:    Maybe(ExplicitContentFilterLevel) `json:"explicit_content_filter,omitempty"`,
	afk_channel_id:             Maybe(Snowflake)            `json:"afk_channel_id,omitempty"`,
	afk_timeout:                Maybe(int)                  `json:"afk_timeout,omitempty"`,
	icon:                       Maybe(string)               `json:"icon,omitempty"`,
	splash:                     Maybe(string)               `json:"splash,omitempty"`,
	banner:                     Maybe(string)               `json:"banner,omitempty"`,
	system_channel_id:          Maybe(Snowflake)            `json:"system_channel_id,omitempty"`,
	system_channel_flags:       Maybe(SystemChannelFlags)   `json:"system_channel_flags,omitempty"`,
	rules_channel_id:           Maybe(Snowflake)            `json:"rules_channel_id,omitempty"`,
	public_updates_channel_id:  Maybe(Snowflake)            `json:"public_updates_channel_id,omitempty"`,
	preferred_locale:           Maybe(string)               `json:"preferred_locale,omitempty"`,
	description:                Maybe(string)               `json:"description,omitempty"`,
	premium_progress_bar_enabled: Maybe(bool)               `json:"premium_progress_bar_enabled,omitempty"`,
	safety_alerts_channel_id:   Maybe(Snowflake)            `json:"safety_alerts_channel_id,omitempty"`,
}

CreateGuildChannelParams :: struct {
	name:                      string                      `json:"name"`,
	type:                      Maybe(ChannelType)          `json:"type,omitempty"`,
	topic:                     Maybe(string)               `json:"topic,omitempty"`,
	bitrate:                   Maybe(int)                  `json:"bitrate,omitempty"`,
	user_limit:                Maybe(int)                  `json:"user_limit,omitempty"`,
	rate_limit_per_user:       Maybe(int)                  `json:"rate_limit_per_user,omitempty"`,
	position:                  Maybe(int)                  `json:"position,omitempty"`,
	permission_overwrites:     []Overwrite                 `json:"permission_overwrites,omitempty"`,
	parent_id:                 Maybe(Snowflake)            `json:"parent_id,omitempty"`,
	nsfw:                      Maybe(bool)                 `json:"nsfw,omitempty"`,
	rtc_region:                Maybe(string)               `json:"rtc_region,omitempty"`,
	video_quality_mode:        Maybe(VideoQualityMode)     `json:"video_quality_mode,omitempty"`,
	default_auto_archive_duration: Maybe(int)              `json:"default_auto_archive_duration,omitempty"`,
}

GuildChannelPosition :: struct {
	id:              Snowflake    `json:"id"`,
	position:        Maybe(int)   `json:"position,omitempty"`,
	lock_permissions: Maybe(bool) `json:"lock_permissions,omitempty"`,
	parent_id:       Maybe(Snowflake) `json:"parent_id,omitempty"`,
}

ActiveThreadsResponse :: struct {
	threads: []Channel       `json:"threads"`,
	members: []ThreadMember  `json:"members"`,
}

ListGuildMembersParams :: struct {
	limit: Maybe(int),
	after: Maybe(Snowflake),
}

SearchGuildMembersParams :: struct {
	query: string,
	limit: Maybe(int),
}

AddGuildMemberParams :: struct {
	access_token: string       `json:"access_token"`,
	nick:         Maybe(string) `json:"nick,omitempty"`,
	roles:        []Snowflake   `json:"roles,omitempty"`,
	mute:         Maybe(bool)   `json:"mute,omitempty"`,
	deaf:         Maybe(bool)   `json:"deaf,omitempty"`,
}

ModifyGuildMemberParams :: struct {
	nick:                        Maybe(string)  `json:"nick,omitempty"`,
	roles:                       []Snowflake    `json:"roles,omitempty"`,
	mute:                        Maybe(bool)    `json:"mute,omitempty"`,
	deaf:                        Maybe(bool)    `json:"deaf,omitempty"`,
	channel_id:                  Maybe(Snowflake) `json:"channel_id,omitempty"`,
	communication_disabled_until: Maybe(string) `json:"communication_disabled_until,omitempty"`,
	flags:                       Maybe(GuildMemberFlags) `json:"flags,omitempty"`,
}

ModifyCurrentMemberParams :: struct {
	nick:   Maybe(string) `json:"nick,omitempty"`,
	banner: Maybe(string) `json:"banner,omitempty"`,
	avatar: Maybe(string) `json:"avatar,omitempty"`,
	bio:    Maybe(string) `json:"bio,omitempty"`,
}

GetGuildBansParams :: struct {
	limit:  Maybe(int),
	before: Maybe(Snowflake),
	after:  Maybe(Snowflake),
}

CreateGuildBanParams :: struct {
	delete_message_seconds: Maybe(int) `json:"delete_message_seconds,omitempty"`,
}

BulkGuildBanParams :: struct {
	user_ids:              []Snowflake `json:"user_ids"`,
	delete_message_seconds: Maybe(int) `json:"delete_message_seconds,omitempty"`,
}

CreateGuildRoleParams :: struct {
	name:          Maybe(string) `json:"name,omitempty"`,
	permissions:   Maybe(string) `json:"permissions,omitempty"`,
	color:         Maybe(int)    `json:"color,omitempty"`,
	colors:        Maybe(RoleColors) `json:"colors,omitempty"`,
	hoist:         Maybe(bool)   `json:"hoist,omitempty"`,
	icon:          Maybe(string) `json:"icon,omitempty"`,
	unicode_emoji: Maybe(string) `json:"unicode_emoji,omitempty"`,
	mentionable:   Maybe(bool)   `json:"mentionable,omitempty"`,
}

ModifyGuildRoleParams :: struct {
	name:          Maybe(string) `json:"name,omitempty"`,
	permissions:   Maybe(string) `json:"permissions,omitempty"`,
	color:         Maybe(int)    `json:"color,omitempty"`,
	colors:        Maybe(RoleColors) `json:"colors,omitempty"`,
	hoist:         Maybe(bool)   `json:"hoist,omitempty"`,
	icon:          Maybe(string) `json:"icon,omitempty"`,
	unicode_emoji: Maybe(string) `json:"unicode_emoji,omitempty"`,
	mentionable:   Maybe(bool)   `json:"mentionable,omitempty"`,
}

GuildRolePosition :: struct {
	id:       Snowflake `json:"id"`,
	position: Maybe(int) `json:"position,omitempty"`,
}

PruneCountResponse :: struct {
	pruned: int `json:"pruned"`,
}

GetGuildPruneCountParams :: struct {
	days:          Maybe(int),
	include_roles: Maybe(string),
}

BeginGuildPruneParams :: struct {
	days:                Maybe(int)   `json:"days,omitempty"`,
	compute_prune_count: Maybe(bool)  `json:"compute_prune_count,omitempty"`,
	include_roles:       []Snowflake  `json:"include_roles,omitempty"`,
}

ModifyGuildWidgetParams :: struct {
	enabled:    Maybe(bool)    `json:"enabled,omitempty"`,
	channel_id: Maybe(Snowflake) `json:"channel_id,omitempty"`,
}

ModifyWelcomeScreenParams :: struct {
	enabled:         Maybe(bool)                `json:"enabled,omitempty"`,
	welcome_channels: []WelcomeScreenChannel    `json:"welcome_channels,omitempty"`,
	description:     Maybe(string)              `json:"description,omitempty"`,
}

ModifyGuildOnboardingParams :: struct {
	prompts:             []OnboardingPrompt `json:"prompts,omitempty"`,
	default_channel_ids: []Snowflake        `json:"default_channel_ids,omitempty"`,
	enabled:             bool               `json:"enabled"`,
	mode:                OnboardingMode     `json:"mode"`,
}

ModifyIncidentActionsParams :: struct {
	invites_disabled_until: Maybe(string) `json:"invites_disabled_until,omitempty"`,
	dms_disabled_until:     Maybe(string) `json:"dms_disabled_until,omitempty"`,
}

VanityUrlResponse :: struct {
	code: string `json:"code"`,
	uses: int    `json:"uses"`,
}

RoleMemberCountsResponse :: struct {
	// map of role_id -> count, use []RoleMemberCountEntry for JSON
}

// --- Guild REST API Procedures ---

get_guild :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	params: ^GetGuildParams = nil,
) -> (
	Guild,
	bool,
) {
	endpoint := fmt.tprintf("/guilds/%s", guild_id)
	endpoint = _append_query_params(endpoint, params)
	return discord_request(Guild, client, endpoint)
}

get_guild_preview :: proc(client: ^Discord_Client, guild_id: Snowflake) -> (GuildPreview, bool) {
	endpoint := fmt.tprintf("/guilds/%s/preview", guild_id)
	return discord_request(GuildPreview, client, endpoint)
}

modify_guild :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	params: ModifyGuildParams,
) -> (
	Guild,
	bool,
) {
	body, err := json.marshal(params, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal modify_guild: %v", err)
		return {}, false
	}
	endpoint := fmt.tprintf("/guilds/%s", guild_id)
	resp, ok := discord_patch(client, endpoint, body)
	if !ok do return {}, false
	defer delete(resp.body)
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("modify_guild got HTTP %d: %s", resp.status_code, string(resp.body))
		return {}, false
	}
	result: Guild
	if err := json.unmarshal(resp.body, &result); err != nil {
		fmt.eprintfln("modify_guild unmarshal failed: %v", err)
		return {}, false
	}
	return result, true
}

get_guild_channels :: proc(client: ^Discord_Client, guild_id: Snowflake) -> ([]Channel, bool) {
	endpoint := fmt.tprintf("/guilds/%s/channels", guild_id)
	return discord_request([]Channel, client, endpoint)
}

create_guild_channel :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	params: CreateGuildChannelParams,
) -> (
	Channel,
	bool,
) {
	body, err := json.marshal(params, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal create_guild_channel: %v", err)
		return {}, false
	}
	endpoint := fmt.tprintf("/guilds/%s/channels", guild_id)
	resp, ok := discord_post(client, endpoint, body)
	if !ok do return {}, false
	defer delete(resp.body)
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("create_guild_channel got HTTP %d: %s", resp.status_code, string(resp.body))
		return {}, false
	}
	result: Channel
	if err := json.unmarshal(resp.body, &result); err != nil {
		fmt.eprintfln("create_guild_channel unmarshal failed: %v", err)
		return {}, false
	}
	return result, true
}

modify_guild_channel_positions :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	positions: []GuildChannelPosition,
) -> bool {
	body, err := json.marshal(positions, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal channel positions: %v", err)
		return false
	}
	endpoint := fmt.tprintf("/guilds/%s/channels", guild_id)
	resp, ok := discord_patch(client, endpoint, body)
	if ok do delete(resp.body)
	return ok
}

list_active_guild_threads :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
) -> (
	ActiveThreadsResponse,
	bool,
) {
	endpoint := fmt.tprintf("/guilds/%s/threads/active", guild_id)
	return discord_request(ActiveThreadsResponse, client, endpoint)
}

get_guild_member :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	user_id: Snowflake,
) -> (
	GuildMember,
	bool,
) {
	endpoint := fmt.tprintf("/guilds/%s/members/%s", guild_id, user_id)
	return discord_request(GuildMember, client, endpoint)
}

list_guild_members :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	params: ^ListGuildMembersParams = nil,
) -> (
	[]GuildMember,
	bool,
) {
	endpoint := fmt.tprintf("/guilds/%s/members", guild_id)
	endpoint = _append_query_params(endpoint, params)
	return discord_request([]GuildMember, client, endpoint)
}

search_guild_members :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	params: SearchGuildMembersParams,
) -> (
	[]GuildMember,
	bool,
) {
	endpoint := fmt.tprintf("/guilds/%s/members/search?query=%s", guild_id, params.query)
	if l, ok := params.limit.?; ok {
		endpoint = fmt.tprintf("%s&limit=%d", endpoint, l)
	}
	return discord_request([]GuildMember, client, endpoint)
}

add_guild_member :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	user_id: Snowflake,
	params: AddGuildMemberParams,
) -> (
	GuildMember,
	bool,
) {
	body, err := json.marshal(params, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal add_guild_member: %v", err)
		return {}, false
	}
	endpoint := fmt.tprintf("/guilds/%s/members/%s", guild_id, user_id)
	resp, ok := discord_put(client, endpoint, body)
	if !ok do return {}, false
	defer delete(resp.body)
	if resp.status_code == 204 do return GuildMember{}, true
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("add_guild_member got HTTP %d: %s", resp.status_code, string(resp.body))
		return {}, false
	}
	result: GuildMember
	if err := json.unmarshal(resp.body, &result); err != nil {
		fmt.eprintfln("add_guild_member unmarshal failed: %v", err)
		return {}, false
	}
	return result, true
}

modify_guild_member :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	user_id: Snowflake,
	params: ModifyGuildMemberParams,
) -> (
	GuildMember,
	bool,
) {
	body, err := json.marshal(params, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal modify_guild_member: %v", err)
		return {}, false
	}
	endpoint := fmt.tprintf("/guilds/%s/members/%s", guild_id, user_id)
	resp, ok := discord_patch(client, endpoint, body)
	if !ok do return {}, false
	defer delete(resp.body)
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("modify_guild_member got HTTP %d: %s", resp.status_code, string(resp.body))
		return {}, false
	}
	result: GuildMember
	if err := json.unmarshal(resp.body, &result); err != nil {
		fmt.eprintfln("modify_guild_member unmarshal failed: %v", err)
		return {}, false
	}
	return result, true
}

modify_current_member :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	params: ModifyCurrentMemberParams,
) -> (
	GuildMember,
	bool,
) {
	body, err := json.marshal(params, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal modify_current_member: %v", err)
		return {}, false
	}
	endpoint := fmt.tprintf("/guilds/%s/members/@me", guild_id)
	resp, ok := discord_patch(client, endpoint, body)
	if !ok do return {}, false
	defer delete(resp.body)
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("modify_current_member got HTTP %d: %s", resp.status_code, string(resp.body))
		return {}, false
	}
	result: GuildMember
	if err := json.unmarshal(resp.body, &result); err != nil {
		fmt.eprintfln("modify_current_member unmarshal failed: %v", err)
		return {}, false
	}
	return result, true
}

add_guild_member_role :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	user_id: Snowflake,
	role_id: Snowflake,
) -> bool {
	endpoint := fmt.tprintf("/guilds/%s/members/%s/roles/%s", guild_id, user_id, role_id)
	resp, ok := discord_put(client, endpoint, {})
	if ok do delete(resp.body)
	return ok
}

remove_guild_member_role :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	user_id: Snowflake,
	role_id: Snowflake,
) -> bool {
	endpoint := fmt.tprintf("/guilds/%s/members/%s/roles/%s", guild_id, user_id, role_id)
	resp, ok := discord_delete(client, endpoint)
	if ok do delete(resp.body)
	return ok
}

remove_guild_member :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	user_id: Snowflake,
) -> bool {
	endpoint := fmt.tprintf("/guilds/%s/members/%s", guild_id, user_id)
	resp, ok := discord_delete(client, endpoint)
	if ok do delete(resp.body)
	return ok
}

get_guild_bans :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	params: ^GetGuildBansParams = nil,
) -> (
	[]Ban,
	bool,
) {
	endpoint := fmt.tprintf("/guilds/%s/bans", guild_id)
	endpoint = _append_query_params(endpoint, params)
	return discord_request([]Ban, client, endpoint)
}

get_guild_ban :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	user_id: Snowflake,
) -> (
	Ban,
	bool,
) {
	endpoint := fmt.tprintf("/guilds/%s/bans/%s", guild_id, user_id)
	return discord_request(Ban, client, endpoint)
}

create_guild_ban :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	user_id: Snowflake,
	params: ^CreateGuildBanParams = nil,
) -> bool {
	endpoint := fmt.tprintf("/guilds/%s/bans/%s", guild_id, user_id)
	if params != nil {
		body, err := json.marshal(params^, allocator = context.temp_allocator)
		if err != nil {
			fmt.eprintfln("Failed to marshal create_guild_ban: %v", err)
			return false
		}
		resp, ok := discord_put(client, endpoint, body)
		if ok do delete(resp.body)
		return ok
	}
	resp, ok := discord_put(client, endpoint, {})
	if ok do delete(resp.body)
	return ok
}

remove_guild_ban :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	user_id: Snowflake,
) -> bool {
	endpoint := fmt.tprintf("/guilds/%s/bans/%s", guild_id, user_id)
	resp, ok := discord_delete(client, endpoint)
	if ok do delete(resp.body)
	return ok
}

bulk_guild_ban :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	params: BulkGuildBanParams,
) -> (
	BulkBanResponse,
	bool,
) {
	body, err := json.marshal(params, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal bulk_guild_ban: %v", err)
		return {}, false
	}
	endpoint := fmt.tprintf("/guilds/%s/bulk-ban", guild_id)
	resp, ok := discord_post(client, endpoint, body)
	if !ok do return {}, false
	defer delete(resp.body)
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("bulk_guild_ban got HTTP %d: %s", resp.status_code, string(resp.body))
		return {}, false
	}
	result: BulkBanResponse
	if err := json.unmarshal(resp.body, &result); err != nil {
		fmt.eprintfln("bulk_guild_ban unmarshal failed: %v", err)
		return {}, false
	}
	return result, true
}

get_guild_roles :: proc(client: ^Discord_Client, guild_id: Snowflake) -> ([]Role, bool) {
	endpoint := fmt.tprintf("/guilds/%s/roles", guild_id)
	return discord_request([]Role, client, endpoint)
}

get_guild_role :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	role_id: Snowflake,
) -> (
	Role,
	bool,
) {
	endpoint := fmt.tprintf("/guilds/%s/roles/%s", guild_id, role_id)
	return discord_request(Role, client, endpoint)
}

create_guild_role :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	params: ^CreateGuildRoleParams = nil,
) -> (
	Role,
	bool,
) {
	body: []byte
	if params != nil {
		marshalled, marshal_err := json.marshal(params^, allocator = context.temp_allocator)
		if marshal_err != nil {
			fmt.eprintfln("Failed to marshal create_guild_role: %v", marshal_err)
			return {}, false
		}
		body = marshalled
	}
	endpoint := fmt.tprintf("/guilds/%s/roles", guild_id)
	resp, ok := discord_post(client, endpoint, body)
	if !ok do return {}, false
	defer delete(resp.body)
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("create_guild_role got HTTP %d: %s", resp.status_code, string(resp.body))
		return {}, false
	}
	result: Role
	if unmarshal_err := json.unmarshal(resp.body, &result); unmarshal_err != nil {
		fmt.eprintfln("create_guild_role unmarshal failed: %v", unmarshal_err)
		return {}, false
	}
	return result, true
}

modify_guild_role :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	role_id: Snowflake,
	params: ModifyGuildRoleParams,
) -> (
	Role,
	bool,
) {
	body, err := json.marshal(params, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal modify_guild_role: %v", err)
		return {}, false
	}
	endpoint := fmt.tprintf("/guilds/%s/roles/%s", guild_id, role_id)
	resp, ok := discord_patch(client, endpoint, body)
	if !ok do return {}, false
	defer delete(resp.body)
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("modify_guild_role got HTTP %d: %s", resp.status_code, string(resp.body))
		return {}, false
	}
	result: Role
	if err := json.unmarshal(resp.body, &result); err != nil {
		fmt.eprintfln("modify_guild_role unmarshal failed: %v", err)
		return {}, false
	}
	return result, true
}

delete_guild_role :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	role_id: Snowflake,
) -> bool {
	endpoint := fmt.tprintf("/guilds/%s/roles/%s", guild_id, role_id)
	resp, ok := discord_delete(client, endpoint)
	if ok do delete(resp.body)
	return ok
}

get_guild_prune_count :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	params: ^GetGuildPruneCountParams = nil,
) -> (
	PruneCountResponse,
	bool,
) {
	endpoint := fmt.tprintf("/guilds/%s/prune", guild_id)
	endpoint = _append_query_params(endpoint, params)
	return discord_request(PruneCountResponse, client, endpoint)
}

begin_guild_prune :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	params: ^BeginGuildPruneParams = nil,
) -> (
	PruneCountResponse,
	bool,
) {
	body: []byte
	if params != nil {
		marshalled, marshal_err := json.marshal(params^, allocator = context.temp_allocator)
		if marshal_err != nil {
			fmt.eprintfln("Failed to marshal begin_guild_prune: %v", marshal_err)
			return {}, false
		}
		body = marshalled
	}
	endpoint := fmt.tprintf("/guilds/%s/prune", guild_id)
	resp, ok := discord_post(client, endpoint, body)
	if !ok do return {}, false
	defer delete(resp.body)
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("begin_guild_prune got HTTP %d: %s", resp.status_code, string(resp.body))
		return {}, false
	}
	result: PruneCountResponse
	if unmarshal_err := json.unmarshal(resp.body, &result); unmarshal_err != nil {
		fmt.eprintfln("begin_guild_prune unmarshal failed: %v", unmarshal_err)
		return {}, false
	}
	return result, true
}

get_guild_invites :: proc(client: ^Discord_Client, guild_id: Snowflake) -> ([]Invite, bool) {
	endpoint := fmt.tprintf("/guilds/%s/invites", guild_id)
	return discord_request([]Invite, client, endpoint)
}

get_guild_integrations :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
) -> (
	[]Integration,
	bool,
) {
	endpoint := fmt.tprintf("/guilds/%s/integrations", guild_id)
	return discord_request([]Integration, client, endpoint)
}

delete_guild_integration :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	integration_id: Snowflake,
) -> bool {
	endpoint := fmt.tprintf("/guilds/%s/integrations/%s", guild_id, integration_id)
	resp, ok := discord_delete(client, endpoint)
	if ok do delete(resp.body)
	return ok
}

get_guild_widget_settings :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
) -> (
	GuildWidgetSettings,
	bool,
) {
	endpoint := fmt.tprintf("/guilds/%s/widget", guild_id)
	return discord_request(GuildWidgetSettings, client, endpoint)
}

modify_guild_widget :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	params: ModifyGuildWidgetParams,
) -> (
	GuildWidgetSettings,
	bool,
) {
	body, err := json.marshal(params, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal modify_guild_widget: %v", err)
		return {}, false
	}
	endpoint := fmt.tprintf("/guilds/%s/widget", guild_id)
	resp, ok := discord_patch(client, endpoint, body)
	if !ok do return {}, false
	defer delete(resp.body)
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("modify_guild_widget got HTTP %d: %s", resp.status_code, string(resp.body))
		return {}, false
	}
	result: GuildWidgetSettings
	if err := json.unmarshal(resp.body, &result); err != nil {
		fmt.eprintfln("modify_guild_widget unmarshal failed: %v", err)
		return {}, false
	}
	return result, true
}

get_guild_widget :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
) -> (
	GuildWidget,
	bool,
) {
	endpoint := fmt.tprintf("/guilds/%s/widget.json", guild_id)
	return discord_request(GuildWidget, client, endpoint)
}

get_guild_vanity_url :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
) -> (
	VanityUrlResponse,
	bool,
) {
	endpoint := fmt.tprintf("/guilds/%s/vanity-url", guild_id)
	resp, ok := discord_get(client, endpoint)
	if !ok do return {}, false
	defer delete(resp.body)
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("get_guild_vanity_url got HTTP %d: %s", resp.status_code, string(resp.body))
		return {}, false
	}
	result: VanityUrlResponse
	if err := json.unmarshal(resp.body, &result); err != nil {
		fmt.eprintfln("get_guild_vanity_url unmarshal failed: %v", err)
		return {}, false
	}
	return result, true
}

get_guild_welcome_screen :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
) -> (
	WelcomeScreen,
	bool,
) {
	endpoint := fmt.tprintf("/guilds/%s/welcome-screen", guild_id)
	return discord_request(WelcomeScreen, client, endpoint)
}

modify_guild_welcome_screen :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	params: ModifyWelcomeScreenParams,
) -> (
	WelcomeScreen,
	bool,
) {
	body, err := json.marshal(params, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal welcome screen: %v", err)
		return {}, false
	}
	endpoint := fmt.tprintf("/guilds/%s/welcome-screen", guild_id)
	resp, ok := discord_patch(client, endpoint, body)
	if !ok do return {}, false
	defer delete(resp.body)
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("modify_guild_welcome_screen got HTTP %d: %s", resp.status_code, string(resp.body))
		return {}, false
	}
	result: WelcomeScreen
	if err := json.unmarshal(resp.body, &result); err != nil {
		fmt.eprintfln("modify_guild_welcome_screen unmarshal failed: %v", err)
		return {}, false
	}
	return result, true
}

get_guild_onboarding :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
) -> (
	GuildOnboarding,
	bool,
) {
	endpoint := fmt.tprintf("/guilds/%s/onboarding", guild_id)
	return discord_request(GuildOnboarding, client, endpoint)
}

modify_guild_onboarding :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	params: ModifyGuildOnboardingParams,
) -> (
	GuildOnboarding,
	bool,
) {
	body, err := json.marshal(params, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal onboarding: %v", err)
		return {}, false
	}
	endpoint := fmt.tprintf("/guilds/%s/onboarding", guild_id)
	resp, ok := discord_put(client, endpoint, body)
	if !ok do return {}, false
	defer delete(resp.body)
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("modify_guild_onboarding got HTTP %d: %s", resp.status_code, string(resp.body))
		return {}, false
	}
	result: GuildOnboarding
	if err := json.unmarshal(resp.body, &result); err != nil {
		fmt.eprintfln("modify_guild_onboarding unmarshal failed: %v", err)
		return {}, false
	}
	return result, true
}

modify_guild_incident_actions :: proc(
	client: ^Discord_Client,
	guild_id: Snowflake,
	params: ModifyIncidentActionsParams,
) -> (
	IncidentsData,
	bool,
) {
	body, err := json.marshal(params, allocator = context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to marshal incident actions: %v", err)
		return {}, false
	}
	endpoint := fmt.tprintf("/guilds/%s/incident-actions", guild_id)
	resp, ok := discord_put(client, endpoint, body)
	if !ok do return {}, false
	defer delete(resp.body)
	if resp.status_code < 200 || resp.status_code >= 300 {
		fmt.eprintfln("modify_incident_actions got HTTP %d: %s", resp.status_code, string(resp.body))
		return {}, false
	}
	result: IncidentsData
	if err := json.unmarshal(resp.body, &result); err != nil {
		fmt.eprintfln("modify_incident_actions unmarshal failed: %v", err)
		return {}, false
	}
	return result, true
}
