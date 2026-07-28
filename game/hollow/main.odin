package main

import "core:log"

import "vlx:velux"

main :: proc() {
	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)

	engine, create_err := velux.create({app_name = "Hollow"}); if create_err != nil {
		log.errorf("%v", create_err)
		return
	}
	defer velux.destroy(engine)

	run_err := run(engine); if run_err != nil {
		log.errorf("%v", run_err)
		return
	}
}

init :: proc(config: velux.Config) -> (engine: velux.Engine, err: velux.Error) {
	err = velux.init(&engine, config)
	return engine, err
}

run :: proc(engine: ^velux.Engine) -> (err: velux.Error) {

	compile_log, compile_err := velux.compile_slang("assets/hollow.slang", "assets/hollow.spv", context.temp_allocator)
	if compile_err != .None {
		if compile_log != "" do log.error(compile_log)
		return compile_err
	}
	if compile_log != "" do log.warn(compile_log)

	shader := velux.create_shader(engine, "assets/hollow.spv", context.temp_allocator) or_return
	defer velux.destroy_shader(engine, shader)

	for velux.running(engine) {
	}
	return
}
