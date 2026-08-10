package velux

import "core:log"

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
	}
}

run :: proc(app: App, allocator := context.allocator) -> Error {
	owns_logger := needs_console_logger()
	logger := owns_logger ? log.create_console_logger() : context.logger
	context.logger = logger
	defer if owns_logger do log.destroy_console_logger(logger)

	engine := create(app.config, allocator)
	defer destroy(engine)

	host := Game_Host {
		app = app,
	}
	return host_run(&host, allocator)
}

quit :: proc() {
	g_engine.quit_requested = true
}
