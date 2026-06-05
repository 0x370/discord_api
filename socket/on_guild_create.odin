package discord

import "core:fmt"
import "core:encoding/json"
import "api"

on_guild_create :: proc(cluster: ^Cluster, event_data: json.Value) {
    fmt.println("on_guild_event proc called")
}