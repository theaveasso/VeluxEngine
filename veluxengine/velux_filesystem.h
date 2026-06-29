#pragma once

#include "velux_common.h"
#include "velux_error.h"
#include <expected>
#include <fstream>
#include <ios>
#include <vector>

namespace vlx
{
inline auto readFile(const std::string &filename) -> std::expected<std::vector<char>, VlxError>
{
	std::ifstream file(filename, std::ios::ate | std::ios::binary);
	if (!file.is_open())
	{
		VLX_FAIL(VlxErrorCode::InvalidHandle, "readFile: failed to open file");
	}

	std::vector<char> buffer(file.tellg());
	file.seekg(0, std::ios::beg);
	file.read(buffer.data(), static_cast<std::streamsize>(buffer.size()));

	file.close();
	return buffer;
}
}        // namespace vlx
