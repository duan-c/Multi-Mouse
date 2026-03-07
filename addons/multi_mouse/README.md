# Multi-Mouse Godot Add-on

This folder holds the Godot-facing layer of the project:

- `plugin.cfg` / `plugin.gd` register the add-on and autoload `MultiMouse`.
- `multi_mouse_manager.gd` listens to the native `MultiMouseServer` signals and
  re-emits them as standard `InputEventMouseMotion` / `InputEventMouseButton`
  instances, annotated with metadata (`device_guid`, `timestamp_us`).
- `bin/multi_mouse.gdextension` points Godot at the compiled native libraries for
  each platform/target.

Drop the entire `addons/multi_mouse` directory into any Godot 4 project,
build the native library for your platform, and enable the add-on via
`Project Settings → Plugins`.
