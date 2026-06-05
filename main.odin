package main

import "core:os"
import "core:fmt"
import curl "vendor:curl"
import "core:flags"

import discord "discord"

Options :: struct {
	token: string `args:"name=token,required" usage:"Your discord bot token"`
} 

main :: proc() {
	opt: Options
	flags.parse_or_exit(&opt, os.args, .Unix)

	if curl.global_init(curl.GLOBAL_ALL) != .E_OK {
		fmt.eprintln("Failed to initialize libcurl globally")
		return
	}
	defer curl.global_cleanup()

	handle := curl.easy_init()
	defer curl.easy_cleanup(handle)

	discord.run(handle, opt.token)
}
