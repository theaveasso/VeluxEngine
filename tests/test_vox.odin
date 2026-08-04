package tests

import "core:testing"

import vox "vlx:velux/_vox"

@(test)
header_rejects_bad_magic :: proc(t: ^testing.T) {
	magic: []u8 = {'B', 'A', 'D', 0, 0, 0, 0, 0}
	version, next, ok := vox.read_header(magic)
	testing.expect(t, version == 0)
	testing.expect(t, next == 0)
	testing.expect(t, !ok)
}

@(test)
header_rejects_short_data :: proc(t: ^testing.T) {
	magic: []u8 = {86, 79, 88, 32, 150, 0, 0}
	version, next, ok := vox.read_header(magic)
	testing.expect(t, version == 0)
	testing.expect(t, next == 0)
	testing.expect(t, !ok)
}

@(test)
header_reads_version :: proc(t: ^testing.T) {
	magic: []u8 = {86, 79, 88, 32, 150, 0, 0, 0}
	version, next, ok := vox.read_header(magic)
	testing.expect(t, version == 150)
	testing.expect(t, next == 8)
	testing.expect(t, ok)
}

@(test)
read_i32_returns_value_and_next :: proc(t: ^testing.T) {
	data: []u8 = {0x9D, 0x81, 0x3A, 0x00}
	value, next, ok := vox.read_i32(data, 0)
	testing.expect(t, value == 3834269)
	testing.expect(t, next == 4)
	testing.expect(t, ok)
}

@(test)
read_i32_rejects_when_too_short :: proc(t: ^testing.T) {
	data: []u8 = {0x9D, 0x81}
	value, next, ok := vox.read_i32(data, 0)
	testing.expect(t, value == 0)
	testing.expect(t, next == 0)
	testing.expect(t, !ok)
}

@(test)
read_i32_starts_at_offset :: proc(t: ^testing.T) {
	data: []u8 = {0, 0, 0x9D, 0x81, 0x3A, 0x00}
	value, next, ok := vox.read_i32(data, 2)
	testing.expect(t, value == 3834269)
	testing.expect(t, next == 6)
	testing.expect(t, ok)
}

@(test)
chunk_walk_reads_id_and_sizes :: proc(t: ^testing.T) {
	data: []u8 = {'S', 'I', 'Z', 'E', 12, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0}

}

@(test)
chunk_walk_counts_sponza_chunks :: proc(t: ^testing.T) {}
