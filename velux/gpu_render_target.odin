package velux

Render_Target :: struct {
	image:  GPU_Image,
	extent: [2]u32,
	format: Format,
}

create_render_target :: proc(width, height: u32, format: Format = .R8G8B8A8_UNORM) -> (rt: Render_Target) {
	rt.image = create_image(image_create_info(format, {width, height, 1}, {.SAMPLED, .COLOR_ATTACHMENT}))
	rt.extent = {width, height}
	rt.format = format
	return
}

destroy_render_target :: proc(target: ^Render_Target) {
	wait_for_idle()
	destroy_gpu_image(&target.image)
	target^ = {}
}
