package velux

import vk "vendor:vulkan"

Image_Transition :: struct {
	image:      vk.Image,
	aspect:     vk.ImageAspectFlags,
	old_layout: vk.ImageLayout,
	new_layout: vk.ImageLayout,
}

@(private)
cmd_transition_image :: proc(cmd: vk.CommandBuffer, image: vk.Image, aspect: vk.ImageAspectFlags, old_layout, new_layout: vk.ImageLayout) {
	cmd_transition_images(cmd, {{image, aspect, old_layout, new_layout}})
}

@(private)
cmd_transition_images :: proc(cmd: vk.CommandBuffer, transitions: []Image_Transition, loc := #caller_location) {
	if len(transitions) > MAX_BATCH_TRANSITIONS {
		fatal("%d image transitions in one batch, MAX_BATCH_TRANSITIONS is %d", len(transitions), MAX_BATCH_TRANSITIONS, loc = loc)
	}

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

cmd_begin_rendering :: proc {
	cmd_begin_rendering_swapchain,
	cmd_begin_rendering_target,
}

cmd_end_rendering :: proc {
	cmd_end_rendering_swapchain,
	cmd_end_rendering_target,
}

@(private)
cmd_begin_rendering_views :: proc(
	frame: Frame,
	view: vk.ImageView,
	extent: vk.Extent2D,
	clear_color: Maybe([4]f32) = nil,
	depth_view: vk.ImageView = 0,
) {
	flush_upload_barrier(frame.cmd)

	color_attachment: vk.RenderingAttachmentInfo = {
		sType       = .RENDERING_ATTACHMENT_INFO,
		pNext       = nil,
		imageView   = view,
		imageLayout = .COLOR_ATTACHMENT_OPTIMAL,
		loadOp      = clear_color != nil ? .CLEAR : .LOAD,
		storeOp     = .STORE,
	}

	if c, ok := clear_color.?; ok do color_attachment.clearValue = {
		color = {float32 = c},
	}

	depth_attachment: vk.RenderingAttachmentInfo

	rendering_info: vk.RenderingInfo = {
		sType = .RENDERING_INFO,
		pNext = nil,
		renderArea = {extent = extent},
		layerCount = 1,
		colorAttachmentCount = 1,
		pColorAttachments = &color_attachment,
	}
	if depth_view != 0 {
		depth_attachment = {
			sType = .RENDERING_ATTACHMENT_INFO,
			pNext = nil,
			imageView = depth_view,
			imageLayout = .DEPTH_ATTACHMENT_OPTIMAL,
			loadOp = clear_color != nil ? .CLEAR : .LOAD,
			storeOp = .STORE,
			clearValue = {depthStencil = {depth = 1.0}},
		}
		rendering_info.pDepthAttachment = &depth_attachment
	}

	vk.CmdBeginRendering(frame.cmd, &rendering_info)

	viewport: vk.Viewport = {
		width    = cast(f32)extent.width,
		height   = cast(f32)extent.height,
		maxDepth = 1.0,
	}
	scissor: vk.Rect2D = {
		extent = extent,
	}

	vk.CmdSetViewport(frame.cmd, 0, 1, &viewport)
	vk.CmdSetScissor(frame.cmd, 0, 1, &scissor)
}

cmd_begin_rendering_swapchain :: proc(frame: Frame, clear_color: Maybe([4]f32) = nil, loc := #caller_location) {
	bound_api(loc).gpu.begin_rendering_swapchain(frame, clear_color)
}

cmd_end_rendering_swapchain :: proc(frame: Frame, loc := #caller_location) {
	bound_api(loc).gpu.end_rendering_swapchain(frame)
}

cmd_begin_rendering_target :: proc(
	frame: Frame,
	target: Render_Target,
	clear_color: [4]f32 = {0, 0, 0, 1},
	loc := #caller_location,
) {
	bound_api(loc).gpu.begin_rendering_target(frame, target, clear_color)
}

cmd_end_rendering_target :: proc(frame: Frame, target: Render_Target, loc := #caller_location) {
	bound_api(loc).gpu.end_rendering_target(frame, target)
}

@(private)
host_cmd_begin_rendering_swapchain :: proc(frame: Frame, clear_color: Maybe([4]f32) = nil) {
	cmd_begin_rendering_views(frame, frame.view, frame.extent, clear_color, frame.depth_view)
}

@(private)
host_cmd_end_rendering_swapchain :: proc(frame: Frame) {
	vk.CmdEndRendering(frame.cmd)
}

@(private)
host_cmd_begin_rendering_target :: proc(frame: Frame, target: Render_Target, clear_color: [4]f32 = {0, 0, 0, 1}) {
	cmd_transition_images(
		frame.cmd,
		{
			{target.image.handle, {.COLOR}, .UNDEFINED, .COLOR_ATTACHMENT_OPTIMAL},
			{target.depth.handle, {.DEPTH}, .UNDEFINED, .DEPTH_ATTACHMENT_OPTIMAL},
		},
	)
	cmd_begin_rendering_views(frame, target.image.view, {target.extent[0], target.extent[1]}, clear_color, target.depth.view)
}

@(private)
host_cmd_end_rendering_target :: proc(frame: Frame, target: Render_Target) {
	vk.CmdEndRendering(frame.cmd)
	cmd_transition_image(frame.cmd, target.image.handle, {.COLOR}, .COLOR_ATTACHMENT_OPTIMAL, .SHADER_READ_ONLY_OPTIMAL)
}

cmd_bind_pipeline :: proc {
	cmd_bind_graphics_pipeline,
}

cmd_bind_graphics_pipeline :: proc(frame: Frame, pipeline: GPU_Pipeline, loc := #caller_location) {
	bound_api(loc).gpu.bind_graphics_pipeline(frame, pipeline)
}

cmd_push_constants :: proc(frame: Frame, pipeline: GPU_Pipeline, data: ^$T, loc := #caller_location) {
	bound_api(loc).gpu.push_constants(frame, pipeline, data, size_of(T), loc)
}

cmd_bind_index_buffer :: proc(
	frame: Frame,
	buffer: vk.Buffer,
	offset: vk.DeviceSize = 0,
	index_type: vk.IndexType = .UINT32,
	loc := #caller_location,
) {
	bound_api(loc).gpu.bind_index_buffer(frame, buffer, offset, index_type)
}

cmd_set_viewport :: proc(frame: Frame, offset, size: [2]f32, loc := #caller_location) {
	bound_api(loc).gpu.set_viewport(frame, offset, size)
}

cmd_draw :: proc(
	frame: Frame,
	vertex_count: u32,
	instance_count: u32 = 1,
	first_vertex: u32 = 0,
	first_instance: u32 = 0,
	loc := #caller_location,
) {
	bound_api(loc).gpu.draw(frame, vertex_count, instance_count, first_vertex, first_instance)
}

cmd_draw_indexed :: proc(
	frame: Frame,
	index_count: u32,
	instance_count: u32 = 1,
	first_index: u32 = 0,
	vertex_offset: i32 = 0,
	first_instance: u32 = 0,
	loc := #caller_location,
) {
	bound_api(loc).gpu.draw_indexed(frame, index_count, instance_count, first_index, vertex_offset, first_instance)
}

@(private)
host_cmd_bind_graphics_pipeline :: proc(frame: Frame, pipeline: GPU_Pipeline) {
	vk.CmdBindPipeline(frame.cmd, .GRAPHICS, pipeline.handle)
	bindless_set := frame.bindless_set
	vk.CmdBindDescriptorSets(frame.cmd, .GRAPHICS, pipeline.layout, 0, 1, &bindless_set, 0, nil)
}

@(private)
host_cmd_push_constants :: proc(
	frame: Frame,
	pipeline: GPU_Pipeline,
	data: rawptr,
	size: int,
	loc := #caller_location,
) {
	if size != int(pipeline.info.push_constant_size) {
		fatal("push constant is %d bytes but the pipeline was built for %d", size, pipeline.info.push_constant_size, loc = loc)
	}
	vk.CmdPushConstants(frame.cmd, pipeline.layout, pipeline.stage_flags, 0, pipeline.info.push_constant_size, data)
}

@(private)
host_cmd_bind_index_buffer :: proc(
	frame: Frame,
	buffer: vk.Buffer,
	offset: vk.DeviceSize = 0,
	index_type: vk.IndexType = .UINT32,
) {
	vk.CmdBindIndexBuffer(frame.cmd, buffer, offset, index_type)
}

@(private)
host_cmd_set_viewport :: proc(frame: Frame, offset, size: [2]f32) {
	viewport: vk.Viewport = {
		x        = offset[0],
		y        = offset[1],
		width    = size[0],
		height   = size[1],
		minDepth = 0,
		maxDepth = 1,
	}
	vk.CmdSetViewport(frame.cmd, 0, 1, &viewport)
}

@(private)
host_cmd_draw :: proc(
	frame: Frame,
	vertex_count: u32,
	instance_count: u32 = 1,
	first_vertex: u32 = 0,
	first_instance: u32 = 0,
) {
	vk.CmdDraw(frame.cmd, vertex_count, instance_count, first_vertex, first_instance)
}

@(private)
host_cmd_draw_indexed :: proc(
	frame: Frame,
	index_count: u32,
	instance_count: u32 = 1,
	first_index: u32 = 0,
	vertex_offset: i32 = 0,
	first_instance: u32 = 0,
) {
	vk.CmdDrawIndexed(frame.cmd, index_count, instance_count, first_index, vertex_offset, first_instance)
}

@(private)
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

@(private)
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
