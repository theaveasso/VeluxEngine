package velux

import "core:log"

App :: struct($T: typeid) {
	config:   Config,
	init:     proc(game: ^T) -> Error,
	update:   proc(game: ^T) -> Error,
	draw:     proc(game: ^T, frame: Frame),
	shutdown: proc(game: ^T),
}

App_Raw :: struct {
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
erase :: proc(app: App($T)) -> App_Raw {
	return {
		config = app.config,
		init = transmute(proc(game: rawptr) -> Error)(app.init),
		update = transmute(proc(game: rawptr) -> Error)(app.update),
		draw = transmute(proc(game: rawptr, frame: Frame))(app.draw),
		shutdown = transmute(proc(game: rawptr))(app.shutdown),
		attach = attach,
		state_size = size_of(T),
		state_align = align_of(T),
		state_hash = type_signature(T),
		engine_hash = type_signature(Engine),
	}
}

run :: proc(app: App($T), allocator := context.allocator) -> Error {
	owns_logger := context.logger.procedure == nil
	if owns_logger do context.logger = log.create_console_logger()
	defer if owns_logger do log.destroy_console_logger(context.logger)

	engine, create_err := create(app.config, allocator)
	if create_err != nil {
		log.errorf("engine create failed: %v", create_err)
		return create_err
	}
	defer destroy(engine)

	raw := erase(app)
	game := new(T, allocator)
	defer free(game, allocator)

	if raw.init != nil {
		if init_err := raw.init(game); init_err != nil {
			log.errorf("game init failed: %v", init_err)
			return init_err
		}
	}
	defer {
		wait_for_idle()
		if raw.shutdown != nil do raw.shutdown(game)
	}

	for running() do app_frame(&raw, rawptr(game))
	return nil
}

quit :: proc() {
	g_engine.quit_requested = true
}

@(private)
app_frame :: proc(app: ^App_Raw, game: rawptr) {
	ui_new_frame()
	if app.update != nil {
		if update_err := app.update(game); update_err != nil {
			log.errorf("update: %v", update_err)
		}
	}

	frame, begin_frame_err := begin_frame()
	if begin_frame_err != nil {
		ui_end_frame()
		return
	}

	if app.draw != nil do app.draw(game, frame)

	cmd_begin_rendering(frame)
	prof_zone_begin(frame, "ui")
	ui_draw(frame)
	prof_zone_end(frame)
	cmd_end_rendering(frame)

	if end_frame_err := end_frame(frame); end_frame_err != nil {
		log.errorf("end frame: %v", end_frame_err)
	}
}
