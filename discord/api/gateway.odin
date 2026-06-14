package discord_api

Gateway_Bot_Response :: struct {
	url:                 string `json:"url"`,
	shards:              int `json:"shards"`,
	session_start_limit: Session_Start_Limit `json:"session_start_limit"`,
}

Session_Start_Limit :: struct {
	total:           int `json:"total"`,
	remaining:       int `json:"remaining"`,
	reset_after:     int `json:"reset_after"`,
	max_concurrency: int `json:"max_concurrency"`,
}
