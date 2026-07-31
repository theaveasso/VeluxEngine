package tests

import "core:testing"

import "vlx:internal/vox"

CAVE_VOX :: #load("../game/hollow/assets/cave.vox")

@(test)
vox_reads_little_endian_i32 :: proc(t: ^testing.T) {
	data := []u8{0x01, 0x00, 0x00, 0x00, 0x2A, 0x00, 0x00, 0x00}

	first, next, first_ok := vox.read_i32(data, 0)
	testing.expect(t, first_ok, "first read succeeds")
	testing.expect(t, first == 1, "little endian 1")
	testing.expect(t, next == 4, "offset advances by 4")

	second, _, second_ok := vox.read_i32(data, next)
	testing.expect(t, second_ok, "second read succeeds")
	testing.expect(t, second == 42, "little endian 42")
}

@(test)
vox_read_i32_refuses_to_run_past_the_end :: proc(t: ^testing.T) {
	data := []u8{0x01, 0x00}
	_, _, ok := vox.read_i32(data, 0)
	testing.expect(t, !ok, "truncated read must fail, not read garbage")
}

@(test)
vox_walks_chunks_and_skips_unknown_ones :: proc(t: ^testing.T) {
	data := []u8 {
		'S',
		'I',
		'Z',
		'E',
		12,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		2,
		0,
		0,
		0,
		3,
		0,
		0,
		0,
		4,
		0,
		0,
		0,
		'N',
		'O',
		'T',
		'E',
		4,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		9,
		9,
		9,
		9,
	}

	size_chunk, next, size_ok := vox.next_chunk(data, 0)
	testing.expect(t, size_ok, "SIZE chunk parses")
	testing.expect(t, size_chunk.id == [4]u8{'S', 'I', 'Z', 'E'}, "id is SIZE")
	testing.expect(t, len(size_chunk.content) == 12, "content is 12 bytes")

	note_chunk, _, note_ok := vox.next_chunk(data, next)
	testing.expect(t, note_ok, "walking past SIZE lands exactly on NOTE")
	testing.expect(t, note_chunk.id == [4]u8{'N', 'O', 'T', 'E'}, "unknown chunks are walked, not rejected")
}

@(test)
vox_rejects_a_bad_magic :: proc(t: ^testing.T) {
	data := []u8{'N', 'O', 'P', 'E', 150, 0, 0, 0}
	_, err := vox.parse(data)
	testing.expect(t, err == .Bad_Magic, "a file that is not VOX is rejected")
}

@(test)
vox_parses_a_minimal_file :: proc(t: ^testing.T) {
	data := []u8 {
		'V',
		'O',
		'X',
		' ',
		150,
		0,
		0,
		0,
		'M',
		'A',
		'I',
		'N',
		0,
		0,
		0,
		0,
		64,
		0,
		0,
		0,
		'S',
		'I',
		'Z',
		'E',
		12,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		4,
		0,
		0,
		0,
		5,
		0,
		0,
		0,
		6,
		0,
		0,
		0,
		'M',
		'A',
		'T',
		'L',
		4,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		7,
		7,
		7,
		7,
		'X',
		'Y',
		'Z',
		'I',
		12,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		2,
		0,
		0,
		0,
		1,
		2,
		3,
		9,
		0,
		0,
		0,
		4,
	}

	model, err := vox.parse(data)
	defer vox.destroy(&model)

	testing.expect(t, err == .None, "a well formed file parses")
	testing.expect(t, model.version == 150, "version is read")
	testing.expect(t, model.dimensions == [3]int{4, 5, 6}, "SIZE becomes dimensions")
	if !testing.expect(t, len(model.voxels) == 2, "both voxels are read") do return
	testing.expect(t, model.voxels[0] == vox.Entry{1, 2, 3, 9}, "first voxel round trips")
	testing.expect(t, model.voxels[1] == vox.Entry{0, 0, 0, 4}, "second voxel round trips")
}

@(test)
vox_loads_the_real_cave_file :: proc(t: ^testing.T) {
	model, err := vox.parse(CAVE_VOX)
	defer vox.destroy(&model)

	testing.expect(t, err == .None, "the real file parses")
	testing.expect(t, model.version == 150, "version 150")
	testing.expect(t, model.dimensions == [3]int{256, 256, 256}, "256 cubed")
	testing.expect(t, len(model.voxels) == 150345, "every voxel is read")
	testing.expect(t, model.palette[0] == [4]u8{146, 140, 128, 255}, "palette slot 0 is the first rock tone")
}

@(test)
vox_reports_a_file_with_no_model :: proc(t: ^testing.T) {
	data := []u8 {
		'V',
		'O',
		'X',
		' ',
		150,
		0,
		0,
		0,
		'M',
		'A',
		'I',
		'N',
		0,
		0,
		0,
		0,
		16,
		0,
		0,
		0,
		'M',
		'A',
		'T',
		'L',
		4,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		7,
		7,
		7,
		7,
	}

	_, err := vox.parse(data)
	testing.expect(t, err == .No_Models, "a file with no SIZE or XYZI is an error")
}
