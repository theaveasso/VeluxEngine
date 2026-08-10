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


PI :: 3.14159265359

/// Convenience macro to convert from degrees to radians.
DEG_TO_RAD :: 0.01745329251

/// Convenience macro to convert from radians to degrees.
RAD_TO_DEG :: 57.2957795131

/// Minimum scale used for scaling collision meshes, etc.
MIN_SCALE :: 0.01

/// A 2D vector.
Vec2 :: struct {
	x: f32,
	y: f32,
}

/// A 3D vector.
Vec3 :: [3]f32

/// Cosine and sine pair.
/// This uses a custom implementation designed for cross-platform determinism.
CosSin :: struct {
	/// cosine and sine
	cosine: f32,
	sine:   f32,
}

/// A quaternion.
Quat :: quaternion128

/// A rigid transform.
Transform :: struct {
	p: Vec3,
	q: Quat,
}

/// In single precision mode these types are the same.
Pos :: Vec3

/// In single precision mode these types are the same.
WorldTransform :: Transform

/// A 3x3 matrix.
Matrix3 :: struct {
	cx, cy, cz: Vec3,
}

/// Axis aligned bounding box.
AABB :: struct {
	lowerBound: Vec3,
	upperBound: Vec3,
}

/// A plane.
/// separation = dot(normal, point) - offset
Plane :: struct {
	normal: Vec3,
	offset: f32,
}

@(default_calling_convention="c", link_prefix="b3")
foreign lib {
	/// Compute an approximate arctangent in the range [-pi, pi]
	/// This is hand coded for cross-platform determinism. The atan2f
	/// function in the standard library is not cross-platform deterministic.
	///	Accurate to around 0.0023 degrees.
	Atan2 :: proc(y: f32, x: f32) -> f32 ---

	/// Compute the cosine and sine of an angle in radians. Implemented
	/// for cross-platform determinism.
	ComputeCosSin :: proc(radians: f32) -> CosSin ---

	/// Extract a quaternion from a rotation matrix.
	MakeQuatFromMatrix :: proc(m: ^Matrix3) -> Quat ---

	/// Find a quaternion that rotates one vector to another.
	ComputeQuatBetweenUnitVectors :: proc(v1: Vec3, v2: Vec3) -> Quat ---

	/// Get the inertia tensor of an offset point.
	/// https://en.wikipedia.org/wiki/Parallel_axis_theorem
	Steiner :: proc(mass: f32, origin: Vec3) -> Matrix3 ---
}

/// The closest points between to segments or infinite lines.
SegmentDistanceResult :: struct {
	point1:    Vec3,
	fraction1: f32,
	point2:    Vec3,
	fraction2: f32,
}

@(default_calling_convention="c", link_prefix="b3")
foreign lib {
	/// Compute the closest point on the segment a-b to the target q.
	PointToSegmentDistance :: proc(a: Vec3, b: Vec3, q: Vec3) -> Vec3 ---

	/// Compute the closest points on two infinite lines.
	LineDistance :: proc(p1: Vec3, d1: Vec3, p2: Vec3, d2: Vec3) -> SegmentDistanceResult ---

	/// Compute the closest points on two line segments.
	SegmentDistance :: proc(p1: Vec3, q1: Vec3, p2: Vec3, q2: Vec3) -> SegmentDistanceResult ---

	/// Is this a valid number? Not NaN or infinity.
	IsValidFloat :: proc(a: f32) -> bool ---

	/// Is this a valid vector? Not NaN or infinity.
	IsValidVec3 :: proc(a: Vec3) -> bool ---

	/// Is this a valid quaternion? Not NaN or infinity. Is normalized.
	IsValidQuat :: proc(q: Quat) -> bool ---

	/// Is this a valid transform? Not NaN or infinity. Is normalized.
	IsValidTransform :: proc(a: Transform) -> bool ---

	/// Is this a valid matrix? Not NaN or infinity.
	IsValidMatrix3 :: proc(a: Matrix3) -> bool ---

	/// Is this a valid bounding box? Not Nan or infinity. Upper bound greater than or equal to lower bound.
	IsValidAABB :: proc(a: AABB) -> bool ---

	/// Is this AABB reasonably close to the origin? See B3_HUGE.
	IsBoundedAABB :: proc(a: AABB) -> bool ---

	/// Is this AABB valid and reasonable?
	IsSaneAABB :: proc(a: AABB) -> bool ---

	/// Is this a valid plane? Normal is a unit vector. Not Nan or infinity.
	IsValidPlane :: proc(a: Plane) -> bool ---

	/// Is this a valid world position? Not NaN or infinity.
	IsValidPosition :: proc(p: Pos) -> bool ---

	/// Is this a valid world transform? Not NaN or infinity. Rotation is normalized.
	IsValidWorldTransform :: proc(t: WorldTransform) -> bool ---
}

