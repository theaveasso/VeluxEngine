package vox

import "core:os"

Error :: enum {
	None,
	File_Not_Found,
	Bad_Magic,
	Truncated,
	No_Models,
}

Chunk :: struct {
	id:       [4]u8,
	content:  []u8,
	children: []u8,
}

Entry :: struct {
	x:           u8,
	y:           u8,
	z:           u8,
	color_index: u8,
}

Model :: struct {
	dimensions: [3]int,
	voxels:     []Entry,
	palette:    [256][4]u8,
	version:    i32,
}

CHUNK_HEADER_SIZE :: 12
PALETTE_SLOTS :: 256

read_i32 :: proc(data: []u8, offset: int) -> (value: i32, next: int, ok: bool) {
	if offset < 0 || offset + 4 > len(data) do return 0, offset, false
	value = i32(data[offset]) | i32(data[offset + 1]) << 8 | i32(data[offset + 2]) << 16 | i32(data[offset + 3]) << 24
	return value, offset + 4, true
}

read_header :: proc(data: []u8) -> (version: i32, next: int, ok: bool) {
	if len(data) < 8 do return 0, 0, false
	if data[0] != 'V' || data[1] != 'O' || data[2] != 'X' || data[3] != ' ' do return 0, 0, false
	return read_i32(data, 4)
}

next_chunk :: proc(data: []u8, offset: int) -> (chunk: Chunk, next: int, ok: bool) {
	if offset < 0 || offset + CHUNK_HEADER_SIZE > len(data) do return {}, offset, false

	chunk.id = {data[offset], data[offset + 1], data[offset + 2], data[offset + 3]}

	content_size, after_content_field, content_ok := read_i32(data, offset + 4)
	if !content_ok do return {}, offset, false

	children_size, content_start, children_ok := read_i32(data, after_content_field)
	if !children_ok do return {}, offset, false
	if content_size < 0 || children_size < 0 do return {}, offset, false

	content_end := content_start + int(content_size)
	children_end := content_end + int(children_size)
	if content_end < content_start || children_end < content_end do return {}, offset, false
	if children_end > len(data) do return {}, offset, false

	chunk.content = data[content_start:content_end]
	chunk.children = data[content_end:children_end]
	return chunk, children_end, true
}

is_id :: proc(chunk: Chunk, name: string) -> bool {
	if len(name) != 4 do return false
	return chunk.id[0] == name[0] && chunk.id[1] == name[1] && chunk.id[2] == name[2] && chunk.id[3] == name[3]
}

parse :: proc(data: []u8, allocator := context.allocator) -> (model: Model, err: Error) {
	version, after_header, header_ok := read_header(data)
	if !header_ok do return {}, .Bad_Magic
	model.version = version

	main_chunk, _, main_ok := next_chunk(data, after_header)
	if !main_ok do return {}, .Truncated
	if !is_id(main_chunk, "MAIN") do return {}, .Bad_Magic

	found_size := false
	found_voxels := false

	offset := 0
	body := main_chunk.children
	for offset < len(body) {
		chunk, next, ok := next_chunk(body, offset)
		if !ok do return {}, .Truncated

		switch {
		case is_id(chunk, "SIZE"):
			if found_size do break
			if len(chunk.content) < 12 do return {}, .Truncated
			size_x, after_x, ok_x := read_i32(chunk.content, 0)
			size_y, after_y, ok_y := read_i32(chunk.content, after_x)
			size_z, _, ok_z := read_i32(chunk.content, after_y)
			if !ok_x || !ok_y || !ok_z do return {}, .Truncated
			if size_x <= 0 || size_y <= 0 || size_z <= 0 do return {}, .Truncated
			model.dimensions = {int(size_x), int(size_y), int(size_z)}
			found_size = true

		case is_id(chunk, "XYZI"):
			if found_voxels do break
			count, after_count, ok_count := read_i32(chunk.content, 0)
			if !ok_count || count < 0 do return {}, .Truncated
			if after_count + int(count) * 4 > len(chunk.content) do return {}, .Truncated

			model.voxels = make([]Entry, int(count), allocator)
			for index in 0 ..< int(count) {
				base := after_count + index * 4
				model.voxels[index] = {
					x           = chunk.content[base],
					y           = chunk.content[base + 1],
					z           = chunk.content[base + 2],
					color_index = chunk.content[base + 3],
				}
			}
			found_voxels = true

		case is_id(chunk, "RGBA"):
			if len(chunk.content) < PALETTE_SLOTS * 4 do return {}, .Truncated
			for slot in 0 ..< PALETTE_SLOTS {
				base := slot * 4
				model.palette[slot] = {chunk.content[base], chunk.content[base + 1], chunk.content[base + 2], chunk.content[base + 3]}
			}
		}

		offset = next
	}

	if !found_size || !found_voxels {
		if model.voxels != nil do delete(model.voxels, allocator)
		return {}, .No_Models
	}
	return model, .None
}

load :: proc(file_name: string, allocator := context.allocator) -> (model: Model, err: Error) {
	data, read_err := os.read_entire_file(file_name, context.temp_allocator)
	if read_err != nil do return {}, .File_Not_Found
	return parse(data, allocator)
}

destroy :: proc(model: ^Model, allocator := context.allocator) {
	if model.voxels != nil do delete(model.voxels, allocator)
	model^ = {}
}
