package gpu

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

@(private, require_results)
create_profiler :: proc(device: ^Device) -> (err: Error) {
	if !device.enable_profiler do return
	defer if err != .None do destroy_profiler(device)

	info: vk.QueryPoolCreateInfo = {
		sType      = .QUERY_POOL_CREATE_INFO,
		pNext      = nil,
		queryType  = .TIMESTAMP,
		queryCount = MAX_ZONES * 2,
	}
	for &pool in device.profiler.pools {
		vk_check(vk.CreateQueryPool(device.device, &info, nil, &pool)) or_return
	}
	device.profiler.period_ns = device.timestamp_period
	return
}

@(private)
destroy_profiler :: proc(device: ^Device) {
	if !device.enable_profiler do return

	for &pool in device.profiler.pools {
		vk.DestroyQueryPool(device.device, pool, nil)
	}
}

zone_begin :: proc(device: ^Device, frame: Frame, name: string, loc := #caller_location) -> (zone_index: u32) {
	if !device.enable_profiler do return 0

	slot := frame.frame_index
	assert(device.profiler.zone_count[slot] < MAX_ZONES, "profiler zone count exceeded MAX_ZONES", loc)
	zone_index = device.profiler.zone_count[slot]
	device.profiler.zone_names[slot][zone_index] = name

	vk.CmdWriteTimestamp2(frame.cmd, {.TOP_OF_PIPE}, device.profiler.pools[slot], zone_index * 2)
	device.profiler.zone_count[slot] += 1
	return zone_index
}

zone_end :: proc(device: ^Device, frame: Frame, loc := #caller_location) {
	if !device.enable_profiler do return

	slot := frame.frame_index
	assert(device.profiler.zone_count[slot] > 0, "zone_end without a matching zone_begin", loc)
	zone_index := device.profiler.zone_count[slot] - 1
	vk.CmdWriteTimestamp2(frame.cmd, {.BOTTOM_OF_PIPE}, device.profiler.pools[slot], zone_index * 2 + 1)
}

@(private, require_results)
readback_profiler :: proc(device: ^Device, slot: u32) -> (err: Error = .None) {
	if !device.enable_profiler do return

	zone_count := device.profiler.zone_count[slot]
	if zone_count == 0 {
		device.profiler.result_count = 0
		return
	}

	ticks: [MAX_ZONES * 2]u64
	query_count := zone_count * 2

	vk_check(
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
	) or_return

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
	return
}

@(private)
reset_profiler :: proc(device: ^Device, cmd: vk.CommandBuffer, slot: u32) {
	if !device.enable_profiler do return

	vk.CmdResetQueryPool(cmd, device.profiler.pools[slot], 0, MAX_ZONES * 2)
	device.profiler.zone_count[slot] = 0
}
