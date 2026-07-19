package gpu

import vk "vendor:vulkan"

Image_Transition :: struct {
	image:      vk.Image,
	aspect:     vk.ImageAspectFlags,
	old_layout: vk.ImageLayout,
	new_layout: vk.ImageLayout,
}

cmd_transition_image :: proc(cmd: vk.CommandBuffer, image: vk.Image, aspect: vk.ImageAspectFlags, old_layout, new_layout: vk.ImageLayout) {
	cmd_transition_images(cmd, {{image, aspect, old_layout, new_layout}})
}

cmd_transition_images :: proc(cmd: vk.CommandBuffer, transitions: []Image_Transition, loc := #caller_location) {
	assert(len(transitions) < MAX_BATCH_TRANSITIONS, "transition batch too large", loc)

	barriers: [MAX_BATCH_TRANSITIONS]vk.ImageMemoryBarrier2
	for t, i in transitions {
		barriers[i] = {
			sType            = .IMAGE_MEMORY_BARRIER_2,
			pNext            = nil,
			image            = t.image,
			srcStageMask     = {.ALL_COMMANDS},
			srcAccessMask    = {.MEMORY_WRITE},
			dstStageMask     = {.ALL_COMMANDS},
			dstAccessMask    = {.MEMORY_WRITE, .MEMORY_READ},
			oldLayout        = t.old_layout,
			newLayout        = t.new_layout,
			subresourceRange = init_image_subresource_range(t.aspect),
		}
	}

	dependency_info: vk.DependencyInfo = {
		sType                   = .DEPENDENCY_INFO,
		pNext                   = nil,
		imageMemoryBarrierCount = cast(u32)len(transitions),
		pImageMemoryBarriers    = raw_data(barriers[:]),
	}

	vk.CmdPipelineBarrier2(cmd, &dependency_info)
}

cmd_begin_rendering :: proc(frame: Frame, clear_color: Maybe([4]f32) = nil) {
	color_attachment: vk.RenderingAttachmentInfo = {
		sType       = .RENDERING_ATTACHMENT_INFO,
		pNext       = nil,
		imageView   = frame.view,
		imageLayout = .COLOR_ATTACHMENT_OPTIMAL,
		loadOp      = clear_color != nil ? .CLEAR : .LOAD,
		storeOp     = .STORE,
	}
	if c, ok := clear_color.?; ok do color_attachment.clearValue = {
		color = {float32 = c},
	}

	depth_attachment: vk.RenderingAttachmentInfo = {
		sType = .RENDERING_ATTACHMENT_INFO,
		pNext = nil,
		imageView = frame.depth_view,
		imageLayout = .DEPTH_ATTACHMENT_OPTIMAL,
		loadOp = .CLEAR,
		storeOp = .DONT_CARE,
		clearValue = {depthStencil = {depth = 1.0}},
	}

	rendering_info: vk.RenderingInfo = {
		sType = .RENDERING_INFO,
		pNext = nil,
		renderArea = {extent = frame.extent},
		layerCount = 1,
		colorAttachmentCount = 1,
		pColorAttachments = &color_attachment,
		pDepthAttachment = &depth_attachment,
	}

	vk.CmdBeginRendering(frame.cmd, &rendering_info)

	viewport: vk.Viewport = {
		width    = cast(f32)frame.extent.width,
		height   = cast(f32)frame.extent.height,
		maxDepth = 1.0,
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

cmd_bind_graphics_pipeline :: proc(frame: Frame, pipeline: Graphics_Pipeline) {
	vk.CmdBindPipeline(frame.cmd, .GRAPHICS, pipeline.handle)
	bindless_set := frame.bindless_set
	vk.CmdBindDescriptorSets(frame.cmd, .GRAPHICS, pipeline.layout, 0, 1, &bindless_set, 0, nil)
}

cmd_push_constants :: proc(frame: Frame, pipeline: Graphics_Pipeline, data: ^$T, loc := #caller_location) {
	assert(T == pipeline.push_constants, "push constants type mismatch with pipeline", loc)
	vk.CmdPushConstants(frame.cmd, pipeline.layout, pipeline.stage_flags, 0, size_of(T), data)
}

cmd_bind_index_buffer :: proc(frame: Frame, buffer: vk.Buffer, offset: vk.DeviceSize = 0, index_type: vk.IndexType = .UINT32) {
	vk.CmdBindIndexBuffer(frame.cmd, buffer, offset, index_type)
}

cmd_draw :: proc(frame: Frame, vertex_count: u32, instance_count: u32 = 1, first_vertex: u32 = 0, first_instance: u32 = 0) {
	vk.CmdDraw(frame.cmd, vertex_count, instance_count, first_vertex, first_instance)
}

cmd_draw_indexed :: proc(
	frame: Frame,
	index_count: u32,
	instance_count: u32 = 1,
	first_index: u32 = 0,
	vertex_offset: i32 = 0,
	first_instance: u32 = 0,
) {
	vk.CmdDrawIndexed(frame.cmd, index_count, instance_count, first_index, vertex_offset, first_instance)
}

cmd_copy_buffer2 :: proc(cmd: vk.CommandBuffer, src: vk.Buffer, dst: vk.Buffer, region: ^vk.BufferCopy2, count: u32 = 1) {
	copy_info: vk.CopyBufferInfo2 = {
		sType       = .COPY_BUFFER_INFO_2,
		pNext       = nil,
		srcBuffer   = src,
		dstBuffer   = dst,
		regionCount = count,
		pRegions    = region,
	}
	vk.CmdCopyBuffer2(cmd, &copy_info)
}

cmd_copy_buffer_to_image2 :: proc(
	cmd: vk.CommandBuffer,
	src: vk.Buffer,
	dst: vk.Image,
	dst_image_layout: vk.ImageLayout,
	region: ^vk.BufferImageCopy2,
	count: u32 = 1,
) {
	copy_info: vk.CopyBufferToImageInfo2 = {
		sType          = .COPY_BUFFER_TO_IMAGE_INFO_2,
		pNext          = nil,
		srcBuffer      = src,
		dstImage       = dst,
		dstImageLayout = dst_image_layout,
		regionCount    = count,
		pRegions       = region,
	}
	vk.CmdCopyBufferToImage2(cmd, &copy_info)
}
