package discord_api

import "base:runtime"
import "core:bytes"
import c "core:c"
import "core:encoding/json"
import "core:fmt"
import "core:strconv"
import "core:strings"
import "core:sync"
import "core:time"
import curl "vendor:curl"

API_VERSION :: "10"
DISCORD_BASE_URL :: "https://discord.com/api/v" + API_VERSION

Bucket :: struct {
	remaining:   int,
	limit:       int,
	reset_after: f64,
	last_update: time.Time,
}

Discord_Client :: struct {
	curl_handle:     ^curl.CURL,
	headers:         ^curl.slist,
	request_mutex:   sync.Mutex,
	total_requests:  u64,
	buckets:         map[string]Bucket,
	route_to_bucket: map[string]string,
	buckets_mutex:   sync.Mutex,
	global_mutex:    sync.Mutex,
}

Http_Response :: struct {
	status_code:     i32,
	body:            []byte,
	perform_time_ns: i64,
}

Http_Method :: enum {
	GET,
	POST,
	PUT,
	PATCH,
	DELETE,
}

@(private)
_method_cstr := [Http_Method]cstring {
	.GET    = "GET",
	.POST   = "POST",
	.PUT    = "PUT",
	.PATCH  = "PATCH",
	.DELETE = "DELETE",
}

@(private)
get_route :: proc(method: Http_Method, endpoint: string) -> string {
	// Simple route grouping: /channels/123/messages -> /channels/123
	// Major parameters (like channel_id, guild_id) should be kept.
	// Message ID should be stripped.

	parts := strings.split(endpoint, "/", context.temp_allocator)
	if len(parts) < 2 do return endpoint

	route_parts := make([dynamic]string, context.temp_allocator)

	i := 0
	for i < len(parts) {
		p := parts[i]
		if p == "" {i += 1; continue}

		append(&route_parts, p)

		// If it's channels/guilds/webhooks, keep the next ID part
		if p == "channels" || p == "guilds" || p == "webhooks" {
			if i + 1 < len(parts) {
				append(&route_parts, parts[i + 1])
				i += 2
				continue
			}
		}

		// For reactions, we keep the emoji but strip the user/message IDs?
		// Actually, keep it simple for now: just the first 2-3 major parts.
		if len(route_parts) >= 3 do break
		i += 1
	}

	return strings.join(route_parts[:], "/", context.temp_allocator)
}

@(private)
header_callback :: proc "c" (
	ptr: [^]byte,
	size: c.size_t,
	nmemb: c.size_t,
	userdata: rawptr,
) -> c.size_t {
	context = runtime.default_context()
	total := int(size * nmemb)
	if total == 0 do return 0

	line := string(ptr[:total])
	ctx := (^Request_Context)(userdata)

	if strings.has_prefix(line, "x-ratelimit-bucket:") {
		val := strings.trim_space(line[len("x-ratelimit-bucket:"):])
		if ctx.bucket_id != "" do delete(ctx.bucket_id, ctx.allocator)
		ctx.bucket_id = strings.clone(val, ctx.allocator)
	} else if strings.has_prefix(line, "x-ratelimit-remaining:") {
		val := strings.trim_space(line[len("x-ratelimit-remaining:"):])
		ctx.temp_bucket.remaining, _ = strconv.parse_int(val)
	} else if strings.has_prefix(line, "x-ratelimit-limit:") {
		val := strings.trim_space(line[len("x-ratelimit-limit:"):])
		ctx.temp_bucket.limit, _ = strconv.parse_int(val)
	} else if strings.has_prefix(line, "x-ratelimit-reset-after:") {
		val := strings.trim_space(line[len("x-ratelimit-reset-after:"):])
		ctx.temp_bucket.reset_after, _ = strconv.parse_f64(val)
	}

	return c.size_t(total)
}

@(private)
Request_Context :: struct {
	client:      ^Discord_Client,
	allocator:   runtime.Allocator,
	bucket_id:   string,
	temp_bucket: Bucket,
}

@(private)
write_callback :: proc "c" (
	ptr: [^]byte,
	size: c.size_t,
	nmemb: c.size_t,
	userdata: rawptr,
) -> c.size_t {
	context = runtime.default_context()
	total := int(size * nmemb)
	if total == 0 do return 0

	b := (^bytes.Buffer)(userdata)
	written, err := bytes.buffer_write(b, ptr[:total])
	if err != nil do return 0
	return c.size_t(written)
}

