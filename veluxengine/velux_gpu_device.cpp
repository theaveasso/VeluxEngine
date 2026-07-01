#include "velux_gpu_device.h"
#include "velux_common.h"
#include "velux_error.h"
#include "velux_filesystem.h"
#include "velux_gpu_vulkan.h"
#include "velux_log.h"

#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>
#include <algorithm>
#include <cstdint>
#include <expected>
#include <limits>
#include <span>
#include <string_view>
#include <utility>
#include <vector>

namespace
{
#ifdef VLX_DEBUG
#	define VLX_VULKAN_ENABLE_VALIDATION true
#else
#	define VLX_VULKAN_ENABLE_VALIDATION false
#endif

static VKAPI_ATTR vk::Bool32 VKAPI_CALL debugCallback(
    vk::DebugUtilsMessageSeverityFlagBitsEXT      severity,
    vk::DebugUtilsMessageTypeFlagsEXT             types,
    vk::DebugUtilsMessengerCallbackDataEXT const *cb_data,
    void                                         *user_data)
{
	if (severity >= vk::DebugUtilsMessageSeverityFlagBitsEXT::eWarning)
	{
		if (severity & vk::DebugUtilsMessageSeverityFlagBitsEXT::eWarning)
		{
			VLX_LOGW("{}", cb_data->pMessage);
		}
		else if (severity & vk::DebugUtilsMessageSeverityFlagBitsEXT::eError)
		{
			VLX_LOGE("{}", cb_data->pMessage);
		}
	}
	return vk::False;
}

constexpr uint32_t VLX_QUEUE_NONE = UINT32_MAX;

auto collectNames(std::span<const vk::LayerProperties> props) -> std::vector<std::string_view>;
auto collectNames(std::span<const vk::ExtensionProperties> props) -> std::vector<std::string_view>;
auto enableIfAvailable(std::span<const std::string_view> available, const char *name, std::vector<const char *> &out) -> bool;

[[nodiscard]] auto contains(std::span<const std::string_view> names, std::string_view wanted) -> bool;
[[nodiscard]] auto isDeviceSuitable(vkr::PhysicalDevice const &physcial_device, std::span<const char *> required_device_exts) -> bool;
[[nodiscard]] auto findQueueFamilies(vkr::Instance const &instance, vkr::PhysicalDevice const &physical_device, uint32_t *graphics, uint32_t *present) -> bool;

[[nodiscard]] auto chooseSwapchainSurfaceFormat(std::span<vk::SurfaceFormatKHR> avail) -> vk::SurfaceFormatKHR;
[[nodiscard]] auto chooseSwapchainPresentMode(std::span<vk::PresentModeKHR> avail) -> vk::PresentModeKHR;
[[nodiscard]] auto chooseSwapchainExtent(vk::SurfaceCapabilitiesKHR const &capabilites, int fbw, int fbh) -> vk::Extent2D;
[[nodiscard]] auto chooseSwapchainMinImageCount(vk::SurfaceCapabilitiesKHR const &capabilites) -> uint32_t;
[[nodiscard]] auto createShaderModule(vkr::Device const &device, const std::vector<char> &code) -> std::expected<vkr::ShaderModule, VlxError>;
}        // namespace

VlxGPUDevice::~VlxGPUDevice()
{
	device_.waitIdle();
}

auto VlxGPUDevice::init(GLFWwindow *window) -> std::expected<void, VlxError>
{
	return createInstance()
	    .and_then([this] { return setupDebugMessenger(); })
	    .and_then([this, window] { return createSurface(window); })
	    .and_then([this] { return pickPhysicalDevice(); })
	    .and_then([this] { return createLogicalDevice(); })
	    .and_then([this, window] { return createSwapchain(window); })
	    .and_then([this] { return createImageViews(); })
	    .and_then([this] { return createGraphicsPipeline(); })
	    .and_then([this] { return createCommandPool(); })
	    .and_then([this] { return allocateCommandBuffer(); })
	    .and_then([this] { return createSyncObjects(); });
}

