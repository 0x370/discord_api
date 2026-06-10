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

		for name, i in names {
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
		}

	case reflect.Type_Info_Struct:
		names := info.names[:info.field_count]
		offsets := info.offsets[:info.field_count]
		types := info.types[:info.field_count]

		for name, i in names {
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
			runtime.mem_free(slice_ptr.data, allocator)
			slice_ptr.data = nil
			slice_ptr.len = 0
		}
	case reflect.Type_Info_Pointer:
		ptr := (^rawptr)(a.data)

		if ptr^ != nil {
			elem_any := any {
				data = ptr^,
				id   = info.elem.id,
			}

			deep_free_any(elem_any, allocator)
			runtime.mem_free(ptr^, allocator)
			ptr^ = nil
		}
	}
}
