package velux

import "core:log"
import "core:strings"
import "core:time"


import vox "_vox"

MAX_DELTA :: 0.1

Config :: struct {
	app_name:           cstring,
	width:              i32,
	height:             i32,
	shader_include_dir: string,
	enable_validation:  bool,
	enable_profiler:    bool,
	enable_log:         bool,
}

Engine :: struct {
	shader_include_dir: string,
	window:             Window,
	input:              Input_State,
	gpu:                GPU_Device,
	audio:              Audio_Device,
	watch_shaders:      [dynamic]Shader_Watch,
	ui_context:         ^UI_Context,
	hud:                Hud,
	last_shader_check:  time.Time,
	quit_requested:     bool,
	dt:                 f32,
	last_time:          f64,
}

Error :: union #shared_nil {
	Audio_Error,
	GPU_Error,
	Platform_Error,
	Shader_Error,
	UI_Error,
	vox.Error,
}

@(private = "package")
g_engine: ^Engine

@(require_results)
create :: proc(config: Config, allocator := context.allocator) -> (engine: ^Engine, err: Error) {
	engine = new(Engine, allocator)
	g_engine = engine
	if err = init(engine, config); err != nil {
		g_engine = nil
		free(engine)
		return nil, err
	}

	return engine, nil
}

destroy :: proc(engine: ^Engine) {
	if engine == nil do return
	shutdown(engine)

	if g_engine == engine do g_engine = nil
	free(engine)
}

@(private, require_results)
init :: proc(engine: ^Engine, config: Config) -> Error {
	config := config
	if config.app_name == nil do config.app_name = "VeluxEngine"
	if config.width == 0 do config.width = 1280
	if config.height == 0 do config.height = 720
	if config.shader_include_dir == "" do config.shader_include_dir = DEFAULT_SHADER_INCLUDE_DIR
	engine.shader_include_dir, _ = strings.clone(config.shader_include_dir)

	if config.enable_validation || ODIN_DEBUG do config.enable_validation = true
	if config.enable_log || ODIN_DEBUG do config.enable_log = true
	if config.enable_profiler || ODIN_DEBUG do config.enable_profiler = true

	init_platform() or_return
	create_window(&engine.window, config.width, config.height, config.app_name) or_return
	input_init(engine)

	init_gpu(
		&engine.gpu,
		{
			app_name = config.app_name,
			window = engine.window.handle,
			enable_validation = config.enable_validation,
			enable_log = config.enable_log,
			enable_profiler = config.enable_profiler,
		},
	) or_return

	init_ui(engine) or_return

	if audio_err := init_audio(&engine.audio); audio_err != nil {
		log.warnf("audio unavailable, continuing withou sound: %v", audio_err)
	}

	engine.last_time = now()
	return nil
}

@(require_results)
@(private)
running :: proc() -> bool {
	engine := g_engine
	free_all(context.temp_allocator)

	poll_events()
	input_new_frame()
	when ODIN_DEBUG {
		poll_shader_watches(engine)
	}

	current := now()
	raw := f32(current - engine.last_time)
	engine.dt = min(raw, MAX_DELTA)
	engine.last_time = current

	if is_key_pressed(.F2) do engine.hud.show = !engine.hud.show
	hud_update(engine)
	if engine.quit_requested do return false
	return !window_should_close(&engine.window)
}

@(require_results)
swapchain_format :: proc() -> Format {
	return g_engine.gpu.swapchain.surface_format.format
}

@(require_results)
window_extent :: proc() -> [2]f32 {
	return framebuffer_extent(&g_engine.window)
}

@(require_results)
delta_time :: proc() -> f32 {
	return g_engine.dt
}

wait_for_idle :: proc() {
	wait_idle(&g_engine.gpu)
}

@(private)
shutdown :: proc(engine: ^Engine) {
	wait_for_idle()
	destroy_ui(engine)
	destroy_gpu(&engine.gpu)
	destroy_audio(&engine.audio)
	destroy_shader_watches(engine)
	destroy_window(&engine.window)
	shutdown_platform()
	delete(engine.shader_include_dir)
}
