package discord_api

MessageComponent :: struct {
	type: ComponentType,
	id:   int,
}

ActionRowComponent :: struct {
	type:       ComponentType,
	id:         int,
	components: []Component,
}

ButtonComponent :: struct {
	type:      ComponentType `json:"type"`,
	id:        int           `json:"id"`,
	style:     ButtonStyle   `json:"style"`,
	label:     string        `json:"label"`,
	emoji:     ^Emoji        `json:"emoji,omitempty"`,
	custom_id: string        `json:"custom_id"`,
	sku_id:    Snowflake     `json:"sku_id,omitempty"`,
	url:       string        `json:"url,omitempty"`,
	disabled:  bool          `json:"disabled,omitempty"`,
}

StringSelectComponent :: struct {
	type:        ComponentType,
	id:          int,
	custom_id:   string,
	options:     []SelectOption,
	placeholder: string,
	min_values:  int,
	max_values:  int,
	required:    bool,
	disabled:    bool,
}

SelectOption :: struct {
	label:       string,
	value:       string,
	description: string,
	emoji:       Emoji,
	default:     bool,
}

SelectMenuComponent :: struct {
	type:           ComponentType,
	id:             int,
	custom_id:      string,
	channel_types:  []ChannelType,
	placeholder:    string,
	min_values:     int,
	max_values:     int,
	disabled:       bool,
	default_values: []SelectDefaultValue,
}

SelectDefaultValue :: struct {
	id:   Snowflake,
	type: SelectDefaultValueType,
}

TextInputComponent :: struct {
	type:        ComponentType,
	id:          int,
	custom_id:   string,
	style:       TextInputStyle,
	min_length:  int,
	max_length:  int,
	required:    bool,
	value:       string,
	placeholder: string,
}

TextDisplayComponent :: struct {
	type:    ComponentType,
	id:      int,
	content: string,
}

ThumbnailComponent :: struct {
	type:        ComponentType,
	id:          int,
	media:       UnfurledMediaItem,
	description: string,
	spoiler:     bool,
}

MediaGalleryComponent :: struct {
	type:  ComponentType,
	id:    int,
	items: []MediaGalleryItem,
}

MediaGalleryItem :: struct {
	media:       UnfurledMediaItem,
	description: string,
	spoiler:     bool,
}

FileComponent :: struct {
	type:    ComponentType,
	id:      int,
	file:    UnfurledMediaItem,
	spoiler: bool,
}

SeparatorComponent :: struct {
	type:    ComponentType,
	id:      int,
	spacing: SeparatorSpacingSize,
	divider: bool,
}

ContainerComponent :: struct {
	type:         ComponentType,
	id:           int,
	components:   []Component,
	accent_color: int,
	spoiler:      bool,
}

SectionComponent :: struct {
	type:       ComponentType,
	id:         int,
	components: []Component,
	accessory:  []Component,
}
UnfurledMediaItem :: struct {
	url: string,
}

ComponentType :: enum i32 {
	ACTION_ROW         = 1,
	BUTTON             = 2,
	STRING_SELECT      = 3,
	TEXT_INPUT         = 4,
	USER_SELECT        = 5,
	ROLE_SELECT        = 6,
	MENTIONABLE_SELECT = 7,
	CHANNEL_SELECT     = 8,
	SECTION            = 9,
	TEXT_DISPLAY       = 10,
	THUMBNAIL          = 11,
	MEDIA_GALLERY      = 12,
	FILE               = 13,
	SEPARATOR          = 14,
	CONTAINER          = 17,
}

ButtonStyle :: enum i32 {
	PRIMARY   = 1,
	SECONDARY = 2,
	SUCCESS   = 3,
	DANGER    = 4,
	LINK      = 5,
	PREMIUM   = 6,
}

TextInputStyle :: enum i32 {
	SHORT     = 1,
	PARAGRAPH = 2,
}

SelectDefaultValueType :: enum i32 {
	USER,
	ROLE,
	CHANNEL,
}

SeparatorSpacingSize :: enum i32 {
	SMALL = 1,
	LARGE = 2,
}

Component :: union {
	ActionRowComponent,
	ButtonComponent,
	StringSelectComponent,
	SelectMenuComponent,
	TextInputComponent,
	TextDisplayComponent,
	ThumbnailComponent,
	MediaGalleryComponent,
	FileComponent,
	SeparatorComponent,
	ContainerComponent,
	SectionComponent,
}
