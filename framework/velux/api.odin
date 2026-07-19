package velux

import "base:runtime"

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

Mouse_Button :: platform.Mouse_Button
Key :: platform.Key

Command_Buffer :: vk.CommandBuffer
Shader_Module :: vk.ShaderModule
Format :: vk.Format

cmd_begin_rendering :: gpu.cmd_begin_rendering
cmd_bind_graphics_pipeline :: gpu.cmd_bind_graphics_pipeline
cmd_push_constants :: gpu.cmd_push_constants
cmd_bind_index_buffer :: gpu.cmd_bind_index_buffer
cmd_draw_indexed :: gpu.cmd_draw_indexed
cmd_end_rendering :: gpu.cmd_end_rendering

time :: platform.time

mouse_delta :: platform.mouse_delta
scroll_delta :: platform.scroll_delta
is_mouse_down :: platform.is_mouse_down
is_key_down :: platform.is_key_down

@(require_results)
create_buffer :: #force_inline proc(
	engine: ^Engine,
	$T: typeid,
	#any_int size: vk.DeviceSize = 1,
	buffer_kind: Buffer_Kind = .Storage,
) -> (
	buffer: Buffer(T),
	err: Error,
) {
	buffer = gpu.create_buffer(&engine.device, T, size, buffer_kind) or_return
	return
}

destroy_buffer :: #force_inline proc(engine: ^Engine, buffer: ^Buffer($T)) {
	gpu.destroy_buffer(&engine.device, buffer)
}

@(require_results)
create_texture :: #force_inline proc(
	engine: ^Engine,
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
	image: Image,
	err: Error,
) {
	image = gpu.create_image(
		&engine.device,
		gpu.image_create_info(
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
		),
	) or_return
	return
}

destroy_texture :: #force_inline proc(engine: ^Engine, image: ^Image) {
	gpu.destroy_image(&engine.device, image)
}

begin_frame :: #force_inline proc(engine: ^Engine) -> (frame: Frame, err: Error) {
	frame = gpu.begin_frame(&engine.device) or_return
	return
}

end_frame :: #force_inline proc(engine: ^Engine, frame: Frame) -> (err: Error) {
	gpu.end_frame(&engine.device, frame) or_return
	return
}

immediate_transfer_begin :: #force_inline proc(engine: ^Engine) -> (cmd: Command_Buffer, err: Error) {
	cmd = gpu.immediate_transfer_begin(&engine.device) or_return
	return
}

immediate_transfer_end :: #force_inline proc(engine: ^Engine) -> (err: Error) {
	gpu.immediate_transfer_end(&engine.device) or_return
	return
}

create_shader :: #force_inline proc(
	engine: ^Engine,
	file_name: string,
	allocator: runtime.Allocator,
) -> (
	shader: Shader_Module,
	err: Error,
) {
	shader = gpu.load_shader_module(&engine.device, file_name, allocator) or_return
	return
}

destroy_shader :: #force_inline proc(engine: ^Engine, shader: Shader_Module) {
	gpu.destroy_shader_module(&engine.device, shader)
}

create_graphics_pipeline :: #force_inline proc(
	engine: ^Engine,
	shader: vk.ShaderModule,
	push_constants: typeid,
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
	pipeline: Graphics_Pipeline,
	err: Error,
) {
	pipeline = gpu.create_graphics_pipeline(
		&engine.device,
		gpu.pipeline_create_info(
			shader,
			push_constants,
			input_topology,
			polygon_mode,
			front_face,
			depth_config,
			cull_mode,
			color_format,
			blend_mode,
			vertex_entry,
			fragment_entry,
		),
	) or_return
	return
}

destroy_pipeline :: #force_inline proc(engine: ^Engine, pipeline: ^Graphics_Pipeline) {
	gpu.destroy_pipeline(&engine.device, pipeline)
}

@(require_results)
write_staging_buffer_slice :: #force_inline proc(
	engine: ^Engine,
	cmd: Command_Buffer,
	buffer: ^Buffer($T),
	in_data: []$U,
	offset: vk.DeviceSize = 0,
	loc := #caller_location,
) -> (
	err: Error,
) {
	gpu.write_staging_buffer_slice(&engine.device, cmd, buffer, in_data, offset, loc) or_return
	return
}

@(require_results)
write_staging_image_slice :: #force_inline proc(
	engine: ^Engine,
	cmd: Command_Buffer,
	image: ^Image,
	in_data: []$T,
	offset: vk.DeviceSize = 0,
	loc := #caller_location,
) -> (
	err: Error,
) {
	gpu.write_staging_image(&engine.device, cmd, image, in_data, offset, loc) or_return
	return
}
