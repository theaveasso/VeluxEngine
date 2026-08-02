package main

TETHER_POINTS :: 8

SEGMENT_LENGTH :: f32(0.3)
SWAY_AMOUNT :: f32(0.55)
SWAY_RESPONSE :: f32(4.0)

HEAD_RADIUS :: f32(0.35)
BEAD_RADIUS :: f32(0.26)
BEAD_TIP_RADIUS :: f32(0.11)

Tether :: struct {
	positions: [TETHER_POINTS][3]f32,
	sway:      [3]f32,
}

create_tether :: proc(head: [3]f32) -> (tether: Tether) {
	update_tether(&tether, head, {}, 0)
	return
}

update_tether :: proc(tether: ^Tether, head: [3]f32, motion: [3]f32, dt: f32) {
	target := [3]f32{-motion.x, 0, -motion.z} * SWAY_AMOUNT
	tether.sway += (target - tether.sway) * clamp(SWAY_RESPONSE * dt, 0, 1)

	for i in 0 ..< TETHER_POINTS {
		lean := f32(i) / f32(TETHER_POINTS - 1)
		drop := [3]f32{0, -SEGMENT_LENGTH * f32(i), 0}
		tether.positions[i] = head + drop + tether.sway * lean * lean
	}
}
