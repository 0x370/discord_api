package discord_api

Embed :: struct {
	title:       string,
	type:        EmbedType,
	description: string,
	url:         string,
	timestamp:   string,
	color:       int,
	footer:      EmbedFooter,
	image:       EmbedImage,
	thumbnail:   EmbedThumbnail,
	video:       EmbedVideo,
	provider:    EmbedProvider,
	author:      EmbedAuthor,
	fields:      []EmbedField,
	flags:       EmbedFlags,
}

EmbedFooter :: struct {
	text:           string,
	icon_url:       string,
	proxy_icon_url: string,
}

EmbedImage :: struct {
	url:                 string,
	proxy_url:           string,
	height:              int,
	width:               int,
	content_type:        string,
	placeholder:         string,
	placeholder_version: int,
	description:         string,
	flags:               EmbedFlags,
}

EmbedThumbnail :: struct {
	url:                 string,
	proxy_url:           string,
	height:              int,
	width:               int,
	content_type:        string,
	placeholder:         string,
	placeholder_version: int,
}

EmbedVideo :: struct {
	url:                 string,
	proxy_url:           string,
	height:              int,
	width:               int,
	content_type:        string,
	placeholder:         string,
	placeholder_version: int,
	description:         string,
	flags:               EmbedFlags,
}

EmbedProvider :: struct {
	name: string,
	url:  string,
}

EmbedAuthor :: struct {
	name:           string,
	url:            string,
	icon_url:       string,
	proxy_icon_url: string,
}

EmbedField :: struct {
	name:    string,
	value:   string,
	_inline: bool `json:"inline"`,
}

EmbedType :: enum i32 {
	RICH,
	IMAGE,
	VIDEO,
	GIFV,
	ARTICLE,
	LINK,
	POLL_RESULT,
}

EmbedFlags :: distinct u64

EMBED_FLAG_IS_CONTENT_INVENTORY_ENTRY :: EmbedFlags(1 << 5)