auto VlxGPUDevice::createInstance() -> std::expected<void, VlxError>
{
	vk::ApplicationInfo app_info{
	    .pApplicationName   = "VeluxGame",
	    .applicationVersion = vk::makeVersion(0, 1, 0),
	    .pEngineName        = "VeluxEngine",
	    .engineVersion      = vk::makeVersion(0, 1, 0),
	    .apiVersion         = vk::ApiVersion14,
	};

	VLX_ASSIGN_OR_RETURN(
	    auto layer_props,
	    vlx::vkExpected(context_.enumerateInstanceLayerProperties()));
	const auto avail_layers = collectNames(layer_props);

	std::vector<const char *> layers;
	enableIfAvailable(avail_layers, "VK_LAYER_LUNARG_monitor", layers);
	enableIfAvailable(avail_layers, "VK_LAYER_KHRONOS_shader_object", layers);
	if (VLX_VULKAN_ENABLE_VALIDATION)
	{
		enableIfAvailable(avail_layers, "VK_LAYER_KHRONOS_validation", layers);
	}

	VLX_ASSIGN_OR_RETURN(
	    auto ext_props,
	    vlx::vkExpected(context_.enumerateInstanceExtensionProperties()));
	const auto avail_exts = collectNames(ext_props);

	std::vector<const char *> exts;
	enableIfAvailable(avail_exts, vk::KHRSurfaceMaintenance1ExtensionName, exts);
	enableIfAvailable(avail_exts, vk::KHRGetSurfaceCapabilities2ExtensionName, exts);

	std::uint32_t glfw_ext_n = 0;
	const char  **glfw_exts  = glfwGetRequiredInstanceExtensions(&glfw_ext_n);
	if (!glfw_exts)
	{
		VLX_FAIL(VlxErrorCode::Vulkan, "createInstance: glfwGetRequiredInstanceExtensions failed");
	}

	for (std::uint32_t i = 0; i < glfw_ext_n; ++i)
	{
		if (!enableIfAvailable(avail_exts, glfw_exts[i], exts))
		{
			VLX_FAIL(VlxErrorCode::Vulkan, glfw_exts[i]);
		}
	}

	if (VLX_VULKAN_ENABLE_VALIDATION)
	{
		enableIfAvailable(avail_exts, vk::EXTDebugUtilsExtensionName, exts);
	}

	vk::InstanceCreateInfo create_info{
	    .pApplicationInfo        = &app_info,
	    .enabledLayerCount       = static_cast<std::uint32_t>(layers.size()),
	    .ppEnabledLayerNames     = layers.data(),
	    .enabledExtensionCount   = static_cast<std::uint32_t>(exts.size()),
	    .ppEnabledExtensionNames = exts.data(),
	};

	VLX_ASSIGN_OR_RETURN(instance_, vlx::vkExpected(context_.createInstance(create_info)));
	VLX_OK();
}

auto VlxGPUDevice::setupDebugMessenger() -> std::expected<void, VlxError>
{
	VLX_ASSIGN_OR_RETURN(
	    auto ext_props,
	    vlx::vkExpected(context_.enumerateInstanceExtensionProperties()));
	if (!VLX_VULKAN_ENABLE_VALIDATION || !contains(collectNames(ext_props), vk::EXTDebugUtilsExtensionName))
	{
		VLX_OK();
	}

	vk::DebugUtilsMessengerCreateInfoEXT debug_info{
	    .messageSeverity = vk::DebugUtilsMessageSeverityFlagBitsEXT::eWarning |
	                       vk::DebugUtilsMessageSeverityFlagBitsEXT::eError,
	    .messageType     = vk::DebugUtilsMessageTypeFlagBitsEXT::ePerformance |
	                       vk::DebugUtilsMessageTypeFlagBitsEXT::eValidation,
	    .pfnUserCallback = &debugCallback,
	};
	VLX_ASSIGN_OR_RETURN(debug_, vlx::vkExpected(instance_.createDebugUtilsMessengerEXT(debug_info)));
	VLX_OK();
}

