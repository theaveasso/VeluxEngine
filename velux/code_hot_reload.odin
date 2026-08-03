package velux

import "core:dynlib"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:time"

ENGINE_ROOT :: #directory

when ODIN_OS == .Windows {
	SHARED_LIB_EXT :: ".dll"
} else when ODIN_OS == .Darwin {
	SHARED_LIB_EXT :: ".dylib"
} else {
	SHARED_LIB_EXT :: ".so"
}

SOURCE_POLL_INTERVAL_MS :: 250
SOURCE_SETTLE_MS :: 300

Game_Host :: struct {
	app:               App,
	lib:               dynlib.Library,
	memory:            rawptr,
	source_dir:        string,
	work_dir:          string,
	output_dir:        string,
	generation:        int,
	last_build:        string,
	retired:           [dynamic]dynlib.Library,
	auto_reload:       bool,
	last_source_check: time.Time,
	newest_source:     time.Time,
	change_seen_at:    time.Time,
	change_pending:    bool,
}

run_hot_reload :: proc(game_dir: string, work_dir := "", allocator := context.allocator) -> (err: Error) {
	owns_logger := context.logger.procedure == nil
	if owns_logger do context.logger = log.create_console_logger()
	defer if owns_logger do log.destroy_console_logger(context.logger)

	host: Game_Host
	host.auto_reload = true

	source_err: os.Error
	host.source_dir, source_err = filepath.abs(game_dir, allocator)
	if source_err != nil {
		log.errorf("cannot resolve %s: %v", game_dir, source_err)
		return Platform_Error.Init_Failed
	}
	defer delete(host.source_dir, allocator)

	run_dir := work_dir == "" ? game_dir : work_dir
	host.work_dir, _ = filepath.abs(run_dir, allocator)
	if host.work_dir == "" {
		log.errorf("cannot resolve %s", run_dir)
		return Platform_Error.Init_Failed
	}
	defer delete(host.work_dir, allocator)

	launch_dir, launch_err := os.get_working_directory(allocator)
	if launch_err != nil {
		log.errorf("cannot read working directory: %v", launch_err)
		return Platform_Error.Init_Failed
	}
	defer delete(launch_dir, allocator)

	host.output_dir, _ = filepath.join({launch_dir, "build", "hot"}, allocator)
	defer delete(host.output_dir, allocator)
	os.make_directory_all(host.output_dir)

	dll_path := dll_path_for(&host, allocator)
	defer delete(dll_path, allocator)

	build_output, build_ok := build_game_dll(&host, dll_path, allocator)
	defer delete(build_output, allocator)
	if build_output != "" do log.info(build_output)
	if !build_ok do return Platform_Error.Dll_Build_Failed

	load_ok: bool
	host.app, host.lib, load_ok = load_game_dll(dll_path)
	if !load_ok {
		log.errorf("cannot load %s", dll_path)
		return Platform_Error.Dll_Load_Failed
	}
	defer unload_game_dll(host.lib)

	if host.app.engine_hash != type_signature(Engine) {
		log.error("engine layout changed - rebuild velux_hot_reload")
		return Platform_Error.Init_Failed
	}

	engine := create(host.app.config, allocator) or_return
	defer destroy(engine)

	if wd_err := os.set_working_directory(host.work_dir); wd_err != nil {
		log.errorf("cannot enter %s: %v", host.work_dir, wd_err)
		return Platform_Error.Init_Failed
	}

	host.app.attach(engine)

	alloc_err: mem.Allocator_Error
	host.memory, alloc_err = mem.alloc(host.app.state_size, host.app.state_align, allocator)
	if alloc_err != nil {
		log.errorf("game state alloc failed: %v", alloc_err)
		return .Allocation_Failed
	}
	defer free(host.memory, allocator)

	if host.app.init != nil {
		if init_err := host.app.init(host.memory); init_err != nil {
			log.errorf("game init failed: %v", init_err)
			return init_err
		}
	}
	defer {
		wait_for_idle()
		if host.app.shutdown != nil do host.app.shutdown(host.memory)
	}

	defer if host.last_build != "" do delete(host.last_build, allocator)
	defer delete(host.retired)

	host.newest_source = newest_source_write(host.source_dir)

	for running() {
		when ODIN_DEBUG do poll_code_reload(&host, allocator)
		app_frame(&host.app, host.memory)
	}
	return
}

poll_code_reload :: proc(host: ^Game_Host, allocator := context.allocator) {
	if is_key_pressed(.F5) {
		host.change_pending = false
		reload_game_code(host, allocator)
		return
	}
	if !host.auto_reload do return

	now := time.now()
	if time.duration_milliseconds(time.diff(host.last_source_check, now)) < SOURCE_POLL_INTERVAL_MS do return
	host.last_source_check = now

	newest := newest_source_write(host.source_dir)
	if time.diff(host.newest_source, newest) > 0 {
		host.newest_source = newest
		host.change_seen_at = now
		host.change_pending = true
		return
	}

	if !host.change_pending do return
	if time.duration_milliseconds(time.diff(host.change_seen_at, now)) < SOURCE_SETTLE_MS do return
	host.change_pending = false
	reload_game_code(host, allocator)
}

