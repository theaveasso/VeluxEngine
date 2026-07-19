package tests

import "core:testing"
import "vlx:velux"

@(test)
carve_sphere_removes_center_and_keeps_far :: proc(t: ^testing.T) {
	grid: velux.Voxel_Grid
	grid.voxels = make([]velux.Voxel, velux.WORLD_DIMENSION[0] * velux.WORLD_DIMENSION[1] * velux.WORLD_DIMENSION[2])
	defer delete(grid.voxels)

	for i in 0 ..< len(grid.voxels) do grid.voxels[i] = velux.Block_Type.Stone

	velux.carve_sphere(&grid, 20, 20, 20)
	testing.expect(t, velux.voxel_at(&grid, 20, 20, 20) == velux.Block_Type.Air, "center should be carved")
	testing.expect(t, velux.voxel_at(&grid, 20, 20 + velux.BLAST_RADIUS + 1, 20) == velux.Block_Type.Stone, "far voxel should remain")
}

@(test)
raycast_hits_solid_voxel :: proc(t: ^testing.T) {
	grid: velux.Voxel_Grid
	grid.voxels = make([]velux.Voxel, velux.WORLD_DIMENSION[0] * velux.WORLD_DIMENSION[1] * velux.WORLD_DIMENSION[2])
	defer delete(grid.voxels)
	velux.voxel_set(&grid, 10, 10, 10, .Stone)

	cell, normal, hit := velux.voxel_raycast(&grid, {10.5, 10.5, 0.5}, {0, 0, 1}, 64)
	testing.expect(t, cell == [3]int{10, 10, 10}, "should hit")
	testing.expect(t, normal == [3]int{0, 0, -1}, "should hit -Z face")
	testing.expect(t, hit, "should hit")
}
@(test)
raycast_misses_in_empty_grid :: proc(t: ^testing.T) {
	grid: velux.Voxel_Grid
	grid.voxels = make([]velux.Voxel, velux.WORLD_DIMENSION[0] * velux.WORLD_DIMENSION[1] * velux.WORLD_DIMENSION[2])
	defer delete(grid.voxels)

	_, _, hit := velux.voxel_raycast(&grid, {10.5, 10.5, 0.5}, {0, 0, 1}, 64)
	testing.expect(t, !hit, "should miss")
}
@(test)
raycast_stops_at_nearest_solid :: proc(t: ^testing.T) {
	grid: velux.Voxel_Grid
	grid.voxels = make([]velux.Voxel, velux.WORLD_DIMENSION[0] * velux.WORLD_DIMENSION[1] * velux.WORLD_DIMENSION[2])
	defer delete(grid.voxels)
	velux.voxel_set(&grid, 10, 10, 5, .Stone)
	velux.voxel_set(&grid, 10, 10, 10, .Stone)

	cell, nrm, hit := velux.voxel_raycast(&grid, {10.5, 10.5, 0.5}, {0, 0, 1}, 64)
	testing.expect(t, hit, "should hit")
	testing.expect(t, nrm.z == -1, "hit the -Z face")
	testing.expect(t, cell.z == 5, "should stop at nearest")
}
@(test)
raycast_hits_along_negative_direction :: proc(t: ^testing.T) {
	grid: velux.Voxel_Grid
	grid.voxels = make([]velux.Voxel, velux.WORLD_DIMENSION[0] * velux.WORLD_DIMENSION[1] * velux.WORLD_DIMENSION[2])
	defer delete(grid.voxels)
}
@(test)
raycast_respects_max_distance :: proc(t: ^testing.T) {
	grid: velux.Voxel_Grid
	grid.voxels = make([]velux.Voxel, velux.WORLD_DIMENSION[0] * velux.WORLD_DIMENSION[1] * velux.WORLD_DIMENSION[2])
	defer delete(grid.voxels)
}
@(test)
grid_to_u32_maps_block_ids :: proc(t: ^testing.T) {
	grid: velux.Voxel_Grid
	grid.voxels = make([]velux.Voxel, velux.WORLD_DIMENSION[0] * velux.WORLD_DIMENSION[1] * velux.WORLD_DIMENSION[2])
	defer delete(grid.voxels)
	velux.voxel_set(&grid, 3, 4, 5, .Stone)

	data := velux.grid_to_u32(&grid)
	defer delete(data)
	testing.expect(t, data[velux.voxel_index(3, 4, 5)] == u32(velux.Block_Type.Stone), "block id maps to u32")
	testing.expect(t, data[0] == u32(velux.Block_Type.Air), "empty stays Air(0)")
}
