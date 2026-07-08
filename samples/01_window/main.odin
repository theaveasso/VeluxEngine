package main

import "vendor:glfw"

main :: proc() {
	if !glfw.Init() {
		return
	}
	defer glfw.Terminate()

	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)

	window := glfw.CreateWindow(1280, 720, "VeluxEngine", nil, nil)
	if window == nil {
		return
	}
	defer glfw.DestroyWindow(window)

	for !glfw.WindowShouldClose(window) {
		glfw.PollEvents()
	}
}
