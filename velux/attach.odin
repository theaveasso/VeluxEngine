package velux

import "vendor:glfw"
import vk "vendor:vulkan"

attach :: proc(engine: ^Engine) {
	g_engine = engine

	vk.load_proc_addresses_global(rawptr(glfw.GetInstanceProcAddress))
	vk.load_proc_addresses_instance(engine.gpu.instance)
	vk.load_proc_addresses_device(engine.gpu.device)
	bind_ui(engine)
}
