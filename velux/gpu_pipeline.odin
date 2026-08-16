package velux

import "base:runtime"
import "core:log"
import "core:os"
import "core:slice"
import "core:strings"

import vk "vendor:vulkan"

Pipeline :: struct {
	layout:      vk.PipelineLayout,
	handle:      vk.Pipeline,
	stage_flags: vk.ShaderStageFlags,
}

GPU_Depth_Config :: struct {
	write_enabled: b32,
	compare_op:    vk.CompareOp,
}

// Velux commits to reverse-z, so GREATER_OR_EQUAL is the only correct compare
// op and is not a per-pipeline choice. These three are the answers that exist.
GPU_Depth :: enum {
	Off,
	Read,
	Read_Write,
}

GPU_Winding :: enum {
	CCW,
	CW,
}

GPU_Cull :: enum {
	None,
	Back,
	Front,
}

@(private, require_results)
depth_config_from :: proc(depth: GPU_Depth) -> GPU_Depth_Config {
	switch depth {
	case .Off:
		return {}
	case .Read:
		return {write_enabled = false, compare_op = .GREATER_OR_EQUAL}
	case .Read_Write:
		return {write_enabled = true, compare_op = .GREATER_OR_EQUAL}
	}
	return {}
}

@(private, require_results)
front_face_from :: proc(winding: GPU_Winding) -> vk.FrontFace {
	return winding == .CW ? .CLOCKWISE : .COUNTER_CLOCKWISE
}

@(private, require_results)
cull_mode_from :: proc(cull: GPU_Cull) -> vk.CullModeFlags {
	switch cull {
	case .None:
		return {}
	case .Back:
		return {.BACK}
	case .Front:
		return {.FRONT}
	}
	return {}
}

GPU_Pipeline_Info :: struct {
	push_constant_size: u32,
	input_topology:     vk.PrimitiveTopology,
	polygon_mode:       vk.PolygonMode,
	front_face:         vk.FrontFace,
	depth_config:       GPU_Depth_Config,
	color_format:       vk.Format,
	depth_format:       vk.Format,
	cull_mode:          vk.CullModeFlags,
	vertex_entry:       cstring,
	fragment_entry:     cstring,
}

GPU_Pipeline :: struct {
	using common: Pipeline,
	info:         GPU_Pipeline_Info,
}

@(require_results)
create_gpu_pipeline :: proc(
	pipeline: ^GPU_Pipeline,
	slang_path: string,
	push_constant_size: u32 = 0,
	topology: vk.PrimitiveTopology = .TRIANGLE_LIST,
	polygon_mode: vk.PolygonMode = .FILL,
	winding: GPU_Winding = .CCW,
	depth: GPU_Depth = .Off,
	cull: GPU_Cull = .None,
	color_format: Format = .UNDEFINED,
	depth_format: Format = .UNDEFINED,
	vertex_entry: cstring = DEFAULT_VERTEX_ENTRY,
	fragment_entry: cstring = DEFAULT_FRAGMENT_ENTRY,
	loc := #caller_location,
) -> Error {
	info := pipeline_create_info(
		push_constant_size,
		topology,
		polygon_mode,
		front_face_from(winding),
		depth_config_from(depth),
		cull_mode_from(cull),
		color_format,
		depth_format,
		vertex_entry,
		fragment_entry,
	)

	spv_path := strings.concatenate({strings.trim_suffix(slang_path, ".slang"), ".spv"}, context.temp_allocator)

	output, compile_err := compile_slang(slang_path, spv_path, context.temp_allocator)
	if compile_err != .None {
		if output != "" do log.error(output)
		return compile_err
	}
	if output != "" do log.warn(output)

	shader := create_gpu_shader(spv_path, context.temp_allocator, loc) or_return
	defer destroy_gpu_shader(shader, loc)

	if info.color_format == .UNDEFINED do info.color_format = swapchain_format(loc)
	if info.depth_format == .UNDEFINED do info.depth_format = DEFAULT_DEPTH_FORMAT
	pipeline^ = rebuild_gpu_pipeline(shader, info, loc) or_return

	when ODIN_DEBUG do watch_shader(pipeline, slang_path, spv_path) or_return
	return .None
}

