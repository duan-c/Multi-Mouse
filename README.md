# Multi-Mouse

Multi-Mouse is a Godot add-on + native extension that gives every physical
mouse plugged into a desktop its own stream of raw motion and button events.
Instance the provided `MultiMouse` node inside any scene, attach it to the
current window, and you instantly get per-device cursors/signals for local
multiplayer toys, collaborative UI pads, or weird physical installations.

https://github.com/WordForgeLive/Multi-Mouse

## Project status (March 2026)

- ✅ **Windows backend** – Raw Input shim is live. The demo builds ship with a
  working DLL and no longer require the user to keep their mouse still while the
  backend spins up.
- ✅ **Scene-local MultiMouse node** – The manager is no longer forced into the
  autoload list. Drop the `MultiMouse` node anywhere (or instance via code) and
  opt-in per scene.
- ✅ **Demos** – The simple diagnostic scene logs motion/button events per
  device. The upgraded “Slime” sandbox lets multiple mice push either a radial
  blob or a rectangular grid, supports multi-button “push harder”, and now keeps
  focus reliably.
- 🟡 **Linux backend** – ManyMouse/libinput port next on deck.

## Quick start

1. **Clone + init submodules**
   ```bash
   git clone https://github.com/WordForgeLive/Multi-Mouse.git
   cd Multi-Mouse
   git submodule update --init --recursive
   ```
2. **Build the native library**
   - Linux: `./scripts/build_linux.sh`
   - Windows (PowerShell): `./scripts/build_windows.ps1`

   The scripts build `godot-cpp`, compile the extension, and drop the resulting
   `.so/.dll` into `addons/multi_mouse/bin/<platform>/` where the plugin expects
   it.
3. **Open the demo project (or your own)**
   - Launch Godot 4.2+, open `demo/project.godot` (or copy `addons/multi_mouse`
     into your project and enable it via **Project → Plugins**).
4. **Add a `MultiMouse` node**
   - In any scene, add the `MultiMouse` node (it’s a regular `Node`).
   - In `_ready()` call `attach_to_window()` **before** `enable()` so the backend
     knows which OS window to listen to. Passing `0` uses the primary window on
     Windows; alternatively you can feed
     `DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE_WINDOW)`.
   - Connect the `motion`, `button`, `device_connected`, and
     `device_disconnected` signals to your gameplay code.

```gdscript
@onready var multi_mouse := $MultiMouse

func _ready():
    if multi_mouse:
        var hwnd = 0 # or query DisplayServer for the exact handle
        multi_mouse.attach_to_window(hwnd)
        multi_mouse.enable()
        multi_mouse.motion.connect(_on_motion)

func _on_motion(event: InputEventMouseMotion) -> void:
    var guid = event.get_meta("device_guid") if event.has_meta("device_guid") else str(event.device)
    print("Mouse", guid, "moved", event.relative)
```

## Demos

### Simple Demo (`demo/simple/demo.tscn`)
Shows the bare minimum wiring:

- Adds a `MultiMouse` node as a child of the scene root.
- Attaches it to the foreground window and enables the backend.
- Displays the most recent motion/button event (`ESC` exits).

Use it to verify the backend sees all plugged-in mice before integrating into
another project.

### Slime Demo (`demo/slime/slime_demo.tscn`)
A mass-spring playground that doubles as a stress test:

- `1` swaps to a **radial blob**, `2` swaps to a **grid** mesh.
- Each mouse cursor gets its own colored halo and pointer physics; pressing any
  button pushes the slime, and holding multiple buttons on the same mouse pushes
  harder.
- Focus/attachment issues are gone—the backend attaches immediately and ignores
  incidental motion during startup.
- ESC exits. The instructions are rendered onscreen.

## Why this exists
Godot collapses all pointing devices into one logical cursor which means you:

- can’t tell which physical mouse sent a packet,
- inherit OS acceleration/noise, and
- only get one cursor’s worth of interaction.

Multi-Mouse captures raw events per device and forwards them to Godot via a
GDExtension so game code can treat each mouse independently without reinventing
input plumbing.

## Architecture
```
+----------------+        +----------------+        +----------------------+
|  RawInput shim | -----> |  GDExtension   | -----> |   Godot add-on API   |
|  (per platform)|        |  (C++ bridge)  |        | (Nodes, signals, UI) |
+----------------+        +----------------+        +----------------------+
```
1. **Native capture layer** – Platform-specific modules (Raw Input on Windows,
   libinput/ManyMouse on Linux) normalise packets into a shared struct.
2. **GDExtension bridge** – `MultiMouseServer` singleton queues events,
   registers devices, and emits Godot `InputEventMouseMotion/Button` objects with
   metadata (`device_guid`, timestamps).
3. **Godot add-on** – The `MultiMouse` node wraps the singleton, exposes
   high-level signals, and demos show how to drive gameplay from them.

## Development notes

- C++ lives under `src/` with platform backends in `src/platform/...`.
- Scripts in `scripts/` compile both `godot-cpp` and the extension with the
  correct flags.
- Built libraries live in `addons/multi_mouse/bin/<platform>/`. Ensure both the
  debug and release variants exist if you want to run editor + export targets.
- On Windows the native layer owns a hidden message window. When you call
  `MultiMouse.attach_to_window(hwnd)` it registers the provided HWND with Raw
  Input so focus changes don’t kill the stream.

## Roadmap

- [x] Windows Raw Input backend (motion + buttons + hotplug)
- [ ] Linux backend (ManyMouse/libinput)
- [ ] Editor diagnostics (device inspector, cursor gizmos)
- [ ] Asset Library packaging

## License
MIT
