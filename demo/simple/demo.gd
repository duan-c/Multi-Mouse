extends Node2D

@onready var label := Label.new()

var _multi_mouse: Node = null
var _multi_enabled := false

func _ready() -> void:
	add_child(label)
	label.text = "Waiting for multi-mouse events..."
	label.position = get_viewport_rect().size * 0.4

	if not Engine.has_singleton("MultiMouseServer"):
		label.text = "Missing native library. Build + copy the GDExtension."
		return

	Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	_setup_multi_mouse("MultiMouse")
	
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_close_dialog"):
		get_tree().quit()

func _exit_tree() -> void:
	_disable_multi_mouse();

func _setup_multi_mouse(path: NodePath = "/root/MultiMouse") -> void:
	# Default path is for autoload
	if not Engine.has_singleton("MultiMouseServer"):
		return
	_multi_mouse = get_node_or_null(path)
	
	if _multi_mouse == null:
		return
	if _multi_mouse.motion.is_connected(_on_motion) == false:
		_multi_mouse.motion.connect(_on_motion)
	if _multi_mouse.button.is_connected(_on_button) == false:
		_multi_mouse.button.connect(_on_button)
	if _multi_mouse.device_disconnected.is_connected(_on_device_connected) == false:
		_multi_mouse.device_disconnected.connect(_on_device_disconnected)
	if _multi_mouse.has_method("attach_to_window"):
		_multi_mouse.attach_to_window(0)
	if _multi_mouse.has_method("enable"):
		_multi_mouse.enable()
	_multi_enabled = true

func _disable_multi_mouse() -> void:
	if _multi_mouse:
		if _multi_mouse.motion.is_connected(_on_motion):
			_multi_mouse.motion.disconnect(_on_motion)
		if _multi_mouse.button.is_connected(_on_button):
			_multi_mouse.button.disconnect(_on_button)
		if _multi_mouse.device_disconnected.is_connected(_on_device_connected):
			_multi_mouse.device_disconnected.disconnect(_on_device_disconnected)
		if _multi_mouse.has_method("disable"):
			_multi_mouse.disable()
	_multi_mouse = null
	_multi_enabled = false

func _on_motion(event: InputEventMouseMotion) -> void:
	label.text = "Motion from %s: rel=%s" % [event.device, event.relative]

func _on_button(event: InputEventMouseButton) -> void:
	label.text = "Button %s from %s (pressed=%s)" % [event.button_index, event.device, event.pressed]

func _on_device_connected(device_id: int, info: Dictionary) -> void:
	print("Device connected", device_id, info)

func _on_device_disconnected(device_id: int) -> void:
	print("Device disconnected", device_id)
