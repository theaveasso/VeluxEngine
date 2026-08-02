package velux

import "base:runtime"
import "core:fmt"

FNV_OFFSET_BASIS :: 0xcbf29ce484222325
FNV_PRIME :: 0x100000001b3

@(require_results)
type_signature :: proc($T: typeid) -> u64 {
	hash := u64(FNV_OFFSET_BASIS)
	hash_type_info(&hash, type_info_of(T))
	return hash
}

@(private)
hash_type_info :: proc(hash: ^u64, ti: ^runtime.Type_Info) {
	#partial switch variant in ti.variant {
	case runtime.Type_Info_Named:
		hash_string(hash, variant.name)
		hash_type_info(hash, variant.base)

	case runtime.Type_Info_Struct:
		hash_number(hash, u64(variant.field_count))
		for index in 0 ..< int(variant.field_count) {
			hash_string(hash, variant.names[index])
			hash_number(hash, u64(variant.offsets[index]))
			hash_type_info(hash, variant.types[index])
		}

	case runtime.Type_Info_Array:
		hash_number(hash, u64(variant.count))
		hash_type_info(hash, variant.elem)

	case runtime.Type_Info_Enumerated_Array:
		hash_number(hash, u64(variant.count))
		hash_type_info(hash, variant.elem)

	case runtime.Type_Info_Pointer:
		hash_pointer_target(hash, variant.elem)

	case runtime.Type_Info_Multi_Pointer:
		hash_pointer_target(hash, variant.elem)

	case:
		hash_number(hash, u64(ti.size))
		hash_string(hash, fmt.tprintf("%v", ti))
	}
}

@(private)
hash_pointer_target :: proc(hash: ^u64, elem: ^runtime.Type_Info) {
	if elem == nil {
		hash_string(hash, "rawptr")
		return
	}
	hash_string(hash, fmt.tprintf("%v", elem))
}

@(private)
hash_bytes :: proc(hash: ^u64, data: []byte) {
	for value in data {
		hash^ ~= u64(value)
		hash^ *= FNV_PRIME
	}
}

@(private)
hash_string :: proc(hash: ^u64, text: string) {
	hash_bytes(hash, transmute([]byte)text)
}

@(private)
hash_number :: proc(hash: ^u64, value: u64) {
	value := value
	hash_bytes(hash, (cast([^]byte)&value)[:8])
}
