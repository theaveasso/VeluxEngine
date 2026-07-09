package gpu

import vma "third_party:odin-vma"
import vk "vendor:vulkan"

Image :: struct {
	handle:       vk.Image,
	view:         vk.ImageView,
	allocation:   vma.Allocation,
	format:       vk.Format,
	extent:       vk.Extent2D,
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
create_image :: proc(
	device: ^Device,
	create_info: Image_Create_Info,
	loc := #caller_location,
) -> (
	image: Image,
	err: Error,
) {
	context.logger = device.logger
	defer if err != .None do destroy_image(device, &image)

	image_info: vk.ImageCreateInfo = {
		sType       = .IMAGE_CREATE_INFO,
		pNext       = nil,
		flags       = create_info.flags,
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

	vk_check(
		vma.CreateImage(
			device.vma_allocator,
			&image_info,
			&allocation_info,
			&image.handle,
			&image.allocation,
			nil,
		),
		.VMA_Call_Failed,
	) or_return

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

	vk_check(
		vk.CreateImageView(device.device, &view_info, nil, &image.view),
		.Vulkan_Call_Failed,
	) or_return

	return image, .None
}

destroy_image :: proc(device: ^Device, image: ^Image) {
	vk.DestroyImageView(device.device, image.view, nil)
	vma.DestroyImage(device.vma_allocator, image.handle, image.allocation)
	image^ = {}
}

@(require_results)
is_depth_format :: proc(format: vk.Format) -> bool {
	#partial switch format {
	case .D16_UNORM,
	     .D32_SFLOAT,
	     .D16_UNORM_S8_UINT,
	     .D24_UNORM_S8_UINT,
	     .D32_SFLOAT_S8_UINT,
	     .X8_D24_UNORM_PACK32:
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
