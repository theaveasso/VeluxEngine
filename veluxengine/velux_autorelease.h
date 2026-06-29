#pragma once

#include "velux_error.h"

#include <expected>
#include <functional>
#include <utility>

template <typename T, T Invalid = {}>
class VlxAutoRelease
{
  public:
	static auto create(T handle, std::function<void(T)> deleter) -> std::expected<VlxAutoRelease, VlxError>
	{
		if (handle == Invalid)
			return std::unexpected(VlxError{VlxErrorCode::InvalidHandle, "invalid handle"});
		if (!deleter)
			return std::unexpected(VlxError{VlxErrorCode::InvalidHandleDeleter, "missing deletor"});
		return VlxAutoRelease(handle, std::move(deleter));
	}

	~VlxAutoRelease()
	{
		if ((handle_ != Invalid) && deleter_)
		{
			deleter_(handle_);
		}
	}

	VlxAutoRelease(const VlxAutoRelease &)            = delete;
	VlxAutoRelease &operator=(const VlxAutoRelease &) = delete;

	VlxAutoRelease(VlxAutoRelease &&other) noexcept
	    : handle_(std::exchange(other.handle_, Invalid)),
	      deleter_(std::exchange(other.deleter_, nullptr))
	{}

	VlxAutoRelease &operator=(VlxAutoRelease &&other) noexcept
	{
		if (this != &other)
		{
			if ((handle_ != Invalid) && deleter_)
				deleter_(handle_);
			handle_  = std::exchange(other.handle_, Invalid);
			deleter_ = std::exchange(other.deleter_, nullptr);
		}
		return *this;
	}

	auto get() const noexcept -> T
	{
		return handle_;
	}
	operator T() const noexcept
	{
		return handle_;
	}

  private:
	explicit VlxAutoRelease(T handle, std::function<void(T)> deleter) noexcept
	    : handle_(handle),
	      deleter_(std::move(deleter))
	{}

	T                      handle_{Invalid};
	std::function<void(T)> deleter_;
};
