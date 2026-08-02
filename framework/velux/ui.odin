package velux

import vk "vendor:vulkan"

import imgui "third_party:odin-imgui"
import imgui_glfw "third_party:odin-imgui/imgui_impl_glfw"
import imgui_vk "third_party:odin-imgui/imgui_impl_vulkan"

UI_Context :: imgui.Context

UI_Error :: enum {
	None,
	ImGui_Call_Failed,
}

ui_new_frame :: proc() {
	if !ui_ready() do return
	imgui_vk.NewFrame()
	imgui_glfw.NewFrame()
	imgui.NewFrame()
}

ui_end_frame :: proc() {
	if !ui_ready() do return
	imgui.EndFrame()
}

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

@(private, require_results)
init_ui :: proc(engine: ^Engine) -> (err: UI_Error) {
	engine.ui_context = imgui.CreateContext()
	if !imgui_glfw.InitForVulkan(engine.window.handle, true) do return .ImGui_Call_Failed

	device := &engine.gpu
	if !imgui_vk.LoadFunctions(vk.API_VERSION_1_4, imgui_loader, rawptr(device.instance)) do return .ImGui_Call_Failed

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
			PipelineRenderingCreateInfo = {
				sType = .PIPELINE_RENDERING_CREATE_INFO,
				colorAttachmentCount = 1,
				pColorAttachmentFormats = &format,
			},
		},
	}
	if !imgui_vk.Init(&info) do return .ImGui_Call_Failed

	return
}

@(private)
destroy_ui :: proc(engine: ^Engine) {
	if engine.ui_context == nil do return
	imgui_vk.Shutdown()
	imgui_glfw.Shutdown()
	imgui.DestroyContext()
	engine.ui_context = nil
}

@(private)
bind_ui :: proc(engine: ^Engine) {
	if engine.ui_context == nil do return
	imgui.SetCurrentContext(engine.ui_context)
	imgui_vk.LoadFunctions(vk.API_VERSION_1_4, imgui_loader, rawptr(engine.gpu.instance))
}

@(private, require_results)
ui_ready :: proc() -> bool {
	return g_engine != nil && g_engine.ui_context != nil
}

@(private)
imgui_loader :: proc "c" (name: cstring, user_data: rawptr) -> vk.ProcVoidFunction {
	return vk.GetInstanceProcAddr(cast(vk.Instance)user_data, name)
}
