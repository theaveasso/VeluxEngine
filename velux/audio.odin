package velux

import "core:strings"

import ma "vendor:miniaudio"

Sound_Handle :: distinct u32

MAX_SOUNDS :: 64
INVALID_SOUND :: Sound_Handle(0)

Audio_Error :: enum {
	None,
	Engine_Init_Failed,
	Load_Failed,
	Too_Many_Sounds,
}

Audio_Device :: struct {
	engine:      ma.engine,
	sounds:      [MAX_SOUNDS]ma.sound,
	sound_count: u32,
	enabled:     bool,
}

@(require_results)
load_sound :: proc(file_name: string, spatial: bool) -> (handle: Sound_Handle, err: Error) {
	audio := &g_engine.audio
	if audio.sound_count >= MAX_SOUNDS do return INVALID_SOUND, Audio_Error.Too_Many_Sounds
	if !audio.enabled do return INVALID_SOUND, nil

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
		return INVALID_SOUND, Audio_Error.Load_Failed
	}

	audio.sound_count += 1
	return Sound_Handle(index + 1), nil
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
init_audio :: proc(audio: ^Audio_Device) -> (err: Audio_Error) {
	result := ma.engine_init(nil, &audio.engine); if result != .SUCCESS {
		return .Engine_Init_Failed
	}
	audio.enabled = true
	return
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
