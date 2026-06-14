package discord_api

InviteType :: enum i32 {
	GUILD    = 0,
	GROUP_DM = 1,
	FRIEND   = 2,
}

InviteTargetType :: enum i32 {
	STREAM               = 1,
	EMBEDDED_APPLICATION = 2,
}

InviteFlags :: distinct u64

IS_GUEST_INVITE :: InviteFlags(1 << 0)

Invite :: struct {
	type:                       InviteType,
	code:                       string,
	guild:                      Guild,
	channel:                    Channel,
	inviter:                    User,
	target_type:                InviteTargetType,
	target_user:                User,
	target_application:         Application,
	approximate_presence_count: int,
	approximate_member_count:   int,
	expires_at:                 string,
	guild_scheduled_event:      GuildScheduledEvent,
	flags:                      InviteFlags,
	roles:                      []Role,
}

InviteMetadata :: struct {
	uses:       int,
	max_uses:   int,
	max_age:    int,
	temporary:  bool,
	created_at: string,
}

InviteStageInstance :: struct {
	members:           []GuildMember,
	participant_count: int,
	speaker_count:     int,
	topic:             string,
}
