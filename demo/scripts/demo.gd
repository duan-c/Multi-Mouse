extends Node2D

@onready var label := Label.new()

func _ready() -> void:
    add_child(label)
    label.text = "Waiting for multi-mouse events..."

    if not Engine.has_singleton("MultiMouseServer"):
        label.text = "Missing native library. Build + copy the GDExtension."
        return

    var manager := get_node_or_null("/root/MultiMouse")
    if manager == null:
        label.text = "Enable the Multi-Mouse plugin (autoload missing)."
        return

    manager.motion.connect(_on_motion)
    manager.button.connect(_on_button)
    manager.device_connected.connect(_on_device_connected)
    manager.device_disconnected.connect(_on_device_disconnected)
    label.text = "Devices: %s" % [manager.get_devices()]
	
	MultiMouse.attach_to_window(0)#hack for now
	MultiMouse.enable()
	
func _exit_tree() -> void:	
	MultiMouse.disable()
	
func _on_motion(event: InputEventMouseMotion) -> void:
    label.text = "Motion from %s: rel=%s" % [event.device, event.relative]

func _on_button(event: InputEventMouseButton) -> void:
    label.text = "Button %s from %s (pressed=%s)" % [event.button_index, event.device, event.pressed]

func _on_device_connected(device_id: int, info: Dictionary) -> void:
    print("Device connected", device_id, info)

func _on_device_disconnected(device_id: int) -> void:
    print("Device disconnected", device_id)
