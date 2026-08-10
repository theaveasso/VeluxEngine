package box3d

HUGE :: #force_inline proc "contextless" () -> f32 {
	return 1.0e5 * GetLengthUnitsPerMeter()
}

LINEAR_SLOP :: #force_inline proc "contextless" () -> f32 {
	return 0.005 * GetLengthUnitsPerMeter()
}

MIN_CAPSULE_LENGTH :: #force_inline proc "contextless" () -> f32 {
	return LINEAR_SLOP()
}

OVERLAP_SLOP :: #force_inline proc "contextless" () -> f32 {
	return 0.1 * LINEAR_SLOP()
}

SPECULATIVE_DISTANCE :: #force_inline proc "contextless" () -> f32 {
	return 4.0 * LINEAR_SLOP()
}

MESH_REST_OFFSET :: #force_inline proc "contextless" () -> f32 {
	return 1.0 * LINEAR_SLOP()
}

CONTACT_RECYCLE_DISTANCE :: #force_inline proc "contextless" () -> f32 {
	return 10.0 * LINEAR_SLOP()
}

MAX_AABB_MARGIN :: #force_inline proc "contextless" () -> f32 {
	return 0.05 * GetLengthUnitsPerMeter()
}
