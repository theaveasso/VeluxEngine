package main

import "core:log"
import "core:math"
import "core:math/linalg"

import "vlx:velux"

MARKER_FIRST :: 251

DAY_LENGTH_SECONDS :: f32(240)
SUN_LEAN :: f32(0.35)

HEAD_SPEED :: f32(8)
HEAD_BOOST :: f32(4)
LOOK_SENSITIVITY :: f32(0.0015)
HEAD_PITCH_LIMIT :: f32(1.4)

NOSE_OFFSET :: f32(0.42)
NOSE_RADIUS :: f32(0.12)
SPHERE_COUNT :: TETHER_POINTS + 1

CAMERA_DISTANCE :: f32(5.0)
CAMERA_HEIGHT :: f32(2.2)
CAMERA_LOOK_AHEAD :: f32(2.0)

WORLD_UP :: [3]f32{0, 1, 0}

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
	defer velux.wait_for_idle()

	Push_Constants :: struct {
		inv_view_proj: matrix[4, 4]f32,
		cam_pos:       [4]f32,
		dims:          [4]i32,
		sun:           [4]f32,
		tether:        velux.GPU_Address([4]f32),
	}
	#assert(size_of(Push_Constants) == 128)
	pc: Push_Constants

	pc.dims = {0, 0, 0, 1024}

	camera: velux.Camera = {
		projection = velux.Perspective{linalg.to_radians(f32(60)), 0.1, 500.0},
	}

	head_position: [3]f32 = {0, 6, -18}
	head_yaw, head_pitch: f32

	compile_log, compile_err := velux.compile_slang("assets/main.slang", "assets/main.spv", context.temp_allocator)
	if compile_err != .None {
		if compile_log != "" do log.error(compile_log)
		return compile_err
	}
	if compile_log != "" do log.warn(compile_log)

	shader := velux.create_gpu_shader("assets/main.spv", context.temp_allocator) or_return
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

	velux.watch_shader(&pipeline, "assets/main.slang", "assets/main.spv") or_return

	tether_positions: [SPHERE_COUNT][4]f32

	tether := create_tether(head_position)

	tether_buffer := velux.create_gpu_buffer([4]f32, SPHERE_COUNT) or_return
	defer velux.destroy_gpu_buffer(&tether_buffer)
	pc.tether = tether_buffer.ptr

	time_of_day: f32 = 0.75
	for velux.running() {
		window_extent := velux.window_extent()

		time_of_day += velux.delta_time() / DAY_LENGTH_SECONDS
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

		input := velux.camera_input_from_platform()

		if input.looking {
			head_yaw -= input.look.x * LOOK_SENSITIVITY
			head_pitch -= input.look.y * LOOK_SENSITIVITY
		}
		head_pitch = clamp(head_pitch, -HEAD_PITCH_LIMIT, HEAD_PITCH_LIMIT)

		cos_pitch := math.cos(head_pitch)
		forward := [3]f32{cos_pitch * math.sin(head_yaw), math.sin(head_pitch), cos_pitch * math.cos(head_yaw)}
		right := linalg.normalize(linalg.cross(forward, WORLD_UP))

		velocity := right * input.move.x + WORLD_UP * input.move.y + forward * input.move.z
		move_direction: [3]f32
		if linalg.dot(velocity, velocity) > 0 {
			move_direction = linalg.normalize(velocity)
			speed := HEAD_SPEED * (input.boost ? HEAD_BOOST : 1)
			head_position += move_direction * speed * velux.delta_time()
		}

		camera.position = head_position - forward * CAMERA_DISTANCE + WORLD_UP * CAMERA_HEIGHT
		camera.target = head_position + forward * CAMERA_LOOK_AHEAD

		proj := velux.camera_projection(camera, window_extent[0] / window_extent[1])
		view := velux.camera_view(camera)

		pc.inv_view_proj = linalg.inverse(proj * view)
		pc.cam_pos = {camera.position[0], camera.position[1], camera.position[2], f32(SPHERE_COUNT)}

		update_tether(&tether, head_position, move_direction, velux.delta_time())
		for i in 0 ..< TETHER_POINTS {
			point := tether.positions[i]
			taper := f32(i - 1) / f32(TETHER_POINTS - 2)
			radius := i == 0 ? HEAD_RADIUS : math.lerp(BEAD_RADIUS, BEAD_TIP_RADIUS, taper)
			tether_positions[i] = {point.x, point.y, point.z, radius}
		}

		nose := head_position + forward * NOSE_OFFSET
		tether_positions[TETHER_POINTS] = {nose.x, nose.y, nose.z, NOSE_RADIUS}

		cmd := velux.immediate_transfer_begin() or_continue
		velux.write_staging_buffer_slice(cmd, &tether_buffer, tether_positions[:]) or_continue
		velux.immediate_transfer_end() or_continue

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
