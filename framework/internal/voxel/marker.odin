package voxel

Marker :: struct {
	palette_index: u8,
	position:      [3]int,
	index:         int,
}

@(require_results)
vox_position :: proc(marker: Marker) -> [3]int {
	return {marker.position.x, marker.position.z, marker.position.y}
}
