package velux

import glfw "vendor:glfw"

Window :: struct {
	handle: glfw.WindowHandle,
	width:  i32,
	height: i32,
}

Window_API :: struct {
	now: proc() -> f64,
}

@(private, require_results)
host_window_api :: proc() -> Window_API {
	return {now = host_now}
}

@(require_results)
now :: proc(loc := #caller_location) -> f64 {
	return bound_api(loc).window.now()
}

@(private, require_results)
host_now :: proc() -> f64 {
	return glfw.GetTime()
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
create_window :: proc(window: ^Window, width, height: i32, title: cstring) {
	window.handle = glfw.CreateWindow(width, height, title, nil, nil)
	if window.handle == nil {
		description, code := glfw.GetError()
		fatal("cannot create a %vx%v window: %v (%v)", width, height, description, code)
	}
	window.width = width
	window.height = height
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

@(private, require_results)
framebuffer_extent :: proc(window: ^Window) -> [2]f32 {
	w, h := glfw.GetFramebufferSize(window.handle)
	return {cast(f32)w, cast(f32)h}
}

@(private)
poll_events :: proc() {
	glfw.PollEvents()
}

@(private)
shutdown_platform :: proc() {
	glfw.Terminate()
}
