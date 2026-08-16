package velux

import "core:log"
import "core:strings"
import "core:time"

MAX_DELTA :: 0.1

Config :: struct {
	app_name:           cstring,
	width:              i32,
	height:             i32,
	shader_include_dir: string,
	physics_config:     Physics_Config,
	enable_validation:  bool,
	enable_profiler:    bool,
	enable_log:         bool,
	disable_validation: bool,
	disable_profiler:   bool,
	disable_log:        bool,
}

Engine :: struct {
	shader_include_dir: string,
	window:             Window,
	input:              Input_State,
	gpu:                GPU_Device,
	audio:              Audio_Device,
	physics:            Physics_World,
	api:                Velux_API,
	watch_shaders:      [dynamic]Shader_Watch,
	shader_reloads:     int,
	ui_context:         ^UI_Context,
	hud:                Hud,
	last_shader_check:  time.Time,
	quit_requested:     bool,
	dt:                 f32,
	last_time:          f64,
}

@(private = "package")
g_engine: ^Engine

@(private, require_results)
engine_bound :: proc(loc := #caller_location) -> ^Engine {
	if g_engine == nil {
		fatal("velux is unbound: the host must run create() before the game calls in", loc = loc)
	}
	return g_engine
}

@(require_results)
create :: proc(config: Config, allocator := context.allocator) -> ^Engine {
	engine := new(Engine, allocator)
	g_engine = engine
	init(engine, config)
	return engine
}

destroy :: proc(engine: ^Engine) {
	if engine == nil do return
	shutdown(engine)

	if g_engine == engine do g_engine = nil
	free(engine)
}

@(private)
init :: proc(engine: ^Engine, config: Config) {
	config := config
	if config.app_name == nil do config.app_name = "VeluxEngine"
	if config.width == 0 do config.width = 1280
	if config.height == 0 do config.height = 720
	if config.shader_include_dir == "" do config.shader_include_dir = DEFAULT_SHADER_INCLUDE_DIR
	engine.shader_include_dir, _ = strings.clone(config.shader_include_dir)

	when ODIN_DEBUG {
		if !config.disable_validation do config.enable_validation = true
		if !config.disable_log do config.enable_log = true
		if !config.disable_profiler do config.enable_profiler = true
	}

	engine.api = host_velux_api()

	init_platform()
	init_window(&engine.window, config.width, config.height, config.app_name)
	init_input(engine)

	gpu_config: GPU_Config = {
		app_name          = config.app_name,
		window            = engine.window.handle,
		enable_validation = config.enable_validation,
		enable_log        = config.enable_log,
		enable_profiler   = config.enable_profiler,
	}
	init_gpu(&engine.gpu, gpu_config)
	init_ui(engine)
	init_physics(&engine.physics, config.physics_config)

	if audio_err := init_audio(&engine.audio); audio_err != .None {
		log.warnf("audio unavailable, continuing without sound: %v", audio_err)
	}

	engine.last_time = now()
}

Engine_API :: struct {
	delta_time: proc() -> f32,
	quit:       proc(),
}

@(private, require_results)
host_engine_api :: proc() -> Engine_API {
	return {delta_time = host_delta_time, quit = host_quit}
}

@(require_results)
delta_time :: proc(loc := #caller_location) -> f32 {
	return bound_api(loc).engine.delta_time()
}

quit :: proc(loc := #caller_location) {
	bound_api(loc).engine.quit()
}

@(private, require_results)
host_delta_time :: proc() -> f32 {
	return g_engine.dt
}

@(private)
host_quit :: proc() {
	g_engine.quit_requested = true
}

@(private)
shutdown :: proc(engine: ^Engine) {
	wait_for_idle()
	destroy_ui(engine)
	destroy_gpu(&engine.gpu)
	destroy_physics(&engine.physics)
	destroy_audio(&engine.audio)
	destroy_shader_watches(engine)
	destroy_window(&engine.window)
	shutdown_platform()
	delete(engine.shader_include_dir)
}
