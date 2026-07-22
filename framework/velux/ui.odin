package velux

import "vlx:ui"

ui_wants_mouse :: #force_inline proc(engine: ^Engine) -> bool {
	return ui.wants_mouse(&engine.ui)
}
ui_wants_keyboard :: #force_inline proc(engine: ^Engine) -> bool {
	return ui.wants_keyboard(&engine.ui)
}

ui_new_frame :: proc(engine: ^Engine) {
	if engine.ui.initialized do ui.new_frame()
}
ui_end_frame :: proc(engine: ^Engine) {
	if engine.ui.initialized do ui.end_frame()
}
ui_draw :: proc(engine: ^Engine, frame: Frame) {
	if engine.ui.initialized do ui.draw(frame.cmd)
}

ui_demo :: proc(engine: ^Engine) {
	if engine.ui.initialized do ui.demo()
}
