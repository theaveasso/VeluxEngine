package main

import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"

import vlx "vlx:velux"

main :: proc() {
	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)

	if len(os.args) < 2 {
		fmt.eprintf("usage: velux_hot_reload <game_dir>")
		os.exit(1)
	}

	if err := vlx.run_hot_reload(os.args[1]); err != nil {
		log.errorf("run_hot_reload: %v", err)
		os.exit(1)
	}
}
