package main

import "core:os"
import "core:fmt"
import curl "vendor:curl"
import "core:flags"

import discord "discord"
import api "discord/api"

Options :: struct {
	token: string `args:"name=token,required" usage:"Your discord bot token"`
}

on_msg :: proc(data: rawptr) {
	msg := (^api.Message)(data)
	fmt.printfln("on_msg: %s", msg.content)
}

main :: proc() {
	opt: Options
	flags.parse_or_exit(&opt, os.args, .Unix)

	if curl.global_init(curl.GLOBAL_ALL) != .E_OK {
		fmt.eprintln("Failed to initialize libcurl globally")
		return
	}
	defer curl.global_cleanup()

	client := discord.new_client({token = opt.token})
	discord.on(client, "MESSAGE_CREATE", on_msg)
	discord.run(client)
}