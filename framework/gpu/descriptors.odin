package gpu

import vk "vendor:vulkan"

Descriptor_Binding :: struct {
	binding: u32,
	type:    vk.DescriptorType,
	count:   u32,
}

@(private, require_results)
create_descriptor_set_layout :: proc(
	device: ^Device,
	bindings: []Descriptor_Binding,
	flags: vk.DescriptorSetLayoutCreateFlags = {},
	stage_flags: vk.ShaderStageFlags = {.VERTEX, .FRAGMENT},
	loc := #caller_location,
) -> (
	set_layout: vk.DescriptorSetLayout,
	err: Error,
) {
	set_bindings: [dynamic]vk.DescriptorSetLayoutBinding
	defer delete(set_bindings)
	resize(&set_bindings, len(bindings))

	for binding, i in bindings {
		set_bindings[i] = vk.DescriptorSetLayoutBinding {
			binding         = binding.binding,
			descriptorType  = binding.type,
			descriptorCount = binding.count > 0 ? binding.count : 1,
			stageFlags      = stage_flags,
		}
	}

	set_layout_info: vk.DescriptorSetLayoutCreateInfo = {
		sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		pNext        = nil,
		flags        = flags,
		bindingCount = cast(u32)len(set_bindings),
		pBindings    = raw_data(set_bindings),
	}

	vk_check(vk.CreateDescriptorSetLayout(device.device, &set_layout_info, nil, &set_layout)) or_return
	return set_layout, .None
}

@(private, require_results)
create_descriptor_pool :: proc(device: ^Device) -> (pool: vk.DescriptorPool, err: Error) {
	pool_size: vk.DescriptorPoolSize = {
		type            = .UNIFORM_BUFFER,
		descriptorCount = MAX_FRAMES_IN_FLIGHT,
	}

	pool_info: vk.DescriptorPoolCreateInfo = {
		sType         = .DESCRIPTOR_POOL_CREATE_INFO,
		pNext         = nil,
		flags         = {.FREE_DESCRIPTOR_SET},
		maxSets       = MAX_FRAMES_IN_FLIGHT,
		poolSizeCount = 1,
		pPoolSizes    = &pool_size,
	}

	vk_check(vk.CreateDescriptorPool(device.device, &pool_info, nil, &pool)) or_return
	return pool, .None
}
