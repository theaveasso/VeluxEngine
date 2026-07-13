package main

import "core:log"
import vlx "velux:engine"
import gpu "velux:gpu"

run :: proc(engine: ^vlx.Engine) -> (err: vlx.Error) {
	vertices: [6]gpu.Vertex = {
		// triangle A — NEAR (z = 0.25), red, drawn FIRST
		{{-0.5, -0.5, 0.25}, {1, 0, 0}},
		{{-0.5, 0.5, 0.25}, {1, 0, 0}},
		{{0.5, 0.5, 0.25}, {1, 0, 0}},
		// triangle B — FAR (z = 0.75), blue, shifted, drawn SECOND
		{{-0.25, -0.75, 0.75}, {0, 0, 1}},
		{{-0.25, 0.25, 0.75}, {0, 0, 1}},
		{{0.75, 0.25, 0.75}, {0, 0, 1}},
	}
	indices: [6]u32 = {0, 1, 2, 3, 4, 5}

	vertex_buffer := gpu.create_buffer(&engine.device, gpu.Vertex, len(vertices), .Storage) or_return
	defer gpu.destroy_buffer(&engine.device, &vertex_buffer)

	index_buffer := gpu.create_buffer(&engine.device, u32, len(indices), .Index) or_return
	defer gpu.destroy_buffer(&engine.device, &index_buffer)

	cmd := gpu.immediate_transfer_begin(&engine.device) or_return
	gpu.write_staging_buffer_slice(&engine.device, cmd, &vertex_buffer, vertices[:]) or_return
	gpu.write_staging_buffer_slice(&engine.device, cmd, &index_buffer, indices[:]) or_return
	gpu.immediate_transfer_end(&engine.device) or_return

	Triangle_PushConstants :: struct {
		vertices: gpu.Device_Address(gpu.Vertex),
	}
	push_constants: Triangle_PushConstants = {
		vertices = vertex_buffer.ptr,
	}

	shader := gpu.load_shader_module(&engine.device, "shaders/out/triangle.spv", context.temp_allocator) or_return
	defer gpu.destroy_shader_module(&engine.device, shader)

	pipeline := gpu.create_graphics_pipeline(
		&engine.device,
		gpu.init_gpu_pipeline_create_info(
			shader = shader,
			push_constants = Triangle_PushConstants,
			input_topology = .TRIANGLE_LIST,
			polygon_mode = .FILL,
			front_face = .CLOCKWISE,
			depth = {write_enabled = true, compare_op = .LESS_OR_EQUAL, format = gpu.DEFAULT_DEPTH_FORMAT},
			cull_mode = {},
			color_format = gpu.swapchain_format(&engine.device),
		),
	) or_return
	defer gpu.destroy_pipeline(&engine.device, &pipeline)

	for vlx.running(engine) {
		frame := gpu.begin_frame(&engine.device) or_continue
		gpu.cmd_begin_rendering(frame, [4]f32{0.05, 0.05, 0.1, 1})

		gpu.cmd_bind_graphics_pipeline(frame, pipeline)
		gpu.cmd_push_constants(frame, pipeline, &push_constants)
		gpu.cmd_bind_index_buffer(frame, index_buffer.handle)
		gpu.cmd_draw_indexed(frame, len(indices))

		gpu.cmd_end_rendering(frame)
		gpu.end_frame(&engine.device, frame) or_continue
	}

	gpu.wait_idle(&engine.device)

	return nil
}

main :: proc() {
	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)

	engine: vlx.Engine
	ok := vlx.init(
		&engine,
		{app_name = "02_triangle", width = 1280, height = 720, enable_validation = ODIN_DEBUG, enable_log = ODIN_DEBUG},
	)
	if ok != nil {log.errorf("%v", ok); return}
	defer (vlx.shutdown(&engine))

	if err := run(&engine); err != nil {
		log.errorf("%v", err)
		return
	}
}
