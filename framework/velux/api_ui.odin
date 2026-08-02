package velux

import "vlx:ui"

UI_Context :: ui.Context

ui_new_frame :: ui.new_frame
ui_end_frame :: ui.end_frame

ui_draw :: proc(frame: Frame) {
	hud_draw(g_engine)
	ui.draw(frame)
}

ui_bind :: ui.bind

ui_wants_mouse :: ui.wants_mouse
ui_wants_keyboard :: ui.wants_keyboard

ui_demo :: ui.demo
ui_begin_panel :: ui.begin_panel
ui_end_panel :: ui.end_panel
ui_slider :: ui.slider
ui_checkbox :: ui.check_box
ui_text :: ui.text
ui_plot_lines :: ui.plot_lines
