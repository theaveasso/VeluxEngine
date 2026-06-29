#include "velux_glfw3.h"
#include "velux_autorelease.h"
#include "velux_error.h"

#include <GLFW/glfw3.h>
#include <expected>

auto VlxGlfwWindow::create(int width, int height, const char *title) -> std::expected<VlxGlfwWindow, VlxError>
{
	GLFWwindow *wnd = glfwCreateWindow(width, height, title, nullptr, nullptr);
	if (!wnd)
	{
		return std::unexpected(VlxError{VlxErrorCode::InvalidHandle, "VlxGlfwWindow::create glfwCreateWindow failed"});
	}

	auto wnd_result = VlxAutoRelease<GLFWwindow *>::create(wnd, glfwDestroyWindow);
	if (!wnd_result)
	{
		return std::unexpected(wnd_result.error());
	}
	return VlxGlfwWindow{std::move(*wnd_result)};
}

auto VlxGlfwWindow::shouldCloses() -> bool
{
	return glfwWindowShouldClose(window_.get());
}

auto VlxGlfwWindow::showWindow() -> void
{
	glfwShowWindow(window_.get());
}
