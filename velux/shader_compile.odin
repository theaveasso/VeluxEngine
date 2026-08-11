package velux

import "base:runtime"
import "core:os"
import "core:path/filepath"
import "core:strings"

DEFAULT_SHADER_INCLUDE_DIR :: "../../velux/shaders"

@(require_results)
compile_slang :: proc(slang_path, spv_path: string, allocator: runtime.Allocator) -> (output: string, err: Error) {
	when ODIN_OS == .Windows {
		SLANGC_NAME :: "slangc.exe"
		SLANGC_DIR :: "Bin"
	} else {
		SLANGC_NAME :: "slangc"
		SLANGC_DIR :: "bin"
	}
	if !os.exists(slang_path) do return "", .Asset_Not_Found

	slangc := SLANGC_NAME
	sdk := os.get_env("VULKAN_SDK", allocator)
	defer delete(sdk, allocator)

	candidate: string
	defer delete(candidate, allocator)

	if sdk != "" {
		candidate, _ = filepath.join({sdk, SLANGC_DIR, SLANGC_NAME}, allocator)
		if os.exists(candidate) do slangc = candidate
	}

	engine_shader_dir := DEFAULT_SHADER_INCLUDE_DIR
	if g_engine != nil && g_engine.shader_include_dir != "" do engine_shader_dir = g_engine.shader_include_dir

	slang_dir := filepath.dir(slang_path)
	cmd := []string{slangc, slang_path, "-I", slang_dir, "-I", engine_shader_dir, "-target", "spirv", "-fvk-use-entrypoint-name", "-o", spv_path}
	state, stdout, stderr, exec_err := os.process_exec({command = cmd}, allocator)
	defer delete(stdout, allocator)
	defer delete(stderr, allocator)
	if exec_err != nil do return "", .Shader_Compiler_Missing

	output = strings.concatenate({string(stdout), string(stderr)}, allocator)
	if state.exit_code != 0 do return output, .Shader_Compile_Failed

	return output, .None
}
