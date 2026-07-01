#pragma once

#include "velux_error.h"

#include <source_location>
#include <string>

namespace vk
{
enum class Result;
}

namespace vlx
{
auto toString(vk::Result result) -> std::string;
auto vkError(vk::Result result, const std::source_location &where) -> VlxError;
}        // namespace vlx
