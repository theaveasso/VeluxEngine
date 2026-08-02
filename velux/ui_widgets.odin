package velux

import "core:strings"

import imgui "third_party:odin-imgui"

ui_demo :: proc() {
	imgui.ShowDemoWindow()
}

@(require_results)
ui_begin_panel :: proc(name: string, allocator := context.temp_allocator) -> bool {
	return ui_ready() ? imgui.Begin(strings.clone_to_cstring(name, allocator)) : false
}
ui_end_panel :: proc() {
	imgui.End()
}

ui_slider :: proc {
	ui_slider_f32,
	ui_slider_int,
	ui_slider_float3,
}

ui_slider_f32 :: proc(label: string, v: ^f32, v_min, v_max: f32, allocator := context.temp_allocator) -> bool {
	return ui_ready() ? imgui.SliderFloat(strings.clone_to_cstring(label, allocator), v, v_min, v_max) : false
}
ui_slider_int :: proc(label: string, v: ^i32, v_min, v_max: i32, allocator := context.temp_allocator) -> bool {
	return ui_ready() ? imgui.SliderInt(strings.clone_to_cstring(label, allocator), v, v_min, v_max) : false
}
ui_slider_float3 :: proc(label: string, v: ^[3]f32, v_min: f32, v_max: f32, allocator := context.temp_allocator) -> bool {
	return ui_ready() ? imgui.SliderFloat3(strings.clone_to_cstring(label, allocator), v, v_min, v_max) : false
}

ui_checkbox :: proc(label: string, v: ^bool, allocator := context.temp_allocator) -> bool {
	return ui_ready() ? imgui.Checkbox(strings.clone_to_cstring(label, allocator), v) : false
}

ui_text :: proc(t: string, allocator := context.temp_allocator) {
	if !ui_ready() do return
	imgui.TextUnformatted(strings.clone_to_cstring(t, allocator))
}

ui_plot_lines :: proc(label: string, v: []f32, s_min: f32 = 0, s_max: f32 = 33, height: f32 = 40, allocator := context.temp_allocator) {
	if !ui_ready() do return
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
