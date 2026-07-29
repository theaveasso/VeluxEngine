package velux

import "vlx:internal/vox"
import "vlx:internal/voxel"

VOXEL_EMPTY :: voxel.EMPTY
PALETTE_BYTES :: vox.PALETTE_SLOTS * size_of(u32)

Voxel :: voxel.Voxel
Voxel_Grid :: voxel.Grid
Voxel_World :: struct {
	grid:   Voxel_Grid,
	buffer: Buffer(u32),
}

// create_voxel_grid :: voxel.create
// destroy_voxel_grid :: voxel.destroy
// voxel_index :: voxel.index
// voxel_at :: voxel.at
// voxel_set :: voxel.set
// voxel_in_bounds :: voxel.in_bounds
// voxel_raycast :: voxel.raycast
// voxel_carve_sphere :: voxel.carve_sphere
// grid_to_u32 :: voxel.to_u32

@(require_results)
create_voxel_world :: proc(file_name: string) -> (world: Voxel_World, err: Error) {
	model := vox.load(file_name) or_return
	world.grid = voxel.from_vox(model)
	world.buffer = create_buffer(u32, 256 + len(world.grid.voxels)) or_return
	palette := vox.pack_palete(model)
	voxels := voxel.to_u32(&world.grid, context.temp_allocator)

	cmd := immediate_transfer_begin() or_return
	write_staging_buffer_slice(cmd, &world.buffer, palette[:]) or_return
	write_staging_buffer_slice(cmd, &world.buffer, voxels, 1024) or_return
	immediate_transfer_end() or_return
	return
}

destroy_voxel_world :: proc(world: ^Voxel_World) {
	destroy_buffer(&world.buffer)
	voxel.destroy_grid(&world.grid)
}
