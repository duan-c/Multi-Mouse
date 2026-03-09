# Slime Demo

Procedural mass-spring toy that doubles as a stress test for the Multi-Mouse
backend. Multiple physical mice can poke the blob at the same time—each cursor
gets its own color, halo, and state.

## Files

- `slime_demo.tscn` – scene wiring + instructions.
- `slime_demo.gd` – simulation + input handling.

## Controls / features

- **ESC** – Exit.
- **1** – Swap to the radial "blob" mesh (concentric rings).
- **2** – Swap to an axis-aligned grid mesh.
- Hold **any mouse button** to push; hold **multiple buttons on the same mouse**
  to push harder (force multiplier).
- Each plugged-in mouse gets its own colored halo. Disconnecting a device removes
  its halo automatically.
- Demo no longer loses focus on Windows startup—you can wiggle the mice whenever
  you like.

## How it works

- Builds either a radial mesh (rings) or a rectangular grid of `SlimePoint`
  particles spaced 32 px apart.
- Connects neighbours via structural + shear springs. Points integrate with a
  simple semi-implicit Euler step and damping.
- Pointer state per device stores target/velocity/button flags. Motion events
  nudge the target directly, button events toggle the push forces.
- When Multi-Mouse isn’t available it falls back to the single Godot mouse and a
  shared pointer (`DEFAULT_POINTER_ID`).

## Wiring to the add-on

The scene expects a sibling `MultiMouse` node:

```gdscript
func _ready():
    _setup_multi_mouse("MultiMouse")
    if not _multi_enabled:
        _ensure_pointer(DEFAULT_POINTER_ID)
```

Inside `_setup_multi_mouse()` it calls `attach_to_window(0)` and `enable()`, then
connects the signals so every `InputEventMouseMotion/Button` is routed to the
pointer map.
