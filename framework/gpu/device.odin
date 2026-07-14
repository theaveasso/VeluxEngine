package gpu

import "base:runtime"
import "core:dynlib"
import "core:log"
import "core:reflect"
import "core:strings"

import vma "third_party:odin-vma"
import glfw "vendor:glfw"
import vk "vendor:vulkan"

import core "vlx:core"

Error :: enum {
	None,
	Library_Load_Failed,
	Symbol_Not_Found,
	File_Read_Failed,
	Invalid_Handle,
	Invalid_Shader,
	No_Suitable_Physical_Device,
	No_Graphics_Queue_Supported,
	Command_Buffer_Allocation_Failed,
	Swapchain_Recreate,
	Vulkan_Call_Failed,
	VMA_Call_Failed,
}

Config :: struct {
	app_name:          cstring,
	enable_validation: bool,
	enable_log:        bool,
	window:            glfw.WindowHandle,
}

Device :: struct {
	logger:                     log.Logger,
	log_state:                  core.Prefix_Logger,
	debug_messenger:            vk.DebugUtilsMessengerEXT,
	vma_allocator:              vma.Allocator,
	instance:                   vk.Instance,
	physical_device:            vk.PhysicalDevice,
	device:                     vk.Device,
	surface:                    vk.SurfaceKHR,
	window:                     glfw.WindowHandle,
	graphics_queue:             vk.Queue,
	graphics_family:            u32,
	swapchain:                  Swapchain,
	depth_image:                Image,
	frames:                     [MAX_FRAMES_IN_FLIGHT]Frame_Data,
	render_finished_semaphores: []vk.Semaphore,
	command_pool:               vk.CommandPool,
	imm_transfer_ctx:           Transfer_Context,
	bindless:                   Bindless,
	enable_validation_layer:    bool,
	current_frame:              u32,
}

Frame_Data :: struct {
	command_buffer:   vk.CommandBuffer,
	in_flight_fence:  vk.Fence,
	present_complete: vk.Semaphore,
}

Swapchain :: struct {
	handle:         vk.SwapchainKHR,
	images:         []vk.Image,
	views:          []vk.ImageView,
	surface_format: vk.SurfaceFormatKHR,
	extent:         vk.Extent2D,
	image_index:    u32,
}

@(require_results)
vk_check :: proc(result: vk.Result, err: Error = .Vulkan_Call_Failed, loc := #caller_location) -> Error {
	if result == .SUCCESS do return .None
	log.errorf("vulkan call failed :%v (%v)", result, loc)
	return err
}

wait_idle :: proc(device: ^Device) {
	if device.device != nil do vk.DeviceWaitIdle(device.device)
}

@(require_results)
init :: proc(device: ^Device, config: Config) -> (err: Error = .None) {
	device.logger = core.logger_from_prefix(&device.log_state, "[gpu]: ")
	context.logger = device.logger
	device.enable_validation_layer = config.enable_validation

	create_instance(device, config) or_return
	setup_debug_utils_messenger(device, config) or_return
	create_surface(device, config) or_return
	pick_physical_device(device) or_return
	find_queue_families(device) or_return
	create_device(device) or_return
	create_vma_allocator(device) or_return
	create_swapchain(device) or_return
	create_depth_resources(device) or_return
	create_per_image_semaphores(device) or_return
	create_command_pool(device) or_return
	allocate_command_buffers(device) or_return
	create_immediate_transfer_context(device) or_return
	create_sync_objects(device) or_return
	create_bindless(device) or_return

	return
}

destroy :: proc(device: ^Device) {
	wait_idle(device)

	destroy_bindless(device)
	destroy_immediate_transfer_context(device)
	destroy_sync_objects(device)
	vk.DestroyCommandPool(device.device, device.command_pool, nil)
	destroy_per_image_semaphores(device)
	destroy_depth_resources(device)
	destroy_swapchain_resources(device)
	vma.DestroyAllocator(device.vma_allocator)
	vk.DestroyDevice(device.device, nil)
	vk.DestroySurfaceKHR(device.instance, device.surface, nil)
	if device.enable_validation_layer do vk.DestroyDebugUtilsMessengerEXT(device.instance, device.debug_messenger, nil)
	vk.DestroyInstance(device.instance, nil)
}

