package velux

import "vendor:glfw"
import vk "vendor:vulkan"

// Odin has no dynamic linking of Odin packages, so a hot reloaded game DLL
// carries its own copy of velux, vendor:vulkan and odin-imgui. Every
// package-level variable therefore exists twice, zeroed in the DLL, and this
// re-points them at the host's.
//
// The velux half stays one assignment only while g_engine remains the only
// mutable package-level variable (see engine.odin). The proc tables belong to
// vendor packages, so each copy must load its own.
attach :: proc(engine: ^Engine) {
	g_engine = engine

	vk.load_proc_addresses_global(rawptr(glfw.GetInstanceProcAddress))
	vk.load_proc_addresses_instance(engine.gpu.instance)
	vk.load_proc_addresses_device(engine.gpu.device)
	bind_ui(engine)
}
