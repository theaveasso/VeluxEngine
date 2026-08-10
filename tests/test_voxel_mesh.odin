package tests

import "core:testing"

import vlx "vlx:velux"

@(test)
naive_empty_grid_has_no_triangles :: proc(t: ^testing.T) {
	grid := vlx.create_grid({4, 4, 4})
	defer vlx.destroy_grid(&grid)

	mesh := vlx.mesh_grid_naive(&grid, 0.25)
	defer vlx.destroy_mesh(&mesh)

	testing.expect_value(t, len(mesh.indices), 0)
}

@(test)
naive_single_voxel_has_six_faces :: proc(t: ^testing.T) {
	grid := vlx.create_grid({3, 3, 3})
	defer vlx.destroy_grid(&grid)
	vlx.set_voxel(&grid, 1, 1, 1, vlx.Voxel(1))

	mesh := vlx.mesh_grid_naive(&grid, 0.25)
	defer vlx.destroy_mesh(&mesh)

	testing.expect_value(t, len(mesh.indices), 36)
	testing.expect_value(t, len(mesh.positions), 24)
}

@(test)
naive_adjacent_voxels_cull_shared_face :: proc(t: ^testing.T) {
	grid := vlx.create_grid({4, 3, 3})
	defer vlx.destroy_grid(&grid)
	vlx.set_voxel(&grid, 1, 1, 1, vlx.Voxel(1))
	vlx.set_voxel(&grid, 2, 1, 1, vlx.Voxel(1))

	mesh := vlx.mesh_grid_naive(&grid, 0.25)
	defer vlx.destroy_mesh(&mesh)

	testing.expect_value(t, len(mesh.indices), 60)
}

@(test)
naive_solid_block_has_twentyfour_faces :: proc(t: ^testing.T) {
	grid := vlx.create_grid({2, 2, 2})
	defer vlx.destroy_grid(&grid)
	for x in 0 ..< 2 do for y in 0 ..< 2 do for z in 0 ..< 2 {
		vlx.set_voxel(&grid, x, y, z, vlx.Voxel(1))
	}

	mesh := vlx.mesh_grid_naive(&grid, 0.25)
	defer vlx.destroy_mesh(&mesh)

	testing.expect_value(t, len(mesh.indices), 144)
}

@(test)
naive_scales_positions_by_voxel_size :: proc(t: ^testing.T) {
	grid := vlx.create_grid({3, 3, 3})
	defer vlx.destroy_grid(&grid)
	vlx.set_voxel(&grid, 1, 1, 1, vlx.Voxel(1))

	mesh := vlx.mesh_grid_naive(&grid, 0.25)
	defer vlx.destroy_mesh(&mesh)

	low := [3]f32{max(f32), max(f32), max(f32)}
	high := [3]f32{min(f32), min(f32), min(f32)}
	for p in mesh.positions {
		for axis in 0 ..< 3 {
			low[axis] = min(low[axis], p[axis])
			high[axis] = max(high[axis], p[axis])
		}
	}

	for axis in 0 ..< 3 {
		testing.expectf(t, abs(low[axis] - 0.25) < 1e-6, "axis %d low was %v, want 0.25", axis, low[axis])
		testing.expectf(t, abs(high[axis] - 0.50) < 1e-6, "axis %d high was %v, want 0.50", axis, high[axis])
	}
}
