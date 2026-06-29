#include "velux_application.h"
#include "velux_common.h"
#include "velux_error.h"
#include "velux_glfw3.h"
#include "velux_gpu_device.h"
#include "velux_log.h"

#include <GLFW/glfw3.h>
#include <expected>

auto VlxApplication::init() -> std::expected<void, VlxError>
{
	if (!glfwInit())
	{
		VLX_FAIL(VlxErrorCode::Initialization, "VlxApplication: glfwInit failed");
	}
	VLX_LOGD("GLFW initialized");

	glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
	glfwWindowHint(GLFW_RESIZABLE, GLFW_TRUE);
	glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE);

	VLX_ASSIGN_OR_RETURN(auto window, VlxGlfwWindow::create(width_, height_, title_.c_str()));
	window_.emplace(std::move(window));
	VLX_LOGD("GLFWwindow created");

	gpu_.emplace();
	VLX_RETURN_IF_ERROR(gpu_->init(window_->get()));
	VLX_LOGD("Vulkan device ready");

	VLX_RETURN_IF_ERROR(onInit());

	window_->showWindow();
	return {};
}

VlxApplication::~VlxApplication()
{
	gpu_.reset();
	window_.reset();
	glfwTerminate();
}

auto VlxApplication::run() -> std::expected<void, VlxError>
{
	while (window_ && !window_->shouldCloses())
	{
		glfwPollEvents();
		VLX_RETURN_IF_ERROR(onUpdate());
		VLX_RETURN_IF_ERROR(onRender());
		VLX_RETURN_IF_ERROR(gpu_->drawFrame());
	}
	VLX_RETURN_IF_ERROR(onQuit());
	return {};
}