debug_callback :: proc "system" (
	message_severity: vk.DebugUtilsMessageSeverityFlagsEXT,
	message_type: vk.DebugUtilsMessageTypeFlagsEXT,
	callback_data: ^vk.DebugUtilsMessengerCallbackDataEXT,
	user_data: rawptr,
) -> b32 {
	context = runtime.default_context()
	if user_data != nil {
		context.logger = (cast(^log.Logger)user_data)^
	}

	level: log.Level
	switch {
	case .ERROR in message_severity:
		level = .Error
	case .WARNING in message_severity:
		level = .Warning
	case .INFO in message_severity:
		level = .Info
	case:
		level = .Debug
	}
	log.log(level, callback_data.pMessage)

	return false
}

@(private, require_results)
create_instance :: proc(device: ^Device, config: Config) -> (err: Error = .None) {
	vk.load_proc_addresses_global(rawptr(glfw.GetInstanceProcAddress))

	if vk.GetInstanceProcAddr == nil {
		lib, lib_ok := dynlib.load_library("vulkan-1.dll")
		if !lib_ok do return .Library_Load_Failed

		get_proc_addr, sym_ok := dynlib.symbol_address(lib, "vkGetInstanceProcAddr")
		if !sym_ok do return .Symbol_Not_Found

		vk.load_proc_addresses_global(get_proc_addr)
	}

	app_info: vk.ApplicationInfo = {
		sType              = .APPLICATION_INFO,
		pApplicationName   = config.app_name,
		applicationVersion = vk.MAKE_VERSION(0, 1, 0),
		apiVersion         = vk.API_VERSION_1_4,
		pEngineName        = "VeluxEngine",
		engineVersion      = vk.MAKE_VERSION(0, 1, 0),
	}

	extensions := get_required_extensions(device.enable_validation_layer)
	defer delete(extensions)

	layers := get_required_layers(device.enable_validation_layer)
	defer delete(layers)

	create_info: vk.InstanceCreateInfo = {
		sType                   = .INSTANCE_CREATE_INFO,
		pApplicationInfo        = &app_info,
		enabledExtensionCount   = cast(u32)len(extensions),
		ppEnabledExtensionNames = raw_data(extensions),
		enabledLayerCount       = device.enable_validation_layer ? cast(u32)len(layers) : 0,
		ppEnabledLayerNames     = device.enable_validation_layer ? raw_data(layers) : nil,
	}

	validation_features: vk.ValidationFeaturesEXT
	debug_create_info: vk.DebugUtilsMessengerCreateInfoEXT

	if device.enable_validation_layer {
		validation_features.sType = .VALIDATION_FEATURES_EXT
		validation_features.enabledValidationFeatureCount = cast(u32)len(VALIDATION_FEATURES)
		validation_features.pEnabledValidationFeatures = raw_data(VALIDATION_FEATURES)

		debug_create_info.sType = .DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT
		debug_create_info.pNext = &validation_features
		debug_create_info.messageSeverity = {.WARNING, .ERROR, .INFO}
		debug_create_info.messageType = {.GENERAL, .VALIDATION, .PERFORMANCE}
		debug_create_info.pfnUserCallback = debug_callback
		debug_create_info.pUserData = &device.logger

		create_info.pNext = &debug_create_info
	} else {
		create_info.pNext = nil
	}

	vk_check(vk.CreateInstance(&create_info, nil, &device.instance)) or_return
	vk.load_proc_addresses_instance(device.instance)

	return
}

