package velux

import "core:fmt"

import vma "third_party:odin-vma"
import vk "vendor:vulkan"



FRAME_HISTORY :: 120

Hud :: struct {
	frame_ms:   [FRAME_HISTORY]f32,
	zone_ms:    [MAX_ZONES]f32,
	head:       u32,
	fps_smooth: f32,
	show:       bool,
}

hud_update :: proc(engine: ^Engine) {
	if engine.dt <= 0 do return

	engine.hud.frame_ms[engine.hud.head] = engine.dt * 1000
	engine.hud.head = (engine.hud.head + 1) % FRAME_HISTORY

	target_fps := 1. / engine.dt
	engine.hud.fps_smooth += (target_fps - engine.hud.fps_smooth) * 0.1

	profiler := &engine.gpu.profiler
	for zone in 0 ..< profiler.result_count {
		engine.hud.zone_ms[zone] += (profiler.results[zone].ms - engine.hud.zone_ms[zone]) * 0.1
	}
}

hud_draw :: proc(engine: ^Engine) {
	if !engine.hud.show do return

	if ui_begin_panel("Profiler") {
		ui_text(fmt.tprintf("%.1f fps		(%.2f ms)", engine.hud.fps_smooth, engine.dt * 1000))
		ui_plot_lines("frame ms", engine.hud.frame_ms[:])

		total_ms: f32
		for zone in 0 ..< engine.gpu.profiler.result_count {
			result := engine.gpu.profiler.results[zone]
			smoothed_ms := engine.hud.zone_ms[zone]
			ui_text(fmt.tprintf("%s		%.3f ms", result.name, smoothed_ms))
			total_ms += smoothed_ms
		}
		ui_text(fmt.tprintf("gpu total %.3f ms", total_ms))

		used_mb, total_mb := hud_vram_usage(engine)
		ui_text(fmt.tprintf("vram 	%.0f / %.0f MB", used_mb, total_mb))
	}
	ui_end_panel()
}

@(private)
hud_vram_usage :: proc(engine: ^Engine) -> (used_mb: f32, total_mb: f32) {
	memory_props: vk.PhysicalDeviceMemoryProperties
	vk.GetPhysicalDeviceMemoryProperties(engine.gpu.physical_device, &memory_props)

	budgets: [vk.MAX_MEMORY_HEAPS]vma.Budget
	vma.GetHeapBudgets(engine.gpu.vma_allocator, &budgets[0])

	used_bytes, total_bytes: u64
	for heap in 0 ..< memory_props.memoryHeapCount {
		if .DEVICE_LOCAL not_in memory_props.memoryHeaps[heap].flags do continue
		used_bytes += u64(budgets[heap].usage)
		total_bytes += u64(budgets[heap].budget)
	}

	MEGABYTE :: 1024 * 1024
	return f32(used_bytes) / MEGABYTE, f32(total_bytes) / MEGABYTE
}
