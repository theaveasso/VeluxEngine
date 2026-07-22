package velux

import "core:time"

import "vlx:gpu"
import "vlx:platform"
import "vlx:ui"

MAX_DELTA :: 0.1

Config :: struct {
	app_name:          cstring,
	width:             i32,
	height:            i32,
	enable_validation: bool,
	enable_log:        bool,
}

Engine :: struct {
	window:            platform.Window,
	device:            gpu.Device,
	ui:                ui.Context,
	watch_shaders:     [dynamic]Shader_Watch,
	last_shader_check: time.Time,
	dt:                f32,
	last_time:         f64,
}

Error :: union #shared_nil {
	Hot_Reload_Shader_Error,
	gpu.Error,
	platform.Error,
	ui.Error,
}

@(require_results)
init :: proc(engine: ^Engine, config: Config) -> Error {
	config := config
	if config.app_name == nil do config.app_name = "VeluxEngine"
	if config.width == 0 do config.width = 1280
	if config.height == 0 do config.height = 720

	platform.init() or_return
	platform.create_window(&engine.window, config.width, config.height, config.app_name) or_return
	platform.input_init(&engine.window)

	gpu.init(
		&engine.device,
		{
			app_name = config.app_name,
			enable_validation = config.enable_validation,
			enable_log = config.enable_log,
			window = engine.window.handle,
		},
	) or_return

	ui.init(&engine.ui, &engine.device, &engine.window) or_return

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
	ui.destroy(&engine.ui)
	gpu.destroy(&engine.device)
	destroy_watch_shaders(engine)
	platform.destroy_window(&engine.window)
	platform.shutdown()
}
