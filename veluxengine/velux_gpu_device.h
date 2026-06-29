#pragma once

#include "velux_error.h"

#include "velux_gpu_vulkan.h"
#include "vulkan/vulkan.hpp"

#include <cstdint>
#include <expected>
#include <string>
#include <vector>
#include <vulkan/vulkan_raii.hpp>

namespace vkr = vk::raii;

struct GLFWwindow;

class VlxGPUDevice
{
  public:
	VlxGPUDevice() : context_(vkr::Context()) {};

	VlxGPUDevice(const VlxGPUDevice &)                     = delete;
	VlxGPUDevice &operator=(const VlxGPUDevice &)          = delete;
	VlxGPUDevice(VlxGPUDevice &&other) noexcept            = default;
	VlxGPUDevice &operator=(VlxGPUDevice &&other) noexcept = default;

	~VlxGPUDevice();

	auto init(GLFWwindow *window) -> std::expected<void, VlxError>;

	auto resize(std::uint32_t width, std::uint32_t height) -> void;
	auto beginFrame() -> std::expected<std::uint32_t, VlxError>;
	auto endFrame(std::uint32_t image_index) -> void;

	[[nodiscard]] auto instance() const noexcept -> vk::Instance
	{
		return instance_;
	}
	[[nodiscard]] auto surface() const noexcept -> vk::SurfaceKHR
	{
		return surface_;
	}
	[[nodiscard]] auto physicalDevice() const noexcept -> vk::PhysicalDevice
	{
		return physical_device_;
	}
	[[nodiscard]] auto device() const noexcept -> vk::Device
	{
		return device_;
	}
	[[nodiscard]] auto graphicsQueue() const noexcept -> vk::Queue
	{
		return queue_;
	}
	[[nodiscard]] auto graphicsQueueFamily() const noexcept -> std::uint32_t
	{
		return graphics_queue_family_;
	}
	[[nodiscard]] auto presentQueueFamily() const noexcept -> std::uint32_t
	{
		return present_queue_family_;
	}
	[[nodiscard]] auto deviceName() const noexcept -> const std::string &
	{
		return device_name_;
	}

	auto drawFrame() -> std::expected<void, VlxError>;

  private:
	vkr::Context                context_;
	vkr::Instance               instance_              = nullptr;
	vkr::DebugUtilsMessengerEXT debug_                 = nullptr;
	vkr::SurfaceKHR             surface_               = nullptr;
	vkr::PhysicalDevice         physical_device_       = nullptr;
	vkr::Device                 device_                = nullptr;
	vkr::Queue                  queue_                 = nullptr;
	uint32_t                    graphics_queue_family_ = UINT32_MAX;
	uint32_t                    present_queue_family_  = UINT32_MAX;
	std::string                 device_name_           = "";

	vkr::SwapchainKHR               swapchain_               = nullptr;
	std::vector<vk::Image>          swapchain_images_        = {};
	std::vector<vkr::ImageView>     swapchain_image_views_   = {};
	vk::SurfaceFormatKHR            swapchain_surfaceformat_ = {};
	vk::Extent2D                    swapchain_extent_        = {};
	uint32_t                        image_count_             = UINT32_MAX;
	vkr::CommandPool                command_pool_            = nullptr;
	std::vector<vkr::CommandBuffer> command_buffers_         = {};
	vkr::Semaphore                  present_complete_        = nullptr;
	vkr::Semaphore                  render_finished_         = nullptr;
	vkr::Fence                      in_flight_fence_         = nullptr;
	uint32_t                        current_frame_           = UINT32_MAX;
	vkr::Pipeline                   graphics_pipeline_       = nullptr;

	std::vector<const char *> required_device_exts_ = {vk::KHRSwapchainExtensionName, vk::EXTExtendedDynamicStateExtensionName};
	float                     queue_priority_       = 1.0f;

  private:
	auto createInstance() -> std::expected<void, VlxError>;
	auto setupDebugMessenger() -> std::expected<void, VlxError>;
	auto createSurface(GLFWwindow *window) -> std::expected<void, VlxError>;
	auto pickPhysicalDevice() -> std::expected<void, VlxError>;
	auto createLogicalDevice() -> std::expected<void, VlxError>;
	auto createSwapchain(GLFWwindow *window) -> std::expected<void, VlxError>;
	auto createImageViews() -> std::expected<void, VlxError>;
	auto createGraphicsPipeline() -> std::expected<void, VlxError>;
	auto createCommandPool() -> std::expected<void, VlxError>;
	auto allocateCommandBuffer() -> std::expected<void, VlxError>;
	auto createSyncObjects() -> std::expected<void, VlxError>;

	auto recordCommandBuffer(uint32_t image_index) -> void;
	auto transitionImageLayout(uint32_t image_index, vk::ImageLayout old_layout, vk::ImageLayout new_layout, vk::AccessFlags2 src_access_mask, vk::AccessFlags2 dst_access_mask, vk::PipelineStageFlags2 src_stage_mask, vk::PipelineStageFlags2 dst_stage_mask) -> void;
};
