package velux

import glfw "vendor:glfw"

Window :: struct {
	handle: glfw.WindowHandle,
}

@(require_results)
now :: proc() -> f64 {
	return glfw.GetTime()
}

// Framebuffer pixels, not window units: on a HiDPI display these differ, and
// swapchains, viewports and render targets are all sized in pixels.
@(require_results)
framebuffer_size :: proc(loc := #caller_location) -> [2]f32 {
	width, height := glfw.GetFramebufferSize(engine_bound(loc).window.handle)
	return {cast(f32)width, cast(f32)height}
}

@(private)
init_platform :: proc() {
	if !glfw.Init() {
		description, code := glfw.GetError()
		fatal("glfwInit failed: %v (%v)", description, code)
	}

	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
	glfw.WindowHint(glfw.RESIZABLE, glfw.TRUE)
}

@(private)
init_window :: proc(window: ^Window, width, height: i32, title: cstring) {
	window.handle = glfw.CreateWindow(width, height, title, nil, nil)
	if window.handle == nil {
		description, code := glfw.GetError()
		fatal("cannot create a %vx%v window: %v (%v)", width, height, description, code)
	}
}

@(private)
destroy_window :: proc(window: ^Window) {
	if window.handle == nil do return
	glfw.DestroyWindow(window.handle)
	window^ = {}
}

@(private, require_results)
window_should_close :: proc(window: ^Window) -> bool {
	return bool(glfw.WindowShouldClose(window.handle))
}

@(private)
poll_events :: proc() {
	glfw.PollEvents()
}

@(private)
shutdown_platform :: proc() {
	glfw.Terminate()
}
