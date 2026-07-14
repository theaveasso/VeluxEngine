package gpu

import vk "vendor:vulkan"

Frame :: struct {
	cmd:               vk.CommandBuffer,
	in_flight_fence:   vk.Fence,
	render_finished:   vk.Semaphore,
	present_completed: vk.Semaphore,
	image:             vk.Image,
	view:              vk.ImageView,
	depth_view:        vk.ImageView,
	extent:            vk.Extent2D,
	bindless_set:      vk.DescriptorSet,
	image_index:       u32,
	frame_index:       u32,
}

@(require_results)
begin_frame :: proc(device: ^Device) -> (frame: Frame, err: Error) {
	context.logger = device.logger

	frame_data := device.frames[device.current_frame]
	vk_check(vk.WaitForFences(device.device, 1, &frame_data.in_flight_fence, true, max(u64))) or_return

	image_index: u32 = max(u32)
	acquire_result := vk.AcquireNextImageKHR(
		device.device,
		device.swapchain.handle,
		max(u64),
		frame_data.present_complete,
		0,
		&image_index,
	)

	#partial switch acquire_result {
	case .SUCCESS, .SUBOPTIMAL_KHR:
	case .ERROR_OUT_OF_DATE_KHR:
		recreate_swapchain(device) or_return
		return {}, .Swapchain_Recreate
	case:
		return {}, .Vulkan_Call_Failed
	}

	vk_check(vk.ResetFences(device.device, 1, &frame_data.in_flight_fence)) or_return
	vk_check(vk.ResetCommandBuffer(frame_data.command_buffer, {.RELEASE_RESOURCES})) or_return

	begin_info: vk.CommandBufferBeginInfo = init_command_buffer_begin_info({.ONE_TIME_SUBMIT})
	vk_check(vk.BeginCommandBuffer(frame_data.command_buffer, &begin_info)) or_return

	cmd_transition_images(
		frame_data.command_buffer,
		{
			{device.swapchain.images[image_index], {.COLOR}, .UNDEFINED, .COLOR_ATTACHMENT_OPTIMAL},
			{device.depth_image.handle, {.DEPTH}, .UNDEFINED, .DEPTH_ATTACHMENT_OPTIMAL},
		},
	)

	return {
			frame_data.command_buffer,
			frame_data.in_flight_fence,
			device.render_finished_semaphores[image_index],
			frame_data.present_complete,
			device.swapchain.images[image_index],
			device.swapchain.views[image_index],
			device.depth_image.view,
			device.swapchain.extent,
			device.bindless.set,
			image_index,
			device.current_frame,
		},
		.None
}

@(require_results)
end_frame :: proc(device: ^Device, frame: Frame) -> (err: Error = .None) {
	context.logger = device.logger
	frame := frame

	cmd_transition_image(frame.cmd, frame.image, {.COLOR}, .COLOR_ATTACHMENT_OPTIMAL, .PRESENT_SRC_KHR)

	vk_check(vk.EndCommandBuffer(frame.cmd), .Vulkan_Call_Failed) or_return

	wait_info := init_semaphore_submit_info(frame.present_completed, {.COLOR_ATTACHMENT_OUTPUT})
	cmd_info := init_command_buffer_submit_info(frame.cmd)
	signal_info := init_semaphore_submit_info(frame.render_finished, {.ALL_GRAPHICS})
	submit_info := init_submit_info(&wait_info, &cmd_info, &signal_info)

	vk_check(vk.QueueSubmit2(device.graphics_queue, 1, &submit_info, frame.in_flight_fence), .Vulkan_Call_Failed) or_return

	present_info := init_present_info(&frame.render_finished, &device.swapchain.handle, &frame.image_index)

	present_result := vk.QueuePresentKHR(device.graphics_queue, &present_info)
	#partial switch present_result {
	case .SUCCESS:
	case .ERROR_OUT_OF_DATE_KHR, .SUBOPTIMAL_KHR:
		recreate_swapchain(device) or_return
	case:
		return .Vulkan_Call_Failed
	}

	device.current_frame = (device.current_frame + 1) % MAX_FRAMES_IN_FLIGHT
	return
}
