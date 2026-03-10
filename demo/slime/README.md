# Slime Demo

A playable stress-test for Multi-Mouse. Multiple hardware mice can poke the blob
at the same time and the simulation reacts to each pointer independently.

## Controls

- `Esc` – exit.
- `1` – switch to the radial “circle” mesh.
- `2` – switch to the rectangular grid mesh.
- `N` – show/hide nodes.
- `C` – show/hide connections.
- Hold any mouse button to push the slime. Hold multiple buttons on the same
  mouse to push harder (the force stacks).

Each pointer gets its own colour and halo so you can tell which device is applying force.

A new exported `mesh_texture` property lets you drop in any tileable texture for
the membrane. Leaving it empty still renders the polygon with a solid color.

## Assets

The default membrane art ships from the **“Handpainted tileable textures 512×512”** pack by
[DeadKir](https://opengameart.org/users/deadkir) (CC0) on OpenGameArt — file `ooz_slime.png`.
Swap in your own tileable texture via the `mesh_texture` export on the root `Slime`
node if you need a different style.

## Multi-Mouse integration

`slime_demo.gd` shows how to:

- Attach a `MultiMouse` node that lives alongside the rest of the scene.
- Map each physical device to its own pointer state (`device_guid` → colour).
- Fall back to the default Godot mouse when the native backend is unavailable.

This is a good reference if you want to build a local-multiplayer sandbox or any
interaction where each player controls their own cursor.