@(private)
_discord_request :: proc(
	client: ^Discord_Client,
	method: Http_Method,
	endpoint: string,
	body: []byte = {},
	allocator := context.allocator,
) -> (
	Http_Response,
	bool,
) #optional_ok {
	if client.curl_handle == nil do return {}, false

	sync.lock(&client.request_mutex)
	defer sync.unlock(&client.request_mutex)

	client.total_requests += 1

	route := get_route(method, endpoint)

	// Pre-emptive check
	sync.lock(&client.buckets_mutex)
	bucket_id, has_bucket_id := client.route_to_bucket[route]
	if has_bucket_id {
		bucket := client.buckets[bucket_id]
		if bucket.remaining == 0 {
			sleep_duration := time.Duration(bucket.reset_after * f64(time.Second))
			// Simple check: if we updated it recently and it was 0, we should wait.
			// Discord reset headers are absolute but curl gives us relative 'reset-after'
			// which is safer.
			if time.since(bucket.last_update) < sleep_duration {
				wait := sleep_duration - time.since(bucket.last_update)
				fmt.printfln("Pre-emptive rate limit hit for route %s, waiting %v", route, wait)
				time.sleep(wait)
			}
		}
	}
	sync.unlock(&client.buckets_mutex)

	g: bytes.Buffer
	bytes.buffer_init_allocator(&g, 0, 0, allocator)

	req_ctx := Request_Context {
		client    = client,
		allocator = context.temp_allocator,
	}

	curl.easy_setopt(client.curl_handle, .WRITEDATA, &g)
	curl.easy_setopt(client.curl_handle, .HEADERDATA, &req_ctx)
	curl.easy_setopt(client.curl_handle, .HEADERFUNCTION, rawptr(header_callback))
	curl.easy_setopt(client.curl_handle, .URL, fmt.ctprintf("%s%s", DISCORD_BASE_URL, endpoint))
	curl.easy_setopt(client.curl_handle, .CUSTOMREQUEST, _method_cstr[method])

	if len(body) > 0 {
		curl.easy_setopt(client.curl_handle, .POSTFIELDS, &body[0])
		curl.easy_setopt(client.curl_handle, .POSTFIELDSIZE, i32(len(body)))
	} else {
		curl.easy_setopt(client.curl_handle, .POSTFIELDS, nil)
		curl.easy_setopt(client.curl_handle, .POSTFIELDSIZE, i32(0))
	}

	perform_start := time.now()
	res := curl.easy_perform(client.curl_handle)
	perform_end := time.now()

	if res != .E_OK {
		bytes.buffer_destroy(&g)
		return {}, false
	}

	// Update bucket info
	if req_ctx.bucket_id != "" {
		sync.lock(&client.buckets_mutex)
		req_ctx.temp_bucket.last_update = time.now()

		bid := req_ctx.bucket_id
		if bid not_in client.buckets {
			bid = strings.clone(req_ctx.bucket_id, context.allocator)
		}
		client.buckets[bid] = req_ctx.temp_bucket

		rt := route
		if rt not_in client.route_to_bucket {
			rt = strings.clone(route, context.allocator)
		}
		client.route_to_bucket[rt] = bid
		sync.unlock(&client.buckets_mutex)
	}

	http_code: i32
	curl.easy_getinfo(client.curl_handle, .RESPONSE_CODE, &http_code)

	if http_code == 429 {
		fmt.eprintfln("429 Too Many Requests on route %s", route)
		// We could retry here, but for now just return the error
	}

	body_slice := bytes.buffer_to_bytes(&g)

	return Http_Response {
			status_code = http_code,
			body = body_slice,
			perform_time_ns = i64(time.diff(perform_start, perform_end)),
		},
		true
}

