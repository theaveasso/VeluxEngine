package gpu

import vk "vendor:vulkan"

Bindless :: struct {
	pool:            vk.DescriptorPool,
	layout:          vk.DescriptorSetLayout,
	set:             vk.DescriptorSet,
	default_sampler: vk.Sampler,
	next_index:      u32,
}

@(private, require_results)
create_bindless :: proc(device: ^Device) -> (err: Error = .None) {
	defer if err != .None do destroy_bindless(device)

	create_bindless_pool(device) or_return
	create_bindless_layout(device) or_return
	allocate_bindless_set(device) or_return
	device.bindless.default_sampler = create_sampler(device, .NEAREST, .REPEAT) or_return
	return
}

destroy_bindless :: proc(device: ^Device) {
	vk.DestroySampler(device.device, device.bindless.default_sampler, nil)
	vk.DestroyDescriptorSetLayout(device.device, device.bindless.layout, nil)
	vk.DestroyDescriptorPool(device.device, device.bindless.pool, nil)
}

@(private)
register_bindless :: proc(device: ^Device, view: vk.ImageView) -> u32 {
	index := device.bindless.next_index
	assert(index < MAX_TEXTURES, "bindless texture array is full")

	image_info: vk.DescriptorImageInfo = {
		sampler     = device.bindless.default_sampler,
		imageView   = view,
		imageLayout = .SHADER_READ_ONLY_OPTIMAL,
	}

	write: vk.WriteDescriptorSet = {
		sType           = .WRITE_DESCRIPTOR_SET,
		pNext           = nil,
		dstSet          = device.bindless.set,
		dstBinding      = 0,
		dstArrayElement = index,
		descriptorCount = 1,
		descriptorType  = .COMBINED_IMAGE_SAMPLER,
		pImageInfo      = &image_info,
	}

	vk.UpdateDescriptorSets(device.device, 1, &write, 0, nil)
	device.bindless.next_index += 1
	return index
}

@(private, require_results)
create_bindless_layout :: proc(device: ^Device) -> (err: Error = .None) {
	binding_flags: vk.DescriptorBindingFlags = {.UPDATE_AFTER_BIND, .PARTIALLY_BOUND}
	flags_info: vk.DescriptorSetLayoutBindingFlagsCreateInfo = {
		sType         = .DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO,
		pNext         = nil,
		bindingCount  = 1,
		pBindingFlags = &binding_flags,
	}

	bindings: vk.DescriptorSetLayoutBinding = {
		binding            = 0,
		descriptorType     = .COMBINED_IMAGE_SAMPLER,
		stageFlags         = {.VERTEX, .FRAGMENT},
		descriptorCount    = MAX_TEXTURES,
		pImmutableSamplers = nil,
	}

	layout_info: vk.DescriptorSetLayoutCreateInfo = {
		sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		pNext        = &flags_info,
		flags        = {.UPDATE_AFTER_BIND_POOL},
		bindingCount = 1,
		pBindings    = &bindings,
	}

	vk_check(vk.CreateDescriptorSetLayout(device.device, &layout_info, nil, &device.bindless.layout)) or_return
	return
}

@(private, require_results)
create_bindless_pool :: proc(device: ^Device) -> (err: Error = .None) {
	pool_size: vk.DescriptorPoolSize = {
		type            = .COMBINED_IMAGE_SAMPLER,
		descriptorCount = MAX_TEXTURES,
	}

	pool_info: vk.DescriptorPoolCreateInfo = {
		sType         = .DESCRIPTOR_POOL_CREATE_INFO,
		pNext         = nil,
		flags         = {.UPDATE_AFTER_BIND},
		maxSets       = 1,
		poolSizeCount = 1,
		pPoolSizes    = &pool_size,
	}

	vk_check(vk.CreateDescriptorPool(device.device, &pool_info, nil, &device.bindless.pool)) or_return
	return
}

@(private, require_results)
allocate_bindless_set :: proc(device: ^Device) -> (err: Error = .None) {
	alloc_info: vk.DescriptorSetAllocateInfo = {
		sType              = .DESCRIPTOR_SET_ALLOCATE_INFO,
		descriptorPool     = device.bindless.pool,
		descriptorSetCount = 1,
		pSetLayouts        = &device.bindless.layout,
	}

	vk_check(vk.AllocateDescriptorSets(device.device, &alloc_info, &device.bindless.set)) or_return
	return
}
