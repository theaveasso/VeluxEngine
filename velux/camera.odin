package velux

import "core:math"
import "core:math/linalg"

ORBIT_SENSITIVITY :: 0.005
ZOOM_SPEED :: 1.0
RADIUS_MIN :: 2.0
RADIUS_MAX :: 50.0
RADIUS_DEFAULT :: 25.0
PITCH_LIMIT :: 1.55

FLY_SENSITIVITY :: 0.0015
FLY_SPEED_DEFAULT :: 10.0
FLY_SPEED_MIN :: 1.0
FLY_SPEED_MAX :: 200.0
FLY_SPEED_STEP :: 2.0
FLY_BOOST_MULTIPLIER :: 4.0
WORLD_UP :: [3]f32{0, 1, 0}

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
Free_Fly_Camera :: struct {
	yaw, pitch:         f32,
	speed:              f32,
	invert_x, invert_y: bool,
}

Camera_Input :: struct {
	move:    [3]f32,
	look:    [2]f32,
	zoom:    f32,
	boost:   bool,
	looking: bool,
}
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

Camera_API :: struct {
	update:              proc(camera: ^Camera, input: Camera_Input, dt: f32),
	set_controller:      proc(camera: ^Camera, controller: Camera_Controller),
	input_from_platform: proc() -> Camera_Input,
	view:                proc(camera: Camera) -> matrix[4, 4]f32,
	projection:          proc(camera: Camera, aspect: f32) -> matrix[4, 4]f32,
	perspective:         proc(p: Perspective, aspect: f32) -> matrix[4, 4]f32,
	orthographic:        proc(o: Orthographic, aspect: f32) -> matrix[4, 4]f32,
}

@(private, require_results)
host_camera_api :: proc() -> Camera_API {
	return {
		update = host_camera_update,
		set_controller = host_camera_set_controller,
		input_from_platform = host_camera_input_from_platform,
		view = host_camera_view,
		projection = host_camera_projection,
		perspective = host_projection_perspective,
		orthographic = host_projection_orthographic,
	}
}

camera_update :: proc(camera: ^Camera, input: Camera_Input, dt: f32, loc := #caller_location) {
	bound_api(loc).camera.update(camera, input, dt)
}

camera_set_controller :: proc(camera: ^Camera, controller: Camera_Controller, loc := #caller_location) {
	bound_api(loc).camera.set_controller(camera, controller)
}

@(require_results)
camera_input_from_platform :: proc(loc := #caller_location) -> Camera_Input {
	return bound_api(loc).camera.input_from_platform()
}

@(require_results)
camera_view :: proc(camera: Camera, loc := #caller_location) -> matrix[4, 4]f32 {
	return bound_api(loc).camera.view(camera)
}

@(require_results)
camera_projection :: proc(camera: Camera, aspect: f32, loc := #caller_location) -> matrix[4, 4]f32 {
	return bound_api(loc).camera.projection(camera, aspect)
}

projection :: proc {
	projection_perspective,
	projection_orthographic,
}

@(require_results)
projection_perspective :: proc(p: Perspective, aspect: f32, loc := #caller_location) -> matrix[4, 4]f32 {
	return bound_api(loc).camera.perspective(p, aspect)
}

@(require_results)
projection_orthographic :: proc(o: Orthographic, aspect: f32 = 0, loc := #caller_location) -> matrix[4, 4]f32 {
	return bound_api(loc).camera.orthographic(o, aspect)
}

