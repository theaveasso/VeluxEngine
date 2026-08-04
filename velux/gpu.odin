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
	info := image_create_info(
		format,
		extent,
		image_usage_flags,
		mip_levels,
		array_layers,
		image_type,
		msaa_samples,
		tiling,
		flags,
		alloc_flags,
		usage,
	)
	return create_image(info, loc)
}

// Errors here are all recoverable and all about the shader: the file is
// missing, slangc rejected it, or the driver would not take the result. In
// every case the caller's previous pipeline is untouched.
@(require_results)
create_gpu_pipeline :: proc(
	pipeline: ^GPU_Pipeline,
	slang_path: string,
	push_constant_size: u32,
	topology: vk.PrimitiveTopology = .TRIANGLE_LIST,
	polygon_mode: vk.PolygonMode = .FILL,
	front_face: vk.FrontFace = .COUNTER_CLOCKWISE,
	depth: GPU_Depth_Config = {write_enabled = false, compare_op = .ALWAYS, format = DEFAULT_DEPTH_FORMAT},
	cull_mode: vk.CullModeFlags = {},
	color_format: Format = .UNDEFINED,
	blend_mode: GPU_Blend_Mode = .None,
	vertex_entry: cstring = DEFAULT_VERTEX_ENTRY,
	fragment_entry: cstring = DEFAULT_FRAGMENT_ENTRY,
) -> Error {
	spv_path := strings.concatenate({strings.trim_suffix(slang_path, ".slang"), ".spv"}, context.temp_allocator)

	output, compile_err := compile_slang(slang_path, spv_path, context.temp_allocator)
	if compile_err != .None {
		if output != "" do log.error(output)
		return compile_err
	}
	if output != "" do log.warn(output)

	shader := create_gpu_shader(spv_path, context.temp_allocator) or_return
	defer destroy_gpu_shader(shader)

	info := pipeline_create_info(
		push_constant_size,
		topology,
		polygon_mode,
		front_face,
		depth,
		cull_mode,
		color_format == .UNDEFINED ? swapchain_format() : color_format,
		blend_mode,
		vertex_entry,
		fragment_entry,
	)
	pipeline^ = rebuild_gpu_pipeline(shader, info) or_return

	when ODIN_DEBUG do watch_shader(pipeline, slang_path, spv_path) or_return
	return .None
}
