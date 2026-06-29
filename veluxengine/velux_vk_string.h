#pragma once

#include "velux_error.h"

#include <string>
#include <string_view>

namespace vk
{
enum class Result;
}

namespace vlx
{
auto toString(vk::Result result) -> std::string;
auto vkError(std::string_view where, vk::Result result) -> VlxError;
}        // namespace vlx
