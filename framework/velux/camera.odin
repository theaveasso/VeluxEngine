package velux

import "core:math"
import "core:math/linalg"

ORBIT_SENSITIVITY :: 0.005
ZOOM_SPEED :: 1.0
RADIUS_MIN :: 2.0
RADIUS_MAX :: 50.0
PITCH_LIMIT :: 1.55

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

Orbit_Camera :: struct {
	yaw, pitch:         f32,
	radius:             f32,
	invert_x, invert_y: bool,
}

Free_Fly_Camera :: struct {}

Camera_Controller :: union {
	Orbit_Camera,
	Free_Fly_Camera,
}

Camera :: struct {
	position:   [3]f32,
	target:     [3]f32,
	projection: Projection,
	controller: Camera_Controller,
}

camera_update :: proc(camera: ^Camera, drag: [2]f32, zoom: f32, dragging: bool, dt: f32) {
	switch &control in camera.controller {
	case Orbit_Camera:
		ix: f32 = control.invert_x ? -1 : 1
		iy: f32 = control.invert_y ? -1 : 1
		if dragging {
			control.yaw += drag.x * ORBIT_SENSITIVITY * ix
			control.pitch += drag.y * ORBIT_SENSITIVITY * iy
		}
		control.pitch = clamp(control.pitch, -PITCH_LIMIT, PITCH_LIMIT)
		control.radius = clamp(control.radius - zoom * ZOOM_SPEED, RADIUS_MIN, RADIUS_MAX)

		cp := math.cos(control.pitch)
		sp := math.sin(control.pitch)
		cy := math.cos(control.yaw)
		sy := math.sin(control.yaw)
		camera.position = camera.target + {control.radius * cp * sy, control.radius * sp, control.radius * cp * cy}
	case Free_Fly_Camera:
	}
}

camera_view :: proc(camera: Camera) -> matrix[4, 4]f32 {
	return linalg.matrix4_look_at(camera.position, camera.target, [3]f32{0.0, 1.0, 0.0})
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
