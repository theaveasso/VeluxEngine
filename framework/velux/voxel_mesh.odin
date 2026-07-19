package velux

Face :: struct {
	neighbor: [3]int,
	corner:   [4][3]u32,
}
FACES :: [6]Face {
	{neighbor = {+1, 0, 0}, corner = {{1, 0, 0}, {1, 1, 0}, {1, 1, 1}, {1, 0, 1}}},
	{neighbor = {-1, 0, 0}, corner = {{0, 0, 1}, {0, 1, 1}, {0, 1, 0}, {0, 0, 0}}},
	{neighbor = {0, +1, 0}, corner = {{0, 1, 0}, {0, 1, 1}, {1, 1, 1}, {1, 1, 0}}},
	{neighbor = {0, -1, 0}, corner = {{0, 0, 1}, {0, 0, 0}, {1, 0, 0}, {1, 0, 1}}},
	{neighbor = {0, 0, +1}, corner = {{1, 0, 1}, {1, 1, 1}, {0, 1, 1}, {0, 0, 1}}},
	{neighbor = {0, 0, -1}, corner = {{0, 0, 0}, {0, 1, 0}, {1, 1, 0}, {1, 0, 0}}},
}

compute_face_ao :: proc(grid: ^Voxel_Grid, x, y, z: int, face: Face) -> [4]u32 {
	n := face.neighbor

	axis_a := -1; axis_b := -1
	for i in 0 ..< 3 {
		if n[i] != 0 do continue
		if axis_a == -1 do axis_a = i
		else do axis_b = i
	}

	result: [4]u32
	for corner, i in face.corner {
		da := corner[axis_a] == 0 ? -1 : +1
		db := corner[axis_b] == 0 ? -1 : +1

		p := [3]int{x + n[0], y + n[1], z + n[2]}

		s1_pos := p; s1_pos[axis_a] += da
		s2_pos := p; s2_pos[axis_b] += db
		c_pos := p; c_pos[axis_a] += da; c_pos[axis_b] += db

		s1 := int(voxel_at(grid, s1_pos[0], s1_pos[1], s1_pos[2]) != .Air)
		s2 := int(voxel_at(grid, s2_pos[0], s2_pos[1], s2_pos[2]) != .Air)
		cn := int(voxel_at(grid, c_pos[0], c_pos[1], c_pos[2]) != .Air)

		if s1 == 1 && s2 == 1 do result[i] = 0
		else do result[i] = u32(3 - (s1 + s2 + cn))
	}
	return result
}

voxel_mesh_build :: proc(grid: ^Voxel_Grid, allocator := context.allocator) -> (vertices: [dynamic]Voxel_Vertex, indices: [dynamic]u32) {
	vertices = make([dynamic]Voxel_Vertex, 0, len(grid.voxels), allocator)
	indices = make([dynamic]u32, 0, len(grid.voxels), allocator)

	for z in 0 ..< WORLD_DIMENSION[2] {
		for y in 0 ..< WORLD_DIMENSION[1] {
			for x in 0 ..< WORLD_DIMENSION[0] {
				voxel := voxel_at(grid, x, y, z)
				if voxel == .Air do continue

				for face, normal_id in FACES {
					n := face.neighbor
					if voxel_at(grid, x + n[0], y + n[1], z + n[2]) != .Air do continue

					ao := compute_face_ao(grid, x, y, z, face)

					base := u32(len(vertices))
					for corner, i in face.corner {
						append(
							&vertices,
							pack_vertex(u32(x) + corner[0], u32(y) + corner[1], u32(z) + corner[2], u32(normal_id), ao[i], u32(voxel)),
						)
					}

					if ao[0] + ao[2] > ao[1] + ao[3] {
						append(&indices, base + 0, base + 1, base + 2)
						append(&indices, base + 0, base + 2, base + 3)
					} else {
						append(&indices, base + 1, base + 2, base + 3)
						append(&indices, base + 1, base + 3, base + 0)
					}
				}
			}
		}
	}

	return
}
