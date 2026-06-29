add_library(velux_engine STATIC
	velux_application.cpp
	velux_glfw3.cpp
	velux_gpu_device.cpp
	velux_log.cpp
	velux_vk_string.cpp)
target_include_directories(velux_engine PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")

target_link_libraries(velux_engine PUBLIC glfw spdlog::spdlog Vulkan::Vulkan Vulkan::Headers)

target_compile_definitions(velux_engine PRIVATE
  VK_NO_PROTOTYPES
  VULKAN_HPP_DISPATCH_LOADER_DYNAMIC=1
  VULKAN_HPP_NO_EXCEPTIONS=1)

target_precompile_headers(velux_engine PRIVATE velux_gpu_vulkan.h)