@(private, require_results)
setup_debug_utils_messenger :: proc(device: ^Device, config: Config) -> (err: Error = .None) {
	if !config.enable_validation do return

	validation_features: vk.ValidationFeaturesEXT = {
		sType                         = .VALIDATION_FEATURES_EXT,
		enabledValidationFeatureCount = cast(u32)len(VALIDATION_FEATURES),
		pEnabledValidationFeatures    = raw_data(VALIDATION_FEATURES),
	}

	debug_create_info: vk.DebugUtilsMessengerCreateInfoEXT = {
		sType           = .DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
		pNext           = &validation_features,
		messageSeverity = {.WARNING, .ERROR, .INFO},
		messageType     = {.GENERAL, .VALIDATION, .PERFORMANCE},
		pfnUserCallback = debug_callback,
		pUserData       = &device.logger,
	}

	vk_check(vk.CreateDebugUtilsMessengerEXT(device.instance, &debug_create_info, nil, &device.debug_messenger)) or_return
	return
}

@(private, require_results)
create_surface :: proc(device: ^Device, config: Config) -> (err: Error = .None) {
	device.window = config.window
	if device.window == nil do return .Invalid_Handle

	vk_check(glfw.CreateWindowSurface(device.instance, device.window, nil, &device.surface)) or_return

	return
}

@(private, require_results)
pick_physical_device :: proc(device: ^Device) -> (err: Error = .No_Suitable_Physical_Device) {
	device_n: u32 = 0
	vk_check(vk.EnumeratePhysicalDevices(device.instance, &device_n, nil), .No_Suitable_Physical_Device) or_return
	if device_n == 0 do return .No_Suitable_Physical_Device

	devices := make([]vk.PhysicalDevice, device_n)
	defer delete(devices)
	vk_check(vk.EnumeratePhysicalDevices(device.instance, &device_n, raw_data(devices)), .No_Suitable_Physical_Device) or_return

	for physical_device in devices {
		is_suitable, is_discrete := is_device_suitable(physical_device, device.surface)
		if is_suitable && is_discrete {
			device.physical_device = physical_device
			return .None
		}
	}

	if device.physical_device == nil {
		for physical_device in devices {
			is_suitable, _is_discrete := is_device_suitable(physical_device, device.surface)
			if is_suitable {
				device.physical_device = physical_device
				return .None
			}
		}
	}

	return
}

@(private, require_results)
find_queue_families :: proc(device: ^Device) -> (err: Error = .None) {
	queue_family_n: u32
	vk.GetPhysicalDeviceQueueFamilyProperties(device.physical_device, &queue_family_n, nil)

	queue_families := make([]vk.QueueFamilyProperties, queue_family_n)
	defer delete(queue_families)
	vk.GetPhysicalDeviceQueueFamilyProperties(device.physical_device, &queue_family_n, raw_data(queue_families))

	queue_family: u32 = max(u32)
	for &qf, i in queue_families {
		if .GRAPHICS not_in qf.queueFlags do continue

		support_present := glfw.GetPhysicalDevicePresentationSupport(device.instance, device.physical_device, cast(u32)i)

		if support_present && .GRAPHICS in qf.queueFlags {
			queue_family = cast(u32)i
			break
		}
	}

	if queue_family != max(u32) do device.graphics_family = queue_family

	return queue_family != max(u32) ? .None : .No_Graphics_Queue_Supported
}

@(private, require_results)
create_device :: proc(device: ^Device) -> (err: Error = .None) {
	queue_priority: f32 = 1.0

	queue_info: vk.DeviceQueueCreateInfo = {
		sType            = .DEVICE_QUEUE_CREATE_INFO,
		queueFamilyIndex = device.graphics_family,
		queueCount       = 1,
		pQueuePriorities = &queue_priority,
	}

	device_info: vk.DeviceCreateInfo = {
		sType                   = .DEVICE_CREATE_INFO,
		pNext                   = &REQUIRED_VULKAN_FEATURES,
		pQueueCreateInfos       = &queue_info,
		queueCreateInfoCount    = 1,
		enabledExtensionCount   = cast(u32)len(DEVICE_EXTENSIONS),
		ppEnabledExtensionNames = raw_data(DEVICE_EXTENSIONS),
	}

	vk_check(vk.CreateDevice(device.physical_device, &device_info, nil, &device.device), .Vulkan_Call_Failed) or_return

	vk.load_proc_addresses_device(device.device)

	vk.GetDeviceQueue(device.device, device.graphics_family, 0, &device.graphics_queue)

	return
}

