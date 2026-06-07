package discord_api

Attachment :: struct {
	id:            Snowflake,
	filename:      string,
	title:         string,
	description:   string,
	content_type:  string,
	size:          int,
	url:           string,
	proxy_url:     string,
	height:        int,
	width:         int,
	ephemeral:     bool,
	duration_secs: f64,
	waveform:      string,
	flags:         AttachmentFlags,
}

AttachmentFlags :: distinct u64

ATTACHMENT_FLAG_IS_CLIP :: AttachmentFlags(1 << 0)
ATTACHMENT_FLAG_IS_THUMBNAIL :: AttachmentFlags(1 << 1)
ATTACHMENT_FLAG_IS_REMIX :: AttachmentFlags(1 << 2)
ATTACHMENT_FLAG_IS_SPOILER :: AttachmentFlags(1 << 3)
ATTACHMENT_FLAG_IS_ANIMATED :: AttachmentFlags(1 << 5)
