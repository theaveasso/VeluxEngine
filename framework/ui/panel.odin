package ui

import "core:strings"
import imgui "third_party:odin-imgui"

demo :: proc() {
	imgui.ShowDemoWindow()
}

begin_panel :: proc(name: string, allocator := context.temp_allocator) -> bool {
	return g_initialized ? imgui.Begin(strings.clone_to_cstring(name, allocator)) : false
}
end_panel :: proc() {
	imgui.End()
}

slider :: proc {
	slider_f32,
	slider_int,
}
slider_f32 :: proc(label: string, v: ^f32, v_min, v_max: f32, allocator := context.temp_allocator) -> bool {
	return g_initialized ? imgui.SliderFloat(strings.clone_to_cstring(label, allocator), v, v_min, v_max) : false
}
slider_int :: proc(label: string, v: ^i32, v_min, v_max: i32, allocator := context.temp_allocator) -> bool {
	return g_initialized ? imgui.SliderInt(strings.clone_to_cstring(label, allocator), v, v_min, v_max) : false
}

check_box :: proc(label: string, v: ^bool, allocator := context.temp_allocator) -> bool {
	return g_initialized ? imgui.Checkbox(strings.clone_to_cstring(label, allocator), v) : false
}
