# Simple Multi-Mouse Demo

Minimal scene that shows how to wire the `MultiMouse` node and inspect raw
motion/button events from every connected mouse. Helpful for sanity checks on
new platforms or when embedding the add-on into another game.

## Files

- `demo.tscn` – root `Node2D` with a `MultiMouse` child and onscreen label.
- `demo.gd` – connects the signals and prints the last event.

## Behaviour

- When the native DLL/SO is present the label displays the last motion or button
  event in the form `Motion from <device>: rel=(x, y)`.
- Devices are identified by their Godot `event.device` index plus the GUID
  mirrored in the metadata.
- Press **ESC** to exit.

## Wiring pattern

```gdscript
func _ready():
    Input.mouse_mode = Input.MOUSE_MODE_CONFINED
    _setup_multi_mouse("MultiMouse")

func _setup_multi_mouse(path: NodePath) -> void:
    _multi_mouse = get_node_or_null(path)
    if _multi_mouse:
        _multi_mouse.motion.connect(_on_motion)
        _multi_mouse.button.connect(_on_button)
        _multi_mouse.attach_to_window(0)
        _multi_mouse.enable()
```

The demo expects a `MultiMouse` node named `"MultiMouse"` as a direct child of
the root (see the provided `demo.tscn`). Feel free to copy the script into your
own scene as a starting point.
