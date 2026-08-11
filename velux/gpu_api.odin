package velux

import "base:runtime"

import vk "vendor:vulkan"

GPU_API :: struct {
	swapchain_format:         proc() -> Format,
	wait_for_idle:            proc(),
	immediate_transfer_begin: proc() -> vk.CommandBuffer,
	immediate_transfer_end:   proc(),
	prof_zone_begin:          proc(frame: Frame, name: string, loc: runtime.Source_Code_Location) -> u32,
	prof_zone_end:            proc(frame: Frame, loc: runtime.Source_Code_Location),
}

@(private, require_results)
host_gpu_api :: proc() -> GPU_API {
	return {
		swapchain_format = host_swapchain_format,
		wait_for_idle = host_wait_for_idle,
		immediate_transfer_begin = host_immediate_transfer_begin,
		immediate_transfer_end = host_immediate_transfer_end,
		prof_zone_begin = host_prof_zone_begin,
		prof_zone_end = host_prof_zone_end,
	}
}
