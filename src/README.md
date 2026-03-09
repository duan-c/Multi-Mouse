# Native extension scaffold

This directory contains the C++ GDExtension that forwards multi-mouse events to
Godot. Platform backends live under `platform/` (Raw Input on Windows today,
libinput/ManyMouse coming next). The extension exposes a singleton named
`MultiMouseServer` that queues per-device motion/button events and hands them to
any `MultiMouse` nodes inside the engine.

## Windows backend status

- Creates a hidden Raw Input window, registers every physical mouse, and assigns
  each one a stable GUID + numeric ID.
- Queues `RawInputMousePacket` structs that include relative deltas, absolute
  timestamps, and button changes.
- `MultiMouseServer.poll()` drains the queue on Godot's main thread, emits stock
  `InputEventMouseMotion/Button` objects, and mirrors the GUID into
  `event.set_meta("device_guid", guid)` so game code can filter without touching
  native APIs.
- `attach_to_window(hwnd)` optionally re-registers the backend against the main
  Godot window so focus changes and confining/unhiding the cursor behave.

## Building

1. Initialise submodules and build `godot-cpp` once per platform/target.
   ```bash
   git submodule update --init --recursive
   cd extern/godot-cpp
   scons platform=linux target=template_debug bits=64 -j$(nproc)
   ```
2. Configure + build the extension with CMake, pointing at the generated
   headers + static library.
   ```bash
   cmake -B build/linux -S src \
     -DGODOT_CPP_PATH=../extern/godot-cpp \
     -DGODOT_CPP_LIB=../extern/godot-cpp/bin/libgodot-cpp.linux.template_debug.x86_64.a
   cmake --build build/linux --config Release
   ```
3. Copy the resulting `.so/.dll` into `addons/multi_mouse/bin/<platform>/` or
   run the helper scripts:
   - `./scripts/build_linux.sh`
   - `./scripts/build_windows.ps1`

The scripts regenerate bindings when needed, build both debug & release
variants, and deposit them where the add-on expects them.

## Next steps

- Port the backend to Linux (ManyMouse prototype + libinput rewrite).
- Add device-name queries and diagnostics helpers to `MultiMouseServer` so the
  Godot layer can present friendlier info.
- Expand the test harnesses under `tests/` to simulate multiple devices.
