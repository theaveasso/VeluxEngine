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

// The hot-reload-only half of a Game_Host.
@(private)
Reloader :: struct {
	lib:               dynlib.Library,
	source_dir:        string,
	work_dir:          string,
	output_dir:        string,
	generation:        int,
	last_build:        string,
	// Shared libraries are never unloaded while the process lives: code from a
	// previous generation can still be on the stack or referenced by a
	// function pointer the game handed us. This grows by one per reload, by
	// design, and is bounded by how long a session lasts.
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

	require_host_matches_source()

	reload: Reloader
	reload.auto_reload = true

	source_err: os.Error
	reload.source_dir, source_err = filepath.abs(game_dir, allocator)
	if source_err != nil do fatal("cannot resolve %s: %v", game_dir, source_err)
	defer delete(reload.source_dir, allocator)

	run_dir := work_dir == "" ? game_dir : work_dir
	reload.work_dir, _ = filepath.abs(run_dir, allocator)
	if reload.work_dir == "" do fatal("cannot resolve %s", run_dir)
	defer delete(reload.work_dir, allocator)

	launch_dir, launch_err := os.get_working_directory(allocator)
	if launch_err != nil do fatal("cannot read working directory: %v", launch_err)
	defer delete(launch_dir, allocator)

	reload.output_dir, _ = filepath.join({launch_dir, "build", "hot"}, allocator)
	defer delete(reload.output_dir, allocator)
	os.make_directory_all(reload.output_dir)

	dll_path := dll_path_for(&reload, allocator)
	defer delete(dll_path, allocator)

	build_output, build_ok := build_game_dll(&reload, dll_path, allocator)
	defer delete(build_output, allocator)
	if build_output != "" do log.info(build_output)
	if !build_ok do return .Game_Build_Failed

	host := Game_Host {
		reload = &reload,
	}

	load_ok: bool
	host.app, reload.lib, load_ok = load_game_dll(dll_path)
	if !load_ok {
		log.errorf("cannot load %s", dll_path)
		return .Game_Load_Failed
	}
	defer unload_game_dll(reload.lib)
	defer delete(reload.retired)
	defer if reload.last_build != "" do delete(reload.last_build, allocator)

	engine := create(host.app.config, allocator)
	defer destroy(engine)

	if wd_err := os.set_working_directory(reload.work_dir); wd_err != nil {
		fatal("cannot enter %s: %v", reload.work_dir, wd_err)
	}

	// The DLL carries its own statically compiled copy of velux. This points
	// that copy's g_engine at ours and reloads the vendor proc tables it also
	// has its own copies of. See attach.odin.
	host.app.attach(engine)

	reload.newest_source = newest_odin_write(reload.source_dir)

	return host_run(&host, allocator)
}

// The host executable and the game DLL each compile their own copy of velux
// from this source tree, so their type layouts agree by construction -- unless
// this binary predates a source edit, in which case the game will be built
// against a different Engine than the one it is handed, and every field read
// through it is garbage.
//
// That is a build staleness problem, so it is reported as one. The FNV hash
// over Engine's Type_Info that used to guard this detected the same condition
// and called it "engine layout changed", which sends you to look at your
// structs instead of at your build. mtime over the source is conservative --
// it also fires on a comment edit -- and the cost of a false positive is one
// rebuild of a dev-only tool.
@(private)
require_host_matches_source :: proc() {
	exe_path, exe_err := os.get_executable_path(context.temp_allocator)
	if exe_err != nil do return

	exe_time, stat_err := os.modification_time_by_path(exe_path)
	if stat_err != nil do return

	newest := newest_odin_write(ENGINE_ROOT)
	vox_dir, _ := filepath.join({ENGINE_ROOT, "_vox"}, context.temp_allocator)
	if vox := newest_odin_write(vox_dir); time.diff(newest, vox) > 0 do newest = vox

	if time.diff(exe_time, newest) <= 0 do return

	script := ODIN_OS == .Windows ? "build_hot_reload.bat" : "./build_hot_reload.sh"
	fatal(
		"%s was built before the current velux source. The game DLL would be compiled against a different Engine layout than this binary was. Run %s and try again.",
		filepath.base(exe_path),
		script,
	)
}