@(private, require_results)
create_vma_allocator :: proc(device: ^Device) -> (err: Error = .None) {
	vulkan_functions := vma.create_vulkan_functions()

	allocator_info: vma.AllocatorCreateInfo = {
		vulkanApiVersion = vk.API_VERSION_1_4,
		physicalDevice   = device.physical_device,
		device           = device.device,
		instance         = device.instance,
		flags            = {.BUFFER_DEVICE_ADDRESS},
		pVulkanFunctions = &vulkan_functions,
	}

	vk_check(vma.CreateAllocator(&allocator_info, &device.vma_allocator), .Vulkan_Call_Failed) or_return

	return
}

@(private, require_results)
create_swapchain :: proc(device: ^Device) -> (err: Error = .None) {
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
create_depth_resources :: proc(device: ^Device) -> (err: Error = .None) {
	device.depth_image = create_image(
		device,
		image_create_info(
			DEFAULT_DEPTH_FORMAT,
			{device.swapchain.extent.width, device.swapchain.extent.height, 1},
			{.DEPTH_STENCIL_ATTACHMENT},
		),
	) or_return
	return
}

@(private)
destroy_depth_resources :: proc(device: ^Device) {
	destroy_image(device, &device.depth_image)
}

@(private, require_results)
recreate_swapchain :: proc(device: ^Device) -> (err: Error = .None) {
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

@(private, require_results)
create_per_image_semaphores :: proc(device: ^Device) -> (err: Error = .None) {
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
destroy_per_image_semaphores :: proc(device: ^Device) {
	for semaphore in device.render_finished_semaphores {
		vk.DestroySemaphore(device.device, semaphore, nil)
	}
	delete(device.render_finished_semaphores)
	device.render_finished_semaphores = nil
}

@(private, require_results)
create_command_pool :: proc(device: ^Device) -> (err: Error = .None) {
	pool_info: vk.CommandPoolCreateInfo = {
		sType            = .COMMAND_POOL_CREATE_INFO,
		flags            = {.RESET_COMMAND_BUFFER},
		queueFamilyIndex = device.graphics_family,
	}

	vk_check(vk.CreateCommandPool(device.device, &pool_info, nil, &device.command_pool), .Vulkan_Call_Failed) or_return

	return
}

@(private, require_results)
allocate_command_buffers :: proc(device: ^Device) -> (err: Error = .None) {
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
create_sync_objects :: proc(device: ^Device) -> (err: Error = .None) {
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
destroy_sync_objects :: proc(device: ^Device) {
	for &frame in device.frames {
		vk.DestroySemaphore(device.device, frame.present_complete, nil)
		vk.DestroyFence(device.device, frame.in_flight_fence, nil)
	}
}

swapchain_format :: proc(device: ^Device) -> vk.Format {
	return device.swapchain.surface_format.format
}

destroy_swapchain_resources :: proc(device: ^Device) {
	for view in device.swapchain.views {
		vk.DestroyImageView(device.device, view, nil)
	}
	delete(device.swapchain.views)
	delete(device.swapchain.images)
	vk.DestroySwapchainKHR(device.device, device.swapchain.handle, nil)
	device.swapchain = {}

}

get_required_extensions :: proc(enable_validation_layers: bool) -> [dynamic]cstring {
	glfw_exts := glfw.GetRequiredInstanceExtensions()

	exts_n := len(glfw_exts)
	exts: [dynamic]cstring
	resize(&exts, exts_n)

	for ext, i in glfw_exts {
		exts[i] = ext
	}

	if enable_validation_layers {
		append(&exts, vk.EXT_DEBUG_UTILS_EXTENSION_NAME)
	}

	return exts
}

get_required_layers :: proc(enable_validation_layers: bool) -> [dynamic]cstring {
	layers: [dynamic]cstring
	if enable_validation_layers {
		resize(&layers, len(VALIDATION_LAYERS))
		for layer, i in VALIDATION_LAYERS {
			layers[i] = layer
		}
	} else {
		resize(&layers, 0)
	}
	return layers
}

is_device_suitable :: proc(physical_device: vk.PhysicalDevice, surface: vk.SurfaceKHR) -> (is_suitable, is_discrete: bool) {
	properties: vk.PhysicalDeviceProperties
	vk.GetPhysicalDeviceProperties(physical_device, &properties)

	vk_13_features: vk.PhysicalDeviceVulkan13Features = {
		sType = .PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
	}
	vk_12_features: vk.PhysicalDeviceVulkan12Features = {
		sType = .PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
		pNext = &vk_13_features,
	}
	vk_11_features: vk.PhysicalDeviceVulkan11Features = {
		sType = .PHYSICAL_DEVICE_VULKAN_1_1_FEATURES,
		pNext = &vk_12_features,
	}
	features: vk.PhysicalDeviceFeatures2 = {
		sType = .PHYSICAL_DEVICE_FEATURES_2,
		pNext = &vk_11_features,
	}
	vk.GetPhysicalDeviceFeatures2(physical_device, &features)
	supports_features :=
		supports_required_features(REQUIRED_VULKAN_FEATURES, features) &&
		supports_required_features(REQUIRED_VULKAN_1_1_FEATURES, vk_11_features) &&
		supports_required_features(REQUIRED_VULKAN_1_2_FEATURES, vk_12_features) &&
		supports_required_features(REQUIRED_VULKAN_1_3_FEATURES, vk_13_features)

	supports_extension := check_device_extension_support(physical_device)
	swapchain_adequate := false
	if supports_extension {
		format_count: u32
		vk.GetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &format_count, nil)
		present_mode_count: u32
		vk.GetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &present_mode_count, nil)
		swapchain_adequate = format_count > 0 && present_mode_count > 0
	}

	return swapchain_adequate && supports_extension && supports_features, properties.deviceType == .DISCRETE_GPU
}

supports_required_features :: proc(required: $T, test: T) -> bool {
	required := required
	test := test

	id := typeid_of(T)
	names := reflect.struct_field_names(id)
	types := reflect.struct_field_types(id)
	offsets := reflect.struct_field_offsets(id)

	builder: strings.Builder
	strings.builder_init(&builder)
	defer strings.builder_destroy(&builder)

	strings.write_string(&builder, " - ")
	reflect.write_type(&builder, type_info_of(T))
	strings.write_string(&builder, "\n")

	supports_all_flags := true

	for i in 0 ..< len(offsets) {
		if reflect.type_kind(types[i].id) == .Boolean {
			offset := offsets[i]

			required_value := (cast(^b32)(uintptr(&required) + offset))^
			test_value := (cast(^b32)(uintptr(&test) + offset))^

			if required_value {
				strings.write_string(&builder, "  + ")
				strings.write_string(&builder, names[i])

				if !test_value {
					strings.write_string(&builder, " \xE2\x9D\x8C\n")
					supports_all_flags = false
				} else {
					strings.write_string(&builder, " \xE2\x9C\x94\n")
				}
			}
		}
	}
	if !supports_all_flags {
		log.warnf("device is missing required features:\n%s", strings.to_string(builder))
	}

	return supports_all_flags
}

check_device_extension_support :: proc(device: vk.PhysicalDevice) -> bool {
	exts_n: u32 = 0
	vk.EnumerateDeviceExtensionProperties(device, nil, &exts_n, nil)

	avail_exts := make([]vk.ExtensionProperties, exts_n)
	defer delete(avail_exts)
	vk.EnumerateDeviceExtensionProperties(device, nil, &exts_n, raw_data(avail_exts))

	for &expected_ext in DEVICE_EXTENSIONS {
		found := false
		for &avail in avail_exts {
			if strings.compare(string(cstring(&avail.extensionName[0])), string(expected_ext)) == 0 {
				found = true
				break
			}
		}
		if !found {
			log.warn("extension not available: ", expected_ext)
		}
		found or_return
	}

	return true
}

choose_swapchain_surface_format :: proc(formats: ^[]vk.SurfaceFormatKHR) -> vk.SurfaceFormatKHR {
	surface_format := formats[0]
	for format in formats {
		if format.format == .B8G8R8A8_SRGB && format.colorSpace == .SRGB_NONLINEAR {
			surface_format = format
			break
		}
	}
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
