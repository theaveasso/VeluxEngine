package velux

import "core:fmt"
import vk "vendor:vulkan"

Error :: enum u8 {
	None = 0,
	Asset_Not_Found,
	Asset_Malformed,
	Shader_Compile_Failed,
	Shader_Compiler_Missing,
	Shader_Invalid,
	Sound_Load_Failed,
	Audio_Unavailable,
	Swapchain_Out_Of_Date,
	Game_Build_Failed,
	Game_Load_Failed,
}

@(private)
fatal :: proc(format: string, args: ..any, loc := #caller_location) -> ! {
	fmt.panicf(format, ..args, loc = loc)
}

@(private)
vk_assert :: proc(result: vk.Result, what: string, loc := #caller_location) {
	if result == .SUCCESS do return
	fmt.panicf("%s failed: %v", what, result, loc = loc)
}