auto VlxGPUDevice::pickPhysicalDevice() -> std::expected<void, VlxError>
{
	VLX_ASSIGN_OR_RETURN(auto devices, vlx::vkExpected(instance_.enumeratePhysicalDevices()));
	if (devices.empty())
	{
		VLX_FAIL(VlxErrorCode::Vulkan, "no physical device");
	}

	auto const device_itr =
	    std::ranges::find_if(devices, [&](auto const &device) {
		    return isDeviceSuitable(device, required_device_exts_) &&
		           findQueueFamilies(instance_, device, &graphics_queue_family_,
		                             &present_queue_family_);
	    });
	if (device_itr == devices.end())
	{
		VLX_FAIL(VlxErrorCode::Vulkan, "no suitable physical device");
	}

	physical_device_ = std::move(*device_itr);
	device_name_     = physical_device_.getProperties().deviceName.data();
	VLX_LOGD("Vulkan selected physical device {}", device_name_);
	VLX_OK();
}

auto VlxGPUDevice::createLogicalDevice() -> std::expected<void, VlxError>
{
	vk::StructureChain<vk::PhysicalDeviceFeatures2,
	                   vk::PhysicalDeviceVulkan11Features,
	                   vk::PhysicalDeviceVulkan13Features,
	                   vk::PhysicalDeviceExtendedDynamicStateFeaturesEXT>
	                          feature_chain = {
	                              {},
	                              {.shaderDrawParameters = true},
	                              {
	                                  .synchronization2 = true,
	                                  .dynamicRendering = true,
	                              },
	                              {.extendedDynamicState = true},
	                          };
	vk::DeviceQueueCreateInfo device_queue_info{
	    .queueFamilyIndex = graphics_queue_family_,
	    .queueCount       = 1,
	    .pQueuePriorities = &queue_priority_,
	};
	vk::DeviceCreateInfo device_info{
	    .pNext                   = &feature_chain.get<vk::PhysicalDeviceFeatures2>(),
	    .queueCreateInfoCount    = 1,
	    .pQueueCreateInfos       = &device_queue_info,
	    .enabledExtensionCount   = static_cast<std::uint32_t>(required_device_exts_.size()),
	    .ppEnabledExtensionNames = required_device_exts_.data(),
	};
	VLX_ASSIGN_OR_RETURN(device_, vlx::vkExpected(physical_device_.createDevice(device_info)));
	queue_ = device_.getQueue(graphics_queue_family_, 0);
	VLX_OK();
}

auto VlxGPUDevice::createSwapchain(GLFWwindow *window) -> std::expected<void, VlxError>
{
	VLX_ASSIGN_OR_RETURN(
	    auto surface_capabilities,
	    vlx::vkExpected(physical_device_.getSurfaceCapabilitiesKHR(*surface_)));

	int fbw{}, fbh{};
	glfwGetFramebufferSize(window, &fbw, &fbh);
	swapchain_extent_ = chooseSwapchainExtent(surface_capabilities, fbw, fbh);

	VLX_ASSIGN_OR_RETURN(
	    auto formats_avail,
	    vlx::vkExpected(physical_device_.getSurfaceFormatsKHR(*surface_)));
	swapchain_surfaceformat_ = chooseSwapchainSurfaceFormat(formats_avail);

	VLX_ASSIGN_OR_RETURN(
	    auto presentmodes_avail,
	    vlx::vkExpected(physical_device_.getSurfacePresentModesKHR(*surface_)));
	auto present_mode = chooseSwapchainPresentMode(presentmodes_avail);

	auto min_image_count = chooseSwapchainMinImageCount(surface_capabilities);

	vk::SwapchainCreateInfoKHR swapchain_info{
	    .surface          = *surface_,
	    .minImageCount    = min_image_count,
	    .imageFormat      = swapchain_surfaceformat_.format,
	    .imageColorSpace  = swapchain_surfaceformat_.colorSpace,
	    .imageExtent      = swapchain_extent_,
	    .imageArrayLayers = 1,
	    .imageUsage       = vk::ImageUsageFlagBits::eColorAttachment,
	    .imageSharingMode = vk::SharingMode::eExclusive,
	    .preTransform     = surface_capabilities.currentTransform,
	    .compositeAlpha   = vk::CompositeAlphaFlagBitsKHR::eOpaque,
	    .presentMode      = present_mode,
	    .clipped          = vk::True,
	};
	VLX_ASSIGN_OR_RETURN(swapchain_, vlx::vkExpected(device_.createSwapchainKHR(swapchain_info)));
	swapchain_images_ = std::move(*swapchain_.getImages());
	VLX_OK();
}

