#pragma once

#include "velux_error.h"

#include <expected>
#include <utility>

#define VLX_OK() \
	return       \
	{}

#define VLX_FAIL(code, message) \
	return std::unexpected(VlxError{(code), (message)})

#define VLX_RETURN_IF_ERROR(expr)                          \
	do                                                     \
	{                                                      \
		if (auto _vlx_expected = (expr); !_vlx_expected)   \
		{                                                  \
			return std::unexpected(_vlx_expected.error()); \
		}                                                  \
	} while (0)

#define VLX_CONCAT_INNER(a, b) a##b
#define VLX_CONCAT(a, b) VLX_CONCAT_INNER(a, b)

#define VLX_ASSIGN_OR_RETURN_IMPL(tmp, decl, expr) \
	auto tmp = (expr);                             \
	if (!(tmp))                                    \
	{                                              \
		return std::unexpected((tmp).error());     \
	}                                              \
	decl = std::move(*(tmp))

#define VLX_ASSIGN_OR_RETURN(decl, expr) \
	VLX_ASSIGN_OR_RETURN_IMPL(VLX_CONCAT(_vlx_expected_, __COUNTER__), decl, expr)
