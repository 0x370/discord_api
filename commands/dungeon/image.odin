package dungeon

import "core:fmt"
import "core:os"
import "core:strings"

import api "../../discord/api"

ASSETS_DIR :: "assets/dungeon"
DEFAULT_IMAGE :: "default.png"

// ─── CDN Configuration ────────────────────────────────────────────
// Change this to the base URL where your dungeon PNGs are hosted.
// The URL must be reachable by Discord's image proxy (no auth).
// Example: "https://your-cdn.com/dungeon"
CDN_BASE_URL :: "https://your-cdn.com/dungeon"

Image_Kind :: enum {
	Character,
	Monster,
	Boss,
	Item,
}
get_image_path :: proc(
	kind: Image_Kind,
	tier: Tier,
	weapon_compat: Weapon_Compat,
	monster_name: string,
	item_type: Item_Type,
) -> (attachment_name: string) {
	// Replace spaces for valid filenames / URLs
	safe_name, _ := strings.replace_all(monster_name, " ", "_", context.temp_allocator)
	switch kind {
	case .Character:
		return fmt.tprintf("char_%s_%s.png", TIER_LABELS[tier], WEAPON_COMPAT_NAMES[weapon_compat])
	case .Monster:
		return fmt.tprintf("mon_%s.png", safe_name)
	case .Boss:
		return fmt.tprintf("boss_%s.png", safe_name)
	case .Item:
		return fmt.tprintf("item_%s_%s.png", ITEM_TIER_NAMES[item_type], TIER_LABELS[tier])
	}
	return ""
}

// Returns the full CDN URL for an image, e.g.:
//   "https://your-cdn.com/dungeon/char_s_attacker.png"
get_image_url :: proc(
	kind: Image_Kind,
	tier: Tier,
	weapon_compat: Weapon_Compat,
	monster_name: string,
	item_type: Item_Type,
) -> string {
	name := get_image_path(kind, tier, weapon_compat, monster_name, item_type)
	return fmt.tprintf("%s/%s", CDN_BASE_URL, name)
}

chest_image_url :: proc() -> string {
	return fmt.tprintf("%s/boss_chest.png", CDN_BASE_URL)
}

load_image_file :: proc(attachment_name: string, allocator := context.allocator) -> (data: []byte, ok: bool) {
	full_path := fmt.tprintf("%s/%s", ASSETS_DIR, attachment_name)
	data, ok = os.read_entire_file(full_path, allocator)
	if ok do return data, true

	if attachment_name != DEFAULT_IMAGE {
		default_path := fmt.tprintf("%s/%s", ASSETS_DIR, DEFAULT_IMAGE)
		return os.read_entire_file(default_path, allocator)
	}
	return nil, false
}

build_image_attachment :: proc(attachment_name: string, file_index: int) -> (file: api.MultipartFile, ok: bool) {
	data, lok := load_image_file(attachment_name, context.temp_allocator)
	if !lok do return {}, false

	return api.MultipartFile{
		field_name = fmt.tprintf("files[%d]", file_index),
		filename   = attachment_name,
		data       = data,
		mime_type  = "image/png",
	}, true
}
