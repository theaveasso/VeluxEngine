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
to_u32 :: proc(grid: ^Grid, allocator := context.allocator) -> []u32 {
	out := make([]u32, len(grid.voxels), allocator)
	for value, position in grid.voxels do out[position] = u32(value)
	return out
}

carve_sphere :: proc(grid: ^Grid, center: [3]int, radius: f32, fill: Voxel) {
	reach := int(radius) + 1
	for offset_z in -reach ..= reach {
		for offset_y in -reach ..= reach {
			for offset_x in -reach ..= reach {
				distance := math.sqrt(f32(offset_x * offset_x + offset_y * offset_y + offset_z * offset_z))
				if distance <= radius {
					set(grid, center.x + offset_x, center.y + offset_y, center.z + offset_z, fill)
				}
			}
		}
	}
}

raycast :: proc(grid: ^Grid, origin, direction: [3]f32, max_distance: f32) -> (cell: [3]int, normal: [3]int, hit: bool) {
	STEP :: 0.1
	position := origin
	previous_cell := [3]int{int(position.x), int(position.y), int(position.z)}
	for _ in 0 ..< int(max_distance / STEP) {
		cell = {int(position.x), int(position.y), int(position.z)}
		if at(grid, cell.x, cell.y, cell.z) != EMPTY do return cell, previous_cell - cell, true
		previous_cell = cell
		position += direction * STEP
	}
	return {}, {}, false
}
