// SPDX-FileCopyrightText: 2025 Erin Catto
// SPDX-License-Identifier: MIT
package box3d

when ODIN_OS == .Windows {
	foreign import lib "external/box3d_windows_x64.lib"
} else when ODIN_OS == .Darwin {
	when ODIN_ARCH == .arm64 {
		foreign import lib "external/box3d_darwin_arm64.a"
	} else {
		foreign import lib "external/box3d_darwin_x64.a"
	}
} else when ODIN_OS == .Linux {
	when ODIN_ARCH == .arm64 {
		foreign import lib "external/box3d_linux_arm64.a"
	} else {
		foreign import lib "external/box3d_linux_x64.a"
	}
}


ENABLE_VALIDATION :: 0

/**
* @defgroup base Base
* Base functionality
* @{
*/

/// This is used to indicate null for interfaces that work with indices instead of pointers
NULL_INDEX :: -1

/// Prototype for user allocation function.
///	@param size the allocation size in bytes
///	@param alignment the required alignment, guaranteed to be a power of 2
AllocFcn :: proc "c" (size: i32, alignment: i32) -> rawptr

/// Prototype for user free function.
///	@param mem the memory previously allocated through `b3AllocFcn`
FreeFcn :: proc "c" (mem: rawptr)

/// Prototype for the user assert callback. Return 0 to skip the debugger break.
AssertFcn :: proc "c" (condition: cstring, fileName: cstring, lineNumber: i32) -> i32

/// Prototype for user log callback. Used to log warnings.
LogFcn :: proc "c" (message: cstring)

@(default_calling_convention="c", link_prefix="b3")
foreign lib {
	/// This allows the user to override the allocation functions. These should be
	///	set during application startup.
	SetAllocator :: proc(allocFcn: ^AllocFcn, freeFcn: ^FreeFcn) ---

	/// Total bytes allocated by Box3D
	GetByteCount :: proc() -> i32 ---

	/// Override the default assert callback.
	///	@param assertFcn a non-null assert callback
	SetAssertFcn :: proc(assertFcn: ^AssertFcn) ---

	/// Internal assertion handler. Allows for host intervention.
	InternalAssert :: proc(condition: cstring, fileName: cstring, lineNumber: i32) -> i32 ---

	/// Override the default logging callback.
	SetLogFcn :: proc(logFcn: ^LogFcn) ---
}

/// Version numbering scheme.
/// See https://semver.org/
Version :: struct {
	/// Significant changes
	major: i32,

	/// Incremental changes
	minor: i32,

	/// Bug fixes
	revision: i32,
}

@(default_calling_convention="c", link_prefix="b3")
foreign lib {
	/// Get the current version of Box3D
	GetVersion :: proc() -> Version ---

	/// @return true if the library was built with BOX3D_DOUBLE_PRECISION (large world mode)
	IsDoublePrecision :: proc() -> bool ---

	/// Get the absolute number of system ticks. The value is platform specific.
	GetTicks :: proc() -> u64 ---

	/// Get the milliseconds passed from an initial tick value.
	GetMilliseconds :: proc(ticks: u64) -> f32 ---

	/// Get the milliseconds passed from an initial tick value.
	GetMillisecondsAndReset :: proc(ticks: ^u64) -> f32 ---

	/// Yield to be used in a busy loop.
	Yield :: proc() ---

	/// Sleep the current thread for a number of milliseconds.
	Sleep :: proc(milliseconds: i32) ---
}

// Simple djb2 hash function for determinism testing
HASH_INIT :: 5381

@(default_calling_convention="c", link_prefix="b3")
foreign lib {
	Hash :: proc(hash: u32, data: ^u8, count: i32) -> u32 ---
}

