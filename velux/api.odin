package velux

Velux_API :: struct {
	bound:   bool,
	engine:  Engine_API,
	ui:      UI_API,
	audio:   Audio_API,
	physics: Physics_API,
	input:   Input_API,
	voxel:   Voxel_API,
	window:  Window_API,
}

@(private, require_results)
host_velux_api :: proc() -> Velux_API {
	return {
		bound = true,
		engine = host_engine_api(),
		ui = host_ui_api(),
		audio = host_audio_api(),
		physics = host_physics_api(),
		input = host_input_api(),
		voxel = host_voxel_api(),
		window = host_window_api(),
	}
}

@(private, require_results)
bound_api :: proc(loc := #caller_location) -> ^Velux_API {
	if g_engine == nil || !g_engine.api.bound {
		fatal("velux api is unbound: the host must run create() before the game calls in", loc = loc)
	}
	return &g_engine.api
}
