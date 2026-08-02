package velux

import "base:runtime"
import "core:dynlib"
import "core:fmt"
import "core:log"
import "core:reflect"
import "core:strings"

import vma "third_party:odin-vma"
import glfw "vendor:glfw"
import vk "vendor:vulkan"


@(private, require_results)
create_per_image_semaphores :: proc(device: ^GPU_Device) -> (err: GPU_Error = .None) {
	defer if err != .None do destroy_per_image_semaphores(device)

	semaphore_info: vk.SemaphoreCreateInfo = {
		sType = .SEMAPHORE_CREATE_INFO,
	}

	device.render_finished_semaphores = make([]vk.Semaphore, len(device.swapchain.images))
	for &semaphore in device.render_finished_semaphores {
		vk_check(vk.CreateSemaphore(device.device, &semaphore_info, nil, &semaphore), .Vulkan_Call_Failed) or_return
	}
	return
}

@(private)
destroy_per_image_semaphores :: proc(device: ^GPU_Device) {
	for semaphore in device.render_finished_semaphores {
		vk.DestroySemaphore(device.device, semaphore, nil)
	}
	delete(device.render_finished_semaphores)
	device.render_finished_semaphores = nil
}

@(private, require_results)
create_command_pool :: proc(device: ^GPU_Device) -> (err: GPU_Error = .None) {
	pool_info: vk.CommandPoolCreateInfo = {
		sType            = .COMMAND_POOL_CREATE_INFO,
		flags            = {.RESET_COMMAND_BUFFER},
		queueFamilyIndex = device.graphics_family,
	}

	vk_check(vk.CreateCommandPool(device.device, &pool_info, nil, &device.command_pool), .Vulkan_Call_Failed) or_return

	return
}

@(private, require_results)
allocate_command_buffers :: proc(device: ^GPU_Device) -> (err: GPU_Error = .None) {
	allocate_info: vk.CommandBufferAllocateInfo = {
		sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
		pNext              = nil,
		commandPool        = device.command_pool,
		commandBufferCount = 1,
		level              = .PRIMARY,
	}
	for &frame in device.frames {
		vk_check(
			vk.AllocateCommandBuffers(device.device, &allocate_info, &frame.command_buffer),
			.Command_Buffer_Allocation_Failed,
		) or_return

	}
	return
}

@(private, require_results)
create_sync_objects :: proc(device: ^GPU_Device) -> (err: GPU_Error = .None) {
	defer if err != .None do destroy_sync_objects(device)

	semaphore_info: vk.SemaphoreCreateInfo = {
		sType = .SEMAPHORE_CREATE_INFO,
	}

	for &frame in device.frames {
		vk_check(vk.CreateSemaphore(device.device, &semaphore_info, nil, &frame.present_complete), .Vulkan_Call_Failed) or_return

		fence_info: vk.FenceCreateInfo = {
			sType = .FENCE_CREATE_INFO,
			flags = {.SIGNALED},
		}
		vk_check(vk.CreateFence(device.device, &fence_info, nil, &frame.in_flight_fence), .Vulkan_Call_Failed) or_return
	}

	return
}

@(private)
destroy_sync_objects :: proc(device: ^GPU_Device) {
	for &frame in device.frames {
		vk.DestroySemaphore(device.device, frame.present_complete, nil)
		vk.DestroyFence(device.device, frame.in_flight_fence, nil)
	}
}

