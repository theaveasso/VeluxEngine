package velux

import "vendor:glfw"
import vk "vendor:vulkan"

import imgui "third_party:odin-imgui"

// Odin has no dynamic linking of Odin packages, so a hot reloaded game DLL
// carries its own copy of velux, vendor:vulkan and odin-imgui. Every
// package-level variable therefore exists twice, zeroed in the DLL, and this
// re-points them at the host's.
//
// The velux half stays one assignment only while g_engine remains the only
// mutable package-level variable (see engine.odin). Vulkan and imgui keep their
// own state outside velux, so each copy must be pointed at the host's: vulkan
// through its dispatch tables, imgui through its context and heap.
//
// Reached only as App.attach, which make_app fills in so the host ends up with
// a pointer into the DLL's copy rather than its own. Not for games to call:
// doing so from a compiled-in game would repoint the one copy at itself, and
// from a DLL would fight the host.
@(private)
attach :: proc(engine: ^Engine) {
	g_engine = engine

	vk.load_proc_addresses_global(rawptr(glfw.GetInstanceProcAddress))
	vk.load_proc_addresses_instance(engine.gpu.instance)
	vk.load_proc_addresses_device(engine.gpu.device)

	if ui := &engine.ui_context; ui.ctx != nil {
		imgui.SetAllocatorFunctions(ui.imgui_alloc, ui.imgui_free, ui.imgui_user_data)
		imgui.SetCurrentContext(ui.ctx)
	}
}
