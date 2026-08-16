package velux

import vk "vendor:vulkan"

Bindless :: struct {
	pool:             vk.DescriptorPool,
	layout:           vk.DescriptorSetLayout,
	set:              vk.DescriptorSet,
	default_sampler:  vk.Sampler,
	// Reused before the table grows.
	free:             [dynamic]u32,
	next_index:       u32,
	// Released slots point here, so a shader reading a stale index samples an
	// obvious wrong colour instead of a destroyed VkImageView.
	placeholder:      GPU_Image,
	placeholder_view: vk.ImageView,
}

@(private)
create_bindless :: proc(device: ^GPU_Device) {
	create_bindless_pool(device)
	create_bindless_layout(device)
	allocate_bindless_set(device)
	device.bindless.default_sampler = create_sampler(.NEAREST, .REPEAT)
	create_bindless_placeholder(device)
}

@(private)
destroy_bindless :: proc(device: ^GPU_Device) {
	// Skip the release path: pointing the slot at the placeholder's own view
	// while destroying that view is circular.
	device.bindless.placeholder.bindless_index = NO_BINDLESS_INDEX
	destroy_gpu_image(&device.bindless.placeholder)

	delete(device.bindless.free)
	vk.DestroySampler(device.device, device.bindless.default_sampler, nil)
	vk.DestroyDescriptorSetLayout(device.device, device.bindless.layout, nil)
	vk.DestroyDescriptorPool(device.device, device.bindless.pool, nil)
}

@(private)
create_bindless_placeholder :: proc(device: ^GPU_Device) {
	device.bindless.placeholder = create_gpu_image(.R8G8B8A8_UNORM, {1, 1, 1}, {.SAMPLED, .TRANSFER_DST})
	device.bindless.placeholder_view = device.bindless.placeholder.view

	cmd := upload_begin()
	cmd_transition_image(cmd, device.bindless.placeholder.handle, {.COLOR}, .UNDEFINED, .TRANSFER_DST_OPTIMAL)

	magenta: vk.ClearColorValue = {
		float32 = {1, 0, 1, 1},
	}
	range := init_image_subresource_range({.COLOR}, 1, 1)
	vk.CmdClearColorImage(cmd, device.bindless.placeholder.handle, .TRANSFER_DST_OPTIMAL, &magenta, 1, &range)

	cmd_transition_image(cmd, device.bindless.placeholder.handle, {.COLOR}, .TRANSFER_DST_OPTIMAL, .SHADER_READ_ONLY_OPTIMAL)
	upload_end()
}

@(private)
register_bindless :: proc(device: ^GPU_Device, view: vk.ImageView, loc := #caller_location) -> u32 {
	index: u32
	if len(device.bindless.free) > 0 {
		index = pop(&device.bindless.free)
	} else {
		if device.bindless.next_index >= MAX_TEXTURES {
			fatal("bindless table full: %d live textures and none freed, MAX_TEXTURES is %d", device.bindless.next_index, MAX_TEXTURES, loc = loc)
		}
		index = device.bindless.next_index
		device.bindless.next_index += 1
	}

	write_bindless_slot(device, index, view)
	return index
}

// Caller must ensure the GPU is not still reading this slot; destroy_gpu_image
// has the same requirement for the image itself.
@(private)
release_bindless :: proc(device: ^GPU_Device, index: u32) {
	if index == NO_BINDLESS_INDEX do return
	if device.bindless.placeholder_view == 0 do return

	write_bindless_slot(device, index, device.bindless.placeholder_view)
	append(&device.bindless.free, index)
}

@(private)
write_bindless_slot :: proc(device: ^GPU_Device, index: u32, view: vk.ImageView) {
	image_info: vk.DescriptorImageInfo = {
		sampler     = device.bindless.default_sampler,
		imageView   = view,
		imageLayout = .SHADER_READ_ONLY_OPTIMAL,
	}

	write: vk.WriteDescriptorSet = {
		sType           = .WRITE_DESCRIPTOR_SET,
		dstSet          = device.bindless.set,
		dstBinding      = 0,
		dstArrayElement = index,
		descriptorCount = 1,
		descriptorType  = .COMBINED_IMAGE_SAMPLER,
		pImageInfo      = &image_info,
	}

	vk.UpdateDescriptorSets(device.device, 1, &write, 0, nil)
}

@(private)
create_bindless_layout :: proc(device: ^GPU_Device) {
	binding_flags: vk.DescriptorBindingFlags = {.UPDATE_AFTER_BIND, .PARTIALLY_BOUND}
	flags_info: vk.DescriptorSetLayoutBindingFlagsCreateInfo = {
		sType         = .DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO,
		bindingCount  = 1,
		pBindingFlags = &binding_flags,
	}

	bindings: vk.DescriptorSetLayoutBinding = {
		binding         = 0,
		descriptorType  = .COMBINED_IMAGE_SAMPLER,
		stageFlags      = {.VERTEX, .FRAGMENT},
		descriptorCount = MAX_TEXTURES,
	}

	layout_info: vk.DescriptorSetLayoutCreateInfo = {
		sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		pNext        = &flags_info,
		flags        = {.UPDATE_AFTER_BIND_POOL},
		bindingCount = 1,
		pBindings    = &bindings,
	}

	vk_assert(vk.CreateDescriptorSetLayout(device.device, &layout_info, nil, &device.bindless.layout), "vkCreateDescriptorSetLayout")
}

@(private)
create_bindless_pool :: proc(device: ^GPU_Device) {
	pool_size: vk.DescriptorPoolSize = {
		type            = .COMBINED_IMAGE_SAMPLER,
		descriptorCount = MAX_TEXTURES,
	}

	pool_info: vk.DescriptorPoolCreateInfo = {
		sType         = .DESCRIPTOR_POOL_CREATE_INFO,
		flags         = {.UPDATE_AFTER_BIND},
		maxSets       = 1,
		poolSizeCount = 1,
		pPoolSizes    = &pool_size,
	}

	vk_assert(vk.CreateDescriptorPool(device.device, &pool_info, nil, &device.bindless.pool), "vkCreateDescriptorPool")
}

@(private)
allocate_bindless_set :: proc(device: ^GPU_Device) {
	alloc_info: vk.DescriptorSetAllocateInfo = {
		sType              = .DESCRIPTOR_SET_ALLOCATE_INFO,
		descriptorPool     = device.bindless.pool,
		descriptorSetCount = 1,
		pSetLayouts        = &device.bindless.layout,
	}

	vk_assert(vk.AllocateDescriptorSets(device.device, &alloc_info, &device.bindless.set), "vkAllocateDescriptorSets")
}
