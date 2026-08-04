package velux

import "core:fmt"
import vk "vendor:vulkan"

// If you cannot write the `case` that handles it, it does not belong here --
// it belongs in a fatal at the site that detected it, where the parameters are
// still in scope.
Error :: enum u8 {
	None = 0,

	Asset_Not_Found,
	Asset_Malformed,
	// The previously built pipeline is still live and still correct, so hot
	// reload keeps running on the old shader.
	Shader_Compile_Failed,
	Shader_Compiler_Missing,
	Shader_Invalid,

	Sound_Load_Failed,
	Audio_Unavailable,

	// The frame was dropped and the swapchain rebuilt. Retry next frame.
	Swapchain_Out_Of_Date,

	// The running code survives both of these untouched.
	Game_Build_Failed,
	Game_Load_Failed,
}

// Stops at the call that failed, while the arguments that caused it are still
// in scope.
@(private)
fatal :: proc(format: string, args: ..any, loc := #caller_location) -> ! {
	fmt.panicf(format, ..args, loc = loc)
}

// `what` names the call -- "vkCreateImageView" -- since the result already
// says what went wrong.
@(private)
vk_assert :: proc(result: vk.Result, what: string, loc := #caller_location) {
	if result == .SUCCESS do return
	fmt.panicf("%s failed: %v", what, result, loc = loc)
}
