package voxel

import "vlx:internal/vox"

from_vox :: proc(model: vox.Model, reserved_from: u8, allocator := context.allocator) -> (grid: Grid, markers: []Marker) {
	if len(model.tiles) == 0 do return

	minimum := [3]int{max(int), max(int), max(int)}
	maximum := [3]int{min(int), min(int), min(int)}

	for tile in model.tiles {
		tile_min := tile_minimum(tile)
		for axis in 0 ..< 3 {
			minimum[axis] = min(minimum[axis], tile_min[axis])
			maximum[axis] = max(maximum[axis], tile_min[axis] + tile.size[axis])
		}
	}

	span := maximum - minimum
	grid = create_grid({span.x, span.y, span.z}, allocator)

	marker_found := make([dynamic]Marker, 0, 16, allocator)
	marker_counts: [vox.PALETTE_SLOTS]int

	for tile in model.tiles {
		origin := tile_minimum(tile) - minimum

		for entry in tile.voxels {
			x := origin.x + int(entry.x)
			y := origin.y + int(entry.y)
			z := origin.z + int(entry.z)

			if entry.color_index < reserved_from {
				set(&grid, x, y, z, Voxel(entry.color_index))
				continue
			}

			slot := int(entry.color_index)
			append(&marker_found, Marker{palette_index = entry.color_index, position = {x, y, z}, index = marker_counts[slot]})
			marker_counts[slot] += 1
		}
	}

	markers = marker_found[:]
	return
}

@(private)
tile_minimum :: proc(tile: vox.Tile) -> [3]int {
	return {tile.translation.x - tile.size.x / 2, tile.translation.y - tile.size.y / 2, tile.translation.z - tile.size.z / 2}
}