destroy_gpu_pipeline :: proc(pipeline: ^GPU_Pipeline, loc := #caller_location) {
	device := &engine_bound(loc).gpu
	if pipeline.handle == 0 do return

	delete(pipeline.info.vertex_entry)
	delete(pipeline.info.fragment_entry)
	vk.DestroyPipelineLayout(device.device, pipeline.layout, nil)
	vk.DestroyPipeline(device.device, pipeline.handle, nil)
	pipeline^ = {}
}

@(require_results)
create_gpu_shader :: proc(file_name: string, allocator: runtime.Allocator, loc := #caller_location) -> (module: vk.ShaderModule, err: Error) {
	device := &engine_bound(loc).gpu
	context.logger = device.logger

	buffer, read_err := os.read_entire_file(file_name, allocator)
	if read_err != nil {
		log.errorf("cannot read '%v': %v", file_name, read_err)
		return 0, .Asset_Not_Found
	}
	defer delete(buffer, allocator)

	if len(buffer) % 4 != 0 {
		log.errorf("'%v' is %v bytes, not a multiple of 4, so it is not SPIR-V", file_name, len(buffer))
		return 0, .Shader_Invalid
	}

	shader_info: vk.ShaderModuleCreateInfo = {
		sType    = .SHADER_MODULE_CREATE_INFO,
		codeSize = len(buffer),
		pCode    = raw_data(slice.reinterpret([]u32, buffer)),
	}

	if result := vk.CreateShaderModule(device.device, &shader_info, nil, &module); result != .SUCCESS {
		log.errorf("vkCreateShaderModule rejected '%v': %v", file_name, result)
		return 0, .Shader_Invalid
	}

	return module, .None
}

destroy_gpu_shader :: proc(module: vk.ShaderModule, loc := #caller_location) {
	device := &engine_bound(loc).gpu
	vk.DestroyShaderModule(device.device, module, nil)
}

@(private)
create_pipeline_layout :: proc(
	device: ^GPU_Device,
	push_constant_size: u32,
	stage_flags: vk.ShaderStageFlags = {.VERTEX, .FRAGMENT},
) -> (
	layout: vk.PipelineLayout,
) {
	layout_info: vk.PipelineLayoutCreateInfo = {
		sType          = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = 1,
		pSetLayouts    = &device.bindless.layout,
	}

	range: vk.PushConstantRange
	if push_constant_size != 0 {
		range = {
			offset     = 0,
			size       = push_constant_size,
			stageFlags = stage_flags,
		}
		layout_info.pushConstantRangeCount = 1
		layout_info.pPushConstantRanges = &range
	}

	vk_assert(vk.CreatePipelineLayout(device.device, &layout_info, nil, &layout), "vkCreatePipelineLayout")
	return layout
}

// Returns an error rather than dying: a shader edited during hot reload can
// produce a pipeline the driver rejects, and the caller keeps the last good one.
@(require_results)
rebuild_gpu_pipeline :: proc(shader: vk.ShaderModule, create_info: GPU_Pipeline_Info, loc := #caller_location) -> (pipeline: GPU_Pipeline, err: Error) {
	device := &engine_bound(loc).gpu
	context.logger = device.logger

	layout := create_pipeline_layout(device, create_info.push_constant_size)
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
	pipeline_builder_disable_blending(&pipeline_builder) // TODO: support blending
	pipeline_builder_set_attachment_format(&pipeline_builder, create_info.color_format)

	pipeline_builder_set_depth_format(&pipeline_builder, create_info.depth_format)

	depth_config := create_info.depth_config
	if depth_config.compare_op == .NEVER {
		pipeline_builder_disabled_depth_test(&pipeline_builder)
	} else {
		pipeline_builder_enable_depth_test(&pipeline_builder, depth_config.write_enabled, depth_config.compare_op)
	}

	handle := pipeline_builder_build_pipeline(device.device, &pipeline_builder) or_return

	info := create_info
	info.vertex_entry = strings.clone_to_cstring(string(vertex_entry))
	info.fragment_entry = strings.clone_to_cstring(string(fragment_entry))

	return {layout = layout, handle = handle, stage_flags = {.VERTEX, .FRAGMENT}, info = info}, .None
}
