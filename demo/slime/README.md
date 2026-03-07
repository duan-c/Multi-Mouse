# Slime Demo

This folder contains a prototype Godot 4 scene for the multi-pointer slime toy.

## Files

- `slime_demo.tscn` – loads the script and draws/updates the blob.
- `slime_demo.gd` – procedural mass-spring net with pointer interaction.

## How it works

- Creates a 10×8 grid of points ("particles") spaced 36 px apart.
- Connects horizontal/vertical neighbors with strong springs and diagonals with softer shear springs.
- Applies gravity, light anchor force on the top row (so the blob doesn't float away), and damping.
- A virtual pointer body follows the mouse; while the left button is held, any particles within a 90 px radius receive a push force toward the pointer.
- Drawing happens in `_draw` – lines for springs, circles for particles, translucent halo for the pointer.

## Trying it out

1. Open `demo/project.godot` in Godot 4.2+.
2. Add `res://slime` as a folder in the FileSystem dock (scan scripts).
3. Run `res://slime/slime_demo.tscn`.
4. Drag the mouse while holding the left button to tug and stretch the blob.

## Multi-Mouse integration

Right now the pointer uses normal Godot mouse events. Once the native extension is loaded you can:

```gdscript
var manager = get_node("/root/MultiMouse")
manager.motion.connect(_on_multi_motion)
manager.button.connect(_on_multi_button)
```

and duplicate the `_pointer_pos/_pointer_down` state per device GUID so up to two physical mice poke the slime simultaneously. The rest of the simulation stays unchanged.
