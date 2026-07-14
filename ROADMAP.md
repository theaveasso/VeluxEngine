# VeluxEngine Roadmap

Goal: an Odin + Vulkan framework strong enough to land an **engine/systems programmer** job.
Pace: 15+ hrs/week → job-ready portfolio in ~5-6 months.

Rule: every milestone ends with a runnable `samples/NN_name` demo and a short devlog note.
Hiring managers look at commits, samples, and whether you can explain tradeoffs — not lines of code.

---

## Phase 1 — Vulkan Foundation (weeks 1–4)

### M1: Vulkan init `samples/02_init`
- Instance, validation layers, debug messenger
- Physical device selection, logical device, queues
- Odin skills: `vendor:vulkan`, error handling with `or_return`, tagged unions for errors
- Framework: `framework/gpu/` package begins

### M2: Swapchain + clear `samples/03_clear`
- Surface, swapchain creation + recreation (resize!)
- Command pools/buffers, frame loop, fences + semaphores
- **Use synchronization2 and dynamic rendering from day one** (no render passes/framebuffers)

### M3: Triangle → mesh `samples/04_mesh`
- Shader compilation (slang or glslc → SPIR-V, build script)
- Graphics pipeline, vertex/index buffers, staging uploads
- Depth buffer, perspective camera, push constants

### M4: Textures + descriptors `samples/05_textured`
- Images, samplers, mipmaps, layout transitions
- Descriptor sets — design for **bindless** (descriptor indexing) early
- Load glTF mesh (`vendor:cgltf`) + KTX2/PNG textures

**Checkpoint: spinning textured model, resizable window, zero validation errors.**

---

## Phase 2 — Systems Core (weeks 5–10) ← this is what gets you the *systems* job

### M5: Memory
- Arena, pool, and free-list allocators using Odin's `Allocator` interface
- Per-frame temp arenas; tracking allocator to catch leaks in debug
- GPU memory: integrate VMA (or write a simple block allocator and say why)

### M6: Handles + resource manager
- Generational handles (`Handle(T)` with index+generation) instead of pointers
- Central GPU resource tables; deferred destruction (per-frame delete queues)

### M7: Job system
- Work-stealing or simple task pool over `core:thread` + `core:sync`
- Parallel command recording as the proof-of-concept

### M8: Asset pipeline
- Offline cook step: glTF → custom binary format (fast memcpy-able loads)
- Hashing, dependency tracking, hot reload of shaders + textures

**Checkpoint: profile it. Capture a frame in RenderDoc/Tracy screenshots for the README.**

---

## Phase 3 — Renderer Depth (weeks 11–18)

### M9: Render graph (the portfolio centerpiece)
- Declare passes + resources, auto-derive barriers and transient allocations
- This is the #1 "modern engine" interview topic

### M10: Scene rendering
- Bindless everything, GPU-driven: draw indirect, per-object data in SSBOs
- Frustum culling on GPU (compute), PBR lighting, shadow maps

### M11: One "wow" technique (pick ONE, do it well)
- Clustered/forward+ lighting, cascaded shadows, GTAO, or bloom+tonemap chain

**Checkpoint: Sponza (or similar) at high FPS with a frame-graph visualizer.**

---

## Phase 4 — Ship It (weeks 19–24)

### M12: Tooling
- Dear ImGui integration, live tweakables, frame stats, allocator visualizer

### M13: Polish for hiring
- README with architecture diagram + GIFs
- 2–3 devlog posts explaining design decisions (render graph, handles, memory)
- Clean build: one command (`build.bat` / `odin build`), Windows first
- Apply while finishing Phase 4, not after

---

## Best practices (enforced from commit one)

**Odin**
- Packages by domain: `framework/gpu`, `framework/mem`, `framework/asset`, `framework/platform`
- Pass `Allocator` explicitly in APIs that allocate; use `context.temp_allocator` for scratch
- `or_return` + error enums/unions, not booleans; zero-is-valid struct design (ZII)
- Handles over pointers across system boundaries
- `#no_bounds_check` only after profiling proves it matters

**Vulkan**
- Validation layers always on in debug; treat any message as a bug
- Dynamic rendering + sync2 + descriptor indexing (Vulkan 1.3 baseline)
- Name every object with debug utils — future-you in RenderDoc will thank you
- Frames in flight = 2; never wait idle except on resize/shutdown

**Process**
- Small commits with real messages (your `tes`/`ddd`/`wip` era ends now)
- Every sample stays buildable forever — they're regression tests and the portfolio
- Devlog notes in `docs/` per milestone: what, why, what went wrong
