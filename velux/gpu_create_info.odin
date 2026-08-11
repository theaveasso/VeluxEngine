package velux

import vma "third_party:odin-vma"
import vk "vendor:vulkan"

@(private)
pipeline_create_info :: proc(
	push_constant_size: u32,
	input_topology: vk.PrimitiveTopology,
	polygon_mode: vk.PolygonMode,
	front_face: vk.FrontFace,
	depth_config: GPU_Depth_Config,
	cull_mode: vk.CullModeFlags = {},
	color_format: vk.Format = .UNDEFINED,
	vertex_entry: cstring = DEFAULT_VERTEX_ENTRY,
	fragment_entry: cstring = DEFAULT_FRAGMENT_ENTRY,
) -> GPU_Pipeline_Info {
	return {
		push_constant_size = push_constant_size,
		input_topology = input_topology,
		polygon_mode = polygon_mode,
		front_face = front_face,
		depth_config = depth_config,
		color_format = color_format,
		cull_mode = cull_mode,
		vertex_entry = vertex_entry,
		fragment_entry = fragment_entry,
	}
}

@(private)
sampler_create_info :: proc(
	filter: vk.Filter,
	address_mode: vk.SamplerAddressMode,
	compare_op: vk.CompareOp = .NEVER,
	border_color: vk.BorderColor = .FLOAT_TRANSPARENT_BLACK,
	max_lod: f32 = 1.0,
	max_anisotropy: f32 = 1.0,
) -> GPU_Sampler_Info {
	return {
		filter = filter,
		address_mode = address_mode,
		compare_op = compare_op,
		border_color = border_color,
		max_lod = max_lod,
		max_anisotropy = max_anisotropy,
	}
}

@(private)
render_target_create_info :: proc(
	width: u32,
	height: u32,
	color_format: Format = .R8G8B8A8_UNORM,
	depth_format: Format = DEFAULT_DEPTH_FORMAT,
) -> Render_Target_Info {
	return {width = width, height = height, color_format = color_format, depth_format = depth_format}
}

@(private)
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
) -> GPU_Image_Info {
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
