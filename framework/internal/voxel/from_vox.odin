package voxel

import "vlx:internal/vox"

from_vox :: proc(model: vox.Model, allocator := context.allocator) -> (grid: Grid) {
	swapped := [3]int{model.dimensions.x, model.dimensions.z, model.dimensions.y}
	grid = create_grid(swapped, allocator)
	for &entry in model.voxels do set(&grid, int(entry.x), int(entry.z), int(entry.y), Voxel(entry.color_index))
	return
}
