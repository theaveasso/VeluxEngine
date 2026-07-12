package velux

import "core:math/linalg"

Perspective :: struct {
	fov_y:     f32,
	near, far: f32,
}

Orthographic :: struct {
	left, right, bottom, top: f32,
	near, far:                f32,
}

Projection :: union {
	Perspective,
	Orthographic,
}

Camera :: struct {
	position:   [3]f32,
	target:     [3]f32,
	projection: Projection,
}

camera_projection :: proc(camera: Camera, aspect: f32) -> matrix[4, 4]f32 {
	switch proj in camera.projection {
	case Perspective:
		return projection(proj, aspect)
	case Orthographic:
		return projection(proj, aspect)
	case:
		return projection(Perspective{linalg.to_radians(cast(f32)70), 0.1, 1000}, aspect)
	}
}

camera_view :: proc(camera: Camera) -> matrix[4, 4]f32 {
	return linalg.matrix4_look_at(camera.position, camera.target, [3]f32{0.0, 1.0, 0.0})
}

projection :: proc {
	projection_perspective,
	projection_orthographic,
}

projection_perspective :: proc(p: Perspective, aspect: f32) -> matrix[4, 4]f32 {
	m := linalg.matrix4_perspective(p.fov_y, aspect, p.near, p.far)
	m[1, 1] *= -1
	return m
}

projection_orthographic :: proc(o: Orthographic, aspect: f32 = 0) -> matrix[4, 4]f32 {
	m := linalg.matrix_ortho3d(o.left, o.right, o.bottom, o.top, o.near, o.far)
	return m
}
