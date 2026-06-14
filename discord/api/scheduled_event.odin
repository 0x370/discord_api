package discord_api

GuildScheduledEventPrivacyLevel :: enum i32 {
	GUILD_ONLY = 2,
}

GuildScheduledEventEntityType :: enum i32 {
	STAGE_INSTANCE = 1,
	VOICE          = 2,
	EXTERNAL       = 3,
}

GuildScheduledEventStatus :: enum i32 {
	SCHEDULED = 1,
	ACTIVE    = 2,
	COMPLETED = 3,
	CANCELED  = 4,
}

GuildScheduledEventEntityMetadata :: struct {
	location: string,
}

GuildScheduledEventRecurrenceRuleFrequency :: enum i32 {
	YEARLY  = 0,
	MONTHLY = 1,
	WEEKLY  = 2,
	DAILY   = 3,
}

GuildScheduledEventRecurrenceRuleWeekday :: enum i32 {
	MONDAY    = 0,
	TUESDAY   = 1,
	WEDNESDAY = 2,
	THURSDAY  = 3,
	FRIDAY    = 4,
	SATURDAY  = 5,
	SUNDAY    = 6,
}

GuildScheduledEventRecurrenceRuleMonth :: enum i32 {
	JANUARY   = 1,
	FEBRUARY  = 2,
	MARCH     = 3,
	APRIL     = 4,
	MAY       = 5,
	JUNE      = 6,
	JULY      = 7,
	AUGUST    = 8,
	SEPTEMBER = 9,
	OCTOBER   = 10,
	NOVEMBER  = 11,
	DECEMBER  = 12,
}

GuildScheduledEventRecurrenceRuleNWeekday :: struct {
	n:   int,
	day: GuildScheduledEventRecurrenceRuleWeekday,
}

GuildScheduledEventRecurrenceRule :: struct {
	start:        string,
	end:          string,
	frequency:    GuildScheduledEventRecurrenceRuleFrequency,
	interval:     int,
	by_weekday:   []GuildScheduledEventRecurrenceRuleWeekday,
	by_n_weekday: []GuildScheduledEventRecurrenceRuleNWeekday,
	by_month:     []GuildScheduledEventRecurrenceRuleMonth,
	by_month_day: []int,
	by_year_day:  []int,
	count:        int,
}

GuildScheduledEvent :: struct {
	id:                   Snowflake,
	guild_id:             Snowflake,
	channel_id:           Snowflake,
	creator_id:           Snowflake,
	name:                 string,
	description:          string,
	scheduled_start_time: string,
	scheduled_end_time:   string,
	privacy_level:        GuildScheduledEventPrivacyLevel,
	status:               GuildScheduledEventStatus,
	entity_type:          GuildScheduledEventEntityType,
	entity_id:            Snowflake,
	entity_metadata:      GuildScheduledEventEntityMetadata,
	creator:              User,
	user_count:           int,
	image:                string,
	recurrence_rule:      GuildScheduledEventRecurrenceRule,
}

GuildScheduledEventUser :: struct {
	guild_scheduled_event_id: Snowflake,
	user:                     User,
	member:                   GuildMember,
}
