package velux

import "base:runtime"
import "core:log"

import vox "_vox"

VOXEL_EMPTY :: Voxel(0)
PALETTE_SLOTS :: vox.PALETTE_SLOTS
PALETTE_BYTES :: vox.PALETTE_SLOTS * size_of(u32)

Voxel :: distinct u8

Voxel_Grid :: struct {
	voxels:     []Voxel,
	dimensions: [3]int,
}

Marker :: struct {
	palette_index: u8,
	position:      [3]int,
	index:         int,
}

Voxel_World :: struct {
	grid:   Voxel_Grid,
	buffer: GPU_Buffer(u32),
}

Level :: struct {
	world:   Voxel_World,
	markers: []Marker,
}

// Everything a .vox file yields before any of it touches a GPU, so the parser
// is testable without a device.
Level_Data :: struct {
	grid:    Voxel_Grid,
	markers: []Marker,
	palette: [PALETTE_SLOTS]u32,
}

@(private)
error_from_vox :: proc(err: vox.Error) -> Error {
	switch err {
	case .None:
		return .None
	case .File_Not_Found:
		return .Asset_Not_Found
	case .Bad_Magic, .Truncated, .No_Models:
		return .Asset_Malformed
	}
	return .Asset_Malformed
}

Voxel_API :: struct {
	load_level_data:    proc(
		file_name: string,
		reserved_from: u8,
		allocator: runtime.Allocator,
	) -> (Level_Data, Error),
	destroy_level_data: proc(data: ^Level_Data),
	upload_level:       proc(data: ^Level_Data) -> Voxel_World,
	load_level:         proc(file_name: string, reserved_from: u8) -> (Level, Error),
	unload_level:       proc(level: ^Level),
	create_grid:        proc(dimensions: [3]int, allocator: runtime.Allocator) -> Voxel_Grid,
	destroy_grid:       proc(grid: ^Voxel_Grid),
	get_voxel:          proc(grid: ^Voxel_Grid, x: int, y: int, z: int) -> Voxel,
	set_voxel:          proc(grid: ^Voxel_Grid, x: int, y: int, z: int, value: Voxel),
	destroy_mesh:       proc(mesh: ^Voxel_Mesh),
	mesh_grid_naive:    proc(grid: ^Voxel_Grid, voxel_size: f32, allocator: runtime.Allocator) -> Voxel_Mesh,
}

@(private, require_results)
host_voxel_api :: proc() -> Voxel_API {
	return {
		load_level_data = host_load_level_data,
		destroy_level_data = host_destroy_level_data,
		upload_level = host_upload_level,
		load_level = host_load_level,
		unload_level = host_unload_level,
		create_grid = host_create_grid,
		destroy_grid = host_destroy_grid,
		get_voxel = host_get_voxel,
		set_voxel = host_set_voxel,
		destroy_mesh = host_destroy_mesh,
		mesh_grid_naive = host_mesh_grid_naive,
	}
}

@(require_results)
load_level_data :: proc(
	file_name: string,
	reserved_from: u8,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	Level_Data,
	Error,
) {
	return bound_api(loc).voxel.load_level_data(file_name, reserved_from, allocator)
}

destroy_level_data :: proc(data: ^Level_Data, loc := #caller_location) {
	bound_api(loc).voxel.destroy_level_data(data)
}

@(require_results)
upload_level :: proc(data: ^Level_Data, loc := #caller_location) -> Voxel_World {
	return bound_api(loc).voxel.upload_level(data)
}

@(require_results)
load_level :: proc(file_name: string, reserved_from: u8, loc := #caller_location) -> (Level, Error) {
	return bound_api(loc).voxel.load_level(file_name, reserved_from)
}

unload_level :: proc(level: ^Level, loc := #caller_location) {
	bound_api(loc).voxel.unload_level(level)
}

@(require_results)
create_grid :: proc(dimensions: [3]int, allocator := context.allocator, loc := #caller_location) -> Voxel_Grid {
	return bound_api(loc).voxel.create_grid(dimensions, allocator)
}

destroy_grid :: proc(grid: ^Voxel_Grid, loc := #caller_location) {
	bound_api(loc).voxel.destroy_grid(grid)
}

@(require_results)
get_voxel :: proc(grid: ^Voxel_Grid, x, y, z: int, loc := #caller_location) -> Voxel {
	return bound_api(loc).voxel.get_voxel(grid, x, y, z)
}

set_voxel :: proc(grid: ^Voxel_Grid, x, y, z: int, value: Voxel, loc := #caller_location) {
	bound_api(loc).voxel.set_voxel(grid, x, y, z, value)
}

