package velux

import vk "vendor:vulkan"

@(private)
create_per_image_semaphores :: proc(device: ^GPU_Device) {
	semaphore_info: vk.SemaphoreCreateInfo = {
		sType = .SEMAPHORE_CREATE_INFO,
	}

	device.render_finished_semaphores = make([]vk.Semaphore, len(device.swapchain.images))
	for &semaphore in device.render_finished_semaphores {
		vk_assert(vk.CreateSemaphore(device.device, &semaphore_info, nil, &semaphore), "vkCreateSemaphore")
	}
}

@(private)
destroy_per_image_semaphores :: proc(device: ^GPU_Device) {
	for semaphore in device.render_finished_semaphores {
		vk.DestroySemaphore(device.device, semaphore, nil)
	}
	delete(device.render_finished_semaphores)
	device.render_finished_semaphores = nil
}

@(private)
create_command_pool :: proc(device: ^GPU_Device) {
	pool_info: vk.CommandPoolCreateInfo = {
		sType            = .COMMAND_POOL_CREATE_INFO,
		flags            = {.RESET_COMMAND_BUFFER},
		queueFamilyIndex = device.graphics_family,
	}

	vk_assert(vk.CreateCommandPool(device.device, &pool_info, nil, &device.command_pool), "vkCreateCommandPool")
}

@(private)
allocate_command_buffers :: proc(device: ^GPU_Device) {
	allocate_info: vk.CommandBufferAllocateInfo = {
		sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
		commandPool        = device.command_pool,
		commandBufferCount = 1,
		level              = .PRIMARY,
	}
	for &frame in device.frames {
		vk_assert(vk.AllocateCommandBuffers(device.device, &allocate_info, &frame.command_buffer), "vkAllocateCommandBuffers")
	}
}

@(private)
create_sync_objects :: proc(device: ^GPU_Device) {
	semaphore_info: vk.SemaphoreCreateInfo = {
		sType = .SEMAPHORE_CREATE_INFO,
	}
	fence_info: vk.FenceCreateInfo = {
		sType = .FENCE_CREATE_INFO,
		flags = {.SIGNALED},
	}

	for &frame in device.frames {
		vk_assert(vk.CreateSemaphore(device.device, &semaphore_info, nil, &frame.present_complete), "vkCreateSemaphore")
		vk_assert(vk.CreateFence(device.device, &fence_info, nil, &frame.in_flight_fence), "vkCreateFence")
	}
}

@(private)
destroy_sync_objects :: proc(device: ^GPU_Device) {
	for &frame in device.frames {
		vk.DestroySemaphore(device.device, frame.present_complete, nil)
		vk.DestroyFence(device.device, frame.in_flight_fence, nil)
	}
}
