#pragma once

#include "velux_error.h"

#include <spdlog/spdlog.h>

namespace VlxLog
{
auto init() -> void;

auto error(const VlxError &err, const char *where = nullptr) -> void;
}        // namespace VlxLog

#define VLX_LOGT(...) ::spdlog::trace(__VA_ARGS__)
#define VLX_LOGI(...) ::spdlog::info(__VA_ARGS__)
#define VLX_LOGD(...) ::spdlog::debug(__VA_ARGS__)
#define VLX_LOGW(...) ::spdlog::warn(__VA_ARGS__)
#define VLX_LOGE(...) ::spdlog::error(__VA_ARGS__)
