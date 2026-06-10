package discord_api

PollLayoutType :: enum i32 {
	DEFAULT = 1,
}

PollCreateRequest :: struct {
	question:            PollMedia,
	answers:             []PollAnswer,
	duration:            int,
	allow_multiselect:   bool,
	layout_type:         PollLayoutType,
}
