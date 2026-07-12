package gpu

import vma "third_party:odin-vma"
import vk "vendor:vulkan"

pipeline_create_info :: proc(
	shader: vk.ShaderModule,
	push_constants: typeid,
	input_topology: vk.PrimitiveTopology,
	polygon_mode: vk.PolygonMode,
	front_face: vk.FrontFace,
	depth_config: Depth_Config,
	cull_mode: vk.CullModeFlags = {},
	color_format: vk.Format = .UNDEFINED,
	blend_mode: Pipeline_Blend_Mode = .None,
	vertex_entry: cstring = DEFAULT_VERTEX_ENTRY,
	fragment_entry: cstring = DEFAULT_FRAGMENT_ENTRY,
) -> Graphics_Pipeline_Create_Info {
	return {
		shader = shader,
		push_constants = push_constants,
		input_topology = input_topology,
		polygon_mode = polygon_mode,
		front_face = front_face,
		depth_config = depth_config,
		color_format = color_format,
		cull_mode = cull_mode,
		blend_mode = blend_mode,
		vertex_entry = vertex_entry,
		fragment_entry = fragment_entry,
	}
}

image_create_info :: proc(
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
) -> Image_Create_Info {
	return {
		format = format,
		extent = extent,
		image_usage_flags = image_usage_flags,
		mip_levels = mip_levels,
		array_layers = array_layers,
		image_type = image_type,
		msaa_samples = msaa_samples,
		tiling = tiling,
		flags = flags,
		alloc_flags = alloc_flags,
		usage = usage,
	}
}
