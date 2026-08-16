package velux

import "base:runtime"

import vk "vendor:vulkan"

import imgui "third_party:odin-imgui"
import imgui_glfw "third_party:odin-imgui/imgui_impl_glfw"
import imgui_vk "third_party:odin-imgui/imgui_impl_vulkan"

UI_Context :: struct {
	ctx:             ^imgui.Context,
	imgui_alloc:     imgui.MemAllocFunc,
	imgui_free:      imgui.MemFreeFunc,
	imgui_user_data: rawptr,
}

@(private)
ui_new_frame :: proc() {
	if !ui_ready() do return
	imgui_vk.NewFrame()
	imgui_glfw.NewFrame()
	imgui.NewFrame()
}

@(private)
ui_end_frame :: proc() {
	if !ui_ready() do return
	imgui.EndFrame()
}

@(private)
ui_draw :: proc(frame: Frame) {
	hud_draw(g_engine)
	if !ui_ready() do return
	imgui.Render()
	imgui_vk.RenderDrawData(imgui.GetDrawData(), frame.cmd)
}

@(require_results)
ui_wants_mouse :: proc() -> bool {
	if !ui_ready() do return false
	return imgui.GetIO().WantCaptureMouse
}

@(require_results)
ui_wants_keyboard :: proc() -> bool {
	if !ui_ready() do return false
	return imgui.GetIO().WantCaptureKeyboard
}

@(private)
init_ui :: proc(engine: ^Engine) {
	engine.ui_context = imgui.CreateContext()
	imgui.GetAllocatorFunctions(&engine.imgui_alloc, &engine.imgui_free, &engine.imgui_user_data)
	if !imgui_glfw.InitForVulkan(engine.window.handle, true) do fatal("ImGui_ImplGlfw_InitForVulkan failed")

	device := &engine.gpu
	if !imgui_vk.LoadFunctions(vk.API_VERSION_1_4, imgui_loader, rawptr(device.instance)) {
		fatal("ImGui_ImplVulkan_LoadFunctions failed")
	}

	format := device.swapchain.surface_format.format
	info: imgui_vk.InitInfo = {
		ApiVersion = vk.API_VERSION_1_4,
		Instance = device.instance,
		PhysicalDevice = device.physical_device,
		Device = device.device,
		QueueFamily = device.graphics_family,
		Queue = device.graphics_queue,
		DescriptorPoolSize = 16,
		MinImageCount = 2,
		ImageCount = u32(len(device.swapchain.images)),
		UseDynamicRendering = true,
		PipelineInfoMain = {
			// cmd_begin_rendering always binds depth, so this must match even
			// though imgui never writes it. UNDEFINED here is a validation
			// error on every UI draw.
			PipelineRenderingCreateInfo = {
				sType = .PIPELINE_RENDERING_CREATE_INFO,
				colorAttachmentCount = 1,
				pColorAttachmentFormats = &format,
				depthAttachmentFormat = DEFAULT_DEPTH_FORMAT,
			},
		},
	}
	if !imgui_vk.Init(&info) do fatal("ImGui_ImplVulkan_Init failed")
}

@(private)
destroy_ui :: proc(engine: ^Engine) {
	if engine.ui_context == nil do return
	imgui_vk.Shutdown()
	imgui_glfw.Shutdown()
	imgui.DestroyContext()
	engine.ui_context = nil
}

@(private, require_results)
ui_ready :: proc() -> bool {
	return g_engine != nil && g_engine.ui_context != nil
}

@(private)
imgui_loader :: proc "c" (name: cstring, user_data: rawptr) -> vk.ProcVoidFunction {
	return vk.GetInstanceProcAddr(cast(vk.Instance)user_data, name)
}
