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

Setup initialises the nested submodules and builds the two native libraries velux links
against: [VulkanMemoryAllocator](https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator)
and [Dear ImGui](https://github.com/ocornut/imgui). Windows uses the prebuilt `.lib` files
that ship with the submodules; macOS and Linux build them from source. The imgui build
clones dear imgui, glfw, SDL2, SDL3 and Vulkan-Headers, so the first run takes a few
minutes. Re-running setup is cheap — it skips anything already built.

## Building a sample

```sh
./build.sh sponza      # macOS / Linux
build.bat sponza       # Windows
```

Run the executable **from its own directory** so its relative asset paths resolve:

```sh
cd samples/sponza && ./sponza
```

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

It defaults to `../../velux/shaders`, which is only correct for velux's own samples.
If a `create_gpu_pipeline` call returns `Compile_Failed` with `undefined identifier`
errors for things like `sky_gradient`, this is the setting that is wrong.

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
samples/          engine samples
game/             games built on velux
third_party/      odin-vma, odin-imgui (submodules)
```

## Note on samples

`samples/sponza` and `game/her_body_waits` track the current App API. Samples `01`–`05`
predate it and do not compile; they are kept as reference for the rendering techniques
only.
