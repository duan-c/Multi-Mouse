# Multi-Mouse

Multi-Mouse is a Godot add-on that exposes simultaneous raw input from every mouse
plugged into a desktop. The end goal is to drop the plugin into any Godot 4 game,
instance one node, and get separate cursor transforms, button events, and motion
streams per physical mouse. Think local multiplayer sandboxes, collaborative UI
sketchpads, or two-handed tactile toys where each palm drives a different blob of
slime.

## Why this exists
Godot collapses all pointing devices into a single logical mouse. That means:

- you can't distinguish which USB mouse sent an event,
- acceleration and OS cursor settings distort the deltas, and
- only one cursor can exist in `InputEventMouseMotion`.

Multi-Mouse wraps a tiny native shim (initially Windows Raw Input, then Linux
/libinput via ManyMouse or evdev) and forwards each device's raw motion/button
state into Godot as structured signals.

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
   - Exposes a singleton `MultiMouseServer` to Godot.
   - Emits signals (`device_connected`, `device_disconnected`, `motion`, `button`)
     and maintains per-device state (position accumulators, button masks).
   - Thread-safe ring buffer so the polling thread can't stomp the main thread.

3. **Godot-facing add-on**
   - Autoload script that registers devices, spawns lightweight `MultiCursor`
     nodes (Sprite + Label), and surfaces a clean API:
     ```gdscript
     MultiMouse.on_motion(func(event: MultiMouseMotionEvent) -> void):
         # event has device_id, delta, position, timestamp
     ```
   - Sample scene showing a dual-hand slime toy to test latency.

## Milestones

1. **Scaffold** (this repo)  ✅
   - [ ] Set up Godot 4 add-on layout (`addons/multi_mouse/`).
   - [ ] Create GDExtension boilerplate (SCons/CMake presets).

2. **Windows proof of concept**
   - [ ] Implement minimal Raw Input collector (single thread, no hotplug yet).
   - [ ] Emit per-device motion events into Godot and draw two cursors.

3. **Hotplug + buttons**
   - [ ] Detect device connect/disconnect, assign stable IDs.
   - [ ] Forward button presses/releases per mouse.

4. **Linux backend**
   - [ ] Integrate ManyMouse (or direct libinput) build option.
   - [ ] Match event semantics with Windows for parity.

5. **Quality pass**
   - [ ] Editor UI helpers (device inspector, cursor glyphs).
   - [ ] Documentation + sample projects.
   - [ ] Publish to Godot Asset Library.

## Development setup

- Godot 4.2+
- C++ toolchain for GDExtension (MSVC/Clang/GCC)
- Windows SDK (for Raw Input) if building that backend
- Optional: `manymouse` submodule for Linux backend

More detailed build instructions will land once the GDExtension skeleton is in place.

## License
MIT (tbd once code lands)
