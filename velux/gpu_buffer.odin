package velux

import "base:runtime"
import "core:mem"

import vma "third_party:odin-vma"
import vk "vendor:vulkan"

GPU_Address :: struct($T: typeid) {
	address: vk.DeviceAddress,
}

GPU_Buffer :: struct($T: typeid) {
	handle:     vk.Buffer,
	allocation: vma.Allocation,
	info:       vma.AllocationInfo,
	ptr:        GPU_Address(T),
}

GPU_Buffer_Kind :: enum {
	Storage,
	Index,
	Staging,
	Dynamic,
}

@(require_results)
create_gpu_buffer :: proc($T: typeid, #any_int size: vk.DeviceSize = 1, kind: GPU_Buffer_Kind = .Storage, loc := #caller_location) -> (buffer: GPU_Buffer(T)) {
	device := &g_engine.gpu
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

	if result := vma.CreateBuffer(device.vma_allocator, &buffer_info, &allocation_info, &buffer.handle, &buffer.allocation, &buffer.info); result != .SUCCESS {
		fatal("vmaCreateBuffer failed: %v (%v bytes, %v)", result, alloc_size, kind, loc = loc)
	}

	if .SHADER_DEVICE_ADDRESS in vk_usage_flags {
		buffer.ptr.address = get_buffer_device_address(device.device, buffer)
	}

	return buffer
}

destroy_gpu_buffer :: proc(buffer: ^GPU_Buffer($T)) {
	device := &g_engine.gpu
	vma.DestroyBuffer(device.vma_allocator, buffer.handle, buffer.allocation)
	buffer^ = {}
}

@(private)
get_buffer_device_address :: proc(device: vk.Device, buffer: GPU_Buffer($T)) -> vk.DeviceAddress {
	device_address_info: vk.BufferDeviceAddressInfo = {
		sType  = .BUFFER_DEVICE_ADDRESS_INFO,
		buffer = buffer.handle,
	}
	return vk.GetBufferDeviceAddress(device, &device_address_info)
}

@(private)
vk_vma_buffer_flags :: proc(kind: GPU_Buffer_Kind) -> (vk.BufferUsageFlags, vma.AllocationCreateFlags) {
	switch kind {
	case .Storage:
		return {.TRANSFER_DST, .STORAGE_BUFFER, .SHADER_DEVICE_ADDRESS}, {}
	case .Index:
		return {.TRANSFER_DST, .INDEX_BUFFER, .SHADER_DEVICE_ADDRESS}, {}
	case .Staging:
		return {.TRANSFER_SRC}, {.MAPPED, .HOST_ACCESS_SEQUENTIAL_WRITE}

	case .Dynamic:
		return {.STORAGE_BUFFER, .SHADER_DEVICE_ADDRESS}, {.MAPPED, .HOST_ACCESS_SEQUENTIAL_WRITE}
	}
	unreachable()
}

// Overrunning corrupts whatever VMA put next to it, which surfaces as a wrong
// pixel somewhere else entirely. Die here instead.
@(private)
check_buffer_bounds :: proc(info: vma.AllocationInfo, size, offset: vk.DeviceSize, loc: runtime.Source_Code_Location) {
	if info.size < size + offset {
		fatal("buffer write of %v bytes at offset %v overruns a %v byte buffer", size, offset, info.size, loc = loc)
	}
}

@(private)
check_buffer_mapped :: proc(info: vma.AllocationInfo, size, offset: vk.DeviceSize, loc: runtime.Source_Code_Location) {
	check_buffer_bounds(info, size, offset, loc)
	if info.pMappedData == nil {
		fatal("write to an unmapped buffer; only .Staging buffers carry a host mapping", loc = loc)
	}
}

write_buffer :: proc(buffer: ^GPU_Buffer($T), in_data: ^$U, offset: vk.DeviceSize = 0, loc := #caller_location) {
	size := cast(vk.DeviceSize)size_of(U)
	check_buffer_mapped(buffer.info, size, offset, loc)

	data := cast([^]u8)buffer.info.pMappedData
	mem.copy(data[offset:], in_data, int(size))
}

write_buffer_slice :: proc(buffer: ^GPU_Buffer($T), in_data: []$U, offset: vk.DeviceSize = 0, loc := #caller_location) {
	size := cast(vk.DeviceSize)(size_of(U) * len(in_data))
	check_buffer_mapped(buffer.info, size, offset, loc)
	if len(in_data) == 0 do return

	data := cast([^]u8)buffer.info.pMappedData
	mem.copy(data[offset:], raw_data(in_data), int(size))
}

upload :: proc {
	upload_ptr,
	upload_slice,
}

// Load-time only: allocates a throwaway staging buffer for
// upload_end to reap. Per frame, use frame_upload_slice.
upload_ptr :: proc(cmd: vk.CommandBuffer, buffer: ^GPU_Buffer($T), in_data: ^$U, offset: vk.DeviceSize = 0, loc := #caller_location) {
	device := &g_engine.gpu
	context.logger = device.logger

	size := cast(vk.DeviceSize)size_of(U)
	check_buffer_bounds(buffer.info, size, offset, loc)

	staging := create_gpu_buffer(u8, size, .Staging, loc)
	write_buffer(&staging, in_data, 0, loc)
	append(&device.transfer.staging_buffers, staging)

	region := init_buffer_copy2(size, offset)
	cmd_copy_buffer2(cmd, staging.handle, buffer.handle, &region)
}

upload_slice :: proc(cmd: vk.CommandBuffer, buffer: ^GPU_Buffer($T), in_data: []$U, offset: vk.DeviceSize = 0, loc := #caller_location) {
	device := &g_engine.gpu
	context.logger = device.logger

	size := cast(vk.DeviceSize)(size_of(U) * len(in_data))
	check_buffer_bounds(buffer.info, size, offset, loc)
	if len(in_data) == 0 do return

	staging := create_gpu_buffer(u8, size, .Staging, loc)
	write_buffer_slice(&staging, in_data, 0, loc)
	append(&device.transfer.staging_buffers, staging)

	region := init_buffer_copy2(size, offset)
	cmd_copy_buffer2(cmd, staging.handle, buffer.handle, &region)
}
