package voxel

import "core:math"

Voxel :: distinct u8
EMPTY :: Voxel(0)

Grid :: struct {
	voxels:     []Voxel,
	dimensions: [3]int,
}

@(require_results)
create_grid :: proc(dimensions: [3]int, allocator := context.allocator) -> (grid: Grid) {
	grid.voxels = make([]Voxel, dimensions.x * dimensions.y * dimensions.z, allocator)
	grid.dimensions = dimensions
	return
}

destroy_grid :: proc(grid: ^Grid) {
	delete(grid.voxels)
	grid^ = {}
}

@(require_results)
index :: proc(grid: ^Grid, x, y, z: int) -> int {
	return x + y * grid.dimensions.x + z * grid.dimensions.x * grid.dimensions.y
}

@(require_results)
in_bounds :: proc(grid: ^Grid, x, y, z: int) -> bool {
	if x < 0 || y < 0 || z < 0 do return false
	return x < grid.dimensions.x && y < grid.dimensions.y && z < grid.dimensions.z
}

@(require_results)
at :: proc(grid: ^Grid, x, y, z: int) -> Voxel {
	if !in_bounds(grid, x, y, z) do return EMPTY
	return grid.voxels[index(grid, x, y, z)]
}

set :: proc(grid: ^Grid, x, y, z: int, value: Voxel) {
	if !in_bounds(grid, x, y, z) do return
	grid.voxels[index(grid, x, y, z)] = value
}

@(require_results)
to_packed_u32 :: proc(grid: ^Grid, allocator := context.allocator) -> (packed: []u32) {
	packed = make([]u32, (len(grid.voxels) + 3) / 4, allocator)
	for value, position in grid.voxels {
		word := position / 4
		slot := position % 4
		packed[word] |= u32(value) << uint(slot * 8)
	}
	return
}
