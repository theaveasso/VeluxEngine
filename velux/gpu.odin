package velux

import vk "vendor:vulkan"

Command_Buffer :: vk.CommandBuffer
GPU_Shader :: vk.ShaderModule
Format :: vk.Format

Vertex :: struct {
	position: [3]f32,
	uv_u:     f32,
	normal:   [3]f32,
	uv_v:     f32,
}

@(require_results)
swapchain_format :: proc(loc := #caller_location) -> Format {
	return engine_bound(loc).gpu.swapchain.surface_format.format
}

wait_for_idle :: proc(loc := #caller_location) {
	wait_idle(&engine_bound(loc).gpu)
}
