#pragma once

#include "velux_error.h"
#include "velux_glfw3.h"
#include "velux_gpu_device.h"
#include <expected>
#include <optional>
#include <string>

class VlxApplication
{
  public:
	virtual ~VlxApplication();

	VlxApplication(int width, int height, const std::string &title) : width_(width),
	                                                                  height_(height),
	                                                                  title_(title)
	{}

	auto init() -> std::expected<void, VlxError>;
	auto run() -> std::expected<void, VlxError>;

	virtual auto onInit() -> std::expected<void, VlxError>   = 0;
	virtual auto onQuit() -> std::expected<void, VlxError>   = 0;
	virtual auto onUpdate() -> std::expected<void, VlxError> = 0;
	virtual auto onRender() -> std::expected<void, VlxError> = 0;

  private:
	int         width_, height_;
	std::string title_;

	std::optional<VlxGlfwWindow> window_;
	std::optional<VlxGPUDevice>  gpu_;
};
