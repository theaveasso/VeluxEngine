#+private

package gpu

import "core:log"
import vk "vendor:vulkan"

Pipeline_Builder :: struct {
	shader_stages:           [dynamic]vk.PipelineShaderStageCreateInfo,
	input_assembly:          vk.PipelineInputAssemblyStateCreateInfo,
	rasterizer:              vk.PipelineRasterizationStateCreateInfo,
	multisampling:           vk.PipelineMultisampleStateCreateInfo,
	depth_stencil:           vk.PipelineDepthStencilStateCreateInfo,
	color_blend_attachment:  vk.PipelineColorBlendAttachmentState,
	color_attachment_format: vk.Format,
	pipeline_layout:         vk.PipelineLayout,
	render_info:             vk.PipelineRenderingCreateInfo,
}

create_pipeline_builder :: proc() -> Pipeline_Builder {
	pipeline_builder: Pipeline_Builder
	pipeline_builder_clear(&pipeline_builder)
	return pipeline_builder
}

destroy_pipeline_builder :: proc(builder: ^Pipeline_Builder) {
	delete(builder.shader_stages)
}

pipeline_builder_clear :: proc(builder: ^Pipeline_Builder) {
	clear(&builder.shader_stages)
	builder.input_assembly.sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO
	builder.rasterizer.sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO
	builder.multisampling.sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
	builder.depth_stencil.sType = .PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO
	builder.color_blend_attachment = {}
	builder.color_attachment_format = {}
	builder.pipeline_layout = {}
	builder.render_info.sType = .PIPELINE_RENDERING_CREATE_INFO
}

pipeline_builder_set_shaders :: proc(
	builder: ^Pipeline_Builder,
	shader: vk.ShaderModule,
	vertex_entry: cstring = DEFAULT_VERTEX_ENTRY,
	fragment_entry: cstring = DEFAULT_FRAGMENT_ENTRY,
) {
	clear(&builder.shader_stages)
	vertex_info: vk.PipelineShaderStageCreateInfo = {
		sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage  = {.VERTEX},
		module = shader,
		pName  = vertex_entry,
	}
	append(&builder.shader_stages, vertex_info)
	fragment_info: vk.PipelineShaderStageCreateInfo = {
		sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage  = {.FRAGMENT},
		module = shader,
		pName  = fragment_entry,
	}
	append(&builder.shader_stages, fragment_info)
}

pipeline_builder_set_topology :: proc(builder: ^Pipeline_Builder, topology: vk.PrimitiveTopology) {
	builder.input_assembly.topology = topology
	builder.input_assembly.primitiveRestartEnable = false
}

pipeline_builder_set_polygon_mode :: proc(builder: ^Pipeline_Builder, mode: vk.PolygonMode) {
	builder.rasterizer.polygonMode = mode
	builder.rasterizer.lineWidth = 1.0
}

pipeline_builder_set_cull_mode :: proc(builder: ^Pipeline_Builder, cull_mode: vk.CullModeFlags, front_face: vk.FrontFace) {
	builder.rasterizer.cullMode = cull_mode
	builder.rasterizer.frontFace = front_face
}

pipeline_builder_multisampling_none :: proc(builder: ^Pipeline_Builder) {
	builder.multisampling.sampleShadingEnable = false
	builder.multisampling.rasterizationSamples = {._1}
	builder.multisampling.minSampleShading = 1.0
	builder.multisampling.pSampleMask = nil
	builder.multisampling.alphaToCoverageEnable = false
	builder.multisampling.alphaToOneEnable = false
}

pipeline_builder_disable_blending :: proc(builder: ^Pipeline_Builder) {
	builder.color_blend_attachment.colorWriteMask = {.R, .G, .B, .A}
	builder.color_blend_attachment.blendEnable = false
}

pipeline_builder_disabled_depth_test :: proc(builder: ^Pipeline_Builder) {
	builder.depth_stencil.depthTestEnable = false
	builder.depth_stencil.depthWriteEnable = false
	builder.depth_stencil.depthCompareOp = .NEVER
	builder.depth_stencil.depthBoundsTestEnable = false
	builder.depth_stencil.stencilTestEnable = false
	builder.depth_stencil.front = {}
	builder.depth_stencil.back = {}
	builder.depth_stencil.minDepthBounds = 0.0
	builder.depth_stencil.maxDepthBounds = 1.0
}

pipeline_builder_enable_depth_test :: proc(builder: ^Pipeline_Builder, depth_write_enable: b32, op: vk.CompareOp) {
	builder.depth_stencil.depthTestEnable = true
	builder.depth_stencil.depthWriteEnable = depth_write_enable
	builder.depth_stencil.depthCompareOp = op
	builder.depth_stencil.depthBoundsTestEnable = false
	builder.depth_stencil.stencilTestEnable = false
	builder.depth_stencil.front = {}
	builder.depth_stencil.back = {}
	builder.depth_stencil.minDepthBounds = 0.0
	builder.depth_stencil.maxDepthBounds = 1.0
}

pipeline_builder_set_depth_format :: proc(builder: ^Pipeline_Builder, format: vk.Format) {
	builder.render_info.depthAttachmentFormat = format
}

pipeline_builder_set_attachment_format :: proc(builder: ^Pipeline_Builder, format: vk.Format) {
	builder.color_attachment_format = format

	builder.render_info.colorAttachmentCount = 1
	builder.render_info.pColorAttachmentFormats = &builder.color_attachment_format
}

pipeline_builder_set_layout :: proc(builder: ^Pipeline_Builder, layout: vk.PipelineLayout) {
	builder.pipeline_layout = layout
}

@(require_results)
pipeline_builder_build_pipeline :: proc(device: vk.Device, builder: ^Pipeline_Builder, loc := #caller_location) -> (vk.Pipeline, Error) {
	viewport_state: vk.PipelineViewportStateCreateInfo = {
		sType         = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
		viewportCount = 1,
		scissorCount  = 1,
	}

	color_blending: vk.PipelineColorBlendStateCreateInfo = {
		sType           = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
		logicOpEnable   = false,
		logicOp         = .COPY,
		attachmentCount = 1,
		pAttachments    = &builder.color_blend_attachment,
	}

	vertex_input_info: vk.PipelineVertexInputStateCreateInfo = {
		sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
	}

	state := []vk.DynamicState{.VIEWPORT, .SCISSOR}
	dynamic_info: vk.PipelineDynamicStateCreateInfo = {
		sType             = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
		dynamicStateCount = cast(u32)len(state),
		pDynamicStates    = raw_data(state),
	}

	pipeline_info: vk.GraphicsPipelineCreateInfo = {
		sType               = .GRAPHICS_PIPELINE_CREATE_INFO,
		pNext               = &builder.render_info,
		stageCount          = cast(u32)len(builder.shader_stages),
		pStages             = raw_data(builder.shader_stages),
		pVertexInputState   = &vertex_input_info,
		pInputAssemblyState = &builder.input_assembly,
		pViewportState      = &viewport_state,
		pRasterizationState = &builder.rasterizer,
		pMultisampleState   = &builder.multisampling,
		pColorBlendState    = &color_blending,
		pDepthStencilState  = &builder.depth_stencil,
		layout              = builder.pipeline_layout,
		pDynamicState       = &dynamic_info,
	}

	pipeline: vk.Pipeline
	result := vk.CreateGraphicsPipelines(device, 0, 1, &pipeline_info, nil, &pipeline)
	if result != .SUCCESS {
		log.errorf("vulkan call failed :%v (%v)", result, loc)
		return 0, .Vulkan_Call_Failed
	}

	return pipeline, .None
}
