package tests

import "core:testing"
import "vlx:audio"

@(test)
bad_sound_handles_are_ignored :: proc(t: ^testing.T) {
	device: audio.Device
	audio.init(&device)
	defer audio.destroy(&device)

	audio.play(&device, audio.INVALID_SOUND)
	audio.play(&device, audio.Sound_Handle(9999))
	audio.stop(&device, audio.INVALID_SOUND)
	audio.stop(&device, audio.Sound_Handle(1))
}

@(test)
loading_a_missing_file_returns_an_invalid_handle :: proc(t: ^testing.T) {
	device: audio.Device
	if audio.init(&device) != .None do return
	defer audio.destroy(&device)

	handle, err := audio.load(&device, "does_not_exist.wav", false)
	testing.expect(t, handle == audio.INVALID_SOUND, "missing file gives an invalid handle")
	testing.expect(t, err == .Load_Failed, "and reports Load_Failed")
}
