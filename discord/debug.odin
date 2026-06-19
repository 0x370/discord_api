package discord

import "core:fmt"

@(private)
_verbose_enabled := false

set_debug :: proc(enabled: bool) {
	_verbose_enabled = enabled
}

@(private)
logd :: proc(format: string, args: ..any, loc := #caller_location) {
	if !_verbose_enabled do return
	fmt.eprintfln("[discord|%s:%d] ", loc.procedure, loc.line)
	fmt.eprintfln(format, ..args)
}
