package velux

import "base:runtime"
import "core:log"
import "core:mem"

// `reload` is nil for a game compiled into this binary, and that is the entire
// difference between the two entry points.
@(private)
Game_Host :: struct {
	app:    App,
	memory: rawptr,
	replay: Replay,
	reload: ^Reloader,
}

// Odin's default context.logger is not nil -- it is runtime.default_logger_proc,
// an empty body -- so `procedure == nil` never fires and every log call is
// silently discarded.
@(private, require_results)
needs_console_logger :: proc() -> bool {
	return context.logger.procedure == nil || context.logger.procedure == runtime.default_logger_proc
}

// Caller owns the engine: it must be created before this and destroyed after,
// because the hot reload path has to attach the freshly loaded DLL to it in
// between.
@(private)
host_run :: proc(host: ^Game_Host, allocator: runtime.Allocator) -> (err: Error) {
	alloc_err: mem.Allocator_Error
	host.memory, alloc_err = mem.alloc(host.app.state_size, host.app.state_align, allocator)
	if alloc_err != nil do fatal("cannot allocate %v bytes of game state: %v", host.app.state_size, alloc_err)
	defer free(host.memory, allocator)
	defer replay_destroy(&host.replay, allocator)

	if host.app.init != nil {
		if init_err := host.app.init(host.memory); init_err != .None {
			log.errorf("game init failed: %v", init_err)
			return init_err
		}
	}
	defer {
		wait_for_idle()
		if host.app.shutdown != nil do host.app.shutdown(host.memory)
	}

	for {
		frame_begin(g_engine)
		if should_quit(g_engine) do break

		when ODIN_DEBUG {
			if host.reload != nil {
				poll_replay(host, allocator)
				poll_code_reload(host, allocator)
			}
		}

		host_frame(host)
	}
	return .None
}

@(private)
frame_begin :: proc(engine: ^Engine) {
	free_all(context.temp_allocator)

	poll_events()
	input_new_frame()
	when ODIN_DEBUG {
		poll_shader_watches(engine)
	}

	current := now()
	engine.dt = min(f32(current - engine.last_time), MAX_DELTA)
	engine.last_time = current

	if is_key_pressed(.F2) do engine.hud.show = !engine.hud.show
	hud_update(engine)
}

@(private, require_results)
should_quit :: proc(engine: ^Engine) -> bool {
	return engine.quit_requested || window_should_close(&engine.window)
}

@(private)
host_frame :: proc(host: ^Game_Host) {
	ui_new_frame()

	physics_step(&g_engine.physics, g_engine.dt)

	replaying := host.reload != nil
	if replaying {
		replay_capture(&host.replay)
		replay_apply(&host.replay, host.memory, host.app.state_size)
	}
	if host.app.update != nil {
		if update_err := host.app.update(host.memory); update_err != .None {
			log.errorf("update: %v", update_err)
		}
	}
	if replaying do replay_unapply(&host.replay)

	frame, begin_err := begin_frame()
	if begin_err != .None {
		// Swapchain went out of date and has been rebuilt. Drop this frame.
		ui_end_frame()
		return
	}

	if host.app.draw != nil do host.app.draw(host.memory, frame)

	cmd_begin_rendering(frame)
	prof_zone_begin(frame, "ui")
	ui_draw(frame)
	prof_zone_end(frame)
	cmd_end_rendering(frame)

	end_frame(frame)
}
