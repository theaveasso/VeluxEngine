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


@(default_calling_convention="c", link_prefix="b3")
foreign lib {
	/// Box3D bases all length units on meters, but you may need different units for your game.
	/// You can set this value to use different units. This should be done at application startup
	/// and only modified once. Default value is 1.
	/// @warning This must be modified before any calls to Box3D
	SetLengthUnitsPerMeter :: proc(lengthUnits: f32) ---

	/// Get the current length units per meter.
	GetLengthUnitsPerMeter :: proc() -> f32 ---

	/// Set the threshold for logging stalls.
	SetStallThreshold :: proc(seconds: f32) ---

	/// Get the threshold for logging stalls.
	GetStallThreshold :: proc() -> f32 ---
}


/// Maximum parallel workers. Used for some fixed size arrays.
MAX_WORKERS :: 32

/// Maximum number of tasks queued per world step. b3EnqueueTaskCallback will never be called
/// more than this per world step. This is related to B3_MAX_WORKERS. With 32 workers,
/// the maximum observed task count is 130. This allows an external task system to use a fixed
/// size array for Box3D task, which may help with creating stable user task pointers.
MAX_TASKS :: 256

// Maximum number of colors in the constraint graph. Constraints that cannot
// find a color are added to the overflow set which are solved single-threaded.
// The compound barrel benchmark has minor overflow with 24 colors
GRAPH_COLOR_COUNT :: 24

// Number of contact point buckets for counting the number of contact points per
// shape contact pair. This is just for reporting and doesn't affect simulation.
CONTACT_MANIFOLD_COUNT_BUCKETS :: 8

// A small length used as a collision and constraint tolerance. Usually it is
// chosen to be numerically significant, but visually insignificant. In meters.
// @warning modifying this can have a significant impact on stability

/// The minimum length of a capsules. Very short capsules should be created as spheres
/// to avoid numerical problems.

/// Minimum contact point friction weight, lower bound for speculative points. Made small
/// enough to be washed away by weights that hit 1.
MIN_FRICTION_WEIGHT :: (1e-10)

/// The distance between shapes where they are considered overlapped. This is needed
/// because GJK may return small positive values for overlapped shapes in degenerate
/// configurations.
MAX_WORLDS   :: 128

/// @warning modifying this can have a significant impact on performance and stability

/// The rest offset is used for mesh contact to reduce ghost collisions and assist with CCD.
/// The rest offset adjusts the contact point separation value, making the solver push the shapes
/// apart by this distance.
/// Must be at least B3_LINEAR_SLOP and less than B3_SPECULATIVE_DISTANCE.

/// The default contact recycling distance.

/// The default contact recycling world angle threshold. For performance this value
/// is cos(angle/2)^2. This value corresponds to 10 degrees.
CONTACT_RECYCLE_ANGULAR_DISTANCE :: (0.99240388)

/// This is used to fatten AABBs in the dynamic tree. This allows proxies
/// to move by a small amount without triggering a tree adjustment. This is in meters.
/// @warning modifying this can have a significant impact on performance

/// Per-shape AABB margin is a fraction of the shape extent (capped by B3_MAX_AABB_MARGIN).
/// Small shapes get small margins; large shapes are clamped to the cap.
AABB_MARGIN_FRACTION :: 0.125

/// The time that a body must be still before it will go to sleep. In seconds.
TIME_TO_SLEEP :: 0.5

/// The maximum number of contact points between two touching shapes.
MAX_MANIFOLD_POINTS   :: 4
GYROSCOPIC_ITERATIONS :: 1

/// The maximum number of convex hull vertices. This is fixed for performance reasons.
MAX_HULL_VERTICES :: 128

/// The maximum number of convex hull faces.
MAX_HULL_FACES :: 128

/// The maximum number of convex hull edges. Full edges, not half-edges.
MAX_HULL_EDGES :: 128

/// Relative tolerance used to determine if two edges are parallel.
PARALLEL_EDGE_TOL :: 0.005

/// The maximum number points to use for shape cast proxies (swept point cloud).
MAX_SHAPE_CAST_POINTS :: MAX_HULL_VERTICES

/// These generous limits allow for easy hashing. See b3ShapePairKey.
SHAPE_POWER            :: 22
CHILD_POWER            :: (64-2*SHAPE_POWER)
MAX_SHAPES             :: (1<<SHAPE_POWER)
MAX_CHILD_SHAPES       :: (1<<CHILD_POWER)
RESTITUTION_ITERATIONS :: 1

