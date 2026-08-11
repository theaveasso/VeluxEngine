package velux

Velux_API :: struct {
	bound:   bool,
	ui:      UI_API,
	audio:   Audio_API,
	physics: Physics_API,
}

@(private, require_results)
host_velux_api :: proc() -> Velux_API {
	return {bound = true, ui = host_ui_api(), audio = host_audio_api(), physics = host_physics_api()}
}

@(private, require_results)
bound_api :: proc(loc := #caller_location) -> ^Velux_API {
	if g_engine == nil || !g_engine.api.bound {
		fatal("velux api is unbound: the host must run create() before the game calls in", loc = loc)
	}
	return &g_engine.api
}