auto VlxGPUDevice::createImageViews() -> std::expected<void, VlxError>
{
	if (!swapchain_image_views_.empty())
	{
		VLX_FAIL(VlxErrorCode::Vulkan, "swapchain image views not empty");
	}

	vk::ImageViewCreateInfo view_info{
	    .viewType         = vk::ImageViewType::e2D,
	    .format           = swapchain_surfaceformat_.format,
	    .components       = {vk::ComponentSwizzle::eIdentity,
	                         vk::ComponentSwizzle::eIdentity,
	                         vk::ComponentSwizzle::eIdentity,
	                         vk::ComponentSwizzle::eIdentity},
	    .subresourceRange = {vk::ImageAspectFlagBits::eColor, 0, 1, 0, 1},
	};
	for (auto &image : swapchain_images_)
	{
		view_info.image = image;
		VLX_ASSIGN_OR_RETURN(auto view, vlx::vkExpected(device_.createImageView(view_info)));
		swapchain_image_views_.emplace_back(std::move(view));
	}
	VLX_OK();
}

auto VlxGPUDevice::createGraphicsPipeline() -> std::expected<void, VlxError>
{
	VLX_ASSIGN_OR_RETURN(auto shader_code, vlx::readFile("assets/shaders/triangle.spv"));
	VLX_ASSIGN_OR_RETURN(vkr::ShaderModule shader_module, createShaderModule(device_, shader_code));

	vk::PipelineLayoutCreateInfo layout_info{
	    .setLayoutCount         = 0,
	    .pushConstantRangeCount = 0,
	};
	VLX_ASSIGN_OR_RETURN(vkr::PipelineLayout pipeline_layout, vlx::vkExpected(device_.createPipelineLayout(layout_info)));

	vk::PipelineShaderStageCreateInfo vert_shader_stage_info{
	    .stage  = vk::ShaderStageFlagBits::eVertex,
	    .module = shader_module,
	    .pName  = "vertMain",
	};
	vk::PipelineShaderStageCreateInfo frag_shader_stage_info{
	    .stage  = vk::ShaderStageFlagBits::eFragment,
	    .module = shader_module,
	    .pName  = "fragMain",
	};
	std::vector<vk::PipelineShaderStageCreateInfo> shader_stages = {vert_shader_stage_info, frag_shader_stage_info};

	vk::PipelineVertexInputStateCreateInfo vertex_input_state_info{};

	vk::PipelineViewportStateCreateInfo viewport_state_info{
	    .viewportCount = 1,
	    .scissorCount  = 1,
	};

	std::vector<vk::DynamicState>      dynamic_states = {vk::DynamicState::eViewport, vk::DynamicState::eScissor};
	vk::PipelineDynamicStateCreateInfo dynamic_state_info{
	    .dynamicStateCount = static_cast<uint32_t>(dynamic_states.size()),
	    .pDynamicStates    = dynamic_states.data(),
	};

	vk::PipelineInputAssemblyStateCreateInfo input_assembly_state_info{
	    .topology = vk::PrimitiveTopology::eTriangleList,
	};

	vk::PipelineRasterizationStateCreateInfo rasterization_state_info{
	    .depthClampEnable        = vk::False,
	    .rasterizerDiscardEnable = vk::False,
	    .polygonMode             = vk::PolygonMode::eFill,
	    .cullMode                = vk::CullModeFlagBits::eBack,
	    .frontFace               = vk::FrontFace::eClockwise,
	    .depthBiasEnable         = vk::False,
	    .lineWidth               = 1.0f,
	};

	vk::PipelineMultisampleStateCreateInfo multisample_state_info{
	    .rasterizationSamples = vk::SampleCountFlagBits::e1,
	    .sampleShadingEnable  = vk::False,
	};

	vk::PipelineColorBlendAttachmentState color_blending_info{
	    .blendEnable    = vk::False,
	    .colorWriteMask = vk::ColorComponentFlagBits::eR |
	                      vk::ColorComponentFlagBits::eG |
	                      vk::ColorComponentFlagBits::eB |
	                      vk::ColorComponentFlagBits::eA,
	};

	vk::PipelineColorBlendStateCreateInfo color_blend_state_info{
	    .logicOpEnable   = vk::False,
	    .logicOp         = vk::LogicOp::eCopy,
	    .attachmentCount = 1,
	    .pAttachments    = &color_blending_info,
	};

	vk::StructureChain<vk::GraphicsPipelineCreateInfo, vk::PipelineRenderingCreateInfo> pipeline_info = {
	    {
	        .stageCount          = static_cast<uint32_t>(shader_stages.size()),
	        .pStages             = shader_stages.data(),
	        .pVertexInputState   = &vertex_input_state_info,
	        .pInputAssemblyState = &input_assembly_state_info,
	        .pViewportState      = &viewport_state_info,
	        .pRasterizationState = &rasterization_state_info,
	        .pMultisampleState   = &multisample_state_info,
	        .pColorBlendState    = &color_blend_state_info,
	        .pDynamicState       = &dynamic_state_info,
	        .layout              = pipeline_layout,
	        .renderPass          = nullptr,
	    },
	    {
	        .colorAttachmentCount    = 1,
	        .pColorAttachmentFormats = &swapchain_surfaceformat_.format,
	    },
	};

	VLX_ASSIGN_OR_RETURN(
	    graphics_pipeline_,
	    vlx::vkExpected(device_.createGraphicsPipeline(
	        nullptr,
	        pipeline_info.get<vk::GraphicsPipelineCreateInfo>(),
	        nullptr)));

	VLX_OK();
}

