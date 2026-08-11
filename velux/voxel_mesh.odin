package velux

Voxel_Mesh :: struct {
	positions: [][3]f32,
	indices:   []u32,
}

destroy_mesh :: proc(mesh: ^Voxel_Mesh, loc := #caller_location) {
	bound_api(loc).voxel.destroy_mesh(mesh)
}

@(require_results)
mesh_grid_naive :: proc(
	grid: ^Voxel_Grid,
	voxel_size: f32,
	allocator := context.allocator,
	loc := #caller_location,
) -> Voxel_Mesh {
	return bound_api(loc).voxel.mesh_grid_naive(grid, voxel_size, allocator)
}

@(private)
host_destroy_mesh :: proc(mesh: ^Voxel_Mesh) {
	delete(mesh.positions)
	delete(mesh.indices)
	mesh^ = {}
}

@(private, require_results)
host_mesh_grid_naive :: proc(
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
