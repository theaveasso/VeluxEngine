package gpu

import vk "vendor:vulkan"

cmd_transition_image :: proc(frame: Frame, old_layout, new_layout: vk.ImageLayout) {
	barrier_info: vk.ImageMemoryBarrier2 = {
		sType            = .IMAGE_MEMORY_BARRIER_2,
		image            = frame.image,
		srcStageMask     = {.ALL_COMMANDS},
		srcAccessMask    = {.MEMORY_WRITE},
		dstStageMask     = {.ALL_COMMANDS},
		dstAccessMask    = {.MEMORY_WRITE, .MEMORY_READ},
		oldLayout        = old_layout,
		newLayout        = new_layout,
		subresourceRange = init_image_subresource_range({.COLOR}), // TODO: support depth image
	}

	dependency_info: vk.DependencyInfo = {
		sType                   = .DEPENDENCY_INFO,
		imageMemoryBarrierCount = 1,
		pImageMemoryBarriers    = &barrier_info,
	}

	vk.CmdPipelineBarrier2(frame.cmd, &dependency_info)
}

cmd_begin_rendering :: proc(frame: Frame, clear_color: Maybe([4]f32) = nil) {
	color_attachment: vk.RenderingAttachmentInfo = {
		sType       = .RENDERING_ATTACHMENT_INFO,
		imageView   = frame.view,
		imageLayout = .COLOR_ATTACHMENT_OPTIMAL,
		loadOp      = clear_color != nil ? .CLEAR : .LOAD,
		storeOp     = .STORE,
	}
	if c, ok := clear_color.?; ok do color_attachment.clearValue = {
		color = {float32 = c},
	}

	rendering_info: vk.RenderingInfo = {
		sType = .RENDERING_INFO,
		renderArea = {extent = frame.extent},
		layerCount = 1,
		colorAttachmentCount = 1,
		pColorAttachments = &color_attachment,
	}

	vk.CmdBeginRendering(frame.cmd, &rendering_info)

	viewport: vk.Viewport = {
		width  = cast(f32)frame.extent.width,
		height = cast(f32)frame.extent.height,
	}
	scissor: vk.Rect2D = {
		extent = frame.extent,
	}

	vk.CmdSetViewport(frame.cmd, 0, 1, &viewport)
	vk.CmdSetScissor(frame.cmd, 0, 1, &scissor)
}

cmd_end_rendering :: proc(frame: Frame) {
	vk.CmdEndRendering(frame.cmd)
}

cmd_bind_pipeline :: proc {
	cmd_bind_graphics_pipeline,
}

cmd_bind_graphics_pipeline :: #force_inline proc(frame: Frame, pipeline: GraphicsPipeline) {
	vk.CmdBindPipeline(frame.cmd, .GRAPHICS, pipeline.handle)
}

cmd_push_constants :: #force_inline proc(
	frame: Frame,
	pipeline: GraphicsPipeline,
	data: ^$T,
	loc := #caller_location,
) {
	assert(T == pipeline.push_constants, "push constants type mismatch with pipeline", loc)
	vk.CmdPushConstants(frame.cmd, pipeline.layout, pipeline.stage_flags, 0, size_of(T), data)
}

cmd_bind_index_buffer :: #force_inline proc(
	frame: Frame,
	buffer: vk.Buffer,
	offset: vk.DeviceSize = 0,
	index_type: vk.IndexType = .UINT32,
) {
	vk.CmdBindIndexBuffer(frame.cmd, buffer, offset, index_type)
}

cmd_draw_indexed :: #force_inline proc(
	frame: Frame,
	index_count: u32,
	instance_count: u32 = 1,
	first_index: u32 = 0,
	vertex_offset: i32 = 0,
	first_instance: u32 = 0,
) {
	vk.CmdDrawIndexed(
		frame.cmd,
		index_count,
		instance_count,
		first_index,
		vertex_offset,
		first_instance,
	)
}

cmd_copy_buffer2 :: proc(
	cmd: vk.CommandBuffer,
	src: vk.Buffer,
	dst: vk.Buffer,
	region: ^vk.BufferCopy2,
	count: u32 = 1,
) {
	copy_info: vk.CopyBufferInfo2 = {
		sType       = .COPY_BUFFER_INFO_2,
		srcBuffer   = src,
		dstBuffer   = dst,
		regionCount = count,
		pRegions    = region,
	}
	vk.CmdCopyBuffer2(cmd, &copy_info)
}
