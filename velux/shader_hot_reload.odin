package velux

import "base:runtime"
import "core:log"
import "core:os"
import "core:strings"
import "core:time"

Shader_Watch :: struct {
	pipeline:   ^GPU_Pipeline,
	slang_path: string,
	spv_path:   string,
	last_write: time.Time,
}

@(private)
poll_shader_watches :: proc(engine: ^Engine) {
	now := time.now()
	if time.duration_milliseconds(time.diff(engine.last_shader_check, now)) < 250 do return
	engine.last_shader_check = now

	for &watch in engine.watch_shaders {
		last_write, stat_err := os.modification_time_by_path(watch.slang_path); if stat_err != nil {
			log.debugf("watch stat failed for %s: %v", watch.slang_path, stat_err)
			continue
		}
		if time.diff(watch.last_write, last_write) == 0 do continue
		watch.last_write = last_write

		start := time.now()
		output, compile_err := compile_slang(watch.slang_path, watch.spv_path, context.temp_allocator); if compile_err != .None {
			log.errorf("shader compile failed (%v): %s", compile_err, watch.slang_path)
			if output != "" do log.error(output)
			continue
		}
		if output != "" do log.warn(output)

		shader, shader_err := create_gpu_shader(watch.spv_path, context.temp_allocator); if shader_err != nil {
			log.errorf("shader module load failed (%v): %s", shader_err, watch.spv_path)
			continue
		}
		defer destroy_gpu_shader(shader)
		pipeline, pipeline_err := rebuild_gpu_pipeline(shader, watch.pipeline.info); if pipeline_err != nil {
			log.errorf("pipeline rebuild failed (%v): %s", pipeline_err, watch.slang_path)
			continue
		}

		wait_for_idle()
		destroy_gpu_pipeline(watch.pipeline)
		watch.pipeline^ = pipeline
		elapsed_ms := time.duration_milliseconds(time.since(start))
		log.infof("reloaded %s (%.0f ms)", watch.slang_path, elapsed_ms)
	}
}

@(require_results)
watch_shader :: proc(pipeline: ^GPU_Pipeline, slang_path, spv_path: string) -> (err: Shader_Error) {
	when !ODIN_DEBUG do return .None
	engine := g_engine

	last_write, stat_err := os.modification_time_by_path(slang_path); if stat_err != nil {
		return .File_Not_Found
	}

	slang_path, _ := strings.clone(slang_path)
	spv_path, _ := strings.clone(spv_path)

	for &watch in engine.watch_shaders {
		if watch.pipeline == pipeline {
			delete(watch.slang_path)
			delete(watch.spv_path)
			watch.slang_path = slang_path
			watch.spv_path = spv_path
			watch.last_write = last_write

			return
		}
	}

	append(&engine.watch_shaders, Shader_Watch{pipeline = pipeline, slang_path = slang_path, spv_path = spv_path, last_write = last_write})
	return
}

@(private)
reset_shader_watches :: proc(engine: ^Engine) {
	for &watch in engine.watch_shaders {
		delete(watch.slang_path)
		delete(watch.spv_path)
	}
	clear(&engine.watch_shaders)
}

@(private)
destroy_shader_watches :: proc(engine: ^Engine) {
	for &watch in engine.watch_shaders {
		delete(watch.slang_path)
		delete(watch.spv_path)
	}
	delete(engine.watch_shaders)
}
