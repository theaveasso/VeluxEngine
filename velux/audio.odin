package velux

import "core:strings"

import ma "vendor:miniaudio"

Sound_Handle :: distinct u32

MAX_SOUNDS :: 64
INVALID_SOUND :: Sound_Handle(0)

Audio_Device :: struct {
	engine:      ma.engine,
	sounds:      [MAX_SOUNDS]ma.sound,
	sound_count: u32,
	enabled:     bool,
}

// A machine with no sound card is a machine velux still runs on, so audio is
// the one subsystem whose absence is not fatal.
@(require_results)
load_sound :: proc(file_name: string, spatial: bool, loc := #caller_location) -> (handle: Sound_Handle, err: Error) {
	audio := &g_engine.audio
	if !audio.enabled do return INVALID_SOUND, .Audio_Unavailable
	if audio.sound_count >= MAX_SOUNDS {
		fatal("more than MAX_SOUNDS (%d) sounds loaded", MAX_SOUNDS, loc = loc)
	}

	index := audio.sound_count
	sound := &audio.sounds[index]
	if result := ma.sound_init_from_file(
		&audio.engine,
		strings.clone_to_cstring(file_name, context.temp_allocator),
		spatial ? {} : {.NO_SPATIALIZATION},
		nil,
		nil,
		sound,
	); result != .SUCCESS {
		return INVALID_SOUND, .Sound_Load_Failed
	}

	audio.sound_count += 1
	return Sound_Handle(index + 1), .None
}

play_sound :: proc(handle: Sound_Handle) {
	audio := &g_engine.audio
	if !audio.enabled do return
	sound := sound_from_handle(audio, handle)
	if sound == nil do return
	ma.sound_start(sound)
}

stop_sound :: proc(handle: Sound_Handle) {
	audio := &g_engine.audio
	if !audio.enabled do return
	sound := sound_from_handle(audio, handle)
	if sound == nil do return
	ma.sound_stop(sound)
}

play_oneshot :: proc(file_name: string) {
	audio := &g_engine.audio
	if !audio.enabled do return
	ma.engine_play_sound(&audio.engine, strings.clone_to_cstring(file_name, context.temp_allocator), nil)
}

@(private)
init_audio :: proc(audio: ^Audio_Device) -> Error {
	if result := ma.engine_init(nil, &audio.engine); result != .SUCCESS {
		return .Audio_Unavailable
	}
	audio.enabled = true
	return .None
}

@(private)
destroy_audio :: proc(audio: ^Audio_Device) {
	if !audio.enabled do return
	for i in 0 ..< audio.sound_count do ma.sound_uninit(&audio.sounds[i])
	ma.engine_uninit(&audio.engine)
	audio^ = {}
}

@(private)
sound_from_handle :: proc(audio: ^Audio_Device, handle: Sound_Handle) -> ^ma.sound {
	if handle == INVALID_SOUND do return nil
	index := u32(handle) - 1
	if index >= audio.sound_count do return nil
	return &audio.sounds[index]
}
