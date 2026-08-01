package vox

import "core:strconv"
import "core:strings"

Scene :: struct {
	transforms: map[i32]Transform_Node,
	groups:     map[i32]Group_Node,
	shapes:     map[i32]Shape_Node,
}

Group_Node :: struct {
	id:       i32,
	children: []i32,
}

Shape_Node :: struct {
	id:     i32,
	models: []i32,
}

Transform_Node :: struct {
	id:          i32,
	child:       i32,
	translation: [3]int,
}

Placement :: struct {
	model_id:    i32,
	translation: [3]int,
}

read_group_node :: proc(content: []u8, allocator := context.allocator) -> (node: Group_Node, ok: bool) {
	id, after_id, id_ok := read_i32(content, 0)
	if !id_ok do return {}, false

	_, after_dict, dict_ok := read_dict(content, after_id, "")
	if !dict_ok do return {}, false

	count, cursor, count_ok := read_i32(content, after_dict)
	if !count_ok do return {}, false
	if count < 0 || int(count) * 4 > len(content) - cursor do return {}, false

	children := make([]i32, int(count), allocator)
	for index in 0 ..< int(count) {
		child, after_child, child_ok := read_i32(content, cursor)
		if !child_ok {
			delete(children, allocator)
			return {}, false
		}
		children[index] = child
		cursor = after_child
	}

	node.id = id
	node.children = children
	return node, true
}

read_shape_node :: proc(content: []u8, allocator := context.allocator) -> (node: Shape_Node, ok: bool) {
	id, after_id, id_ok := read_i32(content, 0)
	if !id_ok do return {}, false

	_, after_dict, dict_ok := read_dict(content, after_id, "")
	if !dict_ok do return {}, false

	count, cursor, count_ok := read_i32(content, after_dict)
	if !count_ok do return {}, false
	if count < 0 || int(count) * 8 > len(content) - cursor do return {}, false

	models := make([]i32, int(count), allocator)
	for index in 0 ..< int(count) {
		model_id, after_model, model_ok := read_i32(content, cursor)
		if !model_ok {
			delete(models, allocator)
			return {}, false
		}

		_, after_attributes, attributes_ok := read_dict(content, after_model, "")
		if !attributes_ok {
			delete(models, allocator)
			return {}, false
		}

		models[index] = model_id
		cursor = after_attributes
	}

	node.id = id
	node.models = models
	return node, true
}

parse_translation :: proc(text: string) -> (translation: [3]int, ok: bool) {
	if text == "" do return {0, 0, 0}, true

	parts := strings.fields(text, context.temp_allocator)
	if len(parts) != 3 do return {}, false

	for part, index in parts {
		value, value_ok := strconv.parse_int(part, 10)
		if !value_ok do return {}, false
		translation[index] = value
	}
	return translation, true
}

read_transform_node :: proc(content: []u8) -> (node: Transform_Node, ok: bool) {
	id, after_id, id_ok := read_i32(content, 0)
	if !id_ok do return {}, false

	_, after_dict, dict_ok := read_dict(content, after_id, "")
	if !dict_ok do return {}, false

	child, after_child, child_ok := read_i32(content, after_dict)
	if !child_ok do return {}, false

	_, after_reserved, reserved_ok := read_i32(content, after_child)
	if !reserved_ok do return {}, false

	_, after_layer, layer_ok := read_i32(content, after_reserved)
	if !layer_ok do return {}, false

	frame_count, cursor, frame_count_ok := read_i32(content, after_layer)
	if !frame_count_ok do return {}, false
	if frame_count < 0 do return {}, false

	for index in 0 ..< int(frame_count) {
		text, after_frame, frame_ok := read_dict(content, cursor, "_t")
		if !frame_ok do return {}, false

		if index == 0 {
			translation, translation_ok := parse_translation(text)
			if !translation_ok do return {}, false
			node.translation = translation
		}
		cursor = after_frame
	}

	node.id = id
	node.child = child
	return node, true
}

walk_node :: proc(scene: ^Scene, node_id: i32, translation: [3]int, placements: ^[dynamic]Placement, depth := 0) {
	if depth > 64 do return

	if transform, found := scene.transforms[node_id]; found {
		walk_node(scene, transform.child, translation + transform.translation, placements, depth + 1)
		return
	}

	if group, found := scene.groups[node_id]; found {
		for child in group.children {
			walk_node(scene, child, translation, placements, depth + 1)
		}
		return
	}

	if shape, found := scene.shapes[node_id]; found {
		for model_id in shape.models {
			append(placements, Placement{model_id = model_id, translation = translation})
		}
	}
}
