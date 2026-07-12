package platform

import glfw "vendor:glfw"

Error :: enum {
	None,
	Init_Failed,
	Window_Creation_Failed,
}

Window :: struct {
	handle: glfw.WindowHandle,
	width:  i32,
	height: i32,
}

@(require_results)
init :: proc() -> Error {
	if !glfw.Init() do return .Init_Failed

	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
	glfw.WindowHint(glfw.RESIZABLE, glfw.TRUE)
	return .None
}

@(require_results)
create_window :: proc(window: ^Window, width, height: i32, title: cstring) -> Error {
	window.handle = glfw.CreateWindow(width, height, title, nil, nil)
	if window.handle == nil do return .Window_Creation_Failed
	return .None
}

destroy_window :: proc(window: ^Window) {
	if window.handle == nil do return
	glfw.DestroyWindow(window.handle)
}

window_should_close :: proc(window: ^Window) -> bool {
	return bool(glfw.WindowShouldClose(window.handle))
}

window_extent :: proc(window: ^Window) -> [2]f32 {
	w, h := glfw.GetFramebufferSize(window.handle)
	return {cast(f32)w, cast(f32)h}
}

poll_events :: proc() {
	glfw.PollEvents()
}

shutdown :: proc() {
	glfw.Terminate()
}

time :: proc() -> f64 {
	return glfw.GetTime()
}
