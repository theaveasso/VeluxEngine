#pragma once

#include <string>

enum class VlxErrorCode
{
	Unknown,
	Initialization,
	InvalidHandle,
	InvalidHandleDeleter,
	Vulkan,
	VulkanLayerNotPresent,
	VulkanEXTNotPresent,
};

struct [[nodiscard]] VlxError
{
	VlxErrorCode code;
	std::string  context;
};

inline auto toString(VlxErrorCode code) -> const char *
{
	switch (code)
	{
		case VlxErrorCode::Initialization:
			return "Initialization";
		case VlxErrorCode::InvalidHandle:
			return "Invalid Handle";
		case VlxErrorCode::InvalidHandleDeleter:
			return "Invalid Handle Deleter";
		case VlxErrorCode::Vulkan:
			return "Vulkan";
		case VlxErrorCode::VulkanLayerNotPresent:
			return "Vulkan Layer Not Present";
		case VlxErrorCode::VulkanEXTNotPresent:
			return "Vulkan Extension Not Present";
		case VlxErrorCode::Unknown:
		default:
			return "Unknown";
	}
}
