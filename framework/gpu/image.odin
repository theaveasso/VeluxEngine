package gpu

import vma "third_party:odin-vma"
import vk "vendor:vulkan"

Image :: struct {
	handle:       vk.Image,
	view:         vk.ImageView,
	allocation:   vma.Allocation,
	format:       vk.Format,
	extent:       vk.Extent3D,
	mip_levels:   u32,
	array_layers: u32,
}

Image_Create_Info :: struct {
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

@(require_results)
create_image :: proc(device: ^Device, create_info: Image_Create_Info, loc := #caller_location) -> (image: Image, err: Error) {
	context.logger = device.logger
	defer if err != .None do destroy_image(device, &image)

	image_info: vk.ImageCreateInfo = {
		sType       = .IMAGE_CREATE_INFO,
		pNext       = nil,
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

	vk_check(vma.CreateImage(device.vma_allocator, &image_info, &allocation_info, &image.handle, &image.allocation, nil)) or_return

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
		subresourceRange = init_image_subresource_range(
			vk_aspect_of_format(create_info.format),
			create_info.mip_levels,
			create_info.array_layers,
		),
	}

	vk_check(vk.CreateImageView(device.device, &view_info, nil, &image.view)) or_return

	image.extent = create_info.extent
	image.format = create_info.format
	image.mip_levels = create_info.mip_levels
	image.array_layers = create_info.array_layers
	return image, .None
}

destroy_image :: proc(device: ^Device, image: ^Image) {
	vk.DestroyImageView(device.device, image.view, nil)
	vma.DestroyImage(device.vma_allocator, image.handle, image.allocation)
	image^ = {}
}

create_sampler :: proc(
	device: ^Device,
	filter: vk.Filter,
	address_mode: vk.SamplerAddressMode,
	compare_op: vk.CompareOp = .NEVER,
	border_color: vk.BorderColor = .FLOAT_TRANSPARENT_BLACK,
	max_lod: f32 = 1.0,
	max_anisotropy: f32 = 1.0,
) -> (
	sampler: vk.Sampler,
	err: Error,
) {
	sampler_info: vk.SamplerCreateInfo = {
		sType            = .SAMPLER_CREATE_INFO,
		pNext            = nil,
		minFilter        = filter,
		magFilter        = filter,
		mipmapMode       = .LINEAR,
		addressModeU     = address_mode,
		addressModeV     = address_mode,
		addressModeW     = address_mode,
		mipLodBias       = 0.0,
		anisotropyEnable = max_anisotropy > 1.0 ? true : false,
		maxAnisotropy    = max_anisotropy,
		minLod           = 0.0,
		maxLod           = max_anisotropy,
		borderColor      = border_color,
		compareOp        = compare_op,
		compareEnable    = compare_op != .NEVER,
	}

	vk_check(vk.CreateSampler(device.device, &sampler_info, nil, &sampler)) or_return
	return sampler, .None
}

@(require_results)
write_staging_image :: proc(
	device: ^Device,
	cmd: vk.CommandBuffer,
	image: ^Image,
	in_data: []$T,
	offset: vk.DeviceSize = 0,
	loc := #caller_location,
) -> (
	err: Error = .None,
) {
	assert(image.view != 0, "image is missing a valid view", loc)

	size := size_of(T) * len(in_data)
	gpu_size := image.extent.width * image.extent.height * image.extent.depth * size_of(T)
	assert(gpu_size >= cast(u32)size + cast(u32)offset, "size of the data and offset is larger than the buffer", loc)

	staging := create_buffer(device, u8, size, .Staging) or_return
	write_buffer_slice(&staging, in_data, offset, loc)
	append(&device.imm_transfer_ctx.staging_buffers, staging)

	aspect := vk_aspect_of_format(image.format)
	cmd_transition_image(cmd, image.handle, aspect, .UNDEFINED, .TRANSFER_DST_OPTIMAL)

	region := init_buffer_image_copy2(image.extent, init_image_subresource_layers(aspect, image.mip_levels, image.array_layers))
	cmd_copy_buffer_to_image2(cmd, staging.handle, image.handle, .TRANSFER_DST_OPTIMAL, &region)
	cmd_transition_image(cmd, image.handle, aspect, .TRANSFER_DST_OPTIMAL, .SHADER_READ_ONLY_OPTIMAL)
	return
}

@(require_results)
is_depth_format :: proc(format: vk.Format) -> bool {
	#partial switch format {
	case .D16_UNORM, .D32_SFLOAT, .D16_UNORM_S8_UINT, .D24_UNORM_S8_UINT, .D32_SFLOAT_S8_UINT, .X8_D24_UNORM_PACK32:
		return true
	}
	return false
}

@(require_results)
is_stencil_format :: proc(format: vk.Format) -> bool {
	#partial switch format {
	case .S8_UINT, .D16_UNORM_S8_UINT, .D24_UNORM_S8_UINT, .D32_SFLOAT_S8_UINT:
		return true
	}
	return false
}

vk_aspect_of_format :: proc(format: vk.Format) -> (flags: vk.ImageAspectFlags) {
	if !is_depth_format(format) && !is_stencil_format(format) do return {.COLOR}

	if is_depth_format(format) do flags |= {.DEPTH}
	if is_stencil_format(format) do flags |= {.STENCIL}
	return flags
}