@(private, require_results)
host_load_level_data :: proc(
	file_name: string,
	reserved_from: u8,
	allocator := context.allocator,
) -> (
	data: Level_Data,
	err: Error,
) {
	model, vox_err := vox.load(file_name, allocator)
	if vox_err != .None {
		log.errorf("cannot load '%v': %v", file_name, vox_err)
		return {}, error_from_vox(vox_err)
	}
	defer vox.destroy(&model, allocator)

	data.grid, data.markers = grid_from_vox(model, reserved_from, allocator)
	data.palette = vox.pack_palete(model)
	return data, .None
}

@(private)
host_destroy_level_data :: proc(data: ^Level_Data) {
	delete(data.markers)
	host_destroy_grid(&data.grid)
	data^ = {}
}

// Blocking, and meant to be: this is load-time work.
@(private, require_results)
host_upload_level :: proc(data: ^Level_Data) -> (world: Voxel_World) {
	packed_words := (len(data.grid.voxels) + 3) / 4
	world.buffer = create_gpu_buffer(u32, PALETTE_SLOTS + packed_words)
	world.grid = data.grid

	voxels := pack_voxels(&data.grid, context.temp_allocator)

	cmd := immediate_transfer_begin()
	write_staging_buffer_slice(cmd, &world.buffer, data.palette[:])
	write_staging_buffer_slice(cmd, &world.buffer, voxels, PALETTE_BYTES)
	immediate_transfer_end()
	return world
}

@(private, require_results)
host_load_level :: proc(file_name: string, reserved_from: u8) -> (level: Level, err: Error) {
	data := host_load_level_data(file_name, reserved_from) or_return
	// Ownership of grid and markers moves into the Level.
	level.world = host_upload_level(&data)
	level.markers = data.markers
	return level, .None
}

@(private)
host_unload_level :: proc(level: ^Level) {
	delete(level.markers)
	destroy_gpu_buffer(&level.world.buffer)
	host_destroy_grid(&level.world.grid)
	level^ = {}
}

@(private, require_results)
host_create_grid :: proc(dimensions: [3]int, allocator := context.allocator) -> (grid: Voxel_Grid) {
	grid.voxels = make([]Voxel, dimensions.x * dimensions.y * dimensions.z, allocator)
	grid.dimensions = dimensions
	return
}

@(private)
host_destroy_grid :: proc(grid: ^Voxel_Grid) {
	delete(grid.voxels)
	grid^ = {}
}

@(private, require_results)
host_get_voxel :: proc(grid: ^Voxel_Grid, x, y, z: int) -> Voxel {
	if !voxel_in_bounds(grid, x, y, z) do return VOXEL_EMPTY
	return grid.voxels[voxel_index(grid, x, y, z)]
}

@(private)
host_set_voxel :: proc(grid: ^Voxel_Grid, x, y, z: int, value: Voxel) {
	if !voxel_in_bounds(grid, x, y, z) do return
	grid.voxels[voxel_index(grid, x, y, z)] = value
}

@(private, require_results)
voxel_index :: proc(grid: ^Voxel_Grid, x, y, z: int) -> int {
	return x + y * grid.dimensions.x + z * grid.dimensions.x * grid.dimensions.y
}

@(private, require_results)
voxel_in_bounds :: proc(grid: ^Voxel_Grid, x, y, z: int) -> bool {
	if x < 0 || y < 0 || z < 0 do return false
	return x < grid.dimensions.x && y < grid.dimensions.y && z < grid.dimensions.z
}

@(private, require_results)
pack_voxels :: proc(grid: ^Voxel_Grid, allocator := context.allocator) -> (packed: []u32) {
	packed = make([]u32, (len(grid.voxels) + 3) / 4, allocator)
	for value, position in grid.voxels {
		word := position / 4
		slot := position % 4
		packed[word] |= u32(value) << uint(slot * 8)
	}
	return
}

@(private, require_results)
grid_from_vox :: proc(
	model: vox.Model,
	reserved_from: u8,
	allocator := context.allocator,
) -> (
	grid: Voxel_Grid,
	markers: []Marker,
) {
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
				set_voxel(&grid, x, y, z, Voxel(entry.color_index))
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

@(private, require_results)
tile_minimum :: proc(tile: vox.Tile) -> [3]int {
	return {tile.translation.x - tile.size.x / 2, tile.translation.y - tile.size.y / 2, tile.translation.z - tile.size.z / 2}
}