auto VlxGPUDevice::createCommandPool() -> std::expected<void, VlxError>
{
	vk::CommandPoolCreateInfo pool_info{
	    .flags            = vk::CommandPoolCreateFlagBits::eResetCommandBuffer,
	    .queueFamilyIndex = graphics_queue_family_,
	};
	VLX_ASSIGN_OR_RETURN(command_pool_, vlx::vkExpected(device_.createCommandPool(pool_info)));
	VLX_OK();
}

auto VlxGPUDevice::allocateCommandBuffer() -> std::expected<void, VlxError>
{
	vk::CommandBufferAllocateInfo allocate_info{
	    .commandPool        = *command_pool_,
	    .level              = vk::CommandBufferLevel::ePrimary,
	    .commandBufferCount = 1,
	};
	VLX_ASSIGN_OR_RETURN(command_buffers_, vlx::vkExpected(device_.allocateCommandBuffers(allocate_info)));
	VLX_OK();
}

auto VlxGPUDevice::createSyncObjects() -> std::expected<void, VlxError>
{
	vk::SemaphoreCreateInfo semaphore_info{};
	VLX_ASSIGN_OR_RETURN(present_complete_, vlx::vkExpected(device_.createSemaphore(semaphore_info)));
	VLX_ASSIGN_OR_RETURN(render_finished_, vlx::vkExpected(device_.createSemaphore(semaphore_info)));

	vk::FenceCreateInfo fence_info{
	    .flags = vk::FenceCreateFlagBits::eSignaled,
	};
	VLX_ASSIGN_OR_RETURN(in_flight_fence_, vlx::vkExpected(device_.createFence(fence_info)));
	VLX_OK();
}

