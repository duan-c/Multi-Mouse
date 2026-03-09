# Native extension

This directory holds the C++ GDExtension that talks to the platform-specific
backends (Raw Input on Windows right now). It exposes a singleton
`MultiMouseServer` to Godot which:

- creates/destroys per-device records when mice are plugged in/out,
- queues raw motion + button events from the capture thread, and
- emits those events as stock `InputEventMouseMotion` / `InputEventMouseButton`
  objects tagged with metadata (`device_guid`, timestamps, etc.).

The Godot add-on (`addons/multi_mouse`) simply polls this server and re-emits the
signals; there is no autoload magic anymore.

## Building

### Windows

```
pwsh ./scripts/build_windows.ps1 -Target template_debug
```

The script:
1. Builds `extern/godot-cpp` via SCons (bindings + static lib).
2. Runs CMake for this folder with the proper include/library paths.
3. Copies the resulting `multi_mouse.dll` into
   `addons/multi_mouse/bin/win64/libmulti_mouse.windows.<target>.x86_64.dll`.

### Linux / other platforms

The Linux helper (`scripts/build_linux.sh`) mirrors the same steps, but the
backend is still a stub. Build here only if you are developing the future
ManyMouse/libinput implementation.

## Folder structure

- `platform/windows/` – Raw Input capture thread, device tracker, and queue.
- `server/` – platform-agnostic server that drains queues and emits Godot events.
- `events/` – thin wrappers around `InputEventMouseMotion/Button` so we can stash
  device metadata.
- `register_types.cpp` – GDExtension entry point.

## Status

- Raw motion / button events confirmed working on Windows.
- Hotplug works; each `device_guid` is stable for the lifetime of the session.
- Linux + macOS backends are not implemented yet.
