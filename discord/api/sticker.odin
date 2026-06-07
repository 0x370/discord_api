package discord_api

Sticker :: struct {
	id:          Snowflake,
	pack_id:     Snowflake,
	name:        string,
	description: string,
	tags:        string,
	type:        StickerType,
	format_type: StickerFormatType,
	available:   bool,
	guild_id:    Snowflake,
	user:        User,
	sort_value:  int,
}

StickerItem :: struct {
	id:          Snowflake,
	name:        string,
	format_type: StickerFormatType,
}

StickerPack :: struct {
	id:               Snowflake,
	stickers:         []Sticker,
	name:             string,
	sku_id:           Snowflake,
	cover_sticker_id: Snowflake,
	description:      string,
	banner_asset_id:  Snowflake,
}

ListStickerPacksResponse :: struct {
	sticker_packs: []StickerPack,
}


StickerType :: enum i32 {
	STANDARD = 1,
	GUILD    = 2,
}

StickerFormatType :: enum i32 {
	PNG    = 1,
	APNG   = 2,
	LOTTIE = 3,
	GIF    = 4,
}
