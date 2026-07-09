package gpu

import vma "third_party:odin-vma"
import vk "vendor:vulkan"

init_image_subresource_range :: proc(
	aspect_mask: vk.ImageAspectFlags,
	mip_levels: u32 = vk.REMAINING_MIP_LEVELS,
	array_layers: u32 = vk.REMAINING_MIP_LEVELS,
) -> vk.ImageSubresourceRange {
	return {
		aspectMask = aspect_mask,
		baseMipLevel = 0,
		levelCount = mip_levels,
		baseArrayLayer = 0,
		layerCount = array_layers,
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

init_gpu_pipeline_create_info :: proc(
	shader: vk.ShaderModule,
	push_constants: typeid,
	input_topology: vk.PrimitiveTopology,
	polygon_mode: vk.PolygonMode,
	front_face: vk.FrontFace,
	depth: struct {
		write_enabled: b32,
		compare_op:    vk.CompareOp,
		format:        vk.Format,
	} = {},
	cull_mode: vk.CullModeFlags = {},
	color_format: vk.Format = .UNDEFINED,
	blend_mode: Pipeline_Blend_Mode = .None,
	vertex_entry: cstring = DEFAULT_VERTEX_ENTRY,
	fragment_entry: cstring = DEFAULT_FRAGMENT_ENTRY,
) -> Graphics_Pipeline_Create_Info {
	return {
		shader = shader,
		push_constants = push_constants,
		input_topology = input_topology,
		polygon_mode = polygon_mode,
		front_face = front_face,
		depth_write_enabled = depth.write_enabled,
		depth_compare_op = depth.compare_op,
		depth_format = depth.format,
		color_format = color_format,
		cull_mode = cull_mode,
		blend_mode = blend_mode,
		vertex_entry = vertex_entry,
		fragment_entry = fragment_entry,
	}
}

init_gpu_image_create_info :: proc(
	format: vk.Format,
	extent: vk.Extent3D,
	image_usage_flags: vk.ImageUsageFlags,
	mip_levels: u32 = 1,
	array_layers: u32 = 1,
	image_type: vk.ImageType = .D2,
	msaa_samples: vk.SampleCountFlags = {._1},
	tiling: vk.ImageTiling = .OPTIMAL,
	flags: vk.ImageCreateFlags = {},
	alloc_flags: vma.AllocationCreateFlags = {},
	usage: vma.MemoryUsage = .AUTO,
) -> Image_Create_Info {
	return {
		format = format,
		extent = extent,
		image_usage_flags = image_usage_flags,
		mip_levels = mip_levels,
		array_layers = array_layers,
		image_type = image_type,
		msaa_samples = msaa_samples,
		tiling = tiling,
		flags = flags,
		alloc_flags = alloc_flags,
		usage = usage,
	}
}
