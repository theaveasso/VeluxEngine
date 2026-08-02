package velux

import vma "third_party:odin-vma"
import vk "vendor:vulkan"

Command_Buffer :: vk.CommandBuffer
Shader_Module :: vk.ShaderModule
Format :: vk.Format

Vertex :: struct {
	position: [3]f32,
	normal:   [3]f32,
	uv:       [2]f32,
}

@(require_results)
create_texture :: proc(
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
) -> (
	Image,
	GPU_Error,
) {
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
	return create_image(info)
}

@(require_results)
create_graphics_pipeline :: proc(
	shader: vk.ShaderModule,
	push_constant_size: u32,
	input_topology: vk.PrimitiveTopology,
	polygon_mode: vk.PolygonMode,
	front_face: vk.FrontFace,
	depth_config: Depth_Config,
	cull_mode: vk.CullModeFlags = {},
	color_format: Format = .UNDEFINED,
	blend_mode: Pipeline_Blend_Mode = .None,
	vertex_entry: cstring = DEFAULT_VERTEX_ENTRY,
	fragment_entry: cstring = DEFAULT_FRAGMENT_ENTRY,
) -> (
	Graphics_Pipeline,
	GPU_Error,
) {
	info := pipeline_create_info(
		push_constant_size,
		input_topology,
		polygon_mode,
		front_face,
		depth_config,
		cull_mode,
		color_format,
		blend_mode,
		vertex_entry,
		fragment_entry,
	)
	return rebuild_graphics_pipeline(shader, info)
}
