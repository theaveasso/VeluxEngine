package gpu

import vk "vendor:vulkan"

DEFAULT_VERTEX_ENTRY: cstring : "vertex_main"
DEFAULT_FRAGMENT_ENTRY: cstring : "fragment_main"
DEFAULT_COMPUTE_ENTRY: cstring : "compute_main"

REQUIRED_VULKAN_FEATURES: vk.PhysicalDeviceFeatures2 = {
	sType = .PHYSICAL_DEVICE_FEATURES_2,
	pNext = &REQUIRED_VULKAN_1_1_FEATURES,
}

REQUIRED_VULKAN_1_1_FEATURES: vk.PhysicalDeviceVulkan11Features = {
	sType                = .PHYSICAL_DEVICE_VULKAN_1_1_FEATURES,
	pNext                = &REQUIRED_VULKAN_1_2_FEATURES,
	shaderDrawParameters = true,
}

REQUIRED_VULKAN_1_2_FEATURES: vk.PhysicalDeviceVulkan12Features = {
	sType               = .PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
	pNext               = &REQUIRED_VULKAN_1_3_FEATURES,
	bufferDeviceAddress = true,
	scalarBlockLayout   = true,
}

REQUIRED_VULKAN_1_3_FEATURES: vk.PhysicalDeviceVulkan13Features = {
	sType            = .PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
	synchronization2 = true,
	dynamicRendering = true,
}

DEVICE_EXTENSIONS := []cstring{vk.KHR_SWAPCHAIN_EXTENSION_NAME}

VALIDATION_LAYERS := []cstring{"VK_LAYER_KHRONOS_validation"}

VALIDATION_FEATURES := []vk.ValidationFeatureEnableEXT{}

MAX_FRAMES_IN_FLIGHT :: 2
