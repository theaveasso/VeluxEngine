package main

import "core:fmt"
import "core:log"
import "core:os"

import vlx "vlx:velux"

main :: proc() {
	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)

	if len(os.args) < 2 {
		fmt.eprintln("usage: velux_hot_reload <source_dir> [work_dir]")
		fmt.eprintln("  source_dir  folder holding the game's .odin files")
		fmt.eprintln("  work_dir    folder the game runs from, for relative asset paths (default: source_dir)")
		os.exit(1)
	}

	work_dir := len(os.args) > 2 ? os.args[2] : ""
	if err := vlx.run_hot_reload(os.args[1], work_dir); err != nil {
		log.errorf("run_hot_reload: %v", err)
		os.exit(1)
	}
}
