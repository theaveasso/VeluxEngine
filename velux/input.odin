package velux

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
	F2           = glfw.KEY_F2,
	F5           = glfw.KEY_F5,
	F6           = glfw.KEY_F6,
}

Input_State :: struct {
	window_handle:       glfw.WindowHandle,
	mouse_position:      [2]f32,
	mouse_delta:         [2]f32,
	scroll_accumulation: [2]f32,
	scroll_delta:        [2]f32,
	keys_current:        #sparse[Key]bool,
	keys_previous:       #sparse[Key]bool,
	mouse_current:       [Mouse_Button]bool,
	mouse_previous:      [Mouse_Button]bool,
	cursor_captured:     bool,
	ignore_next_delta:   bool,
}

@(require_results)
is_mouse_down :: proc(mouse_button: Mouse_Button) -> bool {
	return g_engine.input.mouse_current[mouse_button]
}

@(require_results)
is_mouse_pressed :: proc(mouse_button: Mouse_Button) -> bool {
	input := &g_engine.input
	return input.mouse_current[mouse_button] && !input.mouse_previous[mouse_button]
}

@(require_results)
is_key_down :: proc(key: Key) -> bool {
	return g_engine.input.keys_current[key]
}

@(require_results)
is_key_pressed :: proc(key: Key) -> bool {
	input := &g_engine.input
	return input.keys_current[key] && !input.keys_previous[key]
}

@(require_results)
mouse_delta :: proc() -> [2]f32 {
	return g_engine.input.mouse_delta
}

@(require_results)
scroll_delta :: proc() -> [2]f32 {
	return g_engine.input.scroll_delta
}

set_cursor_captured :: proc(captured: bool) {
	input := &g_engine.input
	if input.cursor_captured == captured do return
	input.cursor_captured = captured
	mode: i32 = captured ? glfw.CURSOR_DISABLED : glfw.CURSOR_NORMAL
	glfw.SetInputMode(input.window_handle, glfw.CURSOR, mode)
	input.ignore_next_delta = true
}

@(require_results)
is_cursor_captured :: proc() -> bool {
	return g_engine.input.cursor_captured
}

@(private)
input_init :: proc(engine: ^Engine) {
	input := &engine.input
	input.window_handle = engine.window.handle
	curr_mx, curr_my := glfw.GetCursorPos(input.window_handle)
	input.mouse_position = {f32(curr_mx), f32(curr_my)}
	glfw.SetScrollCallback(input.window_handle, scroll_callback)
}

@(private)
input_new_frame :: proc() {
	input := &g_engine.input
	mx, my := glfw.GetCursorPos(input.window_handle)
	if input.ignore_next_delta {
		input.mouse_delta = {}
		input.ignore_next_delta = false
	} else {
		input.mouse_delta = {f32(mx), f32(my)} - input.mouse_position
	}
	input.mouse_position = {f32(mx), f32(my)}
	input.scroll_delta = input.scroll_accumulation
	input.scroll_accumulation = {}

	input.keys_previous = input.keys_current
	for key in Key {
		input.keys_current[key] = glfw.GetKey(input.window_handle, i32(key)) == glfw.PRESS
	}

	input.mouse_previous = input.mouse_current
	for button in Mouse_Button {
		input.mouse_current[button] = glfw.GetMouseButton(input.window_handle, i32(button)) == glfw.PRESS
	}
}

@(private)
scroll_callback :: proc "c" (window: glfw.WindowHandle, xoffset, yoffset: f64) {
	g_engine.input.scroll_accumulation += {f32(xoffset), f32(yoffset)}
}
