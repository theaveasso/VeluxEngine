package velux

import "base:runtime"
import "core:dynlib"
import "core:log"
import "core:strings"

import vma "third_party:odin-vma"
import glfw "vendor:glfw"
import vk "vendor:vulkan"

GPU_Config :: struct {
	app_name:          cstring,
	window:            glfw.WindowHandle,
	enable_validation: bool,
	enable_log:        bool,
	enable_profiler:   bool,
}

GPU_Device :: struct {
	logger:                     log.Logger,
	log_state:                  Prefix_Logger,
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
	depth_image:                GPU_Image,
	frames:                     [MAX_FRAMES_IN_FLIGHT]Frame_Data,
	render_finished_semaphores: []vk.Semaphore,
	command_pool:               vk.CommandPool,
	transfer:                   Transfer_Context,
	upload:                     Upload_Ring,
	bindless:                   Bindless,
	enable_validation_layer:    bool,
	current_frame:              u32,
	enable_profiler:            bool,
	profiler:                   Profiler,
	timestamp_period:           f32,
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

@(private)
wait_idle :: proc(device: ^GPU_Device) {
	if device.device != nil do vk.DeviceWaitIdle(device.device)
}

// Nothing in here is recoverable. If the machine cannot present a Vulkan
// surface, velux has no second plan, and the fatal at the failing call names
// what was missing.
@(private)
init_gpu :: proc(device: ^GPU_Device, config: GPU_Config) {
	device.logger = logger_from_prefix(&device.log_state, "[gpu]: ")
	context.logger = device.logger
	device.enable_validation_layer = config.enable_validation
	device.enable_profiler = config.enable_profiler

	create_instance(device, config)
	setup_debug_utils_messenger(device, config)
	create_surface(device, config)
	pick_physical_device(device)
	find_queue_families(device)
	create_device(device)
	create_vma_allocator(device)
	create_swapchain(device)
	create_depth_resources(device)
	create_per_image_semaphores(device)
	create_command_pool(device)
	allocate_command_buffers(device)
	create_transfer_context(device)
	create_upload_ring(device)
	create_sync_objects(device)
	create_profiler(device)
	create_bindless(device)
}

@(private)
destroy_gpu :: proc(device: ^GPU_Device) {
	if device.device == nil do return
	wait_idle(device)

	destroy_bindless(device)
	destroy_profiler(device)
	destroy_sync_objects(device)
	destroy_upload_ring(device)
	destroy_transfer_context(device)
	vk.DestroyCommandPool(device.device, device.command_pool, nil)
	destroy_per_image_semaphores(device)
	destroy_depth_resources(device)
	destroy_swapchain_resources(device)
	vma.DestroyAllocator(device.vma_allocator)
	vk.DestroyDevice(device.device, nil)
	vk.DestroySurfaceKHR(device.instance, device.surface, nil)
	if device.enable_validation_layer do vk.DestroyDebugUtilsMessengerEXT(device.instance, device.debug_messenger, nil)
	vk.DestroyInstance(device.instance, nil)
	device^ = {}
}

@(private)
debug_callback :: proc "system" (
	message_severity: vk.DebugUtilsMessageSeverityFlagsEXT,
	message_type: vk.DebugUtilsMessageTypeFlagsEXT,
	callback_data: ^vk.DebugUtilsMessengerCallbackDataEXT,
	user_data: rawptr,
) -> b32 {
	context = runtime.default_context()
	// Assigned at procedure scope on purpose. `if x != nil { context.logger = .. }`
	// would set the logger inside the if-body's scope and lose it on the way
	// out, which is exactly why validation messages used to vanish.
	context.logger = user_data != nil ? (cast(^log.Logger)user_data)^ : context.logger

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

@(private)
create_instance :: proc(device: ^GPU_Device, config: GPU_Config) {
	vk.load_proc_addresses_global(rawptr(glfw.GetInstanceProcAddress))

	if vk.GetInstanceProcAddr == nil {
		lib: dynlib.Library
		lib_ok: bool
		when ODIN_OS == .Windows {
			lib, lib_ok = dynlib.load_library("vulkan-1.dll")
		} else when ODIN_OS == .Darwin {
			lib, lib_ok = dynlib.load_library("/opt/homebrew/lib/libvulkan.dylib")
		} else {
			lib, lib_ok = dynlib.load_library("libvulkan.so.1")
		}
		if !lib_ok do fatal("no vulkan loader on this machine")

		get_proc_addr, sym_ok := dynlib.symbol_address(lib, "vkGetInstanceProcAddr")
		if !sym_ok do fatal("vulkan loader has no vkGetInstanceProcAddr")

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

	create_info: vk.InstanceCreateInfo = {
		sType                   = .INSTANCE_CREATE_INFO,
		pApplicationInfo        = &app_info,
		enabledExtensionCount   = cast(u32)len(extensions),
		ppEnabledExtensionNames = raw_data(extensions),
		enabledLayerCount       = cast(u32)len(layers),
		ppEnabledLayerNames     = raw_data(layers),
	}

	when ODIN_OS == .Darwin {
		create_info.flags = {.ENUMERATE_PORTABILITY_KHR}
	}

	// Covers messages emitted by vkCreateInstance itself; the standalone
	// messenger below takes over once the instance exists.
	validation_features: vk.ValidationFeaturesEXT
	debug_create_info: vk.DebugUtilsMessengerCreateInfoEXT
	if device.enable_validation_layer {
		debug_create_info = debug_messenger_create_info(device, &validation_features)
		create_info.pNext = &debug_create_info
	}

	vk_assert(vk.CreateInstance(&create_info, nil, &device.instance), "vkCreateInstance")
	vk.load_proc_addresses_instance(device.instance)
}

// `features` is written through and must outlive the returned struct: it is
// reached by pNext, not copied.
@(private)
debug_messenger_create_info :: proc(
	device: ^GPU_Device,
	features: ^vk.ValidationFeaturesEXT,
) -> vk.DebugUtilsMessengerCreateInfoEXT {
	features^ = {
		sType                         = .VALIDATION_FEATURES_EXT,
		enabledValidationFeatureCount = cast(u32)len(VALIDATION_FEATURES),
		pEnabledValidationFeatures    = raw_data(VALIDATION_FEATURES),
	}
	return {
		sType           = .DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
		pNext           = features,
		messageSeverity = {.WARNING, .ERROR, .INFO},
		messageType     = {.GENERAL, .VALIDATION, .PERFORMANCE},
		pfnUserCallback = debug_callback,
		pUserData       = &device.logger,
	}
}

@(private)
setup_debug_utils_messenger :: proc(device: ^GPU_Device, config: GPU_Config) {
	if !config.enable_validation do return

	validation_features: vk.ValidationFeaturesEXT
	debug_create_info := debug_messenger_create_info(device, &validation_features)

	vk_assert(
		vk.CreateDebugUtilsMessengerEXT(device.instance, &debug_create_info, nil, &device.debug_messenger),
		"vkCreateDebugUtilsMessengerEXT",
	)
}

@(private)
create_surface :: proc(device: ^GPU_Device, config: GPU_Config) {
	device.window = config.window
	if device.window == nil do fatal("create_surface called before the window existed")

	vk_assert(glfw.CreateWindowSurface(device.instance, device.window, nil, &device.surface), "glfwCreateWindowSurface")
}

@(private)
pick_physical_device :: proc(device: ^GPU_Device) {
	device_n: u32 = 0
	vk_assert(vk.EnumeratePhysicalDevices(device.instance, &device_n, nil), "vkEnumeratePhysicalDevices")
	if device_n == 0 do fatal("no vulkan physical devices")

	devices := make([]vk.PhysicalDevice, device_n, context.temp_allocator)
	vk_assert(vk.EnumeratePhysicalDevices(device.instance, &device_n, raw_data(devices)), "vkEnumeratePhysicalDevices")

	// One pass: take the first discrete device that qualifies, otherwise fall
	// back to the first qualifying device of any kind.
	chosen: vk.PhysicalDevice
	for physical_device in devices {
		if !device_is_suitable(physical_device, device.surface) do continue
		if device_is_discrete(physical_device) {
			chosen = physical_device
			break
		}
		if chosen == nil do chosen = physical_device
	}

	if chosen == nil do fatal("no suitable GPU:\n%s", device_rejection_report(devices, device.surface))

	device.physical_device = chosen
	props: vk.PhysicalDeviceProperties
	vk.GetPhysicalDeviceProperties(chosen, &props)
	device.timestamp_period = props.limits.timestampPeriod
	log.infof("using %s", cstring(&props.deviceName[0]))
}

@(private)
find_queue_families :: proc(device: ^GPU_Device) {
	queue_family_n: u32
	vk.GetPhysicalDeviceQueueFamilyProperties(device.physical_device, &queue_family_n, nil)

	queue_families := make([]vk.QueueFamilyProperties, queue_family_n, context.temp_allocator)
	vk.GetPhysicalDeviceQueueFamilyProperties(device.physical_device, &queue_family_n, raw_data(queue_families))

	for &qf, i in queue_families {
		if .GRAPHICS not_in qf.queueFlags || qf.timestampValidBits == 0 do continue
		if !glfw.GetPhysicalDevicePresentationSupport(device.instance, device.physical_device, cast(u32)i) do continue

		device.graphics_family = cast(u32)i
		return
	}

	fatal("GPU has no graphics queue that can present with timestamp support")
}

@(private)
create_device :: proc(device: ^GPU_Device) {
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

	vk_assert(vk.CreateDevice(device.physical_device, &device_info, nil, &device.device), "vkCreateDevice")

	vk.load_proc_addresses_device(device.device)
	vk.GetDeviceQueue(device.device, device.graphics_family, 0, &device.graphics_queue)
}

@(private)
create_vma_allocator :: proc(device: ^GPU_Device) {
	vulkan_functions := vma.create_vulkan_functions()

	allocator_info: vma.AllocatorCreateInfo = {
		vulkanApiVersion = vk.API_VERSION_1_4,
		physicalDevice   = device.physical_device,
		device           = device.device,
		instance         = device.instance,
		flags            = {.BUFFER_DEVICE_ADDRESS},
		pVulkanFunctions = &vulkan_functions,
	}

	vk_assert(vma.CreateAllocator(&allocator_info, &device.vma_allocator), "vmaCreateAllocator")
}

@(private)
get_required_extensions :: proc(enable_validation_layers: bool) -> [dynamic]cstring {
	glfw_exts := glfw.GetRequiredInstanceExtensions()

	exts: [dynamic]cstring
	resize(&exts, len(glfw_exts))
	for ext, i in glfw_exts {
		exts[i] = ext
	}

	if enable_validation_layers {
		append(&exts, vk.EXT_DEBUG_UTILS_EXTENSION_NAME)
	}

	when ODIN_OS == .Darwin {
		append(&exts, vk.KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME)
	}

	return exts
}

@(private)
get_required_layers :: proc(enable_validation_layers: bool) -> []cstring {
	return enable_validation_layers ? VALIDATION_LAYERS : nil
}

@(private)
device_is_discrete :: proc(physical_device: vk.PhysicalDevice) -> bool {
	properties: vk.PhysicalDeviceProperties
	vk.GetPhysicalDeviceProperties(physical_device, &properties)
	return properties.deviceType == .DISCRETE_GPU
}

@(private)
device_is_suitable :: proc(physical_device: vk.PhysicalDevice, surface: vk.SurfaceKHR) -> bool {
	if len(device_missing_features(physical_device, context.temp_allocator)) > 0 do return false
	if len(device_missing_extensions(physical_device, context.temp_allocator)) > 0 do return false

	format_count, present_mode_count: u32
	vk.GetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &format_count, nil)
	vk.GetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &present_mode_count, nil)
	return format_count > 0 && present_mode_count > 0
}

// Named explicitly rather than discovered by reflection over the REQUIRED_*
// structs. The list is eleven entries, it is known at compile time, and
// spelling it out is what makes the rejection message worth reading.
@(private)
device_missing_features :: proc(physical_device: vk.PhysicalDevice, allocator := context.allocator) -> []string {
	vk_13: vk.PhysicalDeviceVulkan13Features = {
		sType = .PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
	}
	vk_12: vk.PhysicalDeviceVulkan12Features = {
		sType = .PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
		pNext = &vk_13,
	}
	vk_11: vk.PhysicalDeviceVulkan11Features = {
		sType = .PHYSICAL_DEVICE_VULKAN_1_1_FEATURES,
		pNext = &vk_12,
	}
	features: vk.PhysicalDeviceFeatures2 = {
		sType = .PHYSICAL_DEVICE_FEATURES_2,
		pNext = &vk_11,
	}
	vk.GetPhysicalDeviceFeatures2(physical_device, &features)

	missing := make([dynamic]string, 0, 12, allocator)
	need :: proc(missing: ^[dynamic]string, name: string, present: b32) {
		if !present do append(missing, name)
	}

	need(&missing, "shaderDrawParameters", vk_11.shaderDrawParameters)

	need(&missing, "bufferDeviceAddress", vk_12.bufferDeviceAddress)
	need(&missing, "descriptorIndexing", vk_12.descriptorIndexing)
	need(&missing, "runtimeDescriptorArray", vk_12.runtimeDescriptorArray)
	need(&missing, "descriptorBindingPartiallyBound", vk_12.descriptorBindingPartiallyBound)
	need(&missing, "descriptorBindingSampledImageUpdateAfterBind", vk_12.descriptorBindingSampledImageUpdateAfterBind)
	need(&missing, "shaderSampledImageArrayNonUniformIndexing", vk_12.shaderSampledImageArrayNonUniformIndexing)
	need(&missing, "scalarBlockLayout", vk_12.scalarBlockLayout)

	need(&missing, "synchronization2", vk_13.synchronization2)
	need(&missing, "dynamicRendering", vk_13.dynamicRendering)

	return missing[:]
}

@(private)
device_missing_extensions :: proc(physical_device: vk.PhysicalDevice, allocator := context.allocator) -> []string {
	ext_n: u32 = 0
	vk.EnumerateDeviceExtensionProperties(physical_device, nil, &ext_n, nil)

	available := make([]vk.ExtensionProperties, ext_n, context.temp_allocator)
	vk.EnumerateDeviceExtensionProperties(physical_device, nil, &ext_n, raw_data(available))

	missing := make([dynamic]string, 0, len(DEVICE_EXTENSIONS), allocator)
	for expected in DEVICE_EXTENSIONS {
		found := false
		for &have in available {
			if string(cstring(&have.extensionName[0])) == string(expected) {
				found = true
				break
			}
		}
		if !found do append(&missing, string(expected))
	}
	return missing[:]
}

// Only built when we are about to die, so the cost does not matter and the
// detail does.
@(private)
device_rejection_report :: proc(devices: []vk.PhysicalDevice, surface: vk.SurfaceKHR) -> string {
	builder := strings.builder_make(context.temp_allocator)

	for physical_device in devices {
		props: vk.PhysicalDeviceProperties
		vk.GetPhysicalDeviceProperties(physical_device, &props)
		strings.write_string(&builder, "  ")
		strings.write_string(&builder, string(cstring(&props.deviceName[0])))
		strings.write_string(&builder, "\n")

		for name in device_missing_features(physical_device, context.temp_allocator) {
			strings.write_string(&builder, "    missing feature:   ")
			strings.write_string(&builder, name)
			strings.write_string(&builder, "\n")
		}
		for name in device_missing_extensions(physical_device, context.temp_allocator) {
			strings.write_string(&builder, "    missing extension: ")
			strings.write_string(&builder, name)
			strings.write_string(&builder, "\n")
		}
	}

	return strings.to_string(builder)
}
