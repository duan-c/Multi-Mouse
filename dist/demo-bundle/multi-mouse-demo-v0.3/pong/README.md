# Pong Demo

Local multiplayer Pong that uses nothing but Multi-Mouse input. Each hardware
mouse can claim a side, move its paddle, and rally immediately—no keyboard or
UI selection required.

## Controls

- `Esc` – exit the scene.
- First mouse to **left-click** claims the left paddle (and serves if both
  players are present).
- First mouse to **right-click** claims the right paddle (and serves if both
  players are present).
- Move the claimed mouse to slide your paddle vertically; bounds are clamped to
  the window height.

Join/leave by restarting the scene (or reloading the project). The labels above
each score show “L-Click to join” / “R-Click to join” until a device claims that
side.

![Pong demo screenshot](../../docs/screenshots/pong_demo.png)

## Running the scene

1. Open `demo/project.godot` in Godot 4.
2. Enable the **Multi-Mouse** plugin if it is not already active.
3. Run the `Pong` scene (`demo/pong/pong.tscn`). Have two USB mice ready so each
   player can click their side.

## Multi-Mouse integration

`pong.gd` shows how to:

- Use per-device button presses to claim roles (first left-click → left paddle,
  first right-click → right paddle).
- Track device IDs for movement so each mouse only moves its own paddle.
- Reset the round once both players have joined.

It’s a compact reference for any local-multiplayer game where players need to
self-assign roles using only their mouse.
