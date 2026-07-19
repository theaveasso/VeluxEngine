package main

import "core:log"
import "core:math/linalg"
import "vlx:velux"

run :: proc(engine: ^velux.Engine) -> (err: velux.Error = nil) {
	defer velux.wait_for_idle(engine)

	camera: velux.Camera = {
		position = {0, 0, -5},
		target = {0, 0, 0},
		projection = velux.Perspective{linalg.to_radians(f32(45)), 0.1, 100.0},
		controller = velux.Orbit_Camera{yaw = 0, pitch = 0, radius = 25},
	}

	glade: velux.Voxel_Grid
	velux.create_glade(&glade)
	defer velux.destroy_glade(&glade)

	vertices, indices := velux.voxel_mesh_build(&glade)
	defer {delete(vertices); delete(indices)}

	vertex_buffer := velux.create_buffer(engine, velux.Voxel_Vertex, len(vertices)) or_return
	defer velux.destroy_buffer(engine, &vertex_buffer)

	index_buffer := velux.create_buffer(engine, u32, len(indices), .Index) or_return
	defer velux.destroy_buffer(engine, &index_buffer)

	cmd := velux.immediate_transfer_begin(engine) or_return
	velux.write_staging_buffer_slice(engine, cmd, &vertex_buffer, vertices[:]) or_return
	velux.write_staging_buffer_slice(engine, cmd, &index_buffer, indices[:]) or_return
	velux.immediate_transfer_end(engine) or_return

	Push_Constants :: struct {
		mvp:      matrix[4, 4]f32,
		vertices: velux.Device_Address(velux.Voxel_Vertex),
	}
	pc := Push_Constants {
		vertices = vertex_buffer.ptr,
	}

	shader := velux.create_shader(engine, "assets/voxel.spv", context.temp_allocator) or_return
	defer velux.destroy_shader(engine, shader)

	pipeline := velux.create_graphics_pipeline(
		engine,
		shader,
		Push_Constants,
		.TRIANGLE_LIST,
		.FILL,
		.COUNTER_CLOCKWISE,
		{write_enabled = true, compare_op = .LESS_OR_EQUAL, format = velux.DEFAULT_DEPTH_FORMAT},
		{.BACK},
		velux.swapchain_format(engine),
	) or_return
	defer velux.destroy_pipeline(engine, &pipeline)

	center := [3]f32{f32(velux.WORLD_DIMENSION[0]) * 0.5, f32(velux.WORLD_DIMENSION[1]) * 0.5, f32(velux.WORLD_DIMENSION[2]) * 0.5}

	for velux.running(engine) {
		window_extent := velux.window_extent(engine)
		velux.camera_update(&camera, velux.mouse_delta(), velux.scroll_delta().y, velux.is_mouse_down(.LEFT), engine.dt)
		proj := velux.camera_projection(camera, window_extent[0] / window_extent[1])
		view := velux.camera_view(camera)

		model := linalg.matrix4_scale([3]f32{velux.VOXEL_SIZE, velux.VOXEL_SIZE, velux.VOXEL_SIZE}) * linalg.matrix4_translate(-center)
		pc.mvp = proj * view * model

		frame := velux.begin_frame(engine) or_continue
		velux.cmd_begin_rendering(frame, [4]f32{0.05, 0.05, 0.1, 1})

		velux.cmd_bind_graphics_pipeline(frame, pipeline)
		velux.cmd_bind_index_buffer(frame, index_buffer.handle)

		velux.cmd_push_constants(frame, pipeline, &pc)
		velux.cmd_draw_indexed(frame, u32(len(indices)))

		velux.cmd_end_rendering(frame)
		velux.end_frame(engine, frame) or_continue
	}

	return
}

main :: proc() {
	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)

	engine: velux.Engine = {}
	if err := velux.init(&engine, {"04 model", 1280, 720, ODIN_DEBUG, ODIN_DEBUG}); err != nil {
		log.errorf("%v", err)
		return
	}
	defer velux.shutdown(&engine)

	if err := run(&engine); err != nil {
		log.errorf("%v", err)
		return
	}
}
