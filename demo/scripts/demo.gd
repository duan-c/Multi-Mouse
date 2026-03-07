extends Node2D

func _ready() -> void:
    if Engine.has_singleton("MultiMouseServer"):
        var devices := Engine.get_singleton("MultiMouseServer").get_connected_devices()
        print("Multi-Mouse demo ready. Devices:", devices)
    else:
        push_warning("MultiMouseServer singleton is missing; build the extension and enable the plugin.")
