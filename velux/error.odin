package velux

import "core:fmt"
import vk "vendor:vulkan"

// Every value here is a failure a caller can answer. If you cannot write the
// `case` that handles it, it does not belong in this enum -- it belongs in a
// fatal at the site that detected it, where the parameters are still in scope.
//
// The previous design was a six-arm union over ~25 values, none of which was
// ever switched on: every path terminated in one log.errorf several frames
// above the failure, by which point the only information left was the name of
// the enum.
Error :: enum u8 {
	None = 0,

	// The path does not exist. Callers pick another asset or report it.
	Asset_Not_Found,
	// The file exists but is not what it claims to be.
	Asset_Malformed,
	// slangc rejected the source. The previously built pipeline is still live
	// and still correct, so hot reload keeps running on the old shader.
	Shader_Compile_Failed,
	// slangc is not on disk. Shaders cannot be built at all this run.
	Shader_Compiler_Missing,
	// The SPIR-V on disk is not loadable as a shader module.
	Shader_Invalid,

	// One sound failed to open or decode. Others still work.
	Sound_Load_Failed,
	// No audio output device. The engine runs silent.
	Audio_Unavailable,

	// The frame was dropped and the swapchain rebuilt. Try again next frame.
	Swapchain_Out_Of_Date,

	// Hot reload: `odin build` failed. The running code survives untouched.
	Game_Build_Failed,
	// Hot reload: the freshly built shared library would not load.
	Game_Load_Failed,
}

// Unrecoverable, so it does not travel. Stops here, at the call that failed,
// while the arguments that caused it are still in scope.
//
// This is the right answer for: a machine with no usable GPU, an allocation
// that did not come back, and any Vulkan call that can only fail when velux
// has handed it something invalid. There is no caller who can do better than
// die, and every frame of laundering loses detail.
@(private)
fatal :: proc(format: string, args: ..any, loc := #caller_location) -> ! {
	fmt.panicf(format, ..args, loc = loc)
}

// `what` should name the call, not describe it: "vkCreateImageView", not
// "creating the image view". The result already says what went wrong.
@(private)
vk_assert :: proc(result: vk.Result, what: string, loc := #caller_location) {
	if result == .SUCCESS do return
	fmt.panicf("%s failed: %v", what, result, loc = loc)
}
