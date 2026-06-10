package discord_api

import curl "vendor:curl"
import "base:runtime"
import "core:strings"
import "core:fmt"
import "core:slice"
import "core:sync"
import "core:encoding/json"

API_VERSION :: "10"
DISCORD_BASE_URL :: "https://discord.com/api/v" + API_VERSION

Discord_Client :: struct {
	curl_handle:   ^curl.CURL,
	headers:       ^curl.slist,
	request_mutex: sync.Mutex,
}

Http_Response :: struct {
	status_code: i32,
	body:        []byte,
}

Http_Method :: enum {
	GET,
	POST,
	PUT,
	PATCH,
	DELETE,
}

@(private)
http_method_string :: proc(method: Http_Method) -> string {
	switch method {
	case .GET:    return "GET"
	case .POST:   return "POST"
	case .PUT:    return "PUT"
	case .PATCH:  return "PATCH"
	case .DELETE: return "DELETE"
	}
	return "GET"
}

@(private)
_discord_request :: proc(client: ^Discord_Client, method: Http_Method, endpoint: string, body: []byte = {}, allocator := context.allocator) -> (Http_Response, bool) #optional_ok {
	if client.curl_handle == nil do return {}, false

	sync.lock(&client.request_mutex)
	defer sync.unlock(&client.request_mutex)

	response_buffer: strings.Builder
	strings.builder_init(&response_buffer, context.temp_allocator)
	defer strings.builder_destroy(&response_buffer)

	full_url := fmt.tprintf("%s%s", DISCORD_BASE_URL, endpoint)
	url_cstr := strings.clone_to_cstring(full_url, context.temp_allocator)

	curl.easy_setopt(client.curl_handle, .URL, url_cstr)
	curl.easy_setopt(client.curl_handle, .WRITEDATA, &response_buffer)

	method_cstr := strings.clone_to_cstring(http_method_string(method), context.temp_allocator)
	curl.easy_setopt(client.curl_handle, .CUSTOMREQUEST, method_cstr)

	if len(body) > 0 {
		curl.easy_setopt(client.curl_handle, .POSTFIELDS, &body[0])
		curl.easy_setopt(client.curl_handle, .POSTFIELDSIZE, i32(len(body)))
	} else {
		curl.easy_setopt(client.curl_handle, .POSTFIELDS, nil)
		curl.easy_setopt(client.curl_handle, .POSTFIELDSIZE, i32(0))
	}

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
	return _discord_request(client, .GET, endpoint, {}, allocator)
}

discord_post :: proc(client: ^Discord_Client, endpoint: string, body: []byte, allocator := context.allocator) -> (Http_Response, bool) #optional_ok {
	return _discord_request(client, .POST, endpoint, body, allocator)
}

discord_put :: proc(client: ^Discord_Client, endpoint: string, body: []byte, allocator := context.allocator) -> (Http_Response, bool) #optional_ok {
	return _discord_request(client, .PUT, endpoint, body, allocator)
}

discord_patch :: proc(client: ^Discord_Client, endpoint: string, body: []byte, allocator := context.allocator) -> (Http_Response, bool) #optional_ok {
	return _discord_request(client, .PATCH, endpoint, body, allocator)
}

discord_delete :: proc(client: ^Discord_Client, endpoint: string, allocator := context.allocator) -> (Http_Response, bool) #optional_ok {
	return _discord_request(client, .DELETE, endpoint, {}, allocator)
}

discord_request :: proc {
	discord_request_get,
	discord_request_with_body,
}

discord_request_get :: proc($T: typeid, client: ^Discord_Client, endpoint: string, allocator := context.allocator) -> (data: T, ok: bool) {
	response, network_ok := discord_get(client, endpoint)
	if !network_ok do return
	defer delete(response.body)

	if response.status_code < 200 || response.status_code >= 300 {
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

discord_request_with_body :: proc($T: typeid, client: ^Discord_Client, method: Http_Method, endpoint: string, body: []byte = {}, allocator := context.allocator) -> (data: T, ok: bool) {
	response, network_ok := _discord_request(client, method, endpoint, body)
	if !network_ok do return
	defer delete(response.body)

	if response.status_code < 200 || response.status_code >= 300 {
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