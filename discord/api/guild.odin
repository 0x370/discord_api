package discord_api

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

integrationExpireBehavior :: struct {}
integrationApplication :: struct {}

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
