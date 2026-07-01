#include "velux_vk_string.h"

#include <format>
#include <vulkan/vulkan_to_string.hpp>

namespace vlx
{
auto toString(vk::Result result) -> std::string
{
	return vk::to_string(result);
}

auto vkError(vk::Result result, const std::source_location &where) -> VlxError
{
	return VlxError{VlxErrorCode::Vulkan,
	                std::format("{}:{} ({})", where.function_name(), where.line(), vk::to_string(result))};
}
}        // namespace vlx
