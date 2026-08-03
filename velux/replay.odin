package velux

import "core:log"
import "core:mem"

Replay_Mode :: enum {
	Idle,
	Recording,
	Looping,
}

Replay_Frame :: struct {
	input: Input_State,
	dt:    f32,
}

Replay :: struct {
	mode:           Replay_Mode,
	snapshot:       []byte,
	frames:         [dynamic]Replay_Frame,
	cursor:         int,
	state_hash:     u64,
	shader_reloads: int,
	live_input:     Input_State,
	live_dt:        f32,
}

@(private)
replay_destroy :: proc(replay: ^Replay, allocator := context.allocator) {
	delete(replay.snapshot, allocator)
	delete(replay.frames)
	replay^ = {}
}

@(private)
replay_discard :: proc(replay: ^Replay, reason: string, allocator := context.allocator) {
	if replay.mode == .Idle && len(replay.frames) == 0 do return
	delete(replay.snapshot, allocator)
	replay.snapshot = nil
	clear(&replay.frames)
	replay.cursor = 0
	replay.mode = .Idle
	log.infof("replay: discarded (%s)", reason)
}

@(private)
replay_toggle :: proc(replay: ^Replay, memory: rawptr, state_size: int, state_hash: u64, allocator := context.allocator) {
	switch replay.mode {
	case .Idle:
		delete(replay.snapshot, allocator)
		snapshot, alloc_err := make([]byte, state_size, allocator)
		if alloc_err != nil {
			log.errorf("replay: snapshot alloc failed: %v", alloc_err)
			replay.snapshot = nil
			return
		}
		mem.copy(raw_data(snapshot), memory, state_size)
		replay.snapshot = snapshot
		replay.state_hash = state_hash
		replay.shader_reloads = g_engine.shader_reloads
		clear(&replay.frames)
		replay.cursor = 0
		replay.mode = .Recording
		log.info("replay: recording")

	case .Recording:
		if len(replay.frames) == 0 {
			replay.mode = .Idle
			log.info("replay: nothing recorded")
			return
		}
		replay.cursor = 0
		replay.mode = .Looping
		replay_rewind(replay, memory, state_size)
		log.infof("replay: looping %d frames", len(replay.frames))

	case .Looping:
		replay.mode = .Idle
		log.info("replay: stopped")
	}
}

@(private)
replay_rewind :: proc(replay: ^Replay, memory: rawptr, state_size: int) {
	if len(replay.snapshot) != state_size do return
	mem.copy(memory, raw_data(replay.snapshot), state_size)
	replay.cursor = 0
}

@(private)
replay_capture :: proc(replay: ^Replay) {
	if replay.mode != .Recording do return
	append(&replay.frames, Replay_Frame{input = g_engine.input, dt = g_engine.dt})
}

@(private)
replay_apply :: proc(replay: ^Replay, memory: rawptr, state_size: int) {
	if replay.mode != .Looping do return
	if replay.cursor >= len(replay.frames) do replay_rewind(replay, memory, state_size)
	if len(replay.frames) == 0 do return

	frame := replay.frames[replay.cursor]
	replay.cursor += 1

	replay.live_input = g_engine.input
	replay.live_dt = g_engine.dt

	handle := g_engine.input.window_handle
	g_engine.input = frame.input
	g_engine.input.window_handle = handle
	g_engine.dt = frame.dt
}

@(private)
replay_unapply :: proc(replay: ^Replay) {
	if replay.mode != .Looping do return
	g_engine.input = replay.live_input
	g_engine.dt = replay.live_dt
}
