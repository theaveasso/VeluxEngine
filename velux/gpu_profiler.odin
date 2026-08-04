package velux

import vk "vendor:vulkan"

MAX_ZONES :: 32

Zone_Result :: struct {
	name: string,
	ms:   f32,
}

Profiler :: struct {
	pools:        [MAX_FRAMES_IN_FLIGHT]vk.QueryPool,
	zone_names:   [MAX_FRAMES_IN_FLIGHT][MAX_ZONES]string,
	zone_count:   [MAX_FRAMES_IN_FLIGHT]u32,
	results:      [MAX_ZONES]Zone_Result,
	result_count: u32,
	period_ns:    f32,
}

@(private)
create_profiler :: proc(device: ^GPU_Device) {
	if !device.enable_profiler do return

	info: vk.QueryPoolCreateInfo = {
		sType      = .QUERY_POOL_CREATE_INFO,
		pNext      = nil,
		queryType  = .TIMESTAMP,
		queryCount = MAX_ZONES * 2,
	}
	for &pool in device.profiler.pools {
		vk_assert(vk.CreateQueryPool(device.device, &info, nil, &pool), "vkCreateQueryPool")
	}
	device.profiler.period_ns = device.timestamp_period
}

@(private)
destroy_profiler :: proc(device: ^GPU_Device) {
	if !device.enable_profiler do return

	for &pool in device.profiler.pools {
		vk.DestroyQueryPool(device.device, pool, nil)
	}
}

prof_zone_begin :: proc(frame: Frame, name: string, loc := #caller_location) -> (zone_index: u32) {
	device := &g_engine.gpu
	if !device.enable_profiler do return 0

	slot := frame.frame_index
	if device.profiler.zone_count[slot] >= MAX_ZONES {
		fatal("more than MAX_ZONES (%d) profiler zones in one frame", MAX_ZONES, loc = loc)
	}
	zone_index = device.profiler.zone_count[slot]
	device.profiler.zone_names[slot][zone_index] = name

	vk.CmdWriteTimestamp2(frame.cmd, {.TOP_OF_PIPE}, device.profiler.pools[slot], zone_index * 2)
	device.profiler.zone_count[slot] += 1
	return zone_index
}

prof_zone_end :: proc(frame: Frame, loc := #caller_location) {
	device := &g_engine.gpu
	if !device.enable_profiler do return

	slot := frame.frame_index
	if device.profiler.zone_count[slot] == 0 do fatal("prof_zone_end without a matching prof_zone_begin", loc = loc)
	zone_index := device.profiler.zone_count[slot] - 1
	vk.CmdWriteTimestamp2(frame.cmd, {.BOTTOM_OF_PIPE}, device.profiler.pools[slot], zone_index * 2 + 1)
}

@(private)
readback_profiler :: proc(device: ^GPU_Device, slot: u32) {
	if !device.enable_profiler do return

	zone_count := device.profiler.zone_count[slot]
	if zone_count == 0 {
		device.profiler.result_count = 0
		return
	}

	ticks: [MAX_ZONES * 2]u64
	query_count := zone_count * 2

	vk_assert(
		vk.GetQueryPoolResults(
			device.device,
			device.profiler.pools[slot],
			0,
			query_count,
			size_of(u64) * int(query_count),
			&ticks[0],
			size_of(u64),
			{._64, .WAIT},
		),
		"vkGetQueryPoolResults",
	)

	for zone in 0 ..< zone_count {
		begin_tick := ticks[zone * 2]
		end_tick := ticks[zone * 2 + 1]
		elapsed_ns := f32(end_tick - begin_tick) * device.profiler.period_ns

		device.profiler.results[zone] = {
			name = device.profiler.zone_names[slot][zone],
			ms   = elapsed_ns / 1_000_000,
		}
	}
	device.profiler.result_count = zone_count
}

@(private)
reset_profiler :: proc(device: ^GPU_Device, cmd: vk.CommandBuffer, slot: u32) {
	if !device.enable_profiler do return

	vk.CmdResetQueryPool(cmd, device.profiler.pools[slot], 0, MAX_ZONES * 2)
	device.profiler.zone_count[slot] = 0
}
