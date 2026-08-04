package velux

import "vendor:glfw"
import vk "vendor:vulkan"

// Odin has no dynamic linking of Odin packages, so a hot reloaded game DLL
// carries its own statically compiled copy of velux -- and of vendor:vulkan and
// odin-imgui with it. Every package-level variable therefore exists twice, and
// the DLL's copy starts out zeroed. This is what re-points them at the host's.
//
// The velux half is a single assignment, and stays a single assignment as long
// as g_engine remains the only mutable package-level variable in velux and
// everything shared lives inside Engine (see the note on g_engine in
// engine.odin). Add a second one and it will silently diverge between the two
// copies until someone spends an afternoon on it.
//
// The rest is unavoidable: the proc tables belong to vendor packages, so each
// copy has to load its own.
attach :: proc(engine: ^Engine) {
	g_engine = engine

	vk.load_proc_addresses_global(rawptr(glfw.GetInstanceProcAddress))
	vk.load_proc_addresses_instance(engine.gpu.instance)
	vk.load_proc_addresses_device(engine.gpu.device)
	bind_ui(engine)
}