@(private)
host_camera_update :: proc(camera: ^Camera, input: Camera_Input, dt: f32) {
	switch &control in camera.controller {
	case Orbit_Camera:
		ix: f32 = control.invert_x ? -1 : 1
		iy: f32 = control.invert_y ? -1 : 1
		if input.looking {
			control.yaw += input.look.x * ORBIT_SENSITIVITY * ix
			control.pitch += input.look.y * ORBIT_SENSITIVITY * iy
		}
		control.pitch = clamp(control.pitch, -PITCH_LIMIT, PITCH_LIMIT)
		control.radius = clamp(control.radius - input.zoom * ZOOM_SPEED, RADIUS_MIN, RADIUS_MAX)

		cp := math.cos(control.pitch)
		sp := math.sin(control.pitch)
		cy := math.cos(control.yaw)
		sy := math.sin(control.yaw)
		camera.position = camera.target + {control.radius * cp * sy, control.radius * sp, control.radius * cp * cy}
	case Free_Fly_Camera:
		ix: f32 = control.invert_x ? 1 : -1
		iy: f32 = control.invert_y ? 1 : -1
		if input.looking {
			control.yaw += input.look.x * FLY_SENSITIVITY * ix
			control.pitch += input.look.y * FLY_SENSITIVITY * iy
		}
		control.pitch = clamp(control.pitch, -PITCH_LIMIT, PITCH_LIMIT)
		control.speed = clamp(control.speed + input.zoom * FLY_SPEED_STEP, FLY_SPEED_MIN, FLY_SPEED_MAX)

		cp := math.cos(control.pitch)
		sp := math.sin(control.pitch)
		cy := math.cos(control.yaw)
		sy := math.sin(control.yaw)

		forward := [3]f32{cp * sy, sp, cp * cy}
		right := linalg.normalize(linalg.cross(forward, WORLD_UP))

		velocity := right * input.move.x + WORLD_UP * input.move.y + forward * input.move.z
		if linalg.dot(velocity, velocity) > 0 {
			speed := control.speed * (input.boost ? FLY_BOOST_MULTIPLIER : 1)
			camera.position += linalg.normalize(velocity) * speed * dt
		}
		camera.target = camera.position + forward
	}
}

@(private)
host_camera_set_controller :: proc(camera: ^Camera, controller: Camera_Controller) {
	switch incoming in controller {
	case Orbit_Camera:
		control := incoming
		if control.radius == 0 do control.radius = RADIUS_DEFAULT
		control.radius = clamp(control.radius, RADIUS_MIN, RADIUS_MAX)

		#partial switch old in camera.controller {
		case Free_Fly_Camera:
			control.yaw = old.yaw + math.PI
			control.pitch = clamp(-old.pitch, -PITCH_LIMIT, PITCH_LIMIT)

			cp := math.cos(old.pitch)
			sp := math.sin(old.pitch)
			cy := math.cos(old.yaw)
			sy := math.sin(old.yaw)
			camera.target = camera.position + [3]f32{cp * sy, sp, cp * cy} * control.radius
		}
		camera.controller = control

	case Free_Fly_Camera:
		control := incoming
		if control.speed == 0 do control.speed = FLY_SPEED_DEFAULT
		control.speed = clamp(control.speed, FLY_SPEED_MIN, FLY_SPEED_MAX)

		#partial switch old in camera.controller {
		case Orbit_Camera:
			control.yaw = old.yaw + math.PI
			control.pitch = clamp(-old.pitch, -PITCH_LIMIT, PITCH_LIMIT)
		}
		camera.controller = control
	}
}

@(private, require_results)
host_camera_input_from_platform :: proc() -> (input: Camera_Input) {
	if !ui_wants_keyboard() {
		if is_key_down(.D) do input.move.x += 1
		if is_key_down(.A) do input.move.x -= 1
		if is_key_down(.SPACE) do input.move.y += 1
		if is_key_down(.LEFT_CONTROL) do input.move.y -= 1
		if is_key_down(.W) do input.move.z += 1
		if is_key_down(.S) do input.move.z -= 1
		input.boost = is_key_down(.LEFT_SHIFT)
	}
	if !ui_wants_mouse() {
		input.look = mouse_delta()
		input.zoom = scroll_delta().y
		input.looking = is_cursor_captured() || is_mouse_down(.LEFT) || is_mouse_down(.RIGHT)
	}
	return
}

@(private, require_results)
host_camera_view :: proc(camera: Camera) -> matrix[4, 4]f32 {
	return linalg.matrix4_look_at(camera.position, camera.target, [3]f32{0.0, 1.0, 0.0})
}

@(private, require_results)
host_camera_projection :: proc(camera: Camera, aspect: f32) -> matrix[4, 4]f32 {
	switch proj in camera.projection {
	case Perspective:
		return host_projection_perspective(proj, aspect)
	case Orthographic:
		return host_projection_orthographic(proj, aspect)
	case:
		return host_projection_perspective(Perspective{linalg.to_radians(cast(f32)70), 0.1, 1000}, aspect)
	}
}

@(private, require_results)
host_projection_perspective :: proc(p: Perspective, aspect: f32) -> matrix[4, 4]f32 {
	m := linalg.matrix4_perspective(p.fov_y, aspect, p.near, p.far)
	m[1, 1] *= -1
	return m
}

@(private, require_results)
host_projection_orthographic :: proc(o: Orthographic, aspect: f32 = 0) -> matrix[4, 4]f32 {
	m := linalg.matrix_ortho3d(o.left, o.right, o.bottom, o.top, o.near, o.far)
	return m
}
