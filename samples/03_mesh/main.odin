package main

import "core:log"
import "core:math/linalg"

import "vlx:velux"

run :: proc(engine: ^velux.Engine) -> (err: velux.Error) {
	defer velux.wait_for_idle(engine)

	vertices: [8]velux.Vertex = {
		{{-0.5, -0.5, 0.5}, {0, 0, 1}},
		{{0.5, -0.5, 0.5}, {1, 0, 1}},
		{{0.5, 0.5, 0.5}, {1, 1, 1}},
		{{-0.5, 0.5, 0.5}, {0, 1, 1}},
		{{-0.5, -0.5, -0.5}, {0, 0, 0}},
		{{0.5, -0.5, -0.5}, {1, 0, 0}},
		{{0.5, 0.5, -0.5}, {1, 1, 0}},
		{{-0.5, 0.5, -0.5}, {0, 1, 0}},
	}
	indices: [36]u32 = {0, 1, 2, 2, 3, 0, 1, 5, 6, 6, 2, 1, 5, 4, 7, 7, 6, 5, 4, 0, 3, 3, 7, 4, 3, 2, 6, 6, 7, 3, 4, 5, 1, 1, 0, 4}

	vertex_buffer := velux.create_buffer(engine, velux.Vertex, len(vertices)) or_return
	defer velux.destroy_buffer(engine, &vertex_buffer)

	index_buffer := velux.create_buffer(engine, u32, len(indices), .Index) or_return
	defer velux.destroy_buffer(engine, &index_buffer)

	TEX :: 8
	pixels: [TEX * TEX]u32
	for y in 0 ..< TEX do for x in 0 ..< TEX {
		pixels[y * TEX + x] = (x + y) % 2 == 0 ? 0xFFFFFF : 0xFF181818
	}

	checker_image := velux.create_texture(engine, .R8G8B8A8_SRGB, {TEX, TEX, 1}, {.TRANSFER_DST, .SAMPLED}) or_return
	defer velux.destroy_texture(engine, &checker_image)

	cmd := velux.immediate_transfer_begin(engine) or_return
	velux.write_staging_buffer_slice(engine, cmd, &vertex_buffer, vertices[:]) or_return
	velux.write_staging_buffer_slice(engine, cmd, &index_buffer, indices[:]) or_return
	velux.write_staging_image_slice(engine, cmd, &checker_image, pixels[:]) or_return
	velux.immediate_transfer_end(engine) or_return

	Mesh_Push_Constants :: struct {
		mvp:      matrix[4, 4]f32,
		vertices: velux.Device_Address(velux.Vertex),
	}

	push_constants: Mesh_Push_Constants = {
		vertices = vertex_buffer.ptr,
	}

	shader := velux.create_shader(engine, "shaders/out/mesh.spv", context.temp_allocator) or_return
	pipeline := velux.create_graphics_pipeline(
		engine,
		shader,
		Mesh_Push_Constants,
		.TRIANGLE_LIST,
		.FILL,
		.CLOCKWISE,
		{write_enabled = true, compare_op = .LESS_OR_EQUAL, format = velux.DEFAULT_DEPTH_FORMAT},
		{},
		velux.swapchain_format(engine),
	) or_return
	velux.destroy_shader(engine, shader)
	defer velux.destroy_pipeline(engine, &pipeline)

	camera: velux.Camera = {{0, 0, -10}, {0, 0, 0}, velux.Perspective{linalg.to_radians(cast(f32)45), 0.1, 100.0}}

	for velux.running(engine) {
		window_extent := velux.window_extent(engine)
		proj := velux.camera_projection(camera, window_extent[0] / window_extent[1])
		view := velux.camera_view(camera)

		t := cast(f32)velux.time()
		angle := t * linalg.to_radians(cast(f32)90)

		frame := velux.begin_frame(engine) or_continue
		velux.cmd_begin_rendering(frame, [4]f32{0.05, 0.05, 0.1, 1})

		velux.cmd_bind_graphics_pipeline(frame, pipeline)
		velux.cmd_bind_index_buffer(frame, index_buffer.handle)

		for i in 0 ..< 10 {
			pos := [3]f32{cast(f32)(i % 5) * 1.5 - 3, cast(f32)(i / 5) * 1.5 - 0.75, 0}
			model := linalg.matrix4_translate(pos) * linalg.matrix4_rotate(angle, [3]f32{0, 1, 0})
			push_constants.mvp = linalg.matrix_mul(proj, linalg.matrix_mul(view, model))
			velux.cmd_push_constants(frame, pipeline, &push_constants)
			velux.cmd_draw_indexed(frame, len(indices))
		}

		velux.cmd_end_rendering(frame)
		velux.end_frame(engine, frame) or_continue
	}

	return
}

main :: proc() {
	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)

	engine: velux.Engine = {}
	if err := velux.init(&engine, {"03_mesh", 1280, 720, ODIN_DEBUG, ODIN_DEBUG}); err != nil {
		log.errorf("%v", err)
		return
	}
	defer velux.shutdown(&engine)

	if err := run(&engine); err != nil {
		log.errorf("%v", err)
		return
	}
}
