package gpu

import "core:mem"

import vma "third_party:odin-vma"
import vk "vendor:vulkan"

DeviceAddress :: struct($T: typeid) {
	address: vk.DeviceAddress,
}

Buffer :: struct($T: typeid) {
	handle:     vk.Buffer,
	allocation: vma.Allocation,
	info:       vma.AllocationInfo,
	ptr:        DeviceAddress(T),
}

BufferKind :: enum {
	Storage,
	Index,
	Staging,
}

@(require_results)
create_buffer :: proc(
	device: ^Device,
	$T: typeid,
	#any_int size: vk.DeviceSize = 1,
	kind: BufferKind,
) -> (
	buffer: Buffer(T),
	err: Error,
) {
	context.logger = device.logger

	alloc_size := cast(vk.DeviceSize)(size_of(T) * size)
	vk_usage_flags, vma_create_flags := vk_vma_buffer_flags(kind)

	buffer_info: vk.BufferCreateInfo = {
		sType = .BUFFER_CREATE_INFO,
		size  = alloc_size,
		usage = vk_usage_flags,
	}

	allocation_info: vma.AllocationCreateInfo = {
		usage = .AUTO,
		flags = vma_create_flags,
	}

	vk_check(
		vma.CreateBuffer(
			device.vma_allocator,
			&buffer_info,
			&allocation_info,
			&buffer.handle,
			&buffer.allocation,
			&buffer.info,
		),
		.VMA_Call_Failed,
	) or_return

	if .SHADER_DEVICE_ADDRESS in vk_usage_flags {
		buffer.ptr.address = get_buffer_device_address(device.device, buffer)
	}

	return buffer, .None
}

destroy_buffer :: proc(device: ^Device, buffer: ^Buffer($T)) {
	vma.DestroyBuffer(device.vma_allocator, buffer.handle, buffer.allocation)
	buffer^ = {}
}

get_buffer_device_address :: proc(device: vk.Device, buffer: Buffer($T)) -> vk.DeviceAddress {
	device_address_info: vk.BufferDeviceAddressInfo = {
		sType  = .BUFFER_DEVICE_ADDRESS_INFO,
		buffer = buffer.handle,
	}
	return vk.GetBufferDeviceAddress(device, &device_address_info)
}

vk_vma_buffer_flags :: proc(kind: BufferKind) -> (vk.BufferUsageFlags, vma.AllocationCreateFlags) {
	switch kind {
	case .Storage:
		return {.TRANSFER_DST, .STORAGE_BUFFER, .SHADER_DEVICE_ADDRESS}, {}
	case .Index:
		return {.TRANSFER_DST, .INDEX_BUFFER, .SHADER_DEVICE_ADDRESS}, {}
	case .Staging:
		return {.TRANSFER_SRC}, {.MAPPED, .HOST_ACCESS_SEQUENTIAL_WRITE}
	}
	unreachable()
}

write_buffer :: proc(
	buffer: ^Buffer($T),
	in_data: ^$U,
	offset: vk.DeviceSize = 0,
	loc := #caller_location,
) {
	size := size_of(U)
	assert(
		buffer.info.size >= cast(vk.DeviceSize)(cast(u64)size + cast(u64)offset),
		"The size of the data and offset is larger than the buffer",
		loc,
	)

	data := cast([^]u8)buffer.info.pMappedData
	assert(data != nil, "buffer is not mapped.", loc)
	mem.copy(data[offset:], in_data, size)
}

write_buffer_slice :: proc(
	buffer: ^Buffer($T),
	in_data: []$U,
	offset: vk.DeviceSize = 0,
	loc := #caller_location,
) {
	size := size_of(U) * len(in_data)
	assert(
		buffer.info.size >= cast(vk.DeviceSize)(cast(u64)size + cast(u64)offset),
		"The size of the data and offset is larger than the buffer",
		loc,
	)

	data := cast([^]u8)buffer.info.pMappedData
	assert(data != nil, "buffer is not mapped.", loc)
	assert(raw_data(in_data) != nil)

	mem.copy(data[offset:], raw_data(in_data), size)
}

@(require_results)
staging_write_buffer :: proc(
	device: ^Device,
	cmd: vk.CommandBuffer,
	buffer: ^Buffer($T),
	in_data: ^$U,
	offset: vk.DeviceSize = 0,
	loc := #caller_location,
) -> (
	err: Error,
) {
	context.logger = device.logger

	size := size_of(U)
	assert(
		buffer.info.size >= cast(vk.DeviceSize)(cast(u64)size + cast(u64)offset),
		"The size of the data and offset is larger than the buffer",
		loc,
	)

	staging := create_buffer(device, u8, cast(vk.DeviceSize)size, .Staging) or_return
	write_buffer(&staging, in_data)
	append(&device.imm_transfer_ctx.staging_buffers, staging)

	region := init_buffer_copy2(cast(vk.DeviceSize)size, offset)
	cmd_copy_buffer2(cmd, staging.handle, buffer.handle, &region)

	return .None
}

@(require_results)
staging_write_buffer_slice :: proc(
	device: ^Device,
	cmd: vk.CommandBuffer,
	buffer: ^Buffer($T),
	in_data: []$U,
	offset: vk.DeviceSize = 0,
	loc := #caller_location,
) -> (
	err: Error,
) {
	context.logger = device.logger

	size := size_of(U) * len(in_data)
	assert(
		buffer.info.size >= cast(vk.DeviceSize)(cast(u64)size + cast(u64)offset),
		"The size of the data and offset is larger than the buffer",
		loc,
	)

	staging := create_buffer(device, u8, cast(vk.DeviceSize)size, .Staging) or_return
	write_buffer_slice(&staging, in_data)
	append(&device.imm_transfer_ctx.staging_buffers, staging)

	region := init_buffer_copy2(cast(vk.DeviceSize)size, offset)
	cmd_copy_buffer2(cmd, staging.handle, buffer.handle, &region)

	return .None
}
