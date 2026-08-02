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
create_swapchain :: proc(device: ^GPU_Device) -> (err: GPU_Error = .None) {
	defer if err != .None do destroy_swapchain_resources(device)

	capabilities: vk.SurfaceCapabilitiesKHR
	vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(device.physical_device, device.surface, &capabilities)

	format_n: u32 = 0
	vk.GetPhysicalDeviceSurfaceFormatsKHR(device.physical_device, device.surface, &format_n, nil)

	formats := make([]vk.SurfaceFormatKHR, format_n)
	defer delete(formats)
	vk.GetPhysicalDeviceSurfaceFormatsKHR(device.physical_device, device.surface, &format_n, raw_data(formats))

	present_mode_n: u32 = 0
	vk.GetPhysicalDeviceSurfacePresentModesKHR(device.physical_device, device.surface, &present_mode_n, nil)

	present_modes := make([]vk.PresentModeKHR, present_mode_n)
	defer delete(present_modes)
	vk.GetPhysicalDeviceSurfacePresentModesKHR(device.physical_device, device.surface, &present_mode_n, raw_data(present_modes))

	surface_format := choose_swapchain_surface_format(&formats)
	present_mode := choose_swapchain_present_mode(&present_modes)
	extent := choose_swapchain_extent(device.window, &capabilities)

	image_count := capabilities.minImageCount + 1
	if capabilities.maxImageCount > 0 && image_count > capabilities.maxImageCount {
		image_count = capabilities.maxImageCount
	}

	swapchain_info: vk.SwapchainCreateInfoKHR = {
		sType                 = .SWAPCHAIN_CREATE_INFO_KHR,
		surface               = device.surface,
		minImageCount         = image_count,
		imageFormat           = surface_format.format,
		imageColorSpace       = surface_format.colorSpace,
		imageExtent           = extent,
		imageArrayLayers      = 1,
		imageUsage            = {.COLOR_ATTACHMENT},
		imageSharingMode      = .EXCLUSIVE,
		queueFamilyIndexCount = 0,
		pQueueFamilyIndices   = nil,
		preTransform          = capabilities.currentTransform,
		compositeAlpha        = {.OPAQUE},
		presentMode           = present_mode,
		clipped               = true,
	}

	vk_check(vk.CreateSwapchainKHR(device.device, &swapchain_info, nil, &device.swapchain.handle), .Vulkan_Call_Failed) or_return

	vk.GetSwapchainImagesKHR(device.device, device.swapchain.handle, &image_count, nil)

	device.swapchain.images = make([]vk.Image, image_count)
	vk.GetSwapchainImagesKHR(device.device, device.swapchain.handle, &image_count, raw_data(device.swapchain.images))

	device.swapchain.surface_format = surface_format
	device.swapchain.extent = extent

	device.swapchain.views = make([]vk.ImageView, len(device.swapchain.images))
	for image, i in device.swapchain.images {
		view_info: vk.ImageViewCreateInfo = {
			sType = .IMAGE_VIEW_CREATE_INFO,
			image = image,
			viewType = .D2,
			format = device.swapchain.surface_format.format,
			components = {r = .IDENTITY, g = .IDENTITY, b = .IDENTITY, a = .IDENTITY},
			subresourceRange = init_image_subresource_range({.COLOR}),
		}

		vk_check(vk.CreateImageView(device.device, &view_info, nil, &device.swapchain.views[i]), .Vulkan_Call_Failed) or_return
	}

	return
}

@(private, require_results)
create_depth_resources :: proc(device: ^GPU_Device) -> (err: GPU_Error = .None) {
	device.depth_image = create_image(
		image_create_info(
			DEFAULT_DEPTH_FORMAT,
			{device.swapchain.extent.width, device.swapchain.extent.height, 1},
			{.DEPTH_STENCIL_ATTACHMENT},
		),
	) or_return
	return
}

@(private)
destroy_depth_resources :: proc(device: ^GPU_Device) {
	destroy_texture(&device.depth_image)
}

@(private, require_results)
recreate_swapchain :: proc(device: ^GPU_Device) -> (err: GPU_Error = .None) {
	width, height := glfw.GetFramebufferSize(device.window)
	for width == 0 || height == 0 {
		glfw.WaitEvents()
		width, height = glfw.GetFramebufferSize(device.window)
	}

	vk.DeviceWaitIdle(device.device)

	destroy_depth_resources(device)
	destroy_per_image_semaphores(device)
	destroy_swapchain_resources(device)

	create_swapchain(device) or_return
	create_depth_resources(device) or_return
	create_per_image_semaphores(device) or_return
	return
}

destroy_swapchain_resources :: proc(device: ^GPU_Device) {
	for view in device.swapchain.views {
		vk.DestroyImageView(device.device, view, nil)
	}
	delete(device.swapchain.views)
	delete(device.swapchain.images)
	vk.DestroySwapchainKHR(device.device, device.swapchain.handle, nil)
	device.swapchain = {}

}

choose_swapchain_surface_format :: proc(formats: ^[]vk.SurfaceFormatKHR, loc := #caller_location) -> vk.SurfaceFormatKHR {
	surface_format := formats[0]
	for format in formats {
		if format.format == .B8G8R8A8_SRGB && format.colorSpace == .SRGB_NONLINEAR {
			surface_format = format
			break
		}
	}
	fmt.assertf(
		surface_format.format == .B8G8R8A8_SRGB || surface_format.colorSpace == .SRGB_NONLINEAR,
		"swapchain is NOT sRGB (got %v)",
		loc,
	)
	return surface_format
}

choose_swapchain_present_mode :: proc(present_modes: ^[]vk.PresentModeKHR) -> vk.PresentModeKHR {
	return .FIFO
}

choose_swapchain_extent :: proc(window: glfw.WindowHandle, capabilities: ^vk.SurfaceCapabilitiesKHR) -> vk.Extent2D {
	if (capabilities.currentExtent.width != max(u32)) {
		return capabilities.currentExtent
	} else {
		width, height := glfw.GetFramebufferSize(window)

		actual_extent: vk.Extent2D = {cast(u32)width, cast(u32)height}
		actual_extent.width = clamp(actual_extent.width, capabilities.minImageExtent.width, capabilities.maxImageExtent.width)
		actual_extent.height = clamp(actual_extent.height, capabilities.minImageExtent.height, capabilities.maxImageExtent.height)
		return actual_extent
	}
}
