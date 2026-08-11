package velux

import b3 "third_party:box3d-odin"

DEFAULT_GRAVITY :: [3]f32{0, -9.81, 0}
MAX_STEPS :: 8

Body :: b3.BodyId
Body_Type :: b3.BodyType

Physics_Config :: struct {
	fixed_dt:      f32,
	substep_count: i32,
	gravity:       [3]f32,
}

Physics_World :: struct {
	world:         b3.WorldId,
	fixed_dt:      f32,
	substep_count: i32,
	accumulator:   f32,
	alpha:         f32,
	steps:         i32,
}

Physics_API :: struct {
	world:         proc() -> ^Physics_World,
	add_box:       proc(physics: ^Physics_World, type: Body_Type, center: [3]f32, half_extents: [3]f32) -> Body,
	body_position: proc(body: Body) -> [3]f32,
}

@(private)
physics_step :: proc(physics: ^Physics_World, dt: f32) {
	if physics.fixed_dt <= 0 do return
	if !b3.World_IsValid(physics.world) do return

	physics.accumulator += dt
	steps_this_call := 0

	for physics.accumulator >= physics.fixed_dt && steps_this_call < MAX_STEPS {
		b3.World_Step(physics.world, physics.fixed_dt, physics.substep_count)
		physics.accumulator -= physics.fixed_dt
		physics.steps += 1
		steps_this_call += 1
	}
	physics.alpha = min(physics.accumulator / physics.fixed_dt, 1)
}

@(private)
host_add_box :: proc(physics: ^Physics_World, type: Body_Type, center: [3]f32, half_extents: [3]f32) -> (body: Body) {
	body_def := b3.DefaultBodyDef()
	body_def.type = type
	body_def.position = center
	body = b3.CreateBody(physics.world, &body_def)
	hull := b3.MakeBoxHull(half_extents.x, half_extents.y, half_extents.z)
	shape_def := b3.DefaultShapeDef()
	b3.CreateHullShape(body, &shape_def, &hull.base)
	return
}

@(private)
host_body_position :: proc(body: Body) -> [3]f32 {return b3.Body_GetPosition(body)}

@(private)
host_physics_world :: proc() -> ^Physics_World {return &g_engine.physics}

@(private, require_results)
host_physics_api :: proc() -> Physics_API {
	return {world = host_physics_world, add_box = host_add_box, body_position = host_body_position}
}

physics_add_box :: proc(physics: ^Physics_World, type: Body_Type, center: [3]f32, half_extents: [3]f32, loc := #caller_location) -> Body {
	return bound_api(loc).physics.add_box(physics, type, center, half_extents)
}

@(private)
init_physics :: proc(physics: ^Physics_World, config: Physics_Config = {}) {
	config := config
	if config.gravity == {} do config.gravity = DEFAULT_GRAVITY
	if config.fixed_dt <= 0 do config.fixed_dt = 1.0 / 60.0
	if config.substep_count <= 0 do config.substep_count = 4

	world_def := b3.DefaultWorldDef()
	world_def.gravity = config.gravity
	physics.world = b3.CreateWorld(&world_def)
	if !b3.World_IsValid(physics.world) do fatal("b3CreateWorld failed (max worlds: %d)", b3.GetMaxWorldCount())
	physics.fixed_dt = config.fixed_dt
	physics.substep_count = config.substep_count
}

@(private)
destroy_physics :: proc(physics: ^Physics_World) {
	if !b3.World_IsValid(physics.world) do return
	b3.DestroyWorld(physics.world)
	physics^ = {}
}

physics_world :: proc(loc := #caller_location) -> ^Physics_World {
	return bound_api(loc).physics.world()
}

physics_body_position :: proc(body: Body, loc := #caller_location) -> [3]f32 {
	return bound_api(loc).physics.body_position(body)
}
