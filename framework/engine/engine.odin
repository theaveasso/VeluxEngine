package engine

import "velux:gpu"
import "velux:platform"

Config :: struct {
	app_name:          cstring,
	width:             i32,
	height:            i32,
	enable_validation: bool,
	enable_log:        bool,
}

Engine :: struct {
	window: platform.Window,
	device: gpu.Device,
}

Error :: union #shared_nil {
	platform.Error,
	gpu.Error,
}

@(require_results)
init :: proc(engine: ^Engine, config: Config) -> Error {
	config := config
	if config.app_name == nil do config.app_name = "VeluxEngine"
	if config.width == 0 do config.width = 1280
	if config.height == 0 do config.height = 720

	platform.init() or_return
	platform.create_window(&engine.window, config.width, config.height, config.app_name) or_return

	gpu.init(
		&engine.device,
		{
			app_name = config.app_name,
			enable_validation = config.enable_validation,
			enable_log = config.enable_log,
			window = engine.window.handle,
		},
	) or_return

	return nil
}

running :: #force_inline proc(engine: ^Engine) -> bool {
	platform.poll_events()
	return !platform.window_should_close(&engine.window)
}

shutdown :: proc(engine: ^Engine) {
	gpu.destroy(&engine.device)
	platform.destroy_window(&engine.window)
	platform.shutdown()
}
