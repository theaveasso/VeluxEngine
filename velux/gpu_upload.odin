package velux

import "core:mem"

import vk "vendor:vulkan"

// One persistently mapped, host-visible buffer per frame in flight, filled by
// bumping an offset. No allocation, no submit, no fence wait.
//
// What this replaces: every per-frame upload used to call
// immediate_transfer_begin / write_staging_buffer_slice / immediate_transfer_end,
// which is vmaCreateBuffer, memcpy, vkQueueSubmit2, a blocking
// vkWaitForFences on the GPU, and vmaDestroyBuffer -- per upload, per frame.
// her_body_waits paid that round trip every tick to move 336 bytes.
//
// Safety comes from the frame fence, not from a sync of its own: begin_frame
// has already waited on slot N's in-flight fence before resetting slot N's
// offset, so nothing the GPU is still reading gets overwritten.
Upload_Ring :: struct {
	buffers:  [MAX_FRAMES_IN_FLIGHT]GPU_Buffer(u8),
	used:     [MAX_FRAMES_IN_FLIGHT]vk.DeviceSize,
	capacity: vk.DeviceSize,
	// Set when a copy was recorded this frame, cleared by the barrier that
	// makes it visible. Lets one barrier cover any number of uploads.
	pending:  bool,
}

UPLOAD_RING_BYTES :: 4 * 1024 * 1024
UPLOAD_ALIGNMENT :: 16

@(private)
create_upload_ring :: proc(device: ^GPU_Device) {
	device.upload.capacity = UPLOAD_RING_BYTES
	for &buffer in device.upload.buffers {
		buffer = create_gpu_buffer(u8, UPLOAD_RING_BYTES, .Staging)
	}
}

@(private)
destroy_upload_ring :: proc(device: ^GPU_Device) {
	for &buffer in device.upload.buffers {
		destroy_gpu_buffer(&buffer)
	}
}

// Called by begin_frame once slot N's fence has signalled, which is the proof
// that the GPU is done reading what was written there last time around.
@(private)
reset_upload_slot :: proc(device: ^GPU_Device, slot: u32) {
	device.upload.used[slot] = 0
}

// Records a copy into the frame's command buffer, so it must be called while
// no render pass is open: from `draw`, before cmd_begin_rendering. The data is
// memcpy'd immediately, so the caller's slice does not need to outlive the
// call.
frame_upload_slice :: proc(frame: Frame, dst: ^GPU_Buffer($T), in_data: []$U, dst_offset: vk.DeviceSize = 0, loc := #caller_location) {
	device := &g_engine.gpu

	size := cast(vk.DeviceSize)(size_of(U) * len(in_data))
	if len(in_data) == 0 do return
	check_buffer_bounds(dst.info, size, dst_offset, loc)

	src_offset := suballocate_upload(device, frame.frame_index, size, loc)

	mapped := cast([^]u8)device.upload.buffers[frame.frame_index].info.pMappedData
	mem.copy(mapped[src_offset:], raw_data(in_data), int(size))

	region := init_buffer_copy2(size, dst_offset, src_offset)
	cmd_copy_buffer2(frame.cmd, device.upload.buffers[frame.frame_index].handle, dst.handle, &region)
	device.upload.pending = true
}

frame_upload :: proc(frame: Frame, dst: ^GPU_Buffer($T), in_data: ^$U, dst_offset: vk.DeviceSize = 0, loc := #caller_location) {
	frame_upload_slice(frame, dst, (cast([^]U)in_data)[:1], dst_offset, loc)
}

@(private)
suballocate_upload :: proc(
	device: ^GPU_Device,
	slot: u32,
	size: vk.DeviceSize,
	loc := #caller_location,
) -> (
	offset: vk.DeviceSize,
) {
	offset = cast(vk.DeviceSize)mem.align_forward_uint(uint(device.upload.used[slot]), UPLOAD_ALIGNMENT)
	if offset + size > device.upload.capacity {
		fatal(
			"upload ring exhausted: %v bytes requested at offset %v, capacity is %v. Raise UPLOAD_RING_BYTES or upload less per frame.",
			size,
			offset,
			device.upload.capacity,
			loc = loc,
		)
	}
	device.upload.used[slot] = offset + size
	return offset
}

// One barrier covering every copy recorded this frame, emitted at the point
// the frame stops uploading and starts drawing.
@(private)
flush_upload_barrier :: proc(cmd: vk.CommandBuffer) {
	device := &g_engine.gpu
	if !device.upload.pending do return
	device.upload.pending = false

	barrier: vk.MemoryBarrier2 = {
		sType         = .MEMORY_BARRIER_2,
		srcStageMask  = {.COPY},
		srcAccessMask = {.TRANSFER_WRITE},
		dstStageMask  = {.VERTEX_SHADER, .FRAGMENT_SHADER},
		dstAccessMask = {.SHADER_READ},
	}
	dependency: vk.DependencyInfo = {
		sType              = .DEPENDENCY_INFO,
		memoryBarrierCount = 1,
		pMemoryBarriers    = &barrier,
	}
	vk.CmdPipelineBarrier2(cmd, &dependency)
}
