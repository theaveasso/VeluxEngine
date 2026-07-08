package gpu

import "base:runtime"
import "core:log"
import "core:os"
import "core:reflect"
import "core:slice"

import vk "vendor:vulkan"

PipelineBlendMode :: enum {
	None,
	Additive,
	Alpha,
}

Pipeline :: struct {
	layout:         vk.PipelineLayout,
	handle:         vk.Pipeline,
	stage_flags:    vk.ShaderStageFlags,
	push_constants: typeid,
}

GraphicPipelineCreateInfo :: struct {
	shader:         vk.ShaderModule,
	push_constants: typeid,
	input_topology: vk.PrimitiveTopology,
	polygon_mode:   vk.PolygonMode,
	front_face:     vk.FrontFace,
	color_format:   vk.Format,
	cull_mode:      vk.CullModeFlags,
	blend_mode:     PipelineBlendMode,
	vertex_entry:   cstring,
	fragment_entry: cstring,
}

GraphicsPipeline :: struct {
	using common: Pipeline,
}

@(require_results)
create_graphics_pipeline :: proc(
	device: ^Device,
	create_info: GraphicPipelineCreateInfo,
) -> (
	pipeline: GraphicsPipeline,
	err: Error,
) {
	context.logger = device.logger

	layout := create_pipeline_layout(device.device, create_info.push_constants) or_return
	defer if err != .None do vk.DestroyPipelineLayout(device.device, layout, nil)

	pipeline_builder := pipeline_builder_init()
	defer pipeline_builder_destroy(&pipeline_builder)

	vertex_entry :=
		create_info.vertex_entry != nil ? create_info.vertex_entry : DEFAULT_VERTEX_ENTRY
	fragment_entry :=
		create_info.fragment_entry != nil ? create_info.fragment_entry : DEFAULT_FRAGMENT_ENTRY

	pipeline_builder_set_layout(&pipeline_builder, layout)
	pipeline_builder_set_shaders(
		&pipeline_builder,
		create_info.shader,
		vertex_entry,
		fragment_entry,
	)
	pipeline_builder_set_topology(&pipeline_builder, create_info.input_topology)
	pipeline_builder_set_polygon_mode(&pipeline_builder, create_info.polygon_mode)
	pipeline_builder_set_cull_mode(
		&pipeline_builder,
		create_info.cull_mode,
		create_info.front_face,
	)
	pipeline_builder_set_multisampling_none(&pipeline_builder) // TODO: support multisampling
	pipeline_builder_set_disable_blending(&pipeline_builder)
	pipeline_builder_set_attachment_format(&pipeline_builder, create_info.color_format)

	handle := pipeline_builder_build_pipeline(device.device, &pipeline_builder) or_return

	return {
			layout = layout,
			handle = handle,
			stage_flags = {.VERTEX, .FRAGMENT},
			push_constants = create_info.push_constants,
		},
		.None
}

destroy_pipeline :: proc(device: ^Device, pipline: ^Pipeline) {
	vk.DestroyPipelineLayout(device.device, pipline.layout, nil)
	vk.DestroyPipeline(device.device, pipline.handle, nil)
	pipline^ = {}
}

@(private, require_results)
create_pipeline_layout :: proc(
	device: vk.Device,
	push_constants: typeid,
	stage_flags: vk.ShaderStageFlags = {.VERTEX, .FRAGMENT},
) -> (
	layout: vk.PipelineLayout,
	err: Error,
) {

	layout_info: vk.PipelineLayoutCreateInfo = {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
	}

	range: vk.PushConstantRange

	if push_constants != nil {
		range.offset = 0
		range.size = cast(u32)reflect.size_of_typeid(push_constants)
		range.stageFlags = stage_flags

		layout_info.pushConstantRangeCount = 1
		layout_info.pPushConstantRanges = &range
	}

	vk_check(
		vk.CreatePipelineLayout(device, &layout_info, nil, &layout),
		.Vulkan_Call_Failed,
	) or_return

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
		log.errorf("read_entire_filed '%v' failed: %v", file_name, err)
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
