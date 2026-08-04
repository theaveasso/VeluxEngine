package velux

import "core:log"
import "core:mem"

App :: struct {
	config:      Config,
	init:        proc(game: rawptr) -> Error,
	update:      proc(game: rawptr) -> Error,
	draw:        proc(game: rawptr, frame: Frame),
	shutdown:    proc(game: rawptr),
	attach:      proc(engine: ^Engine),
	state_size:  int,
	state_align: int,
	state_hash:  u64,
	engine_hash: u64,
}

@(require_results)
make_app :: proc(
	$T: typeid,
	config: Config,
	init: proc(game: ^T) -> Error = nil,
	update: proc(game: ^T) -> Error = nil,
	draw: proc(game: ^T, frame: Frame) = nil,
	shutdown: proc(game: ^T) = nil,
) -> App {
	return {
		config = config,
		init = transmute(proc(game: rawptr) -> Error)(init),
		update = transmute(proc(game: rawptr) -> Error)(update),
		draw = transmute(proc(game: rawptr, frame: Frame))(draw),
		shutdown = transmute(proc(game: rawptr))(shutdown),
		attach = attach,
		state_size = size_of(T),
		state_align = align_of(T),
		state_hash = type_signature(T),
		engine_hash = type_signature(Engine),
	}
}

run :: proc(app: App, allocator := context.allocator) -> Error {
	app := app
	owns_logger := context.logger.procedure == nil
	if owns_logger do context.logger = log.create_console_logger()
	defer if owns_logger do log.destroy_console_logger(context.logger)

	engine := create(app.config, allocator)
	defer destroy(engine)

	game, alloc_err := mem.alloc(app.state_size, app.state_align, allocator)
	if alloc_err != nil do fatal("cannot allocate %v bytes of game state: %v", app.state_size, alloc_err)
	defer free(game, allocator)

	if app.init != nil {
		if init_err := app.init(game); init_err != .None {
			log.errorf("game init failed: %v", init_err)
			return init_err
		}
	}
	defer {
		wait_for_idle()
		if app.shutdown != nil do app.shutdown(game)
	}

	for running() do app_frame(&app, game)
	return .None
}

quit :: proc() {
	g_engine.quit_requested = true
}

@(private)
app_frame :: proc(app: ^App, game: rawptr, replay: ^Replay = nil) {
	ui_new_frame()
	if replay != nil {
		replay_capture(replay)
		replay_apply(replay, game, app.state_size)
	}
	if app.update != nil {
		if update_err := app.update(game); update_err != .None {
			log.errorf("update: %v", update_err)
		}
	}
	if replay != nil do replay_unapply(replay)

	frame, begin_frame_err := begin_frame()
	if begin_frame_err != .None {
		ui_end_frame()
		return
	}

	if app.draw != nil do app.draw(game, frame)

	cmd_begin_rendering(frame)
	prof_zone_begin(frame, "ui")
	ui_draw(frame)
	prof_zone_end(frame)
	cmd_end_rendering(frame)

	end_frame(frame)
}
