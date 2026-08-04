package velux

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

@(private)
begin_frame :: proc() -> (frame: Frame, err: Error) {
	device := &g_engine.gpu
	context.logger = device.logger

	frame_data := device.frames[device.current_frame]
	vk_assert(vk.WaitForFences(device.device, 1, &frame_data.in_flight_fence, true, max(u64)), "vkWaitForFences")

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
		recreate_swapchain(device)
		return {}, .Swapchain_Out_Of_Date
	case:
		fatal("vkAcquireNextImageKHR failed: %v", acquire_result)
	}

	// The fence above proves the GPU is done with this slot's upload ring.
	reset_upload_slot(device, device.current_frame)

	vk_assert(vk.ResetFences(device.device, 1, &frame_data.in_flight_fence), "vkResetFences")
	vk_assert(vk.ResetCommandBuffer(frame_data.command_buffer, {.RELEASE_RESOURCES}), "vkResetCommandBuffer")

	begin_info: vk.CommandBufferBeginInfo = init_command_buffer_begin_info({.ONE_TIME_SUBMIT})
	vk_assert(vk.BeginCommandBuffer(frame_data.command_buffer, &begin_info), "vkBeginCommandBuffer")

	readback_profiler(device, device.current_frame)
	reset_profiler(device, frame_data.command_buffer, device.current_frame)

	cmd_transition_images(
		frame_data.command_buffer,
		{
			{device.swapchain.images[image_index], {.COLOR}, .UNDEFINED, .COLOR_ATTACHMENT_OPTIMAL},
			{device.depth_image.handle, {.DEPTH}, .UNDEFINED, .DEPTH_ATTACHMENT_OPTIMAL},
		},
	)

	return {
			cmd = frame_data.command_buffer,
			in_flight_fence = frame_data.in_flight_fence,
			render_finished = device.render_finished_semaphores[image_index],
			present_completed = frame_data.present_complete,
			image = device.swapchain.images[image_index],
			view = device.swapchain.views[image_index],
			depth_view = device.depth_image.view,
			extent = device.swapchain.extent,
			bindless_set = device.bindless.set,
			image_index = image_index,
			frame_index = device.current_frame,
		},
		.None
}

@(private)
end_frame :: proc(frame: Frame) {
	device := &g_engine.gpu
	context.logger = device.logger
	frame := frame

	cmd_transition_image(frame.cmd, frame.image, {.COLOR}, .COLOR_ATTACHMENT_OPTIMAL, .PRESENT_SRC_KHR)

	vk_assert(vk.EndCommandBuffer(frame.cmd), "vkEndCommandBuffer")

	wait_info := init_semaphore_submit_info(frame.present_completed, {.COLOR_ATTACHMENT_OUTPUT})
	cmd_info := init_command_buffer_submit_info(frame.cmd)
	signal_info := init_semaphore_submit_info(frame.render_finished, {.ALL_GRAPHICS})
	submit_info := init_submit_info(&wait_info, &cmd_info, &signal_info)

	vk_assert(vk.QueueSubmit2(device.graphics_queue, 1, &submit_info, frame.in_flight_fence), "vkQueueSubmit2")

	present_info := init_present_info(&frame.render_finished, &device.swapchain.handle, &frame.image_index)

	present_result := vk.QueuePresentKHR(device.graphics_queue, &present_info)
	#partial switch present_result {
	case .SUCCESS:
	case .ERROR_OUT_OF_DATE_KHR, .SUBOPTIMAL_KHR:
		recreate_swapchain(device)
	case:
		fatal("vkQueuePresentKHR failed: %v", present_result)
	}

	device.current_frame = (device.current_frame + 1) % MAX_FRAMES_IN_FLIGHT
}