auto VlxGPUDevice::drawFrame() -> std::expected<void, VlxError>
{
	auto wait_result = device_.waitForFences(*in_flight_fence_, vk::True, UINT64_MAX);
	device_.resetFences(*in_flight_fence_);

	auto aquire_result = swapchain_.acquireNextImage(UINT64_MAX, *present_complete_, nullptr);

	recordCommandBuffer(aquire_result.value);
	queue_.waitIdle();

	vk::PipelineStageFlags wait_destination_stage_mask(vk::PipelineStageFlagBits::eColorAttachmentOutput);

	const vk::SubmitInfo submit_info{
	    .waitSemaphoreCount   = 1,
	    .pWaitSemaphores      = &*present_complete_,
	    .pWaitDstStageMask    = &wait_destination_stage_mask,
	    .commandBufferCount   = 1,
	    .pCommandBuffers      = &*command_buffers_[0],
	    .signalSemaphoreCount = 1,
	    .pSignalSemaphores    = &*render_finished_,
	};
	queue_.submit(submit_info, *in_flight_fence_);

	const vk::PresentInfoKHR present_info{
	    .waitSemaphoreCount = 1,
	    .pWaitSemaphores    = &*render_finished_,
	    .swapchainCount     = 1,
	    .pSwapchains        = &*swapchain_,
	    .pImageIndices      = &aquire_result.value,
	};
	auto present_result = queue_.presentKHR(present_info);
	VLX_OK();
}

auto VlxGPUDevice::recordCommandBuffer(uint32_t image_index) -> void
{
	command_buffers_[0].begin({});
	transitionImageLayout(
	    image_index,
	    vk::ImageLayout::eUndefined,
	    vk::ImageLayout::eColorAttachmentOptimal,
	    {},
	    vk::AccessFlagBits2::eColorAttachmentWrite,
	    vk::PipelineStageFlagBits2::eColorAttachmentOutput,
	    vk::PipelineStageFlagBits2::eColorAttachmentOutput);

	vk::ClearValue              clear_value = vk::ClearColorValue(0.0f, 0.0f, 0.0f, 1.0f);
	vk::RenderingAttachmentInfo attachment_info{
	    .imageView   = swapchain_image_views_[image_index],
	    .imageLayout = vk::ImageLayout::eColorAttachmentOptimal,
	    .loadOp      = vk::AttachmentLoadOp::eClear,
	    .storeOp     = vk::AttachmentStoreOp::eStore,
	    .clearValue  = clear_value,
	};
	vk::RenderingInfo rendering_info{
	    .renderArea           = {.offset = {0, 0}, .extent = swapchain_extent_},
	    .layerCount           = 1,
	    .colorAttachmentCount = 1,
	    .pColorAttachments    = &attachment_info,
	};

	command_buffers_[0].beginRendering(rendering_info);

	command_buffers_[0].bindPipeline(vk::PipelineBindPoint::eGraphics, graphics_pipeline_);
	command_buffers_[0].setViewport(0, vk::Viewport(0.0f, 0.0f, static_cast<float>(swapchain_extent_.width), static_cast<float>(swapchain_extent_.height)));
	command_buffers_[0].setScissor(0, vk::Rect2D(vk::Offset2D(0.0), swapchain_extent_));
	command_buffers_[0].draw(3, 1, 0, 0);

	command_buffers_[0].endRendering();

	transitionImageLayout(
	    image_index,
	    vk::ImageLayout::eColorAttachmentOptimal,
	    vk::ImageLayout::ePresentSrcKHR,
	    vk::AccessFlagBits2::eColorAttachmentWrite,
	    {},
	    vk::PipelineStageFlagBits2::eColorAttachmentOutput,
	    vk::PipelineStageFlagBits2::eBottomOfPipe);
	command_buffers_[0].end();
}

