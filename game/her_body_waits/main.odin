package main

import "core:log"
import "core:math"
import "core:math/linalg"

import "vlx:velux"

MARKER_FIRST :: 251

DAY_LENGTH_SECONDS :: f32(240)
SUN_LEAN :: f32(0.35)

main :: proc() {
	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)

	engine, create_err := velux.create({app_name = "Her Body Waits", width = 1600, height = 900}); if create_err != nil {
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
		sun:           [4]f32,
		scene:         velux.Device_Address(u32),
	}
	#assert(size_of(Push_Constants) == 128)
	pc: Push_Constants

	pc.dims = {0, 0, 0, 1024}

	voxel_size: f32 = 0.1

	camera: velux.Camera = {
		position = {0, 6, -18},
		target = {0, 5, 0},
		projection = velux.Perspective{linalg.to_radians(f32(60)), 0.1, 500.0},
		controller = velux.Free_Fly_Camera{speed = 8},
	}

	compile_log, compile_err := velux.compile_slang("assets/main.slang", "assets/main.spv", context.temp_allocator)
	if compile_err != .None {
		if compile_log != "" do log.error(compile_log)
		return compile_err
	}
	if compile_log != "" do log.warn(compile_log)

	shader := velux.create_shader("assets/main.spv", context.temp_allocator) or_return
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

	velux.create_watch_shader(engine, &pipeline, "assets/main.slang", "assets/main.spv") or_return

	time_of_day: f32 = 0.75
	for velux.running(engine) {
		window_extent := velux.window_extent(engine)

		time_of_day += engine.dt / DAY_LENGTH_SECONDS
		time_of_day = math.mod(time_of_day, 1)

		angle := (time_of_day - 0.25) * 2 * math.PI
		sun_direction := linalg.normalize([3]f32{math.cos(angle), math.sin(angle), SUN_LEAN})
		day_amount := math.smoothstep(f32(-0.10), f32(0.15), sun_direction.y)
		pc.sun = {sun_direction.x, sun_direction.y, sun_direction.z, day_amount}

		velux.ui_new_frame()
		if velux.ui_begin_panel("Her Body Waits") {
			velux.ui_slider("Time of day", &time_of_day, 0, 1)
		}
		velux.ui_end_panel()

		if velux.is_key_pressed(.TAB) do velux.set_cursor_captured(!velux.is_cursor_captured())

		velux.camera_update(&camera, velux.camera_input_from_platform(), engine.dt)
		proj := velux.camera_projection(camera, window_extent[0] / window_extent[1])
		view := velux.camera_view(camera)

		pc.inv_view_proj = linalg.inverse(proj * view)
		pc.cam_pos = {camera.position[0], camera.position[1], camera.position[2], voxel_size}

		frame, frame_err := velux.begin_frame()
		if frame_err != nil {
			velux.ui_end_frame()
			continue
		}

		velux.cmd_begin_rendering(frame, [4]f32{0.02, 0.02, 0.05, 1})

		velux.prof_zone_begin(frame, "raycast")
		velux.cmd_bind_graphics_pipeline(frame, pipeline)
		velux.cmd_push_constants(frame, pipeline, &pc)
		velux.cmd_draw(frame, 3)
		velux.prof_zone_end(frame)

		velux.prof_zone_begin(frame, "ui")
		velux.ui_draw(frame)
		velux.prof_zone_end(frame)

		velux.cmd_end_rendering(frame)
		velux.end_frame(frame) or_continue
	}
	return
}
