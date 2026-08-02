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

Tile :: struct {
	size:        [3]int,
	translation: [3]int,
	voxels:      []Entry,
}

Model :: struct {
	tiles:   []Tile,
	palette: [256][4]u8,
	version: i32,
}

CHUNK_HEADER_SIZE :: 12
PALETTE_SLOTS :: 256

read_string :: proc(data: []u8, offset: int) -> (value: string, next: int, ok: bool) {
	length, after_length, length_ok := read_i32(data, offset)
	if !length_ok || length < 0 do return "", offset, false

	end := after_length + int(length)
	if end < after_length || end > len(data) do return "", offset, false
	return string(data[after_length:end]), end, true
}

read_dict :: proc(data: []u8, offset: int, key: string) -> (value: string, next: int, ok: bool) {
	count, cursor, count_ok := read_i32(data, offset)
	if !count_ok || count < 0 do return "", offset, false

	for _ in 0 ..< int(count) {
		pair_key, after_key, key_ok := read_string(data, cursor)
		if !key_ok do return "", offset, false

		pair_value, after_value, value_ok := read_string(data, after_key)
		if !value_ok do return "", offset, false

		if pair_key == key do value = pair_value
		cursor = after_value
	}
	return value, cursor, true
}

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

	scratch := context.temp_allocator

	sizes := make([dynamic][3]int, 0, 16, scratch)
	voxel_lists := make([dynamic][]Entry, 0, 16, scratch)

	scene: Scene
	scene.transforms = make(map[i32]Transform_Node, 16, scratch)
	scene.groups = make(map[i32]Group_Node, 4, scratch)
	scene.shapes = make(map[i32]Shape_Node, 16, scratch)

	offset := 0
	body := main_chunk.children
	for offset < len(body) {
		chunk, next, ok := next_chunk(body, offset)
		if !ok do return {}, .Truncated

		switch {
		case is_id(chunk, "SIZE"):
			size_x, after_x, ok_x := read_i32(chunk.content, 0)
			size_y, after_y, ok_y := read_i32(chunk.content, after_x)
			size_z, _, ok_z := read_i32(chunk.content, after_y)
			if !ok_x || !ok_y || !ok_z do return {}, .Truncated
			if size_x <= 0 || size_y <= 0 || size_z <= 0 do return {}, .Truncated
			append(&sizes, [3]int{int(size_x), int(size_y), int(size_z)})

		case is_id(chunk, "XYZI"):
			count, after_count, ok_count := read_i32(chunk.content, 0)
			if !ok_count || count < 0 do return {}, .Truncated
			if after_count + int(count) * 4 > len(chunk.content) do return {}, .Truncated

			entries := make([]Entry, int(count), scratch)
			for index in 0 ..< int(count) {
				base := after_count + index * 4
				entries[index] = {
					x           = chunk.content[base],
					y           = chunk.content[base + 1],
					z           = chunk.content[base + 2],
					color_index = chunk.content[base + 3],
				}
			}
			append(&voxel_lists, entries)

		case is_id(chunk, "RGBA"):
			if len(chunk.content) < PALETTE_SLOTS * 4 do return {}, .Truncated
			for slot in 0 ..< PALETTE_SLOTS {
				base := slot * 4
				model.palette[slot] = {chunk.content[base], chunk.content[base + 1], chunk.content[base + 2], chunk.content[base + 3]}
			}

		case is_id(chunk, "nTRN"):
			node, node_ok := read_transform_node(chunk.content)
			if !node_ok do return {}, .Truncated
			scene.transforms[node.id] = node

		case is_id(chunk, "nGRP"):
			node, node_ok := read_group_node(chunk.content, scratch)
			if !node_ok do return {}, .Truncated
			scene.groups[node.id] = node

		case is_id(chunk, "nSHP"):
			node, node_ok := read_shape_node(chunk.content, scratch)
			if !node_ok do return {}, .Truncated
			scene.shapes[node.id] = node
		}

		offset = next
	}

	if len(sizes) == 0 || len(sizes) != len(voxel_lists) do return {}, .No_Models

	placements := make([dynamic]Placement, 0, 16, scratch)
	if len(scene.transforms) == 0 && len(scene.groups) == 0 && len(scene.shapes) == 0 {
		append(&placements, Placement{model_id = 0, translation = {0, 0, 0}})
	} else {
		walk_node(&scene, 0, {0, 0, 0}, &placements)
	}
	if len(placements) == 0 do return {}, .No_Models

	model.tiles = make([]Tile, len(placements), allocator)
	for placement, index in placements {
		model_id := int(placement.model_id)
		if model_id < 0 || model_id >= len(sizes) {
			for filled in 0 ..< index {
				delete(model.tiles[filled].voxels, allocator)
			}
			delete(model.tiles, allocator)
			return {}, .No_Models
		}

		source := voxel_lists[model_id]
		voxels := make([]Entry, len(source), allocator)
		copy(voxels, source)

		model.tiles[index] = {
			size        = sizes[model_id],
			translation = placement.translation,
			voxels      = voxels,
		}
	}

	return model, .None
}

destroy :: proc(model: ^Model, allocator := context.allocator) {
	for tile in model.tiles {
		delete(tile.voxels, allocator)
	}
	if model.tiles != nil do delete(model.tiles, allocator)
	model^ = {}
}

load :: proc(file_name: string, allocator := context.allocator) -> (model: Model, err: Error) {
	data, read_err := os.read_entire_file(file_name, context.temp_allocator)
	if read_err != nil do return {}, .File_Not_Found
	return parse(data, allocator)
}
