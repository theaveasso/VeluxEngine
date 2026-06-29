#include "velux_application.h"
#include "velux_entry.h"
#include <expected>
#include <memory>

class Game final : public VlxApplication
{
  public:
	~Game() = default;

	Game() : VlxApplication(1280, 720, "VeluxEngine")
	{}

	auto onInit() -> std::expected<void, VlxError> override
	{
		return {};
	};
	auto onQuit() -> std::expected<void, VlxError> override
	{
		return {};
	}
	auto onUpdate() -> std::expected<void, VlxError> override
	{
		return {};
	}
	auto onRender() -> std::expected<void, VlxError> override
	{
		return {};
	}
};

auto vlxCreateApplication() -> std::unique_ptr<VlxApplication>
{
	return std::make_unique<Game>();
}
