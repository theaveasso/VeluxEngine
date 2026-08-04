package velux

import "base:runtime"
import "core:log"
import "core:mem"

// Everything a running game needs, whether it was compiled into this binary or
// loaded from a shared library. `reload` is nil in the compiled-in case, and
// that is the entire difference between the two entry points.
//
// There used to be two copies of this loop -- run() and run_hot_reload() --
// which agreed on logger ownership, engine creation, state allocation, init,
// teardown order and frame structure, by being typed out twice. Only one of
// them had replay.
@(private)
Game_Host :: struct {
	app:    App,
	memory: rawptr,
	replay: Replay,
	reload: ^Reloader,
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

// Was the body of `running()`, which did all of this from a loop condition
// named as though it only answered a question.
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
