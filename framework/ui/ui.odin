package ui

import vk "vendor:vulkan"

import imgui "third_party:odin-imgui"
import imgui_glfw "third_party:odin-imgui/imgui_impl_glfw"
import imgui_vk "third_party:odin-imgui/imgui_impl_vulkan"

import "vlx:platform"

import "vlx:gpu"

@(private)
g_initialized: bool

Context :: imgui.Context

Error :: enum {
	None,
	ImGui_Call_Failed,
}

@(require_results)
init :: proc(gpu: ^gpu.Device, window: ^platform.Window) -> (ctx: ^Context, err: Error) {

	ctx = imgui.CreateContext()
	if !imgui_glfw.InitForVulkan(window.handle, true) do return nil, .ImGui_Call_Failed

	if !imgui_vk.LoadFunctions(vk.API_VERSION_1_4, loader_func, rawptr(gpu.instance)) do return nil, .ImGui_Call_Failed
	format := gpu.swapchain.surface_format.format
	info: imgui_vk.InitInfo = {
		ApiVersion = vk.API_VERSION_1_4,
		Instance = gpu.instance,
		PhysicalDevice = gpu.physical_device,
		Device = gpu.device,
		QueueFamily = gpu.graphics_family,
		Queue = gpu.graphics_queue,
		DescriptorPoolSize = 16,
		MinImageCount = 2,
		ImageCount = u32(len(gpu.swapchain.images)),
		UseDynamicRendering = true,
		PipelineInfoMain = {
			PipelineRenderingCreateInfo = {
				sType = .PIPELINE_RENDERING_CREATE_INFO,
				colorAttachmentCount = 1,
				pColorAttachmentFormats = &format,
			},
		},
	}

	if !imgui_vk.Init(&info) do return nil, .ImGui_Call_Failed

	g_initialized = true
	return
}

destroy :: proc() {
	if g_initialized {
		imgui_vk.Shutdown()
		imgui_glfw.Shutdown()
		imgui.DestroyContext()
		g_initialized = false
	}
}

new_frame :: proc() {
	if !g_initialized do return
	imgui_vk.NewFrame()
	imgui_glfw.NewFrame()
	imgui.NewFrame()
}

end_frame :: proc() {
	if !g_initialized do return
	imgui.EndFrame()
}

draw :: proc(frame: gpu.Frame) {
	if !g_initialized do return
	imgui.Render()
	imgui_vk.RenderDrawData(imgui.GetDrawData(), frame.cmd)
}

bind :: proc(gpu: ^gpu.Device, ctx: ^imgui.Context) {
	imgui.SetCurrentContext(ctx)
	imgui_vk.LoadFunctions(vk.API_VERSION_1_4, loader_func, rawptr(gpu.instance))
	g_initialized = true
}

@(require_results)
wants_mouse :: proc() -> bool {
	if !g_initialized do return false
	return imgui.GetIO().WantCaptureMouse
}

@(require_results)
wants_keyboard :: proc() -> bool {
	if !g_initialized do return false
	return imgui.GetIO().WantCaptureKeyboard
}

@(private)
loader_func :: proc "c" (name: cstring, user_data: rawptr) -> vk.ProcVoidFunction {
	return vk.GetInstanceProcAddr(cast(vk.Instance)user_data, name)
}
