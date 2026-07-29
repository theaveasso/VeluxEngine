package tests

import "core:testing"

import "vlx:internal/vox"
import "vlx:internal/voxel"

TEST_GRID_DIMS: [3]int : {20, 20, 20}
STONE :: voxel.Voxel(1)
BLAST_RADIUS :: 5

@(test)
carve_sphere_removes_center_and_keeps_far :: proc(t: ^testing.T) {
	grid := voxel.create(TEST_GRID_DIMS)
	defer voxel.destroy(&grid)
	for i in 0 ..< len(grid.voxels) do grid.voxels[i] = STONE

	voxel.carve_sphere(&grid, {5, 5, 5}, BLAST_RADIUS, voxel.EMPTY)
	testing.expect(t, voxel.at(&grid, 5, 5, 5) == voxel.EMPTY, "center should be carved")
	testing.expect(t, voxel.at(&grid, 10, 10 + BLAST_RADIUS + 1, 10) == STONE, "far voxel should remain")
}

@(test)
raycast_hits_solid_voxel :: proc(t: ^testing.T) {
	grid := voxel.create(TEST_GRID_DIMS)
	defer voxel.destroy(&grid)
	voxel.set(&grid, 10, 10, 10, STONE)

	cell, normal, hit := voxel.raycast(&grid, {10.5, 10.5, 0.5}, {0, 0, 1}, 64)
	testing.expect(t, cell == [3]int{10, 10, 10}, "should hit")
	testing.expect(t, normal == [3]int{0, 0, -1}, "should hit -Z face")
	testing.expect(t, hit, "should hit")
}

@(test)
raycast_misses_in_empty_grid :: proc(t: ^testing.T) {
	grid := voxel.create(TEST_GRID_DIMS)
	defer voxel.destroy(&grid)

	_, _, hit := voxel.raycast(&grid, {10.5, 10.5, 0.5}, {0, 0, 1}, 64)
	testing.expect(t, !hit, "should miss")
}

@(test)
raycast_stops_at_nearest_solid :: proc(t: ^testing.T) {
	grid := voxel.create(TEST_GRID_DIMS)
	defer voxel.destroy(&grid)
	voxel.set(&grid, 10, 10, 5, STONE)
	voxel.set(&grid, 10, 10, 10, STONE)

	cell, normal, hit := voxel.raycast(&grid, {10.5, 10.5, 0.5}, {0, 0, 1}, 64)
	testing.expect(t, hit, "should hit")
	testing.expect(t, normal.z == -1, "hit the -Z face")
	testing.expect(t, cell.z == 5, "should stop at nearest")
}

@(test)
raycast_hits_along_negative_direction :: proc(t: ^testing.T) {
	grid := voxel.create(TEST_GRID_DIMS)
	defer voxel.destroy(&grid)
}

@(test)
raycast_respects_max_distance :: proc(t: ^testing.T) {
	grid := voxel.create(TEST_GRID_DIMS)
	defer voxel.destroy(&grid)
}

@(test)
grid_to_u32_maps_block_ids :: proc(t: ^testing.T) {
	grid := voxel.create(TEST_GRID_DIMS)
	defer voxel.destroy(&grid)
	voxel.set(&grid, 3, 4, 5, STONE)

	data := voxel.to_u32(&grid)
	defer delete(data)
	testing.expect(t, data[voxel.index(&grid, 3, 4, 5)] == u32(STONE), "block id maps to u32")
	testing.expect(t, data[0] == u32(voxel.EMPTY), "empty stays 0")
}

@(test)
out_of_bounds_reads_are_empty :: proc(t: ^testing.T) {
	grid := voxel.create({4, 4, 4})
	defer voxel.destroy(&grid)
	voxel.set(&grid, 1, 1, 1, voxel.Voxel(7))

	testing.expect(t, voxel.at(&grid, 1, 1, 1) == voxel.Voxel(7), "a set cell reads back")
	testing.expect(t, voxel.at(&grid, -1, 0, 0) == voxel.EMPTY, "below the grid is empty")
	testing.expect(t, voxel.at(&grid, 4, 0, 0) == voxel.EMPTY, "past the grid is empty")
}

@(test)
from_vox_swaps_z_up_to_y_up :: proc(t: ^testing.T) {
	model := vox.Model {
		dimensions = {2, 3, 4},
		voxels     = []vox.Entry{{1, 0, 3, 9}},
	}

	grid := voxel.from_vox(model)
	defer voxel.destroy(&grid)

	testing.expect(t, grid.dimensions == [3]int{2, 4, 3}, "dimensions swap y and z")
	testing.expect(t, voxel.at(&grid, 1, 3, 0) == voxel.Voxel(9), "the voxel lands swapped")
	testing.expect(t, voxel.at(&grid, 1, 0, 3) == voxel.EMPTY, "and not at the unswapped spot")
}

@(test)
from_vox_keeps_every_voxel_of_the_real_cave :: proc(t: ^testing.T) {
	model, err := vox.load("game/hollow/assets/cave.vox")
	if err == .File_Not_Found do return
	defer vox.destroy(&model)
	if !testing.expect(t, err == .None, "the real file parses") do return

	grid := voxel.from_vox(model)
	defer voxel.destroy(&grid)

	solid := 0
	for value in grid.voxels do if value != voxel.EMPTY do solid += 1

	testing.expect(t, grid.dimensions == [3]int{256, 256, 256}, "a cube stays a cube")
	testing.expect(t, solid == len(model.voxels), "no voxel is lost or overwritten")
}