@(private, require_results)
newest_source_write :: proc(dir: string) -> (newest: time.Time) {
	entries, read_err := os.read_all_directory_by_path(dir, context.temp_allocator)
	if read_err != nil do return
	for entry in entries {
		if filepath.ext(entry.name) != ".odin" do continue
		if time.diff(newest, entry.modification_time) > 0 do newest = entry.modification_time
	}
	return
}

@(private)
reload_game_code :: proc(host: ^Game_Host, allocator := context.allocator) {
	host.generation += 1
	dll_path := dll_path_for(host, allocator)
	defer delete(dll_path, allocator)

	build_output, build_ok := build_game_dll(host, dll_path, allocator)
	if host.last_build != "" do delete(host.last_build, allocator)
	host.last_build = build_output

	if !build_ok {
		log.errorf("hot reload: build failed\n%s", host.last_build)
		return
	}

	new_app, new_lib, load_ok := load_game_dll(dll_path)
	if !load_ok {
		log.errorf("hot reload: cannot load %s", dll_path)
		return
	}

	if new_app.engine_hash != type_signature(Engine) {
		log.error("hot reload: engine layout changed - restart velux_hot_reload")
		unload_game_dll(new_lib)
		return
	}

	wait_for_idle()
	new_app.attach(g_engine)

	hard := new_app.state_hash != host.app.state_hash
	if hard {
		reset_shader_watches(g_engine)
		if host.app.shutdown != nil do host.app.shutdown(host.memory)
		free(host.memory, allocator)
		host.memory = nil
	}

	append(&host.retired, host.lib)
	host.app = new_app
	host.lib = new_lib

	if !hard {
		log.infof("hot reload: state kept (generation %d)", host.generation)
		return
	}

	alloc_err: mem.Allocator_Error
	host.memory, alloc_err = mem.alloc(host.app.state_size, host.app.state_align, allocator)
	if alloc_err != nil {
		log.errorf("hot reload: state alloc failed: %v", alloc_err)
		return
	}
	if host.app.init != nil {
		if init_err := host.app.init(host.memory); init_err != nil {
			log.errorf("hot reload: game init failed: %v", init_err)
		}
	}
	log.infof("hot reload: state reset, layout changed (generation %d)", host.generation)
}

@(require_results)
engine_root :: #force_inline proc() -> (path: string) {
	return filepath.dir(strings.trim_right(ENGINE_ROOT, "\\/"))
}

@(require_results)
dll_path_for :: proc(host: ^Game_Host, allocator := context.allocator) -> (path: string) {
	name := fmt.tprintf("game_%03d%s", host.generation, SHARED_LIB_EXT)
	path, _ = filepath.join({host.output_dir, name}, allocator)
	return
}

@(require_results)
load_game_dll :: proc(file_name: string) -> (app: App, lib: dynlib.Library, ok: bool) {
	lib, ok = dynlib.load_library(file_name); if !ok do return
	symbol, found := dynlib.symbol_address(lib, "velux_app"); if !found {
		dynlib.unload_library(lib)
		ok = false
		return
	}

	velux_app := cast(proc() -> App)symbol
	app = velux_app()
	return
}

@(require_results)
build_game_dll :: proc(host: ^Game_Host, out_path: string, allocator := context.allocator) -> (output: string, ok: bool) {
	cmd := make([dynamic]string, 0, 12, context.temp_allocator)
	append(&cmd, "odin", "build", host.source_dir)
	append(&cmd, "-build-mode:dll", "-debug", "-o:none", "-define:GLFW_SHARED=true")
	append(&cmd, fmt.tprintf("-collection:vlx=%s", engine_root()))
	append(&cmd, fmt.tprintf("-collection:third_party=%s/third_party", engine_root()))
	append(&cmd, fmt.tprintf("-out:%s", out_path))
	when ODIN_OS == .Windows {
		append(&cmd, fmt.tprintf("-pdb-name:%s.pdb", strings.trim_suffix(out_path, SHARED_LIB_EXT)))
	}

	state, stdout, stderr, exec_err := os.process_exec({command = cmd[:], working_dir = engine_root()}, allocator)
	defer {
		delete(stdout, allocator)
		delete(stderr, allocator)
	}
	if exec_err != nil do return "", false
	output = strings.concatenate({string(stdout), string(stderr)}, allocator = allocator)
	ok = state.exit_code == 0
	return
}

unload_game_dll :: proc(lib: dynlib.Library) {
	dynlib.unload_library(lib)
}
