package velux

import "core:math"
import "core:path/filepath"

import stbtt "vendor:stb/truetype"

MAX_GLYPHS :: 16384

TEXT_SHADER :: "text.slang"

Glyph_Instance :: struct {
	rect:  [4]f32,
	uv:    [4]f32,
	color: [4]u8,
	_pad:  u32,
}
#assert(size_of(Glyph_Instance) == 40)

Text_Push_Constants :: struct {
	scale:     [2]f32,
	bias:      [2]f32,
	instances: GPU_Address(Glyph_Instance),
	atlas:     u32,
	_pad:      u32,
}
#assert(size_of(Text_Push_Constants) == 32)

Text_Renderer :: struct {
	pipeline: GPU_Pipeline,
	buffers:  [MAX_FRAMES_IN_FLIGHT]GPU_Buffer(Glyph_Instance),
	counts:   [MAX_FRAMES_IN_FLIGHT]u32,
}

text :: proc(renderer: ^Text_Renderer, frame: Frame, font: ^Font, str: string, pos: [2]f32, color: [4]u8) {
	origin_x := math.round(pos.x)
	x := origin_x
	y := math.round(pos.y) + math.round(font.atlas.ascent)

	for ch in str {
		if ch == '\n' {
			x = origin_x
			y += font.atlas.line_height
			continue
		}

		i := glyph_index(ch)
		if i < 0 do continue

		q: stbtt.aligned_quad
		stbtt.GetPackedQuad(raw_data(font.atlas.chars[:]), FONT_ATLAS_W, FONT_ATLAS_H + 1, i32(i), &x, &y, &q, true)

		push_glyph(renderer, frame, {rect = {q.x0, q.y0, q.x1, q.y1}, uv = {q.s0, q.t0, q.s1, q.t1}, color = color})
	}
}

rect :: proc(renderer: ^Text_Renderer, frame: Frame, min, max: [2]f32, color: [4]u8) {
	uv := WHITE_TEXEL_UV
	push_glyph(
		renderer,
		frame,
		{rect = {math.round(min.x), math.round(min.y), math.round(max.x), math.round(max.y)}, uv = {uv.x, uv.y, uv.x, uv.y}, color = color},
	)
}

@(require_results)
create_text_renderer :: proc(loc := #caller_location) -> (renderer: Text_Renderer, err: Error) {
	engine := engine_bound(loc)
	slang_path, _ := filepath.join({engine.shader_include_dir, TEXT_SHADER}, context.temp_allocator)
	create_gpu_pipeline(
		pipeline = &renderer.pipeline,
		slang_path = slang_path,
		push_constant_size = size_of(Text_Push_Constants),
		depth = .Off,
		cull = .None,
		blend = .Alpha,
		loc = loc,
	) or_return

	for &buffer in renderer.buffers {
		buffer = create_gpu_buffer(Glyph_Instance, MAX_GLYPHS, .Dynamic, loc)
	}

	return renderer, .None
}

destroy_text_renderer :: proc(renderer: ^Text_Renderer) {
	for &buffer in renderer.buffers {
		destroy_gpu_buffer(&buffer)
	}
	destroy_gpu_pipeline(&renderer.pipeline)
}

push_glyph :: proc(renderer: ^Text_Renderer, frame: Frame, instance: Glyph_Instance) {
	slot := frame.frame_index
	if renderer.counts[slot] >= MAX_GLYPHS do return
	mapped := cast([^]Glyph_Instance)renderer.buffers[slot].info.pMappedData
	mapped[renderer.counts[slot]] = instance
	renderer.counts[slot] += 1
}

flush_text :: proc(renderer: ^Text_Renderer, frame: Frame, font: Font) {
	slot := frame.frame_index
	count := renderer.counts[slot]
	if count == 0 do return
	renderer.counts[slot] = 0

	pc := Text_Push_Constants {
		scale     = {2.0 / f32(frame.extent.width), 2.0 / f32(frame.extent.height)},
		bias      = {-1, -1},
		instances = renderer.buffers[slot].ptr,
		atlas     = font_atlas_index(font),
	}

	bind_graphics_pipeline(frame, renderer.pipeline)
	push_constants(frame, renderer.pipeline, &pc)
	draw(frame, count * 6)
}
