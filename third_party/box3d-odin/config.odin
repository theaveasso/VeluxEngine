// SPDX-FileCopyrightText: 2026 Erin Catto
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


