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

@(require_results)
load_level_data :: proc(file_name: string, reserved_from: u8, allocator := context.allocator) -> (data: Level_Data, err: Error) {
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

destroy_level_data :: proc(data: ^Level_Data) {
	delete(data.markers)
	destroy_grid(&data.grid)
	data^ = {}
}

// Blocking, and meant to be: this is load-time work.
@(require_results)
upload_level :: proc(data: ^Level_Data) -> (world: Voxel_World) {
	packed_words := (len(data.grid.voxels) + 3) / 4
	world.buffer = create_gpu_buffer(u32, PALETTE_SLOTS + packed_words)
	world.grid = data.grid

	voxels := pack_voxels(&data.grid, context.temp_allocator)

	cmd := upload_begin()
	upload(cmd, &world.buffer, data.palette[:])
	upload(cmd, &world.buffer, voxels, PALETTE_BYTES)
	upload_end()
	return world
}

@(require_results)
load_level :: proc(file_name: string, reserved_from: u8) -> (level: Level, err: Error) {
	data := load_level_data(file_name, reserved_from) or_return
	// Ownership of grid and markers moves into the Level.
	level.world = upload_level(&data)
	level.markers = data.markers
	return level, .None
}

unload_level :: proc(level: ^Level) {
	delete(level.markers)
	destroy_gpu_buffer(&level.world.buffer)
	destroy_grid(&level.world.grid)
	level^ = {}
}

@(require_results)
create_grid :: proc(dimensions: [3]int, allocator := context.allocator) -> (grid: Voxel_Grid) {
	grid.voxels = make([]Voxel, dimensions.x * dimensions.y * dimensions.z, allocator)
	grid.dimensions = dimensions
	return
}

destroy_grid :: proc(grid: ^Voxel_Grid) {
	delete(grid.voxels)
	grid^ = {}
}

@(require_results)
get_voxel :: proc(grid: ^Voxel_Grid, x, y, z: int) -> Voxel {
	if !voxel_in_bounds(grid, x, y, z) do return VOXEL_EMPTY
	return grid.voxels[voxel_index(grid, x, y, z)]
}

set_voxel :: proc(grid: ^Voxel_Grid, x, y, z: int, value: Voxel) {
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
grid_from_vox :: proc(model: vox.Model, reserved_from: u8, allocator := context.allocator) -> (grid: Voxel_Grid, markers: []Marker) {
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
