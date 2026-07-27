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
	slider_float3,
}
slider_f32 :: proc(label: string, v: ^f32, v_min, v_max: f32, allocator := context.temp_allocator) -> bool {
	return g_initialized ? imgui.SliderFloat(strings.clone_to_cstring(label, allocator), v, v_min, v_max) : false
}
slider_int :: proc(label: string, v: ^i32, v_min, v_max: i32, allocator := context.temp_allocator) -> bool {
	return g_initialized ? imgui.SliderInt(strings.clone_to_cstring(label, allocator), v, v_min, v_max) : false
}
slider_float3 :: proc(lable: string, v: ^[3]f32, v_min: f32, v_max: f32, allocator := context.temp_allocator) -> bool {
	return g_initialized ? imgui.SliderFloat3(strings.clone_to_cstring(lable, allocator), v, v_min, v_max) : false
}

check_box :: proc(label: string, v: ^bool, allocator := context.temp_allocator) -> bool {
	return g_initialized ? imgui.Checkbox(strings.clone_to_cstring(label, allocator), v) : false
}

text :: proc(t: string, allocator := context.temp_allocator) {
	if !g_initialized do return
	imgui.TextUnformatted(strings.clone_to_cstring(t, allocator))
}

plot_lines :: proc(label: string, v: []f32, s_min: f32 = 0, s_max: f32 = 33, height: f32 = 40, allocator := context.temp_allocator) {
	if !g_initialized do return
	if len(v) == 0 do return

	imgui.PlotLines(
		strings.clone_to_cstring(label, allocator),
		&v[0],
		i32(len(v)),
		scale_min = s_min,
		scale_max = s_max,
		graph_size = {0, height},
	)
}