auto VlxGPUDevice::transitionImageLayout(
    uint32_t                image_index,
    vk::ImageLayout         old_layout,
    vk::ImageLayout         new_layout,
    vk::AccessFlags2        src_access_mask,
    vk::AccessFlags2        dst_access_mask,
    vk::PipelineStageFlags2 src_stage_mask,
    vk::PipelineStageFlags2 dst_stage_mask) -> void
{
	vk::ImageMemoryBarrier2 barrier{
	    .srcStageMask        = src_stage_mask,
	    .srcAccessMask       = src_access_mask,
	    .dstStageMask        = dst_stage_mask,
	    .dstAccessMask       = dst_access_mask,
	    .oldLayout           = old_layout,
	    .newLayout           = new_layout,
	    .srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
	    .dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
	    .image               = swapchain_images_[image_index],
	    .subresourceRange    = {vk::ImageAspectFlagBits::eColor, 0, 1, 0, 1},
	};
	vk::DependencyInfo dependency_info{
	    .dependencyFlags         = {},
	    .imageMemoryBarrierCount = 1,
	    .pImageMemoryBarriers    = &barrier,
	};
	command_buffers_[0].pipelineBarrier2(dependency_info);
}

auto VlxGPUDevice::createSurface(GLFWwindow *window) -> std::expected<void, VlxError>
{
	VkSurfaceKHR _surface = VK_NULL_HANDLE;
	if (glfwCreateWindowSurface(*instance_, window, nullptr, &_surface) != 0)
	{
		VLX_FAIL(VlxErrorCode::Vulkan, "createSurface failed");
	}
	surface_ = vk::raii::SurfaceKHR(instance_, _surface);
	VLX_OK();
}

