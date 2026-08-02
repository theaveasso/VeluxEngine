package velux

import "core:log"

App :: struct($T: typeid) {
	config:   Config,
	init:     proc(game: ^T) -> Error,
	update:   proc(game: ^T, frame: Frame) -> Error,
	shutdown: proc(game: ^T),
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

	game := new(T, allocator)
	defer free(game, allocator)

	if app.init != nil {
		if init_err := app.init(game); init_err != nil {
			log.errorf("game init failed: %v", init_err)
			return init_err
		}
	}
	defer {
		wait_for_idle()
		if app.shutdown != nil do app.shutdown(game)
	}

	for running() {
		frame, frame_err := begin_frame()
		if frame_err != nil do continue

		ui_new_frame()
		if update_err := app.update(game, frame); update_err != nil {
			log.errorf("update: %v", update_err)
		}

		cmd_begin_rendering(frame)
		prof_zone_begin(frame, "ui")
		ui_draw(frame)
		prof_zone_end(frame)
		cmd_end_rendering(frame)

		end_frame(frame) or_continue
	}
	return nil
}

quit :: proc() {
	g_engine.quit_requested = true
}
