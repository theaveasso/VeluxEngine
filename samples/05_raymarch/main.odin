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
		// controller = velux.Orbit_Camera{radius = 25},
		controller = velux.Free_Fly_Camera{speed = 10},
	}

	glade: velux.Voxel_Grid
	velux.create_glade(&glade)
	defer velux.destroy_glade(&glade)

	voxels := velux.grid_to_u32(&glade)
	defer delete(voxels)

	voxel_buffer := velux.create_buffer(engine, u32, len(voxels)) or_return
	defer velux.destroy_buffer(engine, &voxel_buffer)

	cmd := velux.immediate_transfer_begin(engine) or_return
	velux.write_staging_buffer_slice(engine, cmd, &voxel_buffer, voxels[:]) or_return
	velux.immediate_transfer_end(engine) or_return

	Push_Constants :: struct {
		inv_view_proj: matrix[4, 4]f32,
		cam_pos:       [4]f32,
		dims:          [4]i32,
		max_steps:     i32,
		padding:       i32,
		voxels:        velux.Device_Address(u32),
	}
	pc := Push_Constants {
		cam_pos   = {0, 0, 0, velux.VOXEL_SIZE},
		dims      = {i32(velux.WORLD_DIMENSION[0]), i32(velux.WORLD_DIMENSION[1]), i32(velux.WORLD_DIMENSION[2]), 0},
		max_steps = 1,
		voxels    = voxel_buffer.ptr,
	}

	compile_log, compile_err := velux.compile_slang("assets/raymarch.slang", "assets/raymarch.spv", context.temp_allocator)
	if compile_err != .None {
		if compile_log != "" do log.error(compile_log)
		return compile_err
	}
	if compile_log != "" do log.warn(compile_log)
	shader := velux.create_shader(engine, "assets/raymarch.spv", context.temp_allocator) or_return
	defer velux.destroy_shader(engine, shader)

	pipeline := velux.create_graphics_pipeline(
		engine,
		shader,
		size_of(Push_Constants),
		.TRIANGLE_LIST,
		.FILL,
		.COUNTER_CLOCKWISE,
		{write_enabled = false, compare_op = .ALWAYS, format = velux.DEFAULT_DEPTH_FORMAT},
		{},
		velux.swapchain_format(engine),
	) or_return
	defer velux.destroy_pipeline(engine, &pipeline)

	velux.create_watch_shader(engine, &pipeline, "assets/raymarch.slang", "assets/raymarch.spv") or_return

	for velux.running(engine) {
		window_extent := velux.window_extent(engine)

		velux.ui_new_frame()

		if velux.ui_begin_panel("Renderer") {
			velux.ui_slider("View Distance", &pc.max_steps, 1, 1024)
		}
		velux.ui_end_panel()

		if velux.is_key_pressed(.F1) {
			switch _ in camera.controller {
			case velux.Orbit_Camera:
				velux.camera_set_controller(&camera, velux.Free_Fly_Camera{})
			case velux.Free_Fly_Camera:
				velux.camera_set_controller(&camera, velux.Orbit_Camera{})
			}
		}
		if velux.is_key_pressed(.TAB) do velux.set_cursor_captured(!velux.is_cursor_captured())

		velux.camera_update(&camera, velux.camera_input_from_platform(), engine.dt)
		proj := velux.camera_projection(camera, window_extent[0] / window_extent[1])
		view := velux.camera_view(camera)

		pc.inv_view_proj = linalg.inverse(proj * view)
		pc.cam_pos = {camera.position[0], camera.position[1], camera.position[2], velux.VOXEL_SIZE}

		frame, frame_err := velux.begin_frame(engine)
		if frame_err != nil {
			velux.ui_end_frame()
			continue
		}
		velux.cmd_begin_rendering(frame, [4]f32{0.05, 0.05, 0.1, 1})

		velux.cmd_bind_graphics_pipeline(frame, pipeline)
		velux.cmd_push_constants(frame, pipeline, &pc)
		velux.cmd_draw(frame, 3)

		velux.ui_draw(frame)
		velux.cmd_end_rendering(frame)
		velux.end_frame(engine, frame) or_continue
	}

	return
}

main :: proc() {
	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)

	engine: velux.Engine = {}
	if err := velux.init(&engine, {"05 raymarch", 1280, 720, ODIN_DEBUG, ODIN_DEBUG}); err != nil {
		log.errorf("%v", err)
		return
	}
	defer velux.shutdown(&engine)

	if err := run(&engine); err != nil {
		log.errorf("%v", err)
		return
	}
}