discord_client_init :: proc(client: ^Discord_Client, token: string) -> bool {
	client.curl_handle = curl.easy_init()
	if client.curl_handle == nil do return false

	client.buckets = make(map[string]Bucket, allocator = context.allocator)
	client.route_to_bucket = make(map[string]string, allocator = context.allocator)

	client.headers = curl.slist_append(
		client.headers,
		fmt.ctprintf("Authorization: Bot %s", token),
	)
	client.headers = curl.slist_append(
		client.headers,
		"User-Agent: DiscordBot (https://rava.ge, 1.0.0)",
	)
	client.headers = curl.slist_append(client.headers, "Accept: application/json")
	client.headers = curl.slist_append(client.headers, "Content-Type: application/json")

	curl.easy_setopt(client.curl_handle, .HTTPHEADER, client.headers)
	curl.easy_setopt(client.curl_handle, .WRITEFUNCTION, rawptr(write_callback))
	//curl.easy_setopt(client.curl_handle, .HTTP_VERSION,   i32(curl.HTTP_VERSION_1_1))
	curl.easy_setopt(client.curl_handle, .FOLLOWLOCATION, i32(1))

	return true
}

discord_client_destroy :: proc(client: ^Discord_Client) {
	for k, _ in client.route_to_bucket {
		delete(k, context.allocator) // the values are bucket IDs which are owned by the buckets map keys
	}
	delete(client.route_to_bucket)

	for k, _ in client.buckets {
		delete(k, context.allocator)
	}
	delete(client.buckets)

	if client.headers != nil do curl.slist_free_all(client.headers)
	if client.curl_handle != nil do curl.easy_cleanup(client.curl_handle)
}

discord_get :: proc(
	client: ^Discord_Client,
	endpoint: string,
	allocator := context.allocator,
) -> (
	Http_Response,
	bool,
) #optional_ok {
	return _discord_request(client, .GET, endpoint, {}, allocator)
}

discord_post :: proc(
	client: ^Discord_Client,
	endpoint: string,
	body: []byte,
	allocator := context.allocator,
) -> (
	Http_Response,
	bool,
) #optional_ok {
	return _discord_request(client, .POST, endpoint, body, allocator)
}

discord_put :: proc(
	client: ^Discord_Client,
	endpoint: string,
	body: []byte,
	allocator := context.allocator,
) -> (
	Http_Response,
	bool,
) #optional_ok {
	return _discord_request(client, .PUT, endpoint, body, allocator)
}

discord_patch :: proc(
	client: ^Discord_Client,
	endpoint: string,
	body: []byte,
	allocator := context.allocator,
) -> (
	Http_Response,
	bool,
) #optional_ok {
	return _discord_request(client, .PATCH, endpoint, body, allocator)
}

discord_delete :: proc(
	client: ^Discord_Client,
	endpoint: string,
	allocator := context.allocator,
) -> (
	Http_Response,
	bool,
) #optional_ok {
	return _discord_request(client, .DELETE, endpoint, {}, allocator)
}

discord_request :: proc {
	discord_request_get,
	discord_request_with_body,
}

@(private)
_parse_response :: proc(
	$T: typeid,
	response: Http_Response,
	endpoint: string,
	allocator: runtime.Allocator,
) -> (
	T,
	bool,
) {
	if response.status_code < 200 || response.status_code >= 300 {
		fmt.eprintfln("API Error [%s]: Status %d", endpoint, response.status_code)
		return {}, false
	}
	data: T
	if err := json.unmarshal(response.body, &data, json.DEFAULT_SPECIFICATION, allocator);
	   err != nil {
		fmt.eprintfln("Unmarshal error [%s]: %v", endpoint, err)
		return {}, false
	}
	return data, true
}

discord_request_get :: proc(
	$T: typeid,
	client: ^Discord_Client,
	endpoint: string,
	allocator := context.allocator,
) -> (
	T,
	bool,
) {
	response, ok := discord_get(client, endpoint)
	if !ok do return {}, false
	defer delete(response.body)
	return _parse_response(T, response, endpoint, allocator)
}

discord_request_with_body :: proc(
	$T: typeid,
	client: ^Discord_Client,
	method: Http_Method,
	endpoint: string,
	body: []byte = {},
	allocator := context.allocator,
) -> (
	T,
	bool,
) {
	response, ok := _discord_request(client, method, endpoint, body)
	if !ok do return {}, false
	defer delete(response.body)
	return _parse_response(T, response, endpoint, allocator)
}
