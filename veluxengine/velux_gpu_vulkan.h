#pragma once

#include "velux_common.h"
#include "velux_error.h"
#include "velux_vk_string.h"

#define VULKAN_HPP_NO_STRUCT_CONSTRUCTORS
#include <expected>
#include <source_location>
#include <type_traits>
#include <vulkan/vulkan_raii.hpp>

namespace vlx
{
inline auto vkExpected(vk::Result result, std::source_location where = std::source_location::current()) -> std::expected<void, VlxError>
{
	if (result != vk::Result::eSuccess)
	{
		return std::unexpected(vkError(result, where));
	}
	VLX_OK();
}

template <typename R>
auto vkExpected(R &&result_value, std::source_location where = std::source_location::current())
    -> std::expected<std::remove_cvref_t<decltype(result_value.value)>, VlxError>
{
	using T = std::remove_cvref_t<decltype(result_value.value)>;
	if (!result_value.has_value())
	{
		return std::unexpected(vkError(result_value.result, where));
	}
	return std::move(result_value.value);
}
}        // namespace vlx
