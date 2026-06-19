package dungeon

import "core:fmt"

@(private)
verbose_enabled := false

set_debug :: proc(enabled: bool) {
	verbose_enabled = enabled
}

logd :: proc(format: string, args: ..any, loc := #caller_location) {
	if !verbose_enabled do return
	fmt.eprintfln("[%s:%d] ", loc.procedure, loc.line)
	fmt.eprintfln(format, ..args)
}
