package velux

import "base:runtime"

import "vendor:cgltf"

Mesh_API :: struct {
	load_mesh: proc(file_name: string, allocator: runtime.Allocator) -> (Mesh_Data, bool),
}

Mesh_Data :: struct {
	vertices:         []Vertex,
	indices:          []u32,
	material_indices: []u8,
}

Primitive :: struct {
	first_index:   u32,
	index_count:   u32,
	vertex_offset: i32,
	material:      u32,
}

Material_Data :: struct {
	base_color_factor:  [4]f32,
	metallic_roughness: [2]f32,
	base_color_image:   i32,
	normal_image:       i32,
}

Image_Data :: struct {
	pixels: []u8,
	width:  i32,
	height: i32,
	srgb:   bool,
}
