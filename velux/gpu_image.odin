package velux

import vma "third_party:odin-vma"
import vk "vendor:vulkan"

GPU_Image :: struct {
	handle:         vk.Image,
	view:           vk.ImageView,
	allocation:     vma.Allocation,
	bindless_index: u32,
	format:         vk.Format,
	extent:         vk.Extent3D,
	mip_levels:     u32,
	array_layers:   u32,
}

GPU_Image_Info :: struct {
	format:            vk.Format,
	extent:            vk.Extent3D,
	image_usage_flags: vk.ImageUsageFlags,
	mip_levels:        u32,
	array_layers:      u32,
	image_type:        vk.ImageType,
	msaa_samples:      vk.SampleCountFlags,
	tiling:            vk.ImageTiling,
	flags:             vk.ImageCreateFlags,
	alloc_flags:       vma.AllocationCreateFlags,
	usage:             vma.MemoryUsage,
}

GPU_Sampler_Info :: struct {
	filter:         vk.Filter,
	address_mode:   vk.SamplerAddressMode,
	compare_op:     vk.CompareOp,
	border_color:   vk.BorderColor,
	max_lod:        f32,
	max_anisotropy: f32,
}

create_gpu_image :: proc(
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
	loc := #caller_location,
) -> GPU_Image {
	info := image_create_info(format, extent, image_usage_flags, mip_levels, array_layers, image_type, msaa_samples, tiling, flags, alloc_flags, usage)
	return create_image(info, loc)
}

@(private)
create_image :: proc(create_info: GPU_Image_Info, loc := #caller_location) -> (image: GPU_Image) {
	device := &engine_bound(loc).gpu
	context.logger = device.logger

	image_info: vk.ImageCreateInfo = {
		sType       = .IMAGE_CREATE_INFO,
		flags       = create_info.flags,
		usage       = create_info.image_usage_flags,
		imageType   = create_info.image_type,
		format      = create_info.format,
		extent      = create_info.extent,
		mipLevels   = create_info.mip_levels,
		arrayLayers = create_info.array_layers,
		samples     = create_info.msaa_samples,
		tiling      = create_info.tiling,
	}

	allocation_info: vma.AllocationCreateInfo = {
		usage         = create_info.usage,
		requiredFlags = {.DEVICE_LOCAL},
		flags         = create_info.alloc_flags,
	}

	if result := vma.CreateImage(device.vma_allocator, &image_info, &allocation_info, &image.handle, &image.allocation, nil); result != .SUCCESS {
		fatal("vmaCreateImage failed: %v (%v %v)", result, create_info.format, create_info.extent, loc = loc)
	}

	view_type: vk.ImageViewType = .D1
	if .CUBE_COMPATIBLE in create_info.flags {
		view_type = .CUBE
	} else {
		view_type += cast(vk.ImageViewType)create_info.image_type
		if create_info.array_layers > 1 do view_type += cast(vk.ImageViewType)4
	}

	view_info: vk.ImageViewCreateInfo = {
		sType            = .IMAGE_VIEW_CREATE_INFO,
		image            = image.handle,
		format           = create_info.format,
		viewType         = view_type,
		subresourceRange = init_image_subresource_range(vk_aspect_of_format(create_info.format), create_info.mip_levels, create_info.array_layers),
	}

	vk_assert(vk.CreateImageView(device.device, &view_info, nil, &image.view), "vkCreateImageView")

	image.bindless_index = NO_BINDLESS_INDEX
	if .SAMPLED in create_info.image_usage_flags {
		image.bindless_index = register_bindless(device, image.view, loc)
	}

	image.extent = create_info.extent
	image.format = create_info.format
	image.mip_levels = create_info.mip_levels
	image.array_layers = create_info.array_layers
	return image
}

