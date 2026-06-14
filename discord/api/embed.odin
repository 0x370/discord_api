package discord_api

Embed :: struct {
	title:       string       `json:"title,omitempty"`,
	type:        EmbedType    `json:"type,omitempty"`,
	description: string       `json:"description,omitempty"`,
	url:         string       `json:"url,omitempty"`,
	timestamp:   string       `json:"timestamp,omitempty"`,
	color:       int          `json:"color,omitempty"`,
	footer:      EmbedFooter  `json:"footer,omitempty"`,
	image:       EmbedImage   `json:"image,omitempty"`,
	thumbnail:   EmbedThumbnail `json:"thumbnail,omitempty"`,
	video:       EmbedVideo   `json:"video,omitempty"`,
	provider:    EmbedProvider `json:"provider,omitempty"`,
	author:      EmbedAuthor  `json:"author,omitempty"`,
	fields:      []EmbedField `json:"fields,omitempty"`,
	flags:       EmbedFlags   `json:"flags,omitempty"`,
}

EmbedFooter :: struct {
	text:           string `json:"text,omitempty"`,
	icon_url:       string `json:"icon_url,omitempty"`,
	proxy_icon_url: string `json:"proxy_icon_url,omitempty"`,
}

EmbedImage :: struct {
	url:                 string     `json:"url,omitempty"`,
	proxy_url:           string     `json:"proxy_url,omitempty"`,
	height:              int        `json:"height,omitempty"`,
	width:               int        `json:"width,omitempty"`,
	content_type:        string     `json:"content_type,omitempty"`,
	placeholder:         string     `json:"placeholder,omitempty"`,
	placeholder_version: int        `json:"placeholder_version,omitempty"`,
	description:         string     `json:"description,omitempty"`,
	flags:               EmbedFlags `json:"flags,omitempty"`,
}

EmbedThumbnail :: struct {
	url:                 string `json:"url,omitempty"`,
	proxy_url:           string `json:"proxy_url,omitempty"`,
	height:              int    `json:"height,omitempty"`,
	width:               int    `json:"width,omitempty"`,
	content_type:        string `json:"content_type,omitempty"`,
	placeholder:         string `json:"placeholder,omitempty"`,
	placeholder_version: int    `json:"placeholder_version,omitempty"`,
}

EmbedVideo :: struct {
	url:                 string     `json:"url,omitempty"`,
	proxy_url:           string     `json:"proxy_url,omitempty"`,
	height:              int        `json:"height,omitempty"`,
	width:               int        `json:"width,omitempty"`,
	content_type:        string     `json:"content_type,omitempty"`,
	placeholder:         string     `json:"placeholder,omitempty"`,
	placeholder_version: int        `json:"placeholder_version,omitempty"`,
	description:         string     `json:"description,omitempty"`,
	flags:               EmbedFlags `json:"flags,omitempty"`,
}

EmbedProvider :: struct {
	name: string `json:"name,omitempty"`,
	url:  string `json:"url,omitempty"`,
}

EmbedAuthor :: struct {
	name:           string `json:"name,omitempty"`,
	url:            string `json:"url,omitempty"`,
	icon_url:       string `json:"icon_url,omitempty"`,
	proxy_icon_url: string `json:"proxy_icon_url,omitempty"`,
}

EmbedField :: struct {
	name:    string `json:"name,omitempty"`,
	value:   string `json:"value,omitempty"`,
	_inline: bool   `json:"inline,omitempty"`,
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
