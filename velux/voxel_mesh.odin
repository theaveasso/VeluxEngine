package velux

Voxel_Mesh :: struct {
	positions: [][3]f32,
	indices:   []u32,
}

destroy_mesh :: proc(mesh: ^Voxel_Mesh) {
	delete(mesh.positions)
	delete(mesh.indices)
	mesh^ = {}
}

@(require_results)
mesh_grid_naive :: proc(
	grid: ^Voxel_Grid,
	voxel_size: f32,
	allocator := context.allocator,
) -> (mesh: Voxel_Mesh) {
	positions := make([dynamic][3]f32, 0, 0, allocator)
	indices := make([dynamic]u32, 0, 0, allocator)

	mesh.positions = positions[:]
	mesh.indices = indices[:]
	return
}
