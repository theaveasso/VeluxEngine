package velux

import "core:math"
import stbtt "vendor:stb/truetype"

FONT_ATLAS_W :: 512
FONT_ATLAS_H :: 512
FONT_FIRST_CHAR :: 32
FONT_CHAR_COUNT :: 96

Font_Atlas :: struct {
	pixels:       []u8,
	chars:        [FONT_CHAR_COUNT]stbtt.packedchar,
	ascent:       f32,
	descent:      f32,
	line_gap:     f32,
	line_height:  f32,
	pixel_height: f32,
}

@(require_results)
glyph_index :: proc(r: rune) -> int {
	i := int(r) - FONT_FIRST_CHAR
	if i < 0 || i >= FONT_CHAR_COUNT do return -1
	return i
}

@(require_results)
bake_font_atlas :: proc(ttf: []u8, pixel_height: f32, allocator := context.allocator) -> (atlas: Font_Atlas, ok: bool) {
	atlas.pixels = make([]u8, FONT_ATLAS_W * (FONT_ATLAS_H + 1), allocator)
	atlas.pixel_height = pixel_height

	ctx: stbtt.pack_context
	if !stbtt.PackBegin(&ctx, raw_data(atlas.pixels), FONT_ATLAS_W, FONT_ATLAS_H, FONT_ATLAS_W, 1, nil) {
		delete(atlas.pixels, allocator)
		return {}, false
	}

	stbtt.PackSetOversampling(&ctx, 1, 1)
	packed := stbtt.PackFontRange(&ctx, raw_data(ttf), 0, pixel_height, FONT_FIRST_CHAR, FONT_CHAR_COUNT, raw_data(atlas.chars[:]))
	stbtt.PackEnd(&ctx)

	if !packed {
		delete(atlas.pixels, allocator)
		return {}, false
	}

	atlas.pixels[FONT_ATLAS_W * FONT_ATLAS_H] = 0xFF

	stbtt.GetScaledFontVMetrics(raw_data(ttf), 0, pixel_height, &atlas.ascent, &atlas.descent, &atlas.line_gap)
	atlas.line_height = math.round(atlas.ascent - atlas.descent + atlas.line_gap)

	return atlas, true
}

destroy_font_atlas :: proc(atlas: ^Font_Atlas, allocator := context.allocator) {
	delete(atlas.pixels, allocator)
	atlas^ = {}
}

@(require_results)
font_measure :: proc(atlas: Font_Atlas, text: string) -> [2]f32 {
	line_width: f32
	max_width: f32
	lines: f32 = 1

	for r in text {
		if r == '\n' {
			max_width = max(max_width, line_width)
			line_width = 0
			lines += 1
			continue
		}
		i := glyph_index(r)
		if i < 0 do continue
		line_width += atlas.chars[i].xadvance
	}

	return {max(max_width, line_width), lines * atlas.line_height}
}
