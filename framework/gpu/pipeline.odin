package gpu

import "base:runtime"
import "core:log"
import "core:os"
import "core:slice"
import "core:strings"

import vk "vendor:vulkan"

Pipeline_Blend_Mode :: enum {
	None,
	Additive,
	Alpha,
}

Pipeline :: struct {
	layout:      vk.PipelineLayout,
	handle:      vk.Pipeline,
	stage_flags: vk.ShaderStageFlags,
}

Depth_Config :: struct {
	write_enabled: b32,
	compare_op:    vk.CompareOp,
	format:        vk.Format,
}

Graphics_Pipeline_Create_Info :: struct {
	push_constant_size: u32,
	input_topology:     vk.PrimitiveTopology,
	polygon_mode:       vk.PolygonMode,
	front_face:         vk.FrontFace,
	depth_config:       Depth_Config,
	color_format:       vk.Format,
	cull_mode:          vk.CullModeFlags,
	blend_mode:         Pipeline_Blend_Mode,
	vertex_entry:       cstring,
	fragment_entry:     cstring,
}

Graphics_Pipeline :: struct {
	using common: Pipeline,
	info:         Graphics_Pipeline_Create_Info,
}

@(require_results)
create_graphics_pipeline :: proc(
	device: ^Device,
	shader: vk.ShaderModule,
	create_info: Graphics_Pipeline_Create_Info,
) -> (
	pipeline: Graphics_Pipeline,
	err: Error,
) {
	context.logger = device.logger

	layout := create_pipeline_layout(device, create_info.push_constant_size) or_return
	defer if err != .None do vk.DestroyPipelineLayout(device.device, layout, nil)

	pipeline_builder := create_pipeline_builder()
	defer destroy_pipeline_builder(&pipeline_builder)

	vertex_entry := create_info.vertex_entry != nil ? create_info.vertex_entry : DEFAULT_VERTEX_ENTRY
	fragment_entry := create_info.fragment_entry != nil ? create_info.fragment_entry : DEFAULT_FRAGMENT_ENTRY

	pipeline_builder_set_layout(&pipeline_builder, layout)
	pipeline_builder_set_shaders(&pipeline_builder, shader, vertex_entry, fragment_entry)
	pipeline_builder_set_topology(&pipeline_builder, create_info.input_topology)
	pipeline_builder_set_polygon_mode(&pipeline_builder, create_info.polygon_mode)
	pipeline_builder_set_cull_mode(&pipeline_builder, create_info.cull_mode, create_info.front_face)
	pipeline_builder_multisampling_none(&pipeline_builder) // TODO: support multisampling
	pipeline_builder_disable_blending(&pipeline_builder)
	pipeline_builder_set_attachment_format(&pipeline_builder, create_info.color_format)

	depth_config := create_info.depth_config
	if depth_config.format == .UNDEFINED {
		pipeline_builder_disabled_depth_test(&pipeline_builder)
	} else {
		pipeline_builder_enable_depth_test(&pipeline_builder, depth_config.write_enabled, depth_config.compare_op)
		pipeline_builder_set_depth_format(&pipeline_builder, depth_config.format)
	}

	handle := pipeline_builder_build_pipeline(device.device, &pipeline_builder) or_return

	info := create_info
	info.vertex_entry = strings.clone_to_cstring(string(vertex_entry))
	info.fragment_entry = strings.clone_to_cstring(string(fragment_entry))

	return {layout = layout, handle = handle, stage_flags = {.VERTEX, .FRAGMENT}, info = info}, .None
}

destroy_pipeline :: proc {
	destroy_graphics_pipeline,
}

destroy_graphics_pipeline :: proc(device: ^Device, pipeline: ^Graphics_Pipeline) {
	delete(pipeline.info.vertex_entry)
	delete(pipeline.info.fragment_entry)
	vk.DestroyPipelineLayout(device.device, pipeline.layout, nil)
	vk.DestroyPipeline(device.device, pipeline.handle, nil)
	pipeline^ = {}
}

@(private, require_results)
create_pipeline_layout :: proc(
	device: ^Device,
	push_constant_size: u32,
	stage_flags: vk.ShaderStageFlags = {.VERTEX, .FRAGMENT},
) -> (
	layout: vk.PipelineLayout,
	err: Error,
) {

	layout_info: vk.PipelineLayoutCreateInfo = {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
	}

	range: vk.PushConstantRange

	if push_constant_size != 0 {
		range.offset = 0
		range.size = push_constant_size
		range.stageFlags = stage_flags

		layout_info.pushConstantRangeCount = 1
		layout_info.pPushConstantRanges = &range
	}

	layout_info.setLayoutCount = 1
	layout_info.pSetLayouts = &device.bindless.layout

	vk_check(vk.CreatePipelineLayout(device.device, &layout_info, nil, &layout), .Vulkan_Call_Failed) or_return
	return layout, .None
}

@(require_results)
load_shader_module :: proc(
	device: ^Device,
	file_name: string,
	allocator: runtime.Allocator,
	loc := #caller_location,
) -> (
	vk.ShaderModule,
	Error,
) {
	context.logger = device.logger

	buffer, err := os.read_entire_file(file_name, allocator)
	if err != nil {
		log.errorf("read_entire_file '%v' failed: %v", file_name, err)
		return 0, .File_Read_Failed
	}
	defer delete(buffer, allocator)

	return load_shader_module_from_bytes(device, buffer)
}

@(private, require_results)
load_shader_module_from_bytes :: proc(device: ^Device, bytes: []u8) -> (vk.ShaderModule, Error) {
	if len(bytes) % 4 != 0 do return 0, .Invalid_Handle

	shader_info: vk.ShaderModuleCreateInfo = {
		sType    = .SHADER_MODULE_CREATE_INFO,
		codeSize = len(bytes),
		pCode    = raw_data(slice.reinterpret([]u32, bytes)),
	}

	module: vk.ShaderModule
	result := vk.CreateShaderModule(device.device, &shader_info, nil, &module)
	if result != .SUCCESS {
		return 0, .Vulkan_Call_Failed
	}

	return module, .None
}

destroy_shader_module :: proc(device: ^Device, module: vk.ShaderModule) {
	vk.DestroyShaderModule(device.device, module, nil)
}
