package velux

import "vlx:internal/vox"
import "vlx:internal/voxel"

VOXEL_EMPTY :: voxel.EMPTY
PALETTE_SLOTS :: vox.PALETTE_SLOTS
PALETTE_BYTES :: vox.PALETTE_SLOTS * size_of(u32)

Voxel :: voxel.Voxel
Marker :: voxel.Marker
Voxel_Grid :: voxel.Grid

marker_vox_position :: voxel.vox_position

Voxel_World :: struct {
	grid:   Voxel_Grid,
	buffer: Buffer(u32),
}

Level :: struct {
	world:   Voxel_World,
	markers: []Marker,
}

@(require_results)
create_level :: proc(file_name: string, reserved_from: u8) -> (level: Level, err: Error) {
	model := vox.load(file_name) or_return
	defer vox.destroy(&model)

	level.world.grid, level.markers = voxel.from_vox(model, reserved_from)
	packed_words := (len(level.world.grid.voxels) + 3) / 4
	level.world.buffer = create_buffer(u32, PALETTE_SLOTS + packed_words) or_return

	palette := vox.pack_palete(model)
	voxels := voxel.to_packed_u32(&level.world.grid, context.temp_allocator)

	cmd := immediate_transfer_begin() or_return
	write_staging_buffer_slice(cmd, &level.world.buffer, palette[:]) or_return
	write_staging_buffer_slice(cmd, &level.world.buffer, voxels, PALETTE_BYTES) or_return
	immediate_transfer_end() or_return
	return
}

destroy_level :: proc(level: ^Level) {
	delete(level.markers)
	destroy_voxel_world(&level.world)
	level^ = {}
}

destroy_voxel_world :: proc(world: ^Voxel_World) {
	destroy_buffer(&world.buffer)
	voxel.destroy_grid(&world.grid)
}
