package velux

import vk "vendor:vulkan"

Render_Target :: struct {
	image:        GPU_Image,
	depth:        GPU_Image,
	extent:       [2]u32,
	color_format: Format,
	depth_format: Format,
}

Render_Target_Info :: struct {
	width:        u32,
	height:       u32,
	color_format: Format,
	depth_format: Format,
}

create_render_target :: proc(
	width, height: u32,
	color_format: Format = .R8G8B8A8_UNORM,
	depth_format: Format = DEFAULT_DEPTH_FORMAT,
	loc := #caller_location,
) -> Render_Target {
	return bound_api(loc).gpu.create_render_target(render_target_create_info(width, height, color_format, depth_format))
}

destroy_render_target :: proc(target: ^Render_Target, loc := #caller_location) {
	bound_api(loc).gpu.destroy_render_target(target)
}

@(private)
host_create_render_target :: proc(create_info: Render_Target_Info) -> (rt: Render_Target) {
	extent := vk.Extent3D{create_info.width, create_info.height, 1}
	rt.image = host_create_image(image_create_info(create_info.color_format, extent, {.SAMPLED, .COLOR_ATTACHMENT}))
	rt.depth = host_create_image(image_create_info(create_info.depth_format, extent, {.DEPTH_STENCIL_ATTACHMENT}))
	rt.extent = {create_info.width, create_info.height}
	rt.color_format = create_info.color_format
	rt.depth_format = create_info.depth_format
	return
}

@(private)
host_destroy_render_target :: proc(target: ^Render_Target) {
	wait_for_idle()
	destroy_gpu_image(&target.image)
	destroy_gpu_image(&target.depth)
	target^ = {}
}
