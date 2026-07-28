package velux

import "base:runtime"
import "vlx:audio"
import "vlx:shaders"

import vma "third_party:odin-vma"
import vk "vendor:vulkan"

import gpu "vlx:gpu"
import platform "vlx:platform"

DEFAULT_VERTEX_ENTRY :: gpu.DEFAULT_VERTEX_ENTRY
DEFAULT_FRAGMENT_ENTRY :: gpu.DEFAULT_FRAGMENT_ENTRY

DEFAULT_DEPTH_FORMAT :: gpu.DEFAULT_DEPTH_FORMAT

Vertex :: struct {
	position: [3]f32,
	normal:   [3]f32,
	uv:       [2]f32,
}

Frame :: gpu.Frame
Buffer :: gpu.Buffer
Image :: gpu.Image
Device_Address :: gpu.Device_Address
Buffer_Kind :: gpu.Buffer_Kind
Depth_Config :: gpu.Depth_Config
Pipeline_Blend_Mode :: gpu.Pipeline_Blend_Mode
Graphics_Pipeline :: gpu.Graphics_Pipeline
Graphics_Pipeline_Create_Info :: gpu.Graphics_Pipeline_Create_Info

Mouse_Button :: platform.Mouse_Button
Key :: platform.Key

Command_Buffer :: vk.CommandBuffer
Shader_Module :: vk.ShaderModule
Format :: vk.Format

Sound_Handle :: audio.Sound_Handle

cmd_begin_rendering :: gpu.cmd_begin_rendering
cmd_bind_graphics_pipeline :: gpu.cmd_bind_graphics_pipeline
cmd_push_constants :: gpu.cmd_push_constants
cmd_bind_index_buffer :: gpu.cmd_bind_index_buffer
cmd_draw :: gpu.cmd_draw
cmd_draw_indexed :: gpu.cmd_draw_indexed
cmd_end_rendering :: gpu.cmd_end_rendering

time :: platform.time

mouse_delta :: platform.mouse_delta
scroll_delta :: platform.scroll_delta
is_mouse_down :: platform.is_mouse_down
is_key_down :: platform.is_key_down
is_key_pressed :: platform.is_key_pressed
set_cursor_captured :: platform.set_cursor_captured
is_cursor_captured :: platform.is_cursor_captured

// begin	vlx:gpu			---
@(require_results)
create_buffer :: #force_inline proc($T: typeid, #any_int size: vk.DeviceSize = 1, kind: Buffer_Kind = .Storage) -> (Buffer(T), Error) {
	return gpu.create_buffer(&g_engine.gpu, T, size, kind)
}

destroy_buffer :: #force_inline proc(buffer: ^Buffer($T)) {gpu.destroy_buffer(&g_engine.gpu, buffer)}

@(require_results)
create_texture :: #force_inline proc(
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
	Error,
) {
	info := gpu.image_create_info(
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
	return gpu.create_image(&g_engine.gpu, info)
}

destroy_texture :: #force_inline proc(image: ^Image) {gpu.destroy_image(&g_engine.gpu, image)}

begin_frame :: #force_inline proc() -> (Frame, Error) {return gpu.begin_frame(&g_engine.gpu)}

end_frame :: #force_inline proc(frame: Frame) -> Error {return gpu.end_frame(&g_engine.gpu, frame)}

immediate_transfer_begin :: #force_inline proc() -> (Command_Buffer, Error) {return gpu.immediate_transfer_begin(&g_engine.gpu)}

immediate_transfer_end :: #force_inline proc() -> Error {return gpu.immediate_transfer_end(&g_engine.gpu)}

create_shader :: #force_inline proc(file_name: string, allocator: runtime.Allocator) -> (Shader_Module, Error) {
	return gpu.load_shader_module(&g_engine.gpu, file_name, allocator)
}

destroy_shader :: #force_inline proc(shader: Shader_Module) {gpu.destroy_shader_module(&g_engine.gpu, shader)}

@(require_results)
create_graphics_pipeline :: #force_inline proc(
	shader: vk.ShaderModule,
	push_constant_size: u32,
	input_topology: vk.PrimitiveTopology,
	polygon_mode: vk.PolygonMode,
	front_face: vk.FrontFace,
	depth_config: Depth_Config,
	cull_mode: vk.CullModeFlags = {},
	color_format: Format = .UNDEFINED,
	blend_mode: Pipeline_Blend_Mode = .None,
	vertex_entry: cstring = gpu.DEFAULT_VERTEX_ENTRY,
	fragment_entry: cstring = gpu.DEFAULT_FRAGMENT_ENTRY,
) -> (
	Graphics_Pipeline,
	Error,
) {
	info := gpu.pipeline_create_info(
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
	return gpu.create_graphics_pipeline(&g_engine.gpu, shader, info)
}

@(require_results)
rebuild_graphics_pipeline :: #force_inline proc(shader: Shader_Module, info: Graphics_Pipeline_Create_Info) -> (Graphics_Pipeline, Error) {
	return gpu.create_graphics_pipeline(&g_engine.gpu, shader, info)
}

destroy_pipeline :: #force_inline proc(pipeline: ^Graphics_Pipeline) {gpu.destroy_pipeline(&g_engine.gpu, pipeline)}

@(require_results)
write_staging_buffer_slice :: #force_inline proc(
	cmd: Command_Buffer,
	buffer: ^Buffer($T),
	in_data: []$U,
	offset: vk.DeviceSize = 0,
	loc := #caller_location,
) -> Error {
	return gpu.write_staging_buffer_slice(&g_engine.gpu, cmd, buffer, in_data, offset, loc)
}

@(require_results)
write_staging_image_slice :: #force_inline proc(
	cmd: Command_Buffer,
	image: ^Image,
	in_data: []$T,
	offset: vk.DeviceSize = 0,
	loc := #caller_location,
) -> Error {
	return gpu.write_staging_image(&g_engine.gpu, cmd, image, in_data, offset, loc)
}

prof_zone_begin :: #force_inline proc(frame: Frame, name: string, loc := #caller_location) -> u32 {
	return gpu.zone_begin(&g_engine.gpu, frame, name, loc)
}

prof_zone_end :: #force_inline proc(frame: Frame, loc := #caller_location) {gpu.zone_end(&g_engine.gpu, frame, loc)}
// end		vlx:gpu			---

// begin	vlx:shaders		---
compile_slang :: shaders.compile_slang
// end		vlx:shaders		---

// begin	vlx:audio		---
@(require_results)
load_sound :: #force_inline proc(file_name: string, spatial: bool) -> (Sound_Handle, Error) {
	return audio.load(&g_engine.audio, file_name, spatial)
}

play_sound :: #force_inline proc(handle: Sound_Handle) {audio.play(&g_engine.audio, handle)}

stop_sound :: #force_inline proc(handle: Sound_Handle) {audio.stop(&g_engine.audio, handle)}

play_oneshot :: #force_inline proc(file_name: string) {audio.play_oneshot(&g_engine.audio, file_name)}
// end		vlx:audio		---