namespace
{

auto collectNames(std::span<const vk::LayerProperties> props) -> std::vector<std::string_view>
{
	std::vector<std::string_view> names;
	names.reserve(props.size());
	for (const auto &p : props)
	{
		names.emplace_back(p.layerName.data());
	}
	return names;
}

auto collectNames(std::span<const vk::ExtensionProperties> props) -> std::vector<std::string_view>
{
	std::vector<std::string_view> names;
	names.reserve(props.size());
	for (const auto &p : props)
	{
		names.emplace_back(p.extensionName.data());
	}
	return names;
}

auto contains(std::span<const std::string_view> names, std::string_view wanted) -> bool
{
	return std::ranges::find(names, wanted) != names.end();
}

auto enableIfAvailable(std::span<const std::string_view> available, const char *name, std::vector<const char *> &out) -> bool
{
	if (contains(available, name))
	{
		out.emplace_back(name);
		return true;
	}
	return false;
}

auto isDeviceSuitable(vkr::PhysicalDevice const &physical_device, std::span<const char *> required_device_exts) -> bool
{
	bool supportsvk14 = physical_device.getProperties().apiVersion >= vk::ApiVersion14;

	auto exts_avail = physical_device.enumerateDeviceExtensionProperties().value;
	if (exts_avail.empty())
	{
		return false;
	}
	const auto avail_ext_names = collectNames(exts_avail);

	bool supports_all_required_exts =
	    std::ranges::all_of(required_device_exts, [&](const char *required) {
		    return contains(avail_ext_names, required);
	    });

	auto features = physical_device.getFeatures2<
	    vk::PhysicalDeviceFeatures2, vk::PhysicalDeviceVulkan11Features,
	    vk::PhysicalDeviceVulkan13Features,
	    vk::PhysicalDeviceExtendedDynamicStateFeaturesEXT>();

	bool supports_all_required_feats =
	    features.get<vk::PhysicalDeviceVulkan11Features>().shaderDrawParameters &&
	    features.get<vk::PhysicalDeviceVulkan13Features>().dynamicRendering &&
	    features.get<vk::PhysicalDeviceExtendedDynamicStateFeaturesEXT>().extendedDynamicState;

	return supportsvk14 && supports_all_required_exts && supports_all_required_feats;
}

auto findQueueFamilies(vkr::Instance const &instance, vkr::PhysicalDevice const &physical_device, uint32_t *graphics, uint32_t *present) -> bool
{
	uint32_t graphic_queue = VLX_QUEUE_NONE;
	uint32_t present_queue = VLX_QUEUE_NONE;

	auto qfps = physical_device.getQueueFamilyProperties();
	if (qfps.empty())
	{
		return false;
	}
	for (uint32_t i = 0; i < qfps.size(); ++i)
	{
		if (qfps[i].queueFlags & vk::QueueFlagBits::eGraphics && graphic_queue == VLX_QUEUE_NONE)
		{
			graphic_queue = i;
		}
		int present_ok = glfwGetPhysicalDevicePresentationSupport(*instance, *physical_device, i);
		if (present_ok && present_queue == VLX_QUEUE_NONE)
		{
			present_queue = i;
		}
		if (graphic_queue != VLX_QUEUE_NONE && present_queue != VLX_QUEUE_NONE)
		{
			break;
		}
	}
	if (graphic_queue == VLX_QUEUE_NONE || present_queue == VLX_QUEUE_NONE)
	{
		return false;
	}

	*graphics = graphic_queue;
	*present  = present_queue;
	return true;
}

auto chooseSwapchainSurfaceFormat(std::span<vk::SurfaceFormatKHR> avail) -> vk::SurfaceFormatKHR
{
	const auto format_itr = std::ranges::find_if(avail, [](const auto &format) {
		return format.format == vk::Format::eB8G8R8A8Srgb &&
		       format.colorSpace == vk::ColorSpaceKHR::eSrgbNonlinear;
	});
	return format_itr != avail.end() ? *format_itr : avail[0];
}

auto chooseSwapchainPresentMode(std::span<vk::PresentModeKHR> avail) -> vk::PresentModeKHR
{
	return std::ranges::any_of(avail,
	                           [](const vk::PresentModeKHR value) {
		                           return vk::PresentModeKHR::eMailbox == value;
	                           }) ?
	           vk::PresentModeKHR::eMailbox :
	           vk::PresentModeKHR::eFifo;
}

auto chooseSwapchainExtent(vk::SurfaceCapabilitiesKHR const &capabilites, int fbw, int fbh) -> vk::Extent2D
{
	if (capabilites.currentExtent.width != std::numeric_limits<std::uint32_t>::max())
	{
		return capabilites.currentExtent;
	}
	uint32_t width  = std::clamp<uint32_t>(fbw, capabilites.minImageExtent.width, capabilites.maxImageExtent.width);
	uint32_t height = std::clamp<uint32_t>(fbh, capabilites.minImageExtent.height, capabilites.maxImageExtent.height);
	return {.width = width, .height = height};
}

auto chooseSwapchainMinImageCount(vk::SurfaceCapabilitiesKHR const &capabilites) -> uint32_t
{
	auto min_image_count = std::max(3u, capabilites.minImageCount);
	if ((0 < capabilites.maxImageCount) && (capabilites.maxImageCount < min_image_count))
	{
		min_image_count = capabilites.maxImageCount;
	}
	return min_image_count;
}

auto createShaderModule(vkr::Device const &device, const std::vector<char> &code) -> std::expected<vkr::ShaderModule, VlxError>
{
	vk::ShaderModuleCreateInfo module_info{
	    .codeSize = code.size() * sizeof(char),
	    .pCode    = reinterpret_cast<const uint32_t *>(code.data()),
	};
	VLX_ASSIGN_OR_RETURN(
	    auto module,
	    vlx::vkExpected(device.createShaderModule(module_info)));
	return module;
}        // namespace
}        // namespace
