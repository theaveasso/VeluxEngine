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


/// World id references a world instance. This should be treated as an opaque handle.
WorldId :: struct {
	index1:     u16,
	generation: u16,
}

/// Body id references a body instance. This should be treated as an opaque handle.
BodyId :: struct {
	index1:     i32,
	world0:     u16,
	generation: u16,
}

/// Shape id references a shape instance. This should be treated as an opaque handle.
ShapeId :: struct {
	index1:     i32,
	world0:     u16,
	generation: u16,
}

/// Joint id references a joint instance. This should be treated as an opaque handle.
JointId :: struct {
	index1:     i32,
	world0:     u16,
	generation: u16,
}

/// Contact id references a contact instance. This should be treated as an opaque handle.
ContactId :: struct {
	index1:     i32,
	world0:     u16,
	padding:    i16,
	generation: u32,
}

