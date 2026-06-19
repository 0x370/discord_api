package discord_api

Attachment :: struct {
	id:                  Snowflake        `json:"id,omitempty"`,
	filename:            string           `json:"filename,omitempty"`,
	title:               string           `json:"title,omitempty"`,
	description:         string           `json:"description,omitempty"`,
	content_type:        string           `json:"content_type,omitempty"`,
	size:                int              `json:"size,omitempty"`,
	url:                 string           `json:"url,omitempty"`,
	proxy_url:           string           `json:"proxy_url,omitempty"`,
	height:              int              `json:"height,omitempty"`,
	width:               int              `json:"width,omitempty"`,
	placeholder:         string           `json:"placeholder,omitempty"`,
	placeholder_version: int              `json:"placeholder_version,omitempty"`,
	ephemeral:           bool             `json:"ephemeral,omitempty"`,
	duration_secs:       int              `json:"duration_secs,omitempty"`,
	waveform:            string           `json:"waveform,omitempty"`,
	flags:               AttachmentFlags  `json:"flags,omitempty"`,
	clip_participants:   []User           `json:"clip_participants,omitempty"`,
	clip_created_at:     Snowflake        `json:"clip_created_at,omitempty"`,
	application:         Application      `json:"application,omitempty"`,
}

AttachmentFlags :: distinct u64

ATTACHMENT_FLAG_IS_CLIP :: AttachmentFlags(1 << 0)
ATTACHMENT_FLAG_IS_THUMBNAIL :: AttachmentFlags(1 << 1)
ATTACHMENT_FLAG_IS_REMIX :: AttachmentFlags(1 << 2)
ATTACHMENT_FLAG_IS_SPOILER :: AttachmentFlags(1 << 3)
ATTACHMENT_FLAG_IS_ANIMATED :: AttachmentFlags(1 << 5)
