package gpu

import vk "vendor:vulkan"

Transfer_Context :: struct {
	command_pool:    vk.CommandPool,
	command_buffer:  vk.CommandBuffer,
	fence:           vk.Fence,
	staging_buffers: [dynamic]Buffer(u8),
}

@(private, require_results)
create_imm_transfer_context :: proc(device: ^Device) -> (err: Error) {
	defer if err != .None do destroy_imm_transfer_context(device)

	pool_info: vk.CommandPoolCreateInfo = {
		sType            = .COMMAND_POOL_CREATE_INFO,
		flags            = {.TRANSIENT, .RESET_COMMAND_BUFFER},
		queueFamilyIndex = device.graphics_family,
	}

	vk_check(
		vk.CreateCommandPool(
			device.device,
			&pool_info,
			nil,
			&device.imm_transfer_ctx.command_pool,
		),
		.Vulkan_Call_Failed,
	) or_return

	buffer_info: vk.CommandBufferAllocateInfo = {
		sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
		commandPool        = device.imm_transfer_ctx.command_pool,
		commandBufferCount = 1,
		level              = .PRIMARY,
	}

	vk_check(
		vk.AllocateCommandBuffers(
			device.device,
			&buffer_info,
			&device.imm_transfer_ctx.command_buffer,
		),
		.Vulkan_Call_Failed,
	) or_return

	fence_info: vk.FenceCreateInfo = {
		sType = .FENCE_CREATE_INFO,
	}

	vk_check(
		vk.CreateFence(device.device, &fence_info, nil, &device.imm_transfer_ctx.fence),
		.Vulkan_Call_Failed,
	) or_return

	return .None
}

@(private)
destroy_imm_transfer_context :: proc(device: ^Device) {
	vk.DestroyCommandPool(device.device, device.imm_transfer_ctx.command_pool, nil)
	vk.DestroyFence(device.device, device.imm_transfer_ctx.fence, nil)
	destroy_imm_staging_buffers(device)
	delete(device.imm_transfer_ctx.staging_buffers)
}

@(require_results)
imm_transfer_begin :: proc(device: ^Device) -> (cmd: vk.CommandBuffer, err: Error) {
	context.logger = device.logger

	vk_check(
		vk.ResetFences(device.device, 1, &device.imm_transfer_ctx.fence),
		.Vulkan_Call_Failed,
	) or_return

	vk_check(
		vk.ResetCommandBuffer(device.imm_transfer_ctx.command_buffer, {}),
		.Vulkan_Call_Failed,
	) or_return

	cmd_begin_info := init_command_buffer_begin_info({.ONE_TIME_SUBMIT})
	vk_check(
		vk.BeginCommandBuffer(device.imm_transfer_ctx.command_buffer, &cmd_begin_info),
		.Vulkan_Call_Failed,
	) or_return

	return device.imm_transfer_ctx.command_buffer, .None
}

@(require_results)
imm_transfer_end :: proc(device: ^Device) -> (err: Error) {
	defer {
		destroy_imm_staging_buffers(device)
		clear(&device.imm_transfer_ctx.staging_buffers)
	}
	context.logger = device.logger

	vk_check(
		vk.EndCommandBuffer(device.imm_transfer_ctx.command_buffer),
		.Vulkan_Call_Failed,
	) or_return

	cmd_info := init_command_buffer_submit_info(device.imm_transfer_ctx.command_buffer)
	submit_info := init_submit_info(nil, &cmd_info, nil)

	vk_check(
		vk.QueueSubmit2(device.graphics_queue, 1, &submit_info, device.imm_transfer_ctx.fence),
		.Vulkan_Call_Failed,
	) or_return

	vk_check(
		vk.WaitForFences(device.device, 1, &device.imm_transfer_ctx.fence, true, max(u64)),
		.Vulkan_Call_Failed,
	) or_return

	return .None
}

@(private)
destroy_imm_staging_buffers :: proc(device: ^Device) {
	for &staging in device.imm_transfer_ctx.staging_buffers {
		destroy_buffer(device, &staging)
	}
}
