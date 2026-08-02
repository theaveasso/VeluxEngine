package main

import "core:log"
import "core:math/linalg"

import vlx "vlx:velux"

SPONZA :: "assets/sponza_512x512x1024.vox"
NO_MARKERS :: 255

Push_Constants :: struct {
	inv_view_proj: matrix[4, 4]f32,
	cam_pos:       [4]f32,
	dims:          [4]i32,
	world_offset:  [4]f32,
	scene:         vlx.GPU_Address(u32),
}
#assert(size_of(Push_Constants) == 128)

Game :: struct {
	pc:         Push_Constants,
	camera:     vlx.Camera,
	pipeline:   vlx.GPU_Pipeline,
	level:      vlx.Level,
	voxel_size: f32,
}

main :: proc() {
	vlx.run(vlx.App(Game){
		config = {app_name = "Sponza", width = 1600, height = 900},
		init = game_init,
		update = game_update,
		draw = game_draw,
		shutdown = game_shutdown,
	})
}

game_init :: proc(game: ^Game) -> (err: vlx.Error) {
	start := vlx.now()
	game.level = vlx.load_level(SPONZA, NO_MARKERS) or_return
	log.infof("create levels time took %.3f", vlx.now() - start)

	grid := game.level.world.grid
	log.infof("sponza grid %v", grid.dimensions)

	game.pc.dims = {i32(grid.dimensions.x), i32(grid.dimensions.y), i32(grid.dimensions.z), 1024}
	game.pc.scene = game.level.world.buffer.ptr
	game.pc.world_offset = {
		f32(grid.dimensions.x) * 0.5,
		f32(grid.dimensions.y) * 0.5,
		f32(grid.dimensions.z) * 0.5,
		0,
	}

	game.voxel_size = 0.1
	game.camera = {
		position   = {-10.6, -5.6, 7.0},
		target     = {1.4, -4.5, 7.0},
		projection = vlx.Perspective{linalg.to_radians(f32(60)), 0.1, 500.0},
		controller = vlx.Free_Fly_Camera{speed = 8},
	}

	vlx.create_gpu_pipeline(&game.pipeline, "assets/sponza.slang", size_of(Push_Constants)) or_return
	return
}

game_shutdown :: proc(game: ^Game) {
	vlx.destroy_gpu_pipeline(&game.pipeline)
	vlx.unload_level(&game.level)
}

game_update :: proc(game: ^Game) -> (err: vlx.Error) {
	window_extent := vlx.window_extent()

	if vlx.ui_begin_panel("Sponza") {
		vlx.ui_slider("Voxel size (m)", &game.voxel_size, 0.02, 0.3)
		vlx.ui_slider("View distance", &game.pc.dims.w, 64, 2048)
	}
	vlx.ui_end_panel()

	if vlx.is_key_pressed(.TAB) do vlx.set_cursor_captured(!vlx.is_cursor_captured())

	vlx.camera_update(&game.camera, vlx.camera_input_from_platform(), vlx.delta_time())
	proj := vlx.camera_projection(game.camera, window_extent[0] / window_extent[1])
	view := vlx.camera_view(game.camera)

	game.pc.inv_view_proj = linalg.inverse(proj * view)
	game.pc.cam_pos = {game.camera.position[0], game.camera.position[1], game.camera.position[2], game.voxel_size}
	return
}

game_draw :: proc(game: ^Game, frame: vlx.Frame) {
	vlx.cmd_begin_rendering(frame, [4]f32{0.05, 0.05, 0.1, 1})
	vlx.prof_zone_begin(frame, "raycast")
	vlx.cmd_bind_graphics_pipeline(frame, game.pipeline)
	vlx.cmd_push_constants(frame, game.pipeline, &game.pc)
	vlx.cmd_draw(frame, 3)
	vlx.prof_zone_end(frame)
	vlx.cmd_end_rendering(frame)
}
