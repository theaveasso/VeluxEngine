package ui

import vk "vendor:vulkan"

import imgui "third_party:odin-imgui"
import imgui_glfw "third_party:odin-imgui/imgui_impl_glfw"
import imgui_vk "third_party:odin-imgui/imgui_impl_vulkan"

import "vlx:platform"

import "vlx:gpu"

Context :: struct {
	initialized: bool,
}
Error :: enum {
	None,
	ImGui_Call_Failed,
}

@(require_results)
init :: proc(ui: ^Context, device: ^gpu.Device, window: ^platform.Window) -> (err: Error) {

	imgui.CreateContext()
	if !imgui_glfw.InitForVulkan(window.handle, true) do return .ImGui_Call_Failed

	if !imgui_vk.LoadFunctions(vk.API_VERSION_1_4, loader_func, rawptr(device.instance)) do return .ImGui_Call_Failed
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

	ui.initialized = true
	return
}

destroy :: proc(ui: ^Context) {
	if ui.initialized {
		imgui_vk.Shutdown()
		imgui_glfw.Shutdown()
		imgui.DestroyContext()
		ui.initialized = false
	}
}

new_frame :: proc() {
	imgui_vk.NewFrame()
	imgui_glfw.NewFrame()
	imgui.NewFrame()
}

end_frame :: proc() {
	imgui.EndFrame()
}

draw :: proc(cmd: vk.CommandBuffer) {
	imgui.Render()
	imgui_vk.RenderDrawData(imgui.GetDrawData(), cmd)
}

@(require_results)
wants_mouse :: proc(ui: ^Context) -> bool {
	return ui.initialized ? imgui.GetIO().WantCaptureMouse : false
}

@(require_results)
wants_keyboard :: proc(ui: ^Context) -> bool {
	return ui.initialized ? imgui.GetIO().WantCaptureKeyboard : false
}

@(private)
loader_func :: proc "c" (name: cstring, user_data: rawptr) -> vk.ProcVoidFunction {
	return vk.GetInstanceProcAddr(cast(vk.Instance)user_data, name)
}
