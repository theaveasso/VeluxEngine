package velux

import "base:runtime"
import "core:os"
import "core:path/filepath"
import "core:strings"

Shader_Compile_Error :: enum {
	None,
	File_Not_Found,
	Compiler_Not_Found,
	Compile_Failed,
}

compile_slang :: proc(slang_path, spv_path: string, allocator: runtime.Allocator) -> (output: string, err: Shader_Compile_Error) {
	when ODIN_OS == .Windows {
		SLANGC_NAME :: "slangc.exe"
		SLANGC_DIR :: "Bin"
	} else {
		SLANGC_NAME :: "slangc"
		SLANGC_DIR :: "bin"
	}
	if !os.exists(slang_path) do return "", .File_Not_Found

	slangc := SLANGC_NAME
	sdk := os.get_env("VULKAN_SDK", allocator)
	if sdk != "" {
		candidate, _ := filepath.join({sdk, SLANGC_DIR, SLANGC_NAME}, allocator)
		if os.exists(candidate) do slangc = candidate
	}

	cmd := []string{slangc, slang_path, "-target", "spirv", "-fvk-use-entrypoint-name", "-o", spv_path}
	state, stdout, stderr, exec_err := os.process_exec({command = cmd}, allocator)
	if exec_err != nil do return "", .Compiler_Not_Found

	output = strings.concatenate({string(stdout), string(stderr)}, allocator)
	if state.exit_code != 0 do return output, .Compile_Failed

	return output, .None

}
