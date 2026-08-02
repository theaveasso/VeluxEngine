package vox

pack_palete :: proc(model: Model) -> (packed: [PALETTE_SLOTS]u32) {
	packed[0] = 0
	for i in 0 ..< 255 {
		palette := model.palette[i]
		packed[i + 1] = u32(palette.r) | u32(palette.g) << 8 | u32(palette.b) << 16 | u32(palette.a) << 24
	}
	return
}
