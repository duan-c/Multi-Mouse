# Multi-Mouse

Multi-Mouse is a Godot add-on that exposes simultaneous raw input from every mouse
plugged into a desktop. Drop it into any Godot 4 project, instance the provided
nodes, and you get separate cursor transforms, button events, and motion streams
per physical mouse. Think local multiplayer sandboxes, collaborative UI pads, or
slime toys you can grab with both hands.

## Why this exists
Godot collapses all pointing devices into a single logical mouse. That means:

- you can't distinguish which USB mouse sent an event,
- acceleration and OS cursor settings distort the deltas, and
- only one cursor can exist in `InputEventMouseMotion`.

Multi-Mouse wraps a native shim (Windows Raw Input first, Linux libinput /
ManyMouse next) and forwards each device's raw motion/button state into Godot as
strongly-typed events (`InputEventMultiMouseMotion`, `InputEventMultiMouseButton`).

## Planned architecture

```
+----------------+        +----------------+        +----------------------+
|  RawInput shim | -----> |  GDExtension   | -----> |   Godot add-on API   |
|  (per platform)|        |  (C++ bridge)  |        | (Nodes, signals, UI) |
+----------------+        +----------------+        +----------------------+
```

1. **Native capture layer**
   - Windows: Register for `WM_INPUT` via Raw Input, keep per-device handles.
   - Linux: Start with the ManyMouse library (evdev / XInput) for parity.
   - Normalizes packets into a shared struct `{ device_id, name, kind, delta, buttons }`.

2. **GDExtension bridge**
   - Exposes a singleton `MultiMouseServer` + event classes.
   - Emits signals (`device_connected`, `device_disconnected`, `motion`, `button`).
   - Thread-safe queue so the capture thread never blocks Godot's main loop.

3. **Godot-facing add-on**
   - Autoload `MultiMouse` node subscribes to the singleton and re-emits signals.
   - Sample scene shows multiple cursors driven by `InputEventMultiMouseMotion`.

## Milestones

1. **Scaffold** ✅
   - Godot add-on layout (`addons/multi_mouse/`).
   - GDExtension boilerplate + custom input-event classes.
   - Demo Godot project.

2. **Windows proof of concept**
   - Minimal Raw Input collector (single thread, no hotplug yet).
   - Emit per-device motion events into Godot and draw two cursors.

3. **Hotplug + buttons**
   - Detect device connect/disconnect, assign stable IDs.
   - Forward button presses/releases per mouse.

4. **Linux backend**
   - Integrate ManyMouse (or direct libinput) build option.
   - Match event semantics with Windows for parity.

5. **Quality pass**
   - Editor UI helpers (device inspector, cursor glyphs).
   - Documentation + sample projects.
   - Publish to Godot Asset Library.

## Development setup

- Godot 4.2+
- C++ toolchain for GDExtension (MSVC/Clang/GCC)
- Windows SDK (for Raw Input) if building that backend
- Submodule: `extern/godot-cpp` (run `git submodule update --init --recursive`)

### Building (Linux example)

```bash
./scripts/build_linux.sh  # builds godot-cpp + the multi_mouse shared lib

# Then copy the resulting lib into the plugin bin folder, e.g.:
cp build/linux/libmulti_mouse.so addons/multi_mouse/bin/linux/libmulti_mouse.linux.template_debug.x86_64.so
```

On Windows/macOS the flow is similar: build `godot-cpp` with SCons for your
platform/target, run CMake with `-DGODOT_CPP_LIB` pointing at the generated
static library, then copy the produced DLL/Dylib/SO into `addons/multi_mouse/bin/...`.

## License
MIT
