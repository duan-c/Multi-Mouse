extends Node
class_name MultiMouse

signal device_connected(device_id: int, info: Dictionary)
signal device_disconnected(device_id: int)
signal motion(event: InputEventMultiMouseMotion)
signal button(event: InputEventMultiMouseButton)

var _server: Object

func _ready() -> void:
    set_process(true)
    if Engine.has_singleton("MultiMouseServer"):
        _server = Engine.get_singleton("MultiMouseServer")
        _bind_server_callbacks()
        _emit_existing_devices()
    else:
        push_warning("MultiMouseServer native singleton is not available. Build the GDExtension for your platform.")

func _bind_server_callbacks() -> void:
    if not _server:
        return
    _server.device_connected.connect(_on_device_connected)
    _server.device_disconnected.connect(_on_device_disconnected)
    _server.motion.connect(_on_motion)
    _server.button.connect(_on_button)

func _emit_existing_devices() -> void:
    if _server and _server.has_method("get_connected_devices"):
        for dev in _server.get_connected_devices():
            device_connected.emit(int(dev["device_id"]), dev)

func _process(_delta: float) -> void:
    request_poll()

func request_poll() -> void:
    if _server and _server.has_method("poll"):
        _server.poll()

func get_devices() -> Array:
    if _server and _server.has_method("get_connected_devices"):
        return _server.get_connected_devices()
    return []

func _on_device_connected(device_id: int, info: Dictionary) -> void:
    device_connected.emit(device_id, info)

func _on_device_disconnected(device_id: int) -> void:
    device_disconnected.emit(device_id)

func _on_motion(event: InputEventMultiMouseMotion) -> void:
    motion.emit(event)

func _on_button(event: InputEventMultiMouseButton) -> void:
    button.emit(event)
