package main

import "core:os"
import "core:fmt"
import curl "vendor:curl"
import "core:flags"

import socket "socket"

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

	socket.run_socket(handle, opt.token)

	/*

	client: api.Discord_Client
	if !api.discord_client_init(&client, AUTHORIZATION_TOKEN) {
		fmt.eprintln("Failed to initialize custom Discord client session")
		return
	}
	defer api.discord_client_destroy(&client)

    bot, ok := api.get_bot(&client)
    if ok {
        fmt.printfln("%s %s", bot.username, bot.id)
        fmt.println(bot)
    }

    guilds, ok1 := api.get_bot_guilds(&client)
    if ok1 {
        for g in guilds {
            fmt.println(g)
        }
    }
	*/
}
