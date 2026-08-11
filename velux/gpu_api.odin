package velux

import "base:runtime"

import vma "third_party:odin-vma"
import vk "vendor:vulkan"

GPU_API :: struct {
	swapchain_format:          proc() -> Format,
	wait_for_idle:             proc(),
	create_image:              proc(create_info: GPU_Image_Info, loc: runtime.Source_Code_Location) -> GPU_Image,
	destroy_image:             proc(image: ^GPU_Image),
	create_sampler:            proc(create_info: GPU_Sampler_Info) -> vk.Sampler,
	create_pipeline:           proc(pipeline: ^GPU_Pipeline, slang_path: string, create_info: GPU_Pipeline_Info) -> Error,
	rebuild_pipeline:          proc(shader: vk.ShaderModule, create_info: GPU_Pipeline_Info) -> (GPU_Pipeline, Error),
	destroy_pipeline:          proc(pipeline: ^GPU_Pipeline),
	create_shader:             proc(file_name: string, allocator: runtime.Allocator, loc: runtime.Source_Code_Location) -> (vk.ShaderModule, Error),
	destroy_shader:            proc(module: vk.ShaderModule),
	create_render_target:      proc(create_info: Render_Target_Info) -> Render_Target,
	destroy_render_target:     proc(target: ^Render_Target),
	begin_rendering_swapchain: proc(frame: Frame, clear_color: Maybe([4]f32)),
	end_rendering_swapchain:   proc(frame: Frame),
	begin_rendering_target:    proc(frame: Frame, target: Render_Target, clear_color: [4]f32),
	end_rendering_target:      proc(frame: Frame, target: Render_Target),
	bind_graphics_pipeline:    proc(frame: Frame, pipeline: GPU_Pipeline),
	push_constants:            proc(frame: Frame, pipeline: GPU_Pipeline, data: rawptr, size: int, loc: runtime.Source_Code_Location),
	bind_index_buffer:         proc(frame: Frame, buffer: vk.Buffer, offset: vk.DeviceSize, index_type: vk.IndexType),
	set_viewport:              proc(frame: Frame, offset: [2]f32, size: [2]f32),
	draw:                      proc(frame: Frame, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32),
	draw_indexed:              proc(frame: Frame, index_count: u32, instance_count: u32, first_index: u32, vertex_offset: i32, first_instance: u32),
	immediate_transfer_begin:  proc() -> vk.CommandBuffer,
	immediate_transfer_end:    proc(),
	prof_zone_begin:           proc(frame: Frame, name: string, loc: runtime.Source_Code_Location) -> u32,
	prof_zone_end:             proc(frame: Frame, loc: runtime.Source_Code_Location),
}

@(private, require_results)
host_gpu_api :: proc() -> GPU_API {
	return {
		swapchain_format = host_swapchain_format,
		wait_for_idle = host_wait_for_idle,
		create_image = create_image,
		destroy_image = host_destroy_gpu_image,
		create_sampler = host_create_sampler,
		create_pipeline = host_create_gpu_pipeline,
		rebuild_pipeline = host_rebuild_gpu_pipeline,
		destroy_pipeline = host_destroy_gpu_pipeline,
		create_shader = host_create_gpu_shader,
		destroy_shader = host_destroy_gpu_shader,
		create_render_target = host_create_render_target,
		destroy_render_target = host_destroy_render_target,
		begin_rendering_swapchain = host_cmd_begin_rendering_swapchain,
		end_rendering_swapchain = host_cmd_end_rendering_swapchain,
		begin_rendering_target = host_cmd_begin_rendering_target,
		end_rendering_target = host_cmd_end_rendering_target,
		bind_graphics_pipeline = host_cmd_bind_graphics_pipeline,
		push_constants = host_cmd_push_constants,
		bind_index_buffer = host_cmd_bind_index_buffer,
		set_viewport = host_cmd_set_viewport,
		draw = host_cmd_draw,
		draw_indexed = host_cmd_draw_indexed,
		immediate_transfer_begin = host_immediate_transfer_begin,
		immediate_transfer_end = host_immediate_transfer_end,
		prof_zone_begin = host_prof_zone_begin,
		prof_zone_end = host_prof_zone_end,
	}
}