create_sampler :: proc(
	filter: vk.Filter,
	address_mode: vk.SamplerAddressMode,
	compare_op: vk.CompareOp = .NEVER,
	border_color: vk.BorderColor = .FLOAT_TRANSPARENT_BLACK,
	max_lod: f32 = 1.0,
	max_anisotropy: f32 = 1.0,
	loc := #caller_location,
) -> (
	sampler: vk.Sampler,
) {
	device := &engine_bound(loc).gpu
	create_info := sampler_create_info(filter, address_mode, compare_op, border_color, max_lod, max_anisotropy)

	sampler_info: vk.SamplerCreateInfo = {
		sType            = .SAMPLER_CREATE_INFO,
		minFilter        = create_info.filter,
		magFilter        = create_info.filter,
		mipmapMode       = .LINEAR,
		addressModeU     = create_info.address_mode,
		addressModeV     = create_info.address_mode,
		addressModeW     = create_info.address_mode,
		mipLodBias       = 0.0,
		anisotropyEnable = b32(create_info.max_anisotropy > 1.0),
		maxAnisotropy    = create_info.max_anisotropy,
		minLod           = 0.0,
		maxLod           = create_info.max_lod,
		borderColor      = create_info.border_color,
		compareOp        = create_info.compare_op,
		compareEnable    = b32(create_info.compare_op != .NEVER),
	}

	vk_assert(vk.CreateSampler(device.device, &sampler_info, nil, &sampler), "vkCreateSampler")
	return sampler
}

destroy_gpu_image :: proc(image: ^GPU_Image, loc := #caller_location) {
	device := &engine_bound(loc).gpu
	if image.handle == 0 do return

	release_bindless(device, image.bindless_index)
	vk.DestroyImageView(device.device, image.view, nil)
	vma.DestroyImage(device.vma_allocator, image.handle, image.allocation)
	image^ = {}
}

write_image :: proc(cmd: Command_Buffer, image: ^GPU_Image, pixels: []u8, loc := #caller_location) {
	device := &engine_bound(loc).gpu
	context.logger = device.logger

	expected := int(image.extent.width * image.extent.height * image.extent.depth) * bytes_per_pixel(image.format, loc)
	if len(pixels) != expected {
		fatal(
			"image write of %v bytes does not match a %vx%vx%v %v image, which needs %v bytes",
			len(pixels),
			image.extent.width,
			image.extent.height,
			image.extent.depth,
			image.format,
			expected,
			loc = loc,
		)
	}

	staging := create_gpu_buffer(u8, len(pixels), .Staging, loc)
	write_buffer_slice(&staging, pixels, 0, loc)
	append(&device.transfer.staging_buffers, staging)

	cmd_transition_image(cmd, image.handle, {.COLOR}, .UNDEFINED, .TRANSFER_DST_OPTIMAL)
	region := init_buffer_image_copy2(image.extent, init_image_subresource_layers({.COLOR}))
	cmd_copy_buffer_to_image2(cmd, staging.handle, image.handle, .TRANSFER_DST_OPTIMAL, &region)
	cmd_transition_image(cmd, image.handle, {.COLOR}, .TRANSFER_DST_OPTIMAL, .SHADER_READ_ONLY_OPTIMAL)
}

@(private)
is_depth_format :: proc(format: vk.Format) -> bool {
	#partial switch format {
	case .D16_UNORM, .D32_SFLOAT, .D16_UNORM_S8_UINT, .D24_UNORM_S8_UINT, .D32_SFLOAT_S8_UINT, .X8_D24_UNORM_PACK32:
		return true
	}
	return false
}

@(private)
is_stencil_format :: proc(format: vk.Format) -> bool {
	#partial switch format {
	case .S8_UINT, .D16_UNORM_S8_UINT, .D24_UNORM_S8_UINT, .D32_SFLOAT_S8_UINT:
		return true
	}
	return false
}

@(private)
vk_aspect_of_format :: proc(format: vk.Format) -> (flags: vk.ImageAspectFlags) {
	if !is_depth_format(format) && !is_stencil_format(format) do return {.COLOR}

	if is_depth_format(format) do flags |= {.DEPTH}
	if is_stencil_format(format) do flags |= {.STENCIL}
	return flags
}

@(private)
bytes_per_pixel :: proc(format: vk.Format, loc := #caller_location) -> int {
	#partial switch format {
	case .R8G8B8A8_UNORM, .R8G8B8A8_SRGB:
		return 4
	}
	fatal("no byte size known for %v; add it to bytes_per_pixel before uploading to that format", format, loc = loc)
}
