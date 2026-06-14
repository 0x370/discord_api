package discord_api

EntitlementType :: enum i32 {
	PURCHASE                 = 1,
	PREMIUM_SUBSCRIPTION     = 2,
	DEVELOPER_GIFT           = 3,
	TEST_MODE_PURCHASE       = 4,
	FREE_PURCHASE            = 5,
	USER_GIFT                = 6,
	PREMIUM_PURCHASE         = 7,
	APPLICATION_SUBSCRIPTION = 8,
}

Entitlement :: struct {
	id:             Snowflake,
	sku_id:         Snowflake,
	application_id: Snowflake,
	user_id:        Snowflake,
	type:           EntitlementType,
	guild_id:       Snowflake,
	deleted:        bool,
	starts_at:      string,
	ends_at:        string,
	consumed:       bool,
}
