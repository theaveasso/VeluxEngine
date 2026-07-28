package velux

import "core:time"
import "vlx:shaders"

import "vlx:gpu"
import "vlx:platform"
import "vlx:ui"

MAX_DELTA :: 0.1

Config :: struct {
	app_name:          cstring,
	width:             i32,
	height:            i32,
	enable_validation: bool,
	enable_profiler:   bool,
	enable_log:        bool,
}

Engine :: struct {
	window:            platform.Window,
	device:            gpu.Device,
	watch_shaders:     [dynamic]Shader_Watch,
	hud:               Hud,
	last_shader_check: time.Time,
	dt:                f32,
	last_time:         f64,
}

Error :: union #shared_nil {
	gpu.Error,
	platform.Error,
	shaders.Error,
	ui.Error,
}

@(private = "package")
g_engine: ^Engine

@(require_results)
create :: proc(config: Config, allocator := context.allocator) -> (engine: ^Engine, err: Error) {
	engine = new(Engine, allocator)
	if err = init(engine, config); err != nil {
		free(engine)
		return nil, err
	}

	g_engine = engine
	return engine, nil
}

destroy :: proc(engine: ^Engine) {
	if engine == nil do return
	shutdown(engine)

	if g_engine == engine do g_engine = nil
	free(g_engine)
}

@(require_results)
init :: proc(engine: ^Engine, config: Config) -> Error {
	config := config
	if config.app_name == nil do config.app_name = "VeluxEngine"
	if config.width == 0 do config.width = 1280
	if config.height == 0 do config.height = 720

	if config.enable_validation || ODIN_DEBUG do config.enable_validation = true
	if config.enable_log || ODIN_DEBUG do config.enable_log = true
	if config.enable_profiler || ODIN_DEBUG do config.enable_profiler = true

	platform.init() or_return
	platform.create_window(&engine.window, config.width, config.height, config.app_name) or_return
	platform.input_init(&engine.window)

	gpu.init(
		&engine.device,
		{
			app_name = config.app_name,
			window = engine.window.handle,
			enable_validation = config.enable_validation,
			enable_log = config.enable_log,
			enable_profiler = config.enable_profiler,
		},
	) or_return

	ui.init(&engine.device, &engine.window) or_return

	engine.last_time = platform.time()
	return nil
}

running :: proc(engine: ^Engine) -> bool {
	free_all(context.temp_allocator)

	platform.poll_events()
	platform.input_new_frame()
	when ODIN_DEBUG {
		poll_shader_watches(engine)
	}

	now := platform.time()
	raw := f32(now - engine.last_time)
	engine.dt = min(raw, MAX_DELTA)
	engine.last_time = now

	if is_key_pressed(.F2) do engine.hud.show = !engine.hud.show
	hud_update(engine)
	return !platform.window_should_close(&engine.window)
}

swapchain_format :: proc(engine: ^Engine) -> Format {
	return gpu.swapchain_format(&engine.device)
}

window_extent :: proc(engine: ^Engine) -> [2]f32 {
	return platform.window_extent(&engine.window)
}

wait_for_idle :: proc(engine: ^Engine) {
	gpu.wait_idle(&engine.device)
}

shutdown :: proc(engine: ^Engine) {
	wait_for_idle(engine)
	ui.destroy()
	gpu.destroy(&engine.device)
	destroy_watch_shaders(engine)
	platform.destroy_window(&engine.window)
	platform.shutdown()
}
