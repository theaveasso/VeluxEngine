package velux

import vk "vendor:vulkan"

Transfer_Context :: struct {
	command_pool:    vk.CommandPool,
	command_buffer:  vk.CommandBuffer,
	fence:           vk.Fence,
	staging_buffers: [dynamic]GPU_Buffer(u8),
}

@(private)
create_transfer_context :: proc(device: ^GPU_Device) {
	pool_info: vk.CommandPoolCreateInfo = {
		sType            = .COMMAND_POOL_CREATE_INFO,
		flags            = {.TRANSIENT, .RESET_COMMAND_BUFFER},
		queueFamilyIndex = device.graphics_family,
	}
	vk_assert(vk.CreateCommandPool(device.device, &pool_info, nil, &device.transfer.command_pool), "vkCreateCommandPool")

	buffer_info: vk.CommandBufferAllocateInfo = {
		sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
		commandPool        = device.transfer.command_pool,
		commandBufferCount = 1,
		level              = .PRIMARY,
	}
	vk_assert(vk.AllocateCommandBuffers(device.device, &buffer_info, &device.transfer.command_buffer), "vkAllocateCommandBuffers")

	fence_info: vk.FenceCreateInfo = {
		sType = .FENCE_CREATE_INFO,
	}
	vk_assert(vk.CreateFence(device.device, &fence_info, nil, &device.transfer.fence), "vkCreateFence")
}

@(private)
destroy_transfer_context :: proc(device: ^GPU_Device) {
	vk.DestroyCommandPool(device.device, device.transfer.command_pool, nil)
	vk.DestroyFence(device.device, device.transfer.fence, nil)
	destroy_staging_buffers(device)
	delete(device.transfer.staging_buffers)
}

// Blocking: correct at load time, ruinous per frame. See gpu_upload.odin.
immediate_transfer_begin :: proc(loc := #caller_location) -> vk.CommandBuffer {
	device := &engine_bound(loc).gpu
	context.logger = device.logger

	vk_assert(vk.ResetFences(device.device, 1, &device.transfer.fence), "vkResetFences")
	vk_assert(vk.ResetCommandBuffer(device.transfer.command_buffer, {}), "vkResetCommandBuffer")

	cmd_begin_info := init_command_buffer_begin_info({.ONE_TIME_SUBMIT})
	vk_assert(vk.BeginCommandBuffer(device.transfer.command_buffer, &cmd_begin_info), "vkBeginCommandBuffer")

	return device.transfer.command_buffer
}

immediate_transfer_end :: proc(loc := #caller_location) {
	device := &engine_bound(loc).gpu
	context.logger = device.logger
	defer {
		destroy_staging_buffers(device)
		clear(&device.transfer.staging_buffers)
	}

	vk_assert(vk.EndCommandBuffer(device.transfer.command_buffer), "vkEndCommandBuffer")

	cmd_info := init_command_buffer_submit_info(device.transfer.command_buffer)
	submit_info := init_submit_info(nil, &cmd_info, nil)
	vk_assert(vk.QueueSubmit2(device.graphics_queue, 1, &submit_info, device.transfer.fence), "vkQueueSubmit2")
	vk_assert(vk.WaitForFences(device.device, 1, &device.transfer.fence, true, max(u64)), "vkWaitForFences")
}

@(private)
destroy_staging_buffers :: proc(device: ^GPU_Device) {
	for &staging in device.transfer.staging_buffers {
		destroy_gpu_buffer(&staging)
	}
}
