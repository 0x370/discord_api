package discord

import "core:fmt"
import "core:encoding/json"
import "api"

on_message_create :: proc(cluster: ^Cluster, event_data: json.Value) {
    fmt.println("on_message_event proc called")

    msg_bytes, err := json.marshal(event_data, allocator = context.temp_allocator)
    if err != nil do return

    msg: api.Message

    if json.unmarshal(msg_bytes, &msg) == nil {
        defer free(&msg)
        fmt.println(msg)
    }
}