package voxel

import "vlx:internal/vox"

from_vox :: proc(
	model: vox.Model,
	reserved_from: u8,
	allocator := context.allocator,
) -> (
	grid: Grid,
	markers: []Marker,
) {
	swapped := [3]int{model.dimensions.x, model.dimensions.z, model.dimensions.y}
	grid = create_grid(swapped, allocator)

	marker_found := make([dynamic]Marker, 0, 16, allocator)
	marker_counts: [vox.PALETTE_SLOTS]int

	for entry in model.voxels {
		if entry.color_index < reserved_from {
			set(&grid, int(entry.x), int(entry.z), int(entry.y), Voxel(entry.color_index))
			continue
		}

		slot := int(entry.color_index)
		append(
			&marker_found,
			Marker {
				palette_index = entry.color_index,
				position = {int(entry.x), int(entry.z), int(entry.y)},
				index = marker_counts[slot],
			},
		)
		marker_counts[slot] += 1
	}

	markers = marker_found[:]
	return
}
