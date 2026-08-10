# VeluxEngine

A voxel engine in Odin, rendering with Vulkan and GPU ray casting.

Velux is a **library**, not a framework you copy into. You add it to your game repo as a
git submodule and point two Odin collections at it. See
[velux-starter](https://github.com/theaveasso/velux-starter) for a working example you can
clone and rename.

## Requirements

| | Windows | macOS |
|---|---|---|
| Odin | [odin-lang.org](https://odin-lang.org) | `brew install odin` |
| Vulkan | [LunarG SDK](https://vulkan.lunarg.com) | `brew install vulkan-headers vulkan-loader molten-vk vulkan-tools` |
| Slang | ships with the LunarG SDK | `brew install shader-slang` |
| Python 3 | required (builds imgui) | ships with macOS |
| CMake | required (builds box3d) | `brew install cmake` |
| C++ compiler | MSVC | Xcode command line tools (`xcode-select --install`) |

`VULKAN_SDK` must be set. The LunarG installer sets it on Windows. On macOS `setup.sh`
falls back to `/opt/homebrew` automatically, which is where Homebrew puts
`include/vulkan` and `bin/slangc`.

## Setup

```sh
git clone --recurse-submodules https://github.com/theaveasso/VeluxEngine.git
cd VeluxEngine

./setup.sh      # macOS / Linux
setup.bat       # Windows
```

Setup initialises the nested submodules and builds the three native libraries velux links
against: [VulkanMemoryAllocator](https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator),
[Dear ImGui](https://github.com/ocornut/imgui) and [box3d](https://github.com/erincatto/box3d).
Windows uses the prebuilt `.lib` files that ship with the vma and imgui submodules; box3d is
compiled with CMake on every platform, and macOS and Linux build all three from source. The
imgui build clones dear imgui, glfw, SDL2, SDL3 and Vulkan-Headers, so the first run takes a
few minutes. Re-running setup is cheap — it skips anything already built.

## Running something

This repository is the library on its own — there is no executable to launch here. To see
velux render, clone [velux-starter](https://github.com/theaveasso/velux-starter) and run it;
it pulls this repo in as a submodule.

## Using velux from your own repo

Add it as a submodule:

```sh
git submodule add https://github.com/theaveasso/VeluxEngine.git third_party/velux
git submodule update --init --recursive
third_party/velux/setup.sh
```

Your game builds with two collections — one for velux itself, one for velux's own
dependencies:

```sh
odin build src -debug \
  -collection:vlx=third_party/velux \
  -collection:third_party=third_party/velux/third_party \
  -out:build/game
```

`-collection:third_party` is easy to miss. Without it, velux's own
`import vma "third_party:odin-vma"` fails to resolve and you get errors from inside the
engine rather than from your code.

Then in your game:

```odin
import vlx "vlx:velux"
```

### Shader includes

Velux ships shared Slang modules in `velux/shaders` (`world`, `color`, `tonemap`, `hash`).
The engine compiles your `.slang` files at runtime and needs to know where those modules
live, so set `shader_include_dir` in your config — it is a path relative to the working
directory you run from:

```odin
vlx.make_app(Game, config = {
    app_name           = "My Game",
    shader_include_dir = "third_party/velux/velux/shaders",
}, ...)
```

There is a default of `../../velux/shaders`, left over from a layout that no longer exists —
treat it as unset and always pass your own. If a `create_gpu_pipeline` call returns
`Compile_Failed` with `undefined identifier` errors for things like `sky_gradient`, this is
the setting that is wrong.

### Editor support (ols)

Copy velux's collection setup into your repo's `ols.json`:

```json
{
  "collections": [
    { "name": "vlx", "path": "third_party/velux" },
    { "name": "third_party", "path": "third_party/velux/third_party" }
  ]
}
```

## Repository layout

```
velux/            the engine package  -> import vlx "vlx:velux"
velux/shaders/    shared Slang modules
hot_reload/       the hot reload host, built by build_hot_reload
tests/            odin test suite
third_party/      odin-vma, odin-imgui, box3d, box3d-odin
```

## Per-frame data

Anything you upload every frame goes through the frame's upload ring, from `draw`,
before `cmd_begin_rendering`:

```odin
game_draw :: proc(game: ^Game, frame: vlx.Frame) {
    vlx.frame_upload_slice(frame, &game.some_buffer, game.some_data[:])
    vlx.cmd_begin_rendering(frame, clear)
    ...
}
```

That records a copy out of a persistently mapped per-frame buffer — no allocation, no
submit, no fence. `immediate_transfer_begin` / `write_staging_buffer_slice` /
`immediate_transfer_end` still exist and still block; they are for load-time uploads.
Calling them per frame stalls the CPU on the GPU once per call.

## Errors

`Error` holds only failures a caller can act on — a missing asset, a shader that would
not compile, a swapchain that went out of date, audio that is unavailable. Everything
else (no suitable GPU, a failed allocation, a Vulkan call that can only fail on misuse)
stops the process at the point of failure with the parameters that caused it, rather
than travelling up as an enum.

Velux logs through `context.logger`. If you have not installed one, `run` and
`run_hot_reload` install a console logger for the duration.

## Tests

```sh
odin test tests -collection:vlx=. -collection:third_party=third_party
```

In Zed this is the `test all` task, alongside `test current file` for a single file and a
`debug tests` launch config that runs the suite under CodeLLDB.
