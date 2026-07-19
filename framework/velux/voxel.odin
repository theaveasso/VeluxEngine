package velux

import "core:math"

Voxel :: Block_Type
VOXEL_SIZE :: 0.1
WORLD_DIMENSION :: [3]int{255, 128, 255}

BLOCK_PALLETTE :: [Block_Type][3]f32 {
	.Air   = {0.0, 0.0, 0.0},
	.Grass = {0.45, 0.62, 0.28},
	.Dirt  = {0.48, 0.35, 0.24},
	.Wood  = {0.42, 0.30, 0.19},
	.Leaf  = {0.30, 0.48, 0.22},
	.Stone = {0.55, 0.55, 0.58},
}
Block_Type :: enum u8 {
	Air,
	Grass,
	Dirt,
	Wood,
	Leaf,
	Stone,
}
Voxel_Vertex :: struct {
	data0: u32,
	data1: u32,
}
Voxel_Grid :: struct {
	voxels: []Voxel,
}

voxel_index :: proc(x, y, z: int) -> int {
	return x + y * WORLD_DIMENSION[0] + z * WORLD_DIMENSION[0] * WORLD_DIMENSION[1]
}

voxel_at :: proc(grid: ^Voxel_Grid, x, y, z: int) -> Voxel {
	if x < 0 || y < 0 || z < 0 do return .Air
	if x >= WORLD_DIMENSION[0] || y >= WORLD_DIMENSION[1] || z >= WORLD_DIMENSION[2] do return .Air
	return grid.voxels[voxel_index(x, y, z)]
}

voxel_set :: proc(grid: ^Voxel_Grid, x, y, z: int, block: Block_Type) {
	if x < 0 || y < 0 || z < 0 do return
	if x >= WORLD_DIMENSION[0] || y >= WORLD_DIMENSION[1] || z >= WORLD_DIMENSION[2] do return
	grid.voxels[voxel_index(x, y, z)] = block
}

pack_vertex :: proc(x, y, z, normal, ao, block: u32) -> Voxel_Vertex {
	assert(x <= 255 && y <= 255 && z <= 255)
	assert(normal < 6 && ao < 4)
	return {data0 = x | (y << 8) | (z << 16) | (normal << 24) | (ao << 27), data1 = block}
}

create_glade :: proc(grid: ^Voxel_Grid) {
	grid.voxels = make([]Voxel, WORLD_DIMENSION[0] * WORLD_DIMENSION[1] * WORLD_DIMENSION[2])

	GROUND :: 20

	for z in 0 ..< WORLD_DIMENSION[2] {
		for x in 0 ..< WORLD_DIMENSION[0] {
			for y in 0 ..< GROUND {
				voxel_set(grid, x, y, z, .Dirt)
			}
			voxel_set(grid, x, GROUND, z, .Grass)
		}
	}

	place_tree(grid, 40, 50, GROUND + 1)
	place_tree(grid, 60, 20, GROUND + 1)
	place_tree(grid, 40, 30, GROUND + 1)
	place_tree(grid, 20, 60, GROUND + 1)
	place_tree(grid, 10, 30, GROUND + 1)
	place_tree(grid, 85, 75, GROUND + 1)
}

destroy_glade :: proc(grid: ^Voxel_Grid) {
	delete(grid.voxels)
}

hash3 :: proc(x, y, z: int) -> f32 {
	h := u32(x) * 374761393 + u32(y) * 668265263 + u32(z) * 2147483647
	h = (h ~ (h >> 13)) * 1274126177
	h = h ~ (h >> 16)
	return f32(h & 0xFFFF) / f32(0xFFFF)
}

place_leaf_blob :: proc(grid: ^Voxel_Grid, cx, cy, cz: int, radius: f32) {
	r := int(radius) + 1
	for z in -r ..= r {
		for y in -r ..= r {
			for x in -r ..= r {
				dist := math.sqrt(f32(x * x + y * y + z * z))

				wobble := hash3(cx + x, cy + y, cz + z) * 0.3
				if dist > radius * (1.0 - wobble) do continue

				edge := dist / radius
				if edge > 0.7 && hash3(x + cx * 3, y, z + cz * 3) < 0.35 do continue

				if voxel_at(grid, cx + x, cy + y, cz + z) == .Air {
					voxel_set(grid, cx + x, cy + y, cz + z, .Leaf)
				}
			}
		}
	}
}
place_tree :: proc(grid: ^Voxel_Grid, cx, cz, base_y: int) {
	TRUNK_HEIGHT :: 32

	lean_x := (hash3(cx, 0, cz) - 0.5) * 0.25
	lean_z := (hash3(cx, 999, cz) - 0.5) * 0.25

	fx := f32(cx)
	fz := f32(cz)

	for h in 0 ..< TRUNK_HEIGHT {
		fx += lean_x
		fz += lean_z
		tx, tz := int(fx), int(fz)
		y := base_y + h

		t := f32(h) / f32(TRUNK_HEIGHT)
		trunk_r := 2.0 * (1.0 - t) + 0.5

		r := int(trunk_r) + 1
		for oz in -r ..= r {
			for ox in -r ..= r {
				if f32(ox * ox + oz * oz) <= trunk_r * trunk_r {
					voxel_set(grid, tx + ox, y, tz + oz, .Wood)
				}
			}
		}

		if t > 0.45 && hash3(cx, h, cz) < 0.4 {
			place_branch(grid, tx, y, tz, h)
		}
	}

	top_y := base_y + TRUNK_HEIGHT
	place_leaf_blob(grid, int(fx), top_y, int(fz), 12.5)
	place_leaf_blob(grid, int(fx) + 3, top_y - 2, int(fz) - 2, 8.5)
	place_leaf_blob(grid, int(fx) - 2, top_y - 3, int(fz) + 3, 5.0)
}
place_branch :: proc(grid: ^Voxel_Grid, sx, sy, sz: int, seed: int) {
	angle := hash3(sx, seed, sz) * 6.28318
	dx := math.cos(angle)
	dz := math.sin(angle)

	length := 4 + int(hash3(seed, sx, sz) * 4.0)

	fx, fy, fz := f32(sx), f32(sy), f32(sz)
	for _ in 0 ..< length {
		fx += dx
		fz += dz
		fy += 0.4
		voxel_set(grid, int(fx), int(fy), int(fz), .Wood)
	}

	place_leaf_blob(grid, int(fx), int(fy) + 1, int(fz), 3.0)
}
