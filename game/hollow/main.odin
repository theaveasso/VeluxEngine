package main

import "core:log"
import "core:math/linalg"

import "vlx:velux"

main :: proc() {
	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)

	engine, create_err := velux.create({app_name = "Hollow"}); if create_err != nil {
		log.errorf("%v", create_err)
		return
	}
	defer velux.destroy(engine)

	run_err := run(engine); if run_err != nil {
		log.errorf("%v", run_err)
		return
	}
}

run :: proc(engine: ^velux.Engine) -> (err: velux.Error) {
	defer velux.wait_for_idle(engine)

	Push_Constants :: struct {
		inv_view_proj: matrix[4, 4]f32,
		cam_pos:       [4]f32,
		dims:          [4]i32,
		world_offset:  [4]f32,
		scene:         velux.Device_Address(u32),
	}
	#assert(size_of(Push_Constants) == 128)
	pc: Push_Constants

	level := velux.create_level("assets/den.vox", MARKER_FIRST) or_return
	defer velux.destroy_level(&level)
	report_markers(level.markers)

	grid := level.world.grid
	pc.dims = {i32(grid.dimensions.x), i32(grid.dimensions.y), i32(grid.dimensions.z), 1024}
	pc.scene = level.world.buffer.ptr
	pc.world_offset = {f32(grid.dimensions.x) * 0.5, f32(grid.dimensions.y) * 0.5, f32(grid.dimensions.z) * 0.5, 0}

	camera: velux.Camera = {
		position = {-6.8, 3.7, -6.8},
		target = {0, 0, 0},
		projection = velux.Perspective{linalg.to_radians(f32(45)), 0.1, 100.0},
		controller = velux.Free_Fly_Camera{speed = 10},
	}

	compile_log, compile_err := velux.compile_slang("assets/hollow.slang", "assets/hollow.spv", context.temp_allocator)
	if compile_err != .None {
		if compile_log != "" do log.error(compile_log)
		return compile_err
	}
	if compile_log != "" do log.warn(compile_log)

	shader := velux.create_shader("assets/hollow.spv", context.temp_allocator) or_return
	defer velux.destroy_shader(shader)

	pipeline := velux.create_graphics_pipeline(
		shader,
		size_of(Push_Constants),
		.TRIANGLE_LIST,
		.FILL,
		.COUNTER_CLOCKWISE,
		{write_enabled = false, compare_op = .ALWAYS, format = velux.DEFAULT_DEPTH_FORMAT},
		{},
		velux.swapchain_format(engine),
	) or_return
	defer velux.destroy_pipeline(&pipeline)

	velux.create_watch_shader(engine, &pipeline, "assets/hollow.slang", "assets/hollow.spv") or_return

	for velux.running(engine) {
		window_extent := velux.window_extent(engine)

		velux.camera_update(&camera, velux.camera_input_from_platform(), engine.dt)
		proj := velux.camera_projection(camera, window_extent[0] / window_extent[1])
		view := velux.camera_view(camera)

		pc.inv_view_proj = linalg.inverse(proj * view)
		pc.cam_pos = {camera.position[0], camera.position[1], camera.position[2], 0.05}

		frame, frame_err := velux.begin_frame()
		if frame_err != nil {
			velux.ui_end_frame()
			continue
		}

		velux.cmd_begin_rendering(frame, [4]f32{0.05, 0.05, 0.1, 1})

		velux.prof_zone_begin(frame, "raycast")
		velux.cmd_bind_graphics_pipeline(frame, pipeline)
		velux.cmd_push_constants(frame, pipeline, &pc)
		velux.cmd_draw(frame, 3)
		velux.prof_zone_end(frame)

		velux.cmd_end_rendering(frame)

		velux.ui_new_frame()
		velux.prof_zone_begin(frame, "ui")
		velux.ui_draw(frame)
		velux.prof_zone_end(frame)

		velux.end_frame(frame) or_continue
	}
	return
}
