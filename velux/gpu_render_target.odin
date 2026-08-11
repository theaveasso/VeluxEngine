package velux

Render_Target :: struct {
	image:        GPU_Image,
	depth:        GPU_Image,
	extent:       [2]u32,
	color_format: Format,
	depth_format: Format,
}

create_render_target :: proc(
	width, height: u32,
	color_format: Format = .R8G8B8A8_UNORM,
	depth_format: Format = DEFAULT_DEPTH_FORMAT,
	loc := #caller_location,
) -> Render_Target {
	return bound_api(loc).gpu.create_render_target(width, height, color_format, depth_format)
}

destroy_render_target :: proc(target: ^Render_Target, loc := #caller_location) {
	bound_api(loc).gpu.destroy_render_target(target)
}

@(private)
host_create_render_target :: proc(
	width, height: u32,
	color_format: Format = .R8G8B8A8_UNORM,
	depth_format: Format = DEFAULT_DEPTH_FORMAT,
) -> (
	rt: Render_Target,
) {
	rt.image = create_image(image_create_info(color_format, {width, height, 1}, {.SAMPLED, .COLOR_ATTACHMENT}))
	rt.depth = create_image(image_create_info(depth_format, {width, height, 1}, {.DEPTH_STENCIL_ATTACHMENT}))
	rt.extent = {width, height}
	rt.color_format = color_format
	rt.depth_format = depth_format
	return
}

@(private)
host_destroy_render_target :: proc(target: ^Render_Target) {
	wait_for_idle()
	destroy_gpu_image(&target.image)
	destroy_gpu_image(&target.depth)
	target^ = {}
}
