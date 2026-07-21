package platform

import "vendor:glfw"

Mouse_Button :: enum i32 {
	LEFT   = glfw.MOUSE_BUTTON_LEFT,
	RIGHT  = glfw.MOUSE_BUTTON_RIGHT,
	MIDDLE = glfw.MOUSE_BUTTON_MIDDLE,
}
Key :: enum i32 {
	W            = glfw.KEY_W,
	A            = glfw.KEY_A,
	S            = glfw.KEY_S,
	D            = glfw.KEY_D,
	ESCAPE       = glfw.KEY_ESCAPE,
	LEFT_CONTROL = glfw.KEY_LEFT_CONTROL,
	LEFT_SHIFT   = glfw.KEY_LEFT_SHIFT,
	SPACE        = glfw.KEY_SPACE,
	TAB          = glfw.KEY_TAB,
	F1           = glfw.KEY_F1,
}

Input_State :: struct {
	window_handle:       glfw.WindowHandle,
	mouse_position:      [2]f32,
	mouse_delta:         [2]f32,
	scroll_accumulation: [2]f32,
	scroll_delta:        [2]f32,
	keys_current:        #sparse[Key]bool,
	keys_previous:       #sparse[Key]bool,
	cursor_captured:     bool,
	ignore_next_delta:   bool,
}

g_input_state: Input_State

input_init :: proc(window: ^Window) {
	g_input_state.window_handle = window.handle
	curr_mx, curr_my := glfw.GetCursorPos(window.handle)
	g_input_state.mouse_position = {f32(curr_mx), f32(curr_my)}
	glfw.SetScrollCallback(g_input_state.window_handle, scroll_callback)
}

input_new_frame :: proc() {
	mx, my := glfw.GetCursorPos(g_input_state.window_handle)
	if g_input_state.ignore_next_delta {
		g_input_state.mouse_delta = {}
		g_input_state.ignore_next_delta = false
	} else {
		g_input_state.mouse_delta = {f32(mx), f32(my)} - g_input_state.mouse_position
	}
	g_input_state.mouse_position = {f32(mx), f32(my)}
	g_input_state.scroll_delta = g_input_state.scroll_accumulation
	g_input_state.scroll_accumulation = {}

	g_input_state.keys_previous = g_input_state.keys_current
	for key in Key {
		g_input_state.keys_current[key] = glfw.GetKey(g_input_state.window_handle, i32(key)) == glfw.PRESS
	}
}

@(require_results)
is_mouse_down :: proc(mouse_button: Mouse_Button) -> bool {
	return glfw.GetMouseButton(g_input_state.window_handle, i32(mouse_button)) == glfw.PRESS
}
@(require_results)
is_key_down :: proc(key: Key) -> bool {
	return g_input_state.keys_current[key]
}
@(require_results)
is_key_pressed :: proc(key: Key) -> bool {
	return g_input_state.keys_current[key] && !g_input_state.keys_previous[key]
}
@(require_results)
mouse_delta :: proc() -> [2]f32 {
	return g_input_state.mouse_delta
}
@(require_results)
scroll_delta :: proc() -> [2]f32 {
	return g_input_state.scroll_delta
}
set_cursor_captured :: proc(captured: bool) {
	if g_input_state.cursor_captured == captured do return
	g_input_state.cursor_captured = captured
	mode: i32 = captured ? glfw.CURSOR_DISABLED : glfw.CURSOR_NORMAL
	glfw.SetInputMode(g_input_state.window_handle, glfw.CURSOR, mode)
	g_input_state.ignore_next_delta = true
}
@(require_results)
is_cursor_captured :: proc() -> bool {
	return g_input_state.cursor_captured
}

scroll_callback :: proc "c" (window: glfw.WindowHandle, xoffset, yoffset: f64) {
	g_input_state.scroll_accumulation += {f32(xoffset), f32(yoffset)}
}
