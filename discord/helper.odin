package discord

import "base:runtime"
import "core:reflect"
import "core:strings"

deep_clone :: proc(val: $T, allocator: runtime.Allocator) -> T {
	dst := val
	val_any := any{&dst, typeid_of(T)}
	deep_clone_any(val_any, allocator)
	return dst
}

deep_clone_any :: proc(a: any, allocator: runtime.Allocator) {
	if a == nil do return

	ti := reflect.type_info_base(type_info_of(a.id))

	#partial switch info in ti.variant {
	case reflect.Type_Info_String:
		str_ptr := (^string)(a.data)
		if str_ptr^ != "" {
			str_ptr^ = strings.clone(str_ptr^, allocator)
		}
	case reflect.Type_Info_Struct:
		names := info.names[:info.field_count]
		offsets := info.offsets[:info.field_count]
		types := info.types[:info.field_count]

		for _, i in names {
			field_any := any {
				data = rawptr(uintptr(a.data) + offsets[i]),
				id   = types[i].id,
			}
			deep_clone_any(field_any, allocator)
		}
	case reflect.Type_Info_Array:
		for i in 0 ..< info.count {
			elem_any := any {
				data = rawptr(uintptr(a.data) + uintptr(i * info.elem.size)),
				id   = info.elem.id,
			}
			deep_clone_any(elem_any, allocator)
		}
	case reflect.Type_Info_Slice:
		slice_ptr := (^runtime.Raw_Slice)(a.data)
		if slice_ptr.len > 0 && slice_ptr.data != nil {
			old_data := slice_ptr.data
			element_size := info.elem.size

			new_bytes, _ := runtime.mem_alloc(slice_ptr.len * element_size, allocator = allocator)

			new_heap_ptr := raw_data(new_bytes)

			runtime.mem_copy(new_heap_ptr, old_data, slice_ptr.len * element_size)

			slice_ptr.data = new_heap_ptr

			for i in 0 ..< slice_ptr.len {
				elem_any := any {
					data = rawptr(uintptr(new_heap_ptr) + uintptr(i * element_size)),
					id   = info.elem.id,
				}
				deep_clone_any(elem_any, allocator)
			}
		}
	case reflect.Type_Info_Pointer:
		ptr := (^rawptr)(a.data)

		if ptr^ != nil {
			new_mem, _ := runtime.mem_alloc(info.elem.size, allocator = allocator)

			runtime.mem_copy(raw_data(new_mem), ptr^, info.elem.size)

			ptr^ = raw_data(new_mem)

			elem_any := any {
				data = ptr^,
				id   = info.elem.id,
			}

			deep_clone_any(elem_any, allocator)
		}
	case reflect.Type_Info_Union:
		tag_ptr := rawptr(uintptr(a.data) + info.tag_offset)
		tag_value: i64 = ---
		if info.tag_type != nil {
			switch info.tag_type.size {
			case 1: tag_value = i64((^u8)(tag_ptr)^)
			case 2: tag_value = i64((^u16)(tag_ptr)^)
			case 4: tag_value = i64((^u32)(tag_ptr)^)
			case 8: tag_value = (^i64)(tag_ptr)^
			}
		}
		if tag_value > 0 {
			idx := int(tag_value) - 1
			if idx < len(info.variants) {
				variant_ti := info.variants[idx]
				if variant_ti != nil {
					variant_any := any{data = a.data, id = variant_ti.id}
					deep_clone_any(variant_any, allocator)
				}
			}
		}
	case reflect.Type_Info_Map:
		// Maps are reference types. The parent struct's mem_copy
		// already shallow-copies the map header.
	}
}

deep_free :: proc(val: $T, allocator: runtime.Allocator) {
	v := val
	val_any := any{&v, typeid_of(T)}
	deep_free_any(val_any, allocator)
}

deep_free_any :: proc(a: any, allocator: runtime.Allocator) {
	if a == nil do return

	ti := reflect.type_info_base(type_info_of(a.id))

	#partial switch info in ti.variant {
	case reflect.Type_Info_String:
		str_ptr := (^string)(a.data)
		if str_ptr^ != "" {
			delete(str_ptr^, allocator)
			str_ptr^ = ""
		}

	case reflect.Type_Info_Struct:
		names := info.names[:info.field_count]
		offsets := info.offsets[:info.field_count]
		types := info.types[:info.field_count]

		for _, i in names {
			field_any := any {
				data = rawptr(uintptr(a.data) + offsets[i]),
				id   = types[i].id,
			}
			deep_free_any(field_any, allocator)
		}

	case reflect.Type_Info_Array:
		for i in 0 ..< info.count {
			elem_any := any {
				data = rawptr(uintptr(a.data) + uintptr(i * info.elem.size)),
				id   = info.elem.id,
			}
			deep_free_any(elem_any, allocator)
		}

	case reflect.Type_Info_Slice:
		slice_ptr := (^runtime.Raw_Slice)(a.data)
		if slice_ptr.data != nil {
			for i in 0 ..< slice_ptr.len {
				elem_any := any {
					data = rawptr(uintptr(slice_ptr.data) + uintptr(i * info.elem.size)),
					id   = info.elem.id,
				}
				deep_free_any(elem_any, allocator)
			}
			free(slice_ptr.data, allocator)
			slice_ptr.data = nil
			slice_ptr.len = 0
		}
	case reflect.Type_Info_Pointer:
		ptr := (^rawptr)(a.data)
		if ptr^ != nil {
			pointee_ti := reflect.type_info_base(info.elem)
			#partial switch inner in pointee_ti.variant {
			case reflect.Type_Info_Struct, reflect.Type_Info_Union,
			     reflect.Type_Info_Slice, reflect.Type_Info_String,
			     reflect.Type_Info_Array, reflect.Type_Info_Pointer:
				inner_any := any{data = ptr^, id = info.elem.id}
				deep_free_any(inner_any, allocator)
			}
			free(ptr^, allocator)
			ptr^ = nil
		}
	case reflect.Type_Info_Union:
		tag_ptr := rawptr(uintptr(a.data) + info.tag_offset)
		tag_value: i64 = ---
		if info.tag_type != nil {
			switch info.tag_type.size {
			case 1: tag_value = i64((^u8)(tag_ptr)^)
			case 2: tag_value = i64((^u16)(tag_ptr)^)
			case 4: tag_value = i64((^u32)(tag_ptr)^)
			case 8: tag_value = (^i64)(tag_ptr)^
			}
		}
		if tag_value > 0 {
			idx := int(tag_value) - 1
			if idx < len(info.variants) {
				variant_ti := info.variants[idx]
				if variant_ti != nil {
					variant_any := any{data = a.data, id = variant_ti.id}
					deep_free_any(variant_any, allocator)
				}
			}
		}
	case reflect.Type_Info_Map:
		// Map entries cannot be easily iterated from reflection.
	}
}
