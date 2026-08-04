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



GPU_Error :: enum {
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
	imm_transfer_ctx:           Transfer_Context,
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

@(private, require_results)
vk_check :: proc(result: vk.Result, err: GPU_Error = .Vulkan_Call_Failed, loc := #caller_location) -> GPU_Error {
	if result == .SUCCESS do return .None
	fmt.eprintfln("vulkan call failed :%v (%v)", result, loc)
	return err
}

@(private)
wait_idle :: proc(device: ^GPU_Device) {
	if device.device != nil do vk.DeviceWaitIdle(device.device)
}

@(private, require_results)
init_gpu :: proc(device: ^GPU_Device, config: GPU_Config) -> (err: GPU_Error = .None) {
	device.logger = logger_from_prefix(&device.log_state, "[gpu]: ")
	context.logger = device.logger
	device.enable_validation_layer = config.enable_validation
	device.enable_profiler = config.enable_profiler

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
	create_profiler(device) or_return
	create_bindless(device) or_return
	return
}

@(private)
destroy_gpu :: proc(device: ^GPU_Device) {
	wait_idle(device)

	destroy_bindless(device)
	destroy_profiler(device)
	destroy_sync_objects(device)
	destroy_immediate_transfer_context(device)
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

@(private)
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
create_instance :: proc(device: ^GPU_Device, config: GPU_Config) -> (err: GPU_Error = .None) {
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

	// Covers messages emitted by vkCreateInstance itself; the standalone messenger
	// created in setup_debug_utils_messenger takes over once the instance exists.
	validation_features: vk.ValidationFeaturesEXT
	debug_create_info: vk.DebugUtilsMessengerCreateInfoEXT
	if device.enable_validation_layer {
		debug_create_info = debug_messenger_create_info(device, &validation_features)
		create_info.pNext = &debug_create_info
	}

	vk_check(vk.CreateInstance(&create_info, nil, &device.instance)) or_return
	vk.load_proc_addresses_instance(device.instance)

	return
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

@(private, require_results)
setup_debug_utils_messenger :: proc(device: ^GPU_Device, config: GPU_Config) -> (err: GPU_Error = .None) {
	if !config.enable_validation do return

	validation_features: vk.ValidationFeaturesEXT
	debug_create_info := debug_messenger_create_info(device, &validation_features)

	vk_check(vk.CreateDebugUtilsMessengerEXT(device.instance, &debug_create_info, nil, &device.debug_messenger)) or_return
	return
}

@(private, require_results)
create_surface :: proc(device: ^GPU_Device, config: GPU_Config) -> (err: GPU_Error = .None) {
	device.window = config.window
	if device.window == nil do return .Invalid_Handle

	vk_check(glfw.CreateWindowSurface(device.instance, device.window, nil, &device.surface)) or_return

	return
}

@(private, require_results)
pick_physical_device :: proc(device: ^GPU_Device) -> (err: GPU_Error = .No_Suitable_Physical_Device) {
	device_n: u32 = 0
	vk_check(vk.EnumeratePhysicalDevices(device.instance, &device_n, nil), .No_Suitable_Physical_Device) or_return
	if device_n == 0 do return .No_Suitable_Physical_Device

	devices := make([]vk.PhysicalDevice, device_n)
	defer delete(devices)
	vk_check(vk.EnumeratePhysicalDevices(device.instance, &device_n, raw_data(devices)), .No_Suitable_Physical_Device) or_return

	// One pass: take the first discrete device that qualifies, otherwise fall back
	// to the first qualifying device of any kind.
	chosen: vk.PhysicalDevice
	for physical_device in devices {
		is_suitable, is_discrete := is_device_suitable(physical_device, device.surface)
		if !is_suitable do continue
		if is_discrete {
			chosen = physical_device
			break
		}
		if chosen == nil do chosen = physical_device
	}
	if chosen == nil do return .No_Suitable_Physical_Device

	device.physical_device = chosen
	props: vk.PhysicalDeviceProperties
	vk.GetPhysicalDeviceProperties(chosen, &props)
	device.timestamp_period = props.limits.timestampPeriod
	return .None
}

@(private, require_results)
find_queue_families :: proc(device: ^GPU_Device) -> (err: GPU_Error = .None) {
	queue_family_n: u32
	vk.GetPhysicalDeviceQueueFamilyProperties(device.physical_device, &queue_family_n, nil)

	queue_families := make([]vk.QueueFamilyProperties, queue_family_n)
	defer delete(queue_families)
	vk.GetPhysicalDeviceQueueFamilyProperties(device.physical_device, &queue_family_n, raw_data(queue_families))

	for &qf, i in queue_families {
		if .GRAPHICS not_in qf.queueFlags || qf.timestampValidBits == 0 do continue
		if !glfw.GetPhysicalDevicePresentationSupport(device.instance, device.physical_device, cast(u32)i) do continue

		device.graphics_family = cast(u32)i
		return .None
	}

	return .No_Graphics_Queue_Supported
}

@(private, require_results)
create_device :: proc(device: ^GPU_Device) -> (err: GPU_Error = .None) {
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
create_vma_allocator :: proc(device: ^GPU_Device) -> (err: GPU_Error = .None) {
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

@(private)
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

@(private)
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

@(private)
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

