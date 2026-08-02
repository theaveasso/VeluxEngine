package main

import "core:math"
import "core:math/linalg"

import vlx "vlx:velux"

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

Push_Constants :: struct {
	inv_view_proj: matrix[4, 4]f32,
	cam_pos:       [4]f32,
	dims:          [4]i32,
	sun:           [4]f32,
	tether:        vlx.GPU_Address([4]f32),
}
#assert(size_of(Push_Constants) == 128)

Game :: struct {
	pc:               Push_Constants,
	camera:           vlx.Camera,
	pipeline:         vlx.GPU_Pipeline,
	tether_buffer:    vlx.GPU_Buffer([4]f32),
	tether:           Tether,
	tether_positions: [SPHERE_COUNT][4]f32,
	head_position:    [3]f32,
	head_yaw:         f32,
	head_pitch:       f32,
	time_of_day:      f32,
}

main :: proc() {
	vlx.run(vlx.App(Game){
		config = {app_name = "Her Body Waits", width = 1600, height = 900},
		init = game_init,
		update = game_update,
		shutdown = game_shutdown,
	})
}

game_init :: proc(game: ^Game) -> (err: vlx.Error) {
	game.pc.dims = {0, 0, 0, 1024}
	game.camera.projection = vlx.Perspective{linalg.to_radians(f32(60)), 0.1, 500.0}
	game.head_position = {0, 6, -18}
	game.time_of_day = 0.75

	vlx.create_gpu_pipeline(&game.pipeline, "assets/main.slang", size_of(Push_Constants)) or_return

	game.tether = create_tether(game.head_position)
	game.tether_buffer = vlx.create_gpu_buffer([4]f32, SPHERE_COUNT) or_return
	game.pc.tether = game.tether_buffer.ptr
	return
}

game_shutdown :: proc(game: ^Game) {
	vlx.destroy_gpu_buffer(&game.tether_buffer)
	vlx.destroy_gpu_pipeline(&game.pipeline)
}

game_update :: proc(game: ^Game, frame: vlx.Frame) -> (err: vlx.Error) {
	window_extent := vlx.window_extent()
	dt := vlx.delta_time()

	game.time_of_day += dt / DAY_LENGTH_SECONDS
	game.time_of_day = math.mod(game.time_of_day, 1)

	angle := (game.time_of_day - 0.25) * 2 * math.PI
	sun_direction := linalg.normalize([3]f32{math.cos(angle), math.sin(angle), SUN_LEAN})
	day_amount := math.smoothstep(f32(-0.10), f32(0.15), sun_direction.y)
	game.pc.sun = {sun_direction.x, sun_direction.y, sun_direction.z, day_amount}

	if vlx.ui_begin_panel("Her Body Waits") {
		vlx.ui_slider("Time of day", &game.time_of_day, 0, 1)
	}
	vlx.ui_end_panel()

	if vlx.is_key_pressed(.TAB) do vlx.set_cursor_captured(!vlx.is_cursor_captured())

	input := vlx.camera_input_from_platform()

	if input.looking {
		game.head_yaw -= input.look.x * LOOK_SENSITIVITY
		game.head_pitch -= input.look.y * LOOK_SENSITIVITY
	}
	game.head_pitch = clamp(game.head_pitch, -HEAD_PITCH_LIMIT, HEAD_PITCH_LIMIT)

	cos_pitch := math.cos(game.head_pitch)
	forward := [3]f32 {
		cos_pitch * math.sin(game.head_yaw),
		math.sin(game.head_pitch),
		cos_pitch * math.cos(game.head_yaw),
	}
	right := linalg.normalize(linalg.cross(forward, WORLD_UP))

	velocity := right * input.move.x + WORLD_UP * input.move.y + forward * input.move.z
	move_direction: [3]f32
	if linalg.dot(velocity, velocity) > 0 {
		move_direction = linalg.normalize(velocity)
		speed := HEAD_SPEED * (input.boost ? HEAD_BOOST : 1)
		game.head_position += move_direction * speed * dt
	}

	game.camera.position = game.head_position - forward * CAMERA_DISTANCE + WORLD_UP * CAMERA_HEIGHT
	game.camera.target = game.head_position + forward * CAMERA_LOOK_AHEAD

	proj := vlx.camera_projection(game.camera, window_extent[0] / window_extent[1])
	view := vlx.camera_view(game.camera)

	game.pc.inv_view_proj = linalg.inverse(proj * view)
	game.pc.cam_pos = {game.camera.position[0], game.camera.position[1], game.camera.position[2], f32(SPHERE_COUNT)}

	update_tether(&game.tether, game.head_position, move_direction, dt)
	for i in 0 ..< TETHER_POINTS {
		point := game.tether.positions[i]
		taper := f32(i - 1) / f32(TETHER_POINTS - 2)
		radius := i == 0 ? HEAD_RADIUS : math.lerp(BEAD_RADIUS, BEAD_TIP_RADIUS, taper)
		game.tether_positions[i] = {point.x, point.y, point.z, radius}
	}

	nose := game.head_position + forward * NOSE_OFFSET
	game.tether_positions[TETHER_POINTS] = {nose.x, nose.y, nose.z, NOSE_RADIUS}

	cmd := vlx.immediate_transfer_begin() or_return
	vlx.write_staging_buffer_slice(cmd, &game.tether_buffer, game.tether_positions[:]) or_return
	vlx.immediate_transfer_end() or_return

	vlx.cmd_begin_rendering(frame, [4]f32{0.02, 0.02, 0.05, 1})
	vlx.prof_zone_begin(frame, "raycast")
	vlx.cmd_bind_graphics_pipeline(frame, game.pipeline)
	vlx.cmd_push_constants(frame, game.pipeline, &game.pc)
	vlx.cmd_draw(frame, 3)
	vlx.prof_zone_end(frame)
	vlx.cmd_end_rendering(frame)
	return
}
