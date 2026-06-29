#include "velux_vk_string.h"

#include <format>
#include <vulkan/vulkan_to_string.hpp>

namespace vlx
{
auto toString(vk::Result result) -> std::string
{
	return vk::to_string(result);
}

auto vkError(std::string_view where, vk::Result result) -> VlxError
{
	return VlxError{VlxErrorCode::Vulkan, std::format("{} ({})", where, vk::to_string(result))};
}
}        // namespace vlx
