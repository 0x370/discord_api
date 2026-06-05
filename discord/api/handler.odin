package discord_api

import curl "vendor:curl"
import "base:runtime"
import "core:strings"
import "core:fmt"
import "core:slice"
import "core:encoding/json"

API_VERSION :: "10"
DISCORD_BASE_URL :: "https://discord.com/api/v" + API_VERSION

Discord_Client :: struct {
	curl_handle: ^curl.CURL,
	headers:     ^curl.slist,
}

Http_Response :: struct {
	status_code: i32,
	body:        []byte,
}

write_callback :: proc "c" (ptr: [^]byte, size, nmemb: i32, userdata: rawptr) -> i32 {
	context = runtime.default_context()
	total_size := size * nmemb
	builder := (^strings.Builder)(userdata)
	strings.write_bytes(builder, ptr[:total_size])
	return total_size
}

discord_client_init :: proc(client: ^Discord_Client, token: string) -> bool {
	client.curl_handle = curl.easy_init()
	if client.curl_handle == nil do return false

	auth_header := fmt.tprintf("Authorization: Bot %s", token)
	ua_header   := "User-Agent: DiscordBot (https://rava.ge, 1.0.0)"

	client.headers = curl.slist_append(client.headers, strings.clone_to_cstring(auth_header))
	client.headers = curl.slist_append(client.headers, strings.clone_to_cstring(ua_header))
	client.headers = curl.slist_append(client.headers, "Accept: application/json")
	client.headers = curl.slist_append(client.headers, "Content-Type: application/json")

	curl.easy_setopt(client.curl_handle, .HTTPHEADER, client.headers)
	curl.easy_setopt(client.curl_handle, .WRITEFUNCTION, rawptr(write_callback))
	curl.easy_setopt(client.curl_handle, .HTTP_VERSION, i32(curl.HTTP_VERSION_1_1))
	curl.easy_setopt(client.curl_handle, .FOLLOWLOCATION, i32(1))

	return true
}

discord_client_destroy :: proc(client: ^Discord_Client) {
	if client.headers != nil do curl.slist_free_all(client.headers)
	if client.curl_handle != nil do curl.easy_cleanup(client.curl_handle)
}

discord_get :: proc(client: ^Discord_Client, endpoint: string, allocator := context.allocator) -> (Http_Response, bool) #optional_ok {
	if client.curl_handle == nil do return {}, false

	response_buffer: strings.Builder
	strings.builder_init(&response_buffer, context.temp_allocator)
	defer strings.builder_destroy(&response_buffer)

	full_url := fmt.tprintf("%s%s", DISCORD_BASE_URL, endpoint)
	url_cstr := strings.clone_to_cstring(full_url, context.temp_allocator)

	curl.easy_setopt(client.curl_handle, .URL, url_cstr)
	curl.easy_setopt(client.curl_handle, .WRITEDATA, &response_buffer)

	res := curl.easy_perform(client.curl_handle)
	if res != .E_OK {
		fmt.eprintfln("HTTP request failed: %s", curl.easy_strerror(res))
		return {}, false
	}

	http_code: i32
	curl.easy_getinfo(client.curl_handle, .RESPONSE_CODE, &http_code)

    builder_str := strings.to_string(response_buffer)
    builder_bytes := transmute([]byte)builder_str
    body_data := slice.clone(builder_bytes, allocator)
	return Http_Response{status_code = http_code, body = body_data}, true
}

discord_fetch :: proc($T: typeid, client: ^Discord_Client, endpoint: string, allocator := context.allocator) -> (data: T, ok: bool) {
	response, network_ok := discord_get(client, endpoint)
	if !network_ok do return
	defer delete(response.body)

	if response.status_code != 200 {
		fmt.eprintfln("API Error [%s]: Status: %d", endpoint, response.status_code)
		return
	}

	err := json.unmarshal(response.body, &data, json.DEFAULT_SPECIFICATION, allocator)
	if err != nil {
		fmt.eprintfln("Unmarshal error on [%s]: %v", endpoint, err)
		return T{}, false
	}

	return data, true
}