@(private)
poll_replay :: proc(host: ^Game_Host, allocator := context.allocator) {
	if g_engine.shader_reloads != host.replay.shader_reloads {
		host.replay.shader_reloads = g_engine.shader_reloads
		replay_discard(&host.replay, "shader reloaded", allocator)
	}
	if is_key_pressed(.F6) {
		replay_toggle(&host.replay, host.memory, host.app.state_size, host.app.state_hash, allocator)
	}
}

@(private)
poll_code_reload :: proc(host: ^Game_Host, allocator := context.allocator) {
	reload := host.reload

	if is_key_pressed(.F5) {
		reload.change_pending = false
		reload_game_code(host, allocator)
		return
	}
	if !reload.auto_reload do return

	now := time.now()
	if time.duration_milliseconds(time.diff(reload.last_source_check, now)) < SOURCE_POLL_INTERVAL_MS do return
	reload.last_source_check = now

	newest := newest_odin_write(reload.source_dir)
	if time.diff(reload.newest_source, newest) > 0 {
		reload.newest_source = newest
		reload.change_seen_at = now
		reload.change_pending = true
		return
	}

	// Wait for the editor to stop writing before shelling out to the compiler.
	if !reload.change_pending do return
	if time.duration_milliseconds(time.diff(reload.change_seen_at, now)) < SOURCE_SETTLE_MS do return
	reload.change_pending = false
	reload_game_code(host, allocator)
}

@(private, require_results)
newest_odin_write :: proc(dir: string) -> (newest: time.Time) {
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
	reload := host.reload

	reload.generation += 1
	dll_path := dll_path_for(reload, allocator)
	defer delete(dll_path, allocator)

	build_output, build_ok := build_game_dll(reload, dll_path, allocator)
	if reload.last_build != "" do delete(reload.last_build, allocator)
	reload.last_build = build_output

	if !build_ok {
		log.errorf("hot reload: build failed\n%s", reload.last_build)
		return
	}

	new_app, new_lib, load_ok := load_game_dll(dll_path)
	if !load_ok {
		log.errorf("hot reload: cannot load %s", dll_path)
		return
	}

	wait_for_idle()
	new_app.attach(g_engine)

	// Same struct, new code: keep the state and the player keeps their
	// position. Different struct: the old bytes mean something else now.
	hard := new_app.state_hash != host.app.state_hash
	if hard {
		replay_discard(&host.replay, "game layout changed", allocator)
		reset_shader_watches(g_engine)
		if host.app.shutdown != nil do host.app.shutdown(host.memory)
		free(host.memory, allocator)
		host.memory = nil
	}

	append(&reload.retired, reload.lib)
	host.app = new_app
	reload.lib = new_lib

	if !hard {
		log.infof("hot reload: state kept (generation %d)", reload.generation)
		return
	}

	alloc_err: mem.Allocator_Error
	host.memory, alloc_err = mem.alloc(host.app.state_size, host.app.state_align, allocator)
	if alloc_err != nil do fatal("cannot allocate %v bytes of game state: %v", host.app.state_size, alloc_err)

	if host.app.init != nil {
		if init_err := host.app.init(host.memory); init_err != .None {
			log.errorf("hot reload: game init failed: %v", init_err)
		}
	}
	log.infof("hot reload: state reset, layout changed (generation %d)", reload.generation)
}

@(require_results)
engine_root :: #force_inline proc() -> (path: string) {
	return filepath.dir(strings.trim_right(ENGINE_ROOT, "\\/"))
}

@(private, require_results)
dll_path_for :: proc(reload: ^Reloader, allocator := context.allocator) -> (path: string) {
	name := fmt.tprintf("game_%03d%s", reload.generation, SHARED_LIB_EXT)
	path, _ = filepath.join({reload.output_dir, name}, allocator)
	return
}

@(private, require_results)
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

@(private, require_results)
build_game_dll :: proc(reload: ^Reloader, out_path: string, allocator := context.allocator) -> (output: string, ok: bool) {
	cmd := make([dynamic]string, 0, 12, context.temp_allocator)
	append(&cmd, "odin", "build", reload.source_dir)
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

@(private)
unload_game_dll :: proc(lib: dynlib.Library) {
	dynlib.unload_library(lib)
}
