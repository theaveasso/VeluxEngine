package velux

import glfw "vendor:glfw"

Platform_Error :: enum {
	None,
	Init_Failed,
	Window_Creation_Failed,
	Allocation_Failed,
	Dll_Build_Failed,
	Dll_Load_Failed,
}

Window :: struct {
	handle: glfw.WindowHandle,
	width:  i32,
	height: i32,
}

@(require_results)
now :: proc() -> f64 {
	return glfw.GetTime()
}

@(private, require_results)
init_platform :: proc() -> Platform_Error {
	if !glfw.Init() do return .Init_Failed

	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
	glfw.WindowHint(glfw.RESIZABLE, glfw.TRUE)
	return .None
}

@(private, require_results)
create_window :: proc(window: ^Window, width, height: i32, title: cstring) -> Platform_Error {
	window.handle = glfw.CreateWindow(width, height, title, nil, nil)
	if window.handle == nil do return .Window_Creation_Failed
	return .None
}

@(private)
destroy_window :: proc(window: ^Window) {
	if window.handle == nil do return
	glfw.DestroyWindow(window.handle)
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
