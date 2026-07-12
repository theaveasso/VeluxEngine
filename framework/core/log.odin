package core

import "core:fmt"
import "core:log"

Prefix_Logger :: struct {
	backing: log.Logger,
	prefix:  string,
}

logger_from_prefix :: proc(state: ^Prefix_Logger, prefix: string, backing := context.logger) -> log.Logger {
	state.backing = backing
	state.prefix = prefix

	return log.Logger {
		procedure = prefix_logger_proc,
		data = cast(rawptr)state,
		lowest_level = backing.lowest_level,
		options = backing.options,
	}
}

prefix_logger_proc :: proc(data: rawptr, level: log.Level, text: string, options: log.Options, loc := #caller_location) {
	d := cast(^Prefix_Logger)data

	tagged := fmt.tprintf("%s%s", d.prefix, text)
	d.backing.procedure(d.backing.data, level, tagged, options, loc)
}
