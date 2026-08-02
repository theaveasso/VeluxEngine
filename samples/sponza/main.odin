package main

import "core:log"
import "core:math/linalg"

import "vlx:velux"

SPONZA :: "assets/sponza_512x512x1024.vox"
NO_MARKERS :: 255

main :: proc() {
	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)

	engine, create_err := velux.create({app_name = "Sponza", width = 1600, height = 900}); if create_err != nil {
		log.errorf("%v", create_err)
		return
	}
	defer velux.destroy(engine)

	run_err := run(engine); if run_err != nil {
		log.errorf("%v", run_err)
		return
	}
	return
}

run :: proc(engine: ^velux.Engine) -> (err: velux.Error) {
	defer velux.wait_for_idle()

	Push_Constants :: struct {
		inv_view_proj: matrix[4, 4]f32,
		cam_pos:       [4]f32,
		dims:          [4]i32,
		world_offset:  [4]f32,
		scene:         velux.GPU_Address(u32),
	}
	#assert(size_of(Push_Constants) == 128)
	pc: Push_Constants

	now := velux.now()
	level := velux.load_level(SPONZA, NO_MARKERS) or_return
	defer velux.unload_level(&level)
	log.infof("create levels time took %.3f", velux.now() - now)

	grid := level.world.grid
	log.infof("sponza grid %v", grid.dimensions)

	pc.dims = {i32(grid.dimensions.x), i32(grid.dimensions.y), i32(grid.dimensions.z), 1024}
	pc.scene = level.world.buffer.ptr
	pc.world_offset = {f32(grid.dimensions.x) * 0.5, f32(grid.dimensions.y) * 0.5, f32(grid.dimensions.z) * 0.5, 0}

	voxel_size: f32 = 0.1

	camera: velux.Camera = {
		position = {-10.6, -5.6, 7.0},
		target = {1.4, -4.5, 7.0},
		projection = velux.Perspective{linalg.to_radians(f32(60)), 0.1, 500.0},
		controller = velux.Free_Fly_Camera{speed = 8},
	}

	compile_log, compile_err := velux.compile_slang("assets/sponza.slang", "assets/sponza.spv", context.temp_allocator)
	if compile_err != .None {
		if compile_log != "" do log.error(compile_log)
		return compile_err
	}
	if compile_log != "" do log.warn(compile_log)

	shader := velux.create_gpu_shader("assets/sponza.spv", context.temp_allocator) or_return
	defer velux.destroy_gpu_shader(shader)

	pipeline := velux.create_gpu_pipeline(
		shader,
		size_of(Push_Constants),
		.TRIANGLE_LIST,
		.FILL,
		.COUNTER_CLOCKWISE,
		{write_enabled = false, compare_op = .ALWAYS, format = velux.DEFAULT_DEPTH_FORMAT},
		{},
		velux.swapchain_format(),
	) or_return
	defer velux.destroy_gpu_pipeline(&pipeline)

	velux.watch_shader(&pipeline, "assets/sponza.slang", "assets/sponza.spv") or_return

	for velux.running() {
		window_extent := velux.window_extent()

		velux.ui_new_frame()
		if velux.ui_begin_panel("Sponza") {
			velux.ui_slider("Voxel size (m)", &voxel_size, 0.02, 0.3)
			velux.ui_slider("View distance", &pc.dims.w, 64, 2048)
		}
		velux.ui_end_panel()

		if velux.is_key_pressed(.TAB) do velux.set_cursor_captured(!velux.is_cursor_captured())

		velux.camera_update(&camera, velux.camera_input_from_platform(), velux.delta_time())
		proj := velux.camera_projection(camera, window_extent[0] / window_extent[1])
		view := velux.camera_view(camera)

		pc.inv_view_proj = linalg.inverse(proj * view)
		pc.cam_pos = {camera.position[0], camera.position[1], camera.position[2], voxel_size}

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

		velux.prof_zone_begin(frame, "ui")
		velux.ui_draw(frame)
		velux.prof_zone_end(frame)

		velux.cmd_end_rendering(frame)
		velux.end_frame(frame) or_continue
	}
	return
}
