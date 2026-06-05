package discord

import "core:fmt"
import "core:encoding/json"
import "api"

on_guild_create :: proc(cluster: ^Cluster, event_data: json.Value) {
    context.allocator = context.temp_allocator
    defer free_all(context.temp_allocator)
    
    fmt.println("on_guild_event proc called")
}