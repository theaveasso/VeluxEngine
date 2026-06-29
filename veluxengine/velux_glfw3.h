#pragma once

#include "velux_autorelease.h"
#include "velux_error.h"
#include <expected>

struct GLFWwindow;

class VlxGlfwWindow
{
  public:
	static auto create(int width, int height, const char *title) -> std::expected<VlxGlfwWindow, VlxError>;

	auto get() const noexcept -> GLFWwindow *
	{
		return window_.get();
	}
	[[nodiscard]] auto shouldCloses() -> bool;
	auto               showWindow() -> void;

  private:
	explicit VlxGlfwWindow(VlxAutoRelease<GLFWwindow *> window) : window_(std::move(window))
	{}

	VlxAutoRelease<GLFWwindow *> window_;
};
