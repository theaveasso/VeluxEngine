package velux

import "core:log"
import "core:strings"

import vma "third_party:odin-vma"
import vk "vendor:vulkan"

Command_Buffer :: vk.CommandBuffer
GPU_Shader :: vk.ShaderModule
Format :: vk.Format

Vertex :: struct {
	position: [3]f32,
	normal:   [3]f32,
	uv:       [2]f32,
}

@(require_results)
swapchain_format :: proc(loc := #caller_location) -> Format {
	return bound_api(loc).gpu.swapchain_format()
}

wait_for_idle :: proc(loc := #caller_location) {
	bound_api(loc).gpu.wait_for_idle()
}

@(private, require_results)
host_swapchain_format :: proc() -> Format {
	return g_engine.gpu.swapchain.surface_format.format
}

@(private)
host_wait_for_idle :: proc() {
	wait_idle(&g_engine.gpu)
}

create_gpu_image :: proc(
	format: vk.Format,
	extent: vk.Extent3D,
	image_usage_flags: vk.ImageUsageFlags,
	mip_levels: u32 = 1,
	array_layers: u32 = 1,
	image_type: vk.ImageType = .D2,
	msaa_samples: vk.SampleCountFlags = {._1},
	tiling: vk.ImageTiling = .OPTIMAL,
	flags: vk.ImageCreateFlags = {},
	alloc_flags: vma.AllocationCreateFlags = {},
	usage: vma.MemoryUsage = .AUTO,
	loc := #caller_location,
) -> GPU_Image {
	info := image_create_info(format, extent, image_usage_flags, mip_levels, array_layers, image_type, msaa_samples, tiling, flags, alloc_flags, usage)
	return bound_api(loc).gpu.create_image(info, loc)
}

@(require_results)
create_gpu_pipeline :: proc(
	pipeline: ^GPU_Pipeline,
	slang_path: string,
	push_constant_size: u32,
	topology: vk.PrimitiveTopology = .TRIANGLE_LIST,
	polygon_mode: vk.PolygonMode = .FILL,
	front_face: vk.FrontFace = .COUNTER_CLOCKWISE,
	depth: GPU_Depth_Config = {},
	cull_mode: vk.CullModeFlags = {},
	color_format: Format = .UNDEFINED,
	depth_format: Format = .UNDEFINED,
	vertex_entry: cstring = DEFAULT_VERTEX_ENTRY,
	fragment_entry: cstring = DEFAULT_FRAGMENT_ENTRY,
	loc := #caller_location,
) -> Error {
	info := pipeline_create_info(
		push_constant_size,
		topology,
		polygon_mode,
		front_face,
		depth,
		cull_mode,
		color_format,
		depth_format,
		vertex_entry,
		fragment_entry,
	)
	return bound_api(loc).gpu.create_pipeline(pipeline, slang_path, info)
}

@(private)
host_create_gpu_pipeline :: proc(pipeline: ^GPU_Pipeline, slang_path: string, create_info: GPU_Pipeline_Info) -> Error {
	spv_path := strings.concatenate({strings.trim_suffix(slang_path, ".slang"), ".spv"}, context.temp_allocator)

	output, compile_err := compile_slang(slang_path, spv_path, context.temp_allocator)
	if compile_err != .None {
		if output != "" do log.error(output)
		return compile_err
	}
	if output != "" do log.warn(output)

	shader := create_gpu_shader(spv_path, context.temp_allocator) or_return
	defer destroy_gpu_shader(shader)

	resolved := create_info
	if resolved.color_format == .UNDEFINED do resolved.color_format = swapchain_format()
	if resolved.depth_format == .UNDEFINED do resolved.depth_format = DEFAULT_DEPTH_FORMAT
	pipeline^ = rebuild_gpu_pipeline(shader, resolved) or_return

	when ODIN_DEBUG do watch_shader(pipeline, slang_path, spv_path) or_return
	return .None
}
