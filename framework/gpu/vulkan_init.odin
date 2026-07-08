package gpu

import vk "vendor:vulkan"

init_image_subresource_range :: proc(
	aspect_mask: vk.ImageAspectFlags,
) -> vk.ImageSubresourceRange {
	return {
		aspectMask = aspect_mask,
		baseMipLevel = 0,
		levelCount = vk.REMAINING_MIP_LEVELS,
		baseArrayLayer = 0,
		layerCount = vk.REMAINING_ARRAY_LAYERS,
	}
}

init_command_buffer_begin_info :: proc(
	flags: vk.CommandBufferUsageFlags,
) -> vk.CommandBufferBeginInfo {
	return {sType = .COMMAND_BUFFER_BEGIN_INFO, flags = flags}
}

init_command_buffer_submit_info :: proc(
	command_buffer: vk.CommandBuffer,
) -> vk.CommandBufferSubmitInfo {
	return {sType = .COMMAND_BUFFER_SUBMIT_INFO, commandBuffer = command_buffer}
}

init_semaphore_submit_info :: proc(
	semaphore: vk.Semaphore,
	stage_mask: vk.PipelineStageFlags2,
) -> vk.SemaphoreSubmitInfo {
	return {sType = .SEMAPHORE_SUBMIT_INFO, semaphore = semaphore, stageMask = stage_mask}
}

init_submit_info :: proc(
	wait_info: ^vk.SemaphoreSubmitInfo,
	command_buffer_info: ^vk.CommandBufferSubmitInfo,
	signal_info: ^vk.SemaphoreSubmitInfo,
) -> vk.SubmitInfo2 {
	return {
		sType = .SUBMIT_INFO_2,
		waitSemaphoreInfoCount = wait_info == nil ? 0 : 1,
		pWaitSemaphoreInfos = wait_info,
		commandBufferInfoCount = command_buffer_info == nil ? 0 : 1,
		pCommandBufferInfos = command_buffer_info,
		signalSemaphoreInfoCount = signal_info == nil ? 0 : 1,
		pSignalSemaphoreInfos = signal_info,
	}
}

init_present_info :: proc(
	wait_semaphore: ^vk.Semaphore,
	swapchain: ^vk.SwapchainKHR,
	image_indices: ^u32,
) -> vk.PresentInfoKHR {
	return {
		sType = .PRESENT_INFO_KHR,
		waitSemaphoreCount = 1,
		pWaitSemaphores = wait_semaphore,
		swapchainCount = 1,
		pSwapchains = swapchain,
		pImageIndices = image_indices,
	}
}

init_buffer_copy2 :: proc(
	size: vk.DeviceSize,
	dst_offset: vk.DeviceSize = 0,
	src_offset: vk.DeviceSize = 0,
) -> vk.BufferCopy2 {
	return {sType = .BUFFER_COPY_2, srcOffset = src_offset, dstOffset = dst_offset, size = size}
}
