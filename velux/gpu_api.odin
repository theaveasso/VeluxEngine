package velux

import "base:runtime"

import vma "third_party:odin-vma"
import vk "vendor:vulkan"

GPU_API :: struct {
	swapchain_format:         proc() -> Format,
	wait_for_idle:            proc(),
	create_image:             proc(
		format: vk.Format,
		extent: vk.Extent3D,
		image_usage_flags: vk.ImageUsageFlags,
		mip_levels: u32,
		array_layers: u32,
		image_type: vk.ImageType,
		msaa_samples: vk.SampleCountFlags,
		tiling: vk.ImageTiling,
		flags: vk.ImageCreateFlags,
		alloc_flags: vma.AllocationCreateFlags,
		usage: vma.MemoryUsage,
		loc: runtime.Source_Code_Location,
	) -> GPU_Image,
	destroy_image:            proc(image: ^GPU_Image),
	create_sampler:           proc(
		filter: vk.Filter,
		address_mode: vk.SamplerAddressMode,
		compare_op: vk.CompareOp,
		border_color: vk.BorderColor,
		max_lod: f32,
		max_anisotropy: f32,
	) -> vk.Sampler,
	create_pipeline:          proc(
		pipeline: ^GPU_Pipeline,
		slang_path: string,
		push_constant_size: u32,
		topology: vk.PrimitiveTopology,
		polygon_mode: vk.PolygonMode,
		front_face: vk.FrontFace,
		depth: GPU_Depth_Config,
		cull_mode: vk.CullModeFlags,
		color_format: Format,
		vertex_entry: cstring,
		fragment_entry: cstring,
	) -> Error,
	rebuild_pipeline:         proc(shader: vk.ShaderModule, create_info: GPU_Pipeline_Info) -> (GPU_Pipeline, Error),
	destroy_pipeline:         proc(pipeline: ^GPU_Pipeline),
	create_shader:            proc(
		file_name: string,
		allocator: runtime.Allocator,
		loc: runtime.Source_Code_Location,
	) -> (vk.ShaderModule, Error),
	destroy_shader:           proc(module: vk.ShaderModule),
	create_render_target:     proc(
		width: u32,
		height: u32,
		color_format: Format,
		depth_format: Format,
	) -> Render_Target,
	destroy_render_target:    proc(target: ^Render_Target),
	immediate_transfer_begin: proc() -> vk.CommandBuffer,
	immediate_transfer_end:   proc(),
	prof_zone_begin:          proc(frame: Frame, name: string, loc: runtime.Source_Code_Location) -> u32,
	prof_zone_end:            proc(frame: Frame, loc: runtime.Source_Code_Location),
}

@(private, require_results)
host_gpu_api :: proc() -> GPU_API {
	return {
		swapchain_format = host_swapchain_format,
		wait_for_idle = host_wait_for_idle,
		create_image = host_create_gpu_image,
		destroy_image = host_destroy_gpu_image,
		create_sampler = host_create_sampler,
		create_pipeline = host_create_gpu_pipeline,
		rebuild_pipeline = host_rebuild_gpu_pipeline,
		destroy_pipeline = host_destroy_gpu_pipeline,
		create_shader = host_create_gpu_shader,
		destroy_shader = host_destroy_gpu_shader,
		create_render_target = host_create_render_target,
		destroy_render_target = host_destroy_render_target,
		immediate_transfer_begin = host_immediate_transfer_begin,
		immediate_transfer_end = host_immediate_transfer_end,
		prof_zone_begin = host_prof_zone_begin,
		prof_zone_end = host_prof_zone_end,
	}
}
