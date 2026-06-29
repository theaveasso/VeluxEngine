#pragma once

#include "velux_common.h"
#include "velux_error.h"
#include "velux_vk_string.h"

#define VULKAN_HPP_NO_STRUCT_CONSTRUCTORS
#include <expected>
#include <string_view>
#include <type_traits>
#include <vulkan/vulkan_raii.hpp>

namespace vlx
{
inline auto vkExpected(std::string_view where, vk::Result result) -> std::expected<void, VlxError>
{
	if (result != vk::Result::eSuccess)
	{
		return std::unexpected(vkError(where, result));
	}
	VLX_OK();
}

template <typename R>
auto vkExpected(std::string_view where, R &&result_value)
    -> std::expected<std::remove_cvref_t<decltype(result_value.value)>, VlxError>
{
	using T = std::remove_cvref_t<decltype(result_value.value)>;
	if (!result_value.has_value())
	{
		return std::unexpected(vkError(where, result_value.result));
	}
	return std::move(result_value.value);
}
}        // namespace vlx
