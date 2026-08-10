package tests

import "core:testing"

import b3 "third_party:box3d-odin"

@(test)
world_creates_and_destroys :: proc(t: ^testing.T) {
	def := b3.DefaultWorldDef()
	world := b3.CreateWorld(&def)
	testing.expect(t, b3.World_IsValid(world))
	b3.DestroyWorld(world)
	testing.expect(t, !b3.World_IsValid(world))
}

@(test)
world_steps_without_bodies :: proc(t: ^testing.T) {
	def := b3.DefaultWorldDef()
	world := b3.CreateWorld(&def)
	defer b3.DestroyWorld(world)

	for _ in 0 ..< 10 {
		b3.World_Step(world, 1.0 / 60.0, 4)
	}
	testing.expect(t, b3.World_IsValid(world))
}

@(test)
default_gravity_points_down :: proc(t: ^testing.T) {
	def := b3.DefaultWorldDef()
	testing.expect(t, def.gravity.y < 0)
}
