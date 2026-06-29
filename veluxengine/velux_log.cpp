#include "velux_log.h"

#include <spdlog/sinks/stdout_color_sinks.h>

namespace VlxLog
{
auto init() -> void
{
	spdlog::set_pattern("[%T] [%^%l%$] %v");
#ifdef VLX_DEBUG
	spdlog::set_level(spdlog::level::debug);
#else
	spdlog::set_level(spdlog::level::info);
#endif
	spdlog::set_default_logger(spdlog::stdout_color_mt("velux"));
}

auto error(const VlxError &err, const char *where) -> void
{
	if (where)
	{
		spdlog::error("[{} {} ({})]", where, err.context, toString(err.code));
	}
	else
	{
		spdlog::error("{} ({})", err.context, toString(err.code));
	}
}

}        // namespace VlxLog
