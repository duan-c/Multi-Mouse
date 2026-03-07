extends Node2D

const GRID_COLS := 10
const GRID_ROWS := 8
const GRID_SPACING := 36.0
const POINT_MASS := 1.0
const SPRING_STIFFNESS := 18.0
const SHEAR_STIFFNESS := 10.0
const SPRING_DAMPING := 0.95
const GRAVITY := Vector2.ZERO
const POINTER_RADIUS := 110.0
const POINTER_STRENGTH := 2200.0
const POINTER_DAMPING := 0.25
const EDGE_RESTORING_FORCE := 2.0
const DEFAULT_POINTER_ID := "default"

var _points: Array[SlimePoint] = []
var _connections: Array = []
var _shear_connections: Array = []
var _pointer_map: Dictionary = {}
var _device_pointer_keys: Dictionary = {}
var _multi_node: Node = null
var _multi_enabled := false

class SlimePoint:
	var position: Vector2
	var velocity: Vector2 = Vector2.ZERO
	var force: Vector2 = Vector2.ZERO
	var mass: float = 1.0
	var anchor: Vector2
	var anchor_strength: float = 0.0

class PointerState:
	var position := Vector2.ZERO
	var target := Vector2.ZERO
	var velocity := Vector2.ZERO
	var pressed := false
	var color := Color(0.4, 0.8, 1.0)

func _ready() -> void:
	_build_grid()
	_ensure_pointer(DEFAULT_POINTER_ID)
	_setup_multi_mouse()
	set_physics_process(true)

func _exit_tree() -> void:
	_disable_multi_mouse()

func _build_grid() -> void:
	_points.clear()
	_connections.clear()
	_shear_connections.clear()
	var origin := Vector2(-((GRID_COLS - 1) * GRID_SPACING) * 0.5, -40)
	for y in range(GRID_ROWS):
		for x in range(GRID_COLS):
			var p := SlimePoint.new()
			var pos := origin + Vector2(x, y) * GRID_SPACING
			p.position = pos
			p.anchor = pos
			p.mass = POINT_MASS
			if y == 0:
				p.anchor_strength = EDGE_RESTORING_FORCE
			_points.append(p)

	for y in range(GRID_ROWS):
		for x in range(GRID_COLS):
			var idx := y * GRID_COLS + x
			if x < GRID_COLS - 1:
				_connections.append([idx, idx + 1, GRID_SPACING, SPRING_STIFFNESS])
			if y < GRID_ROWS - 1:
				_connections.append([idx, idx + GRID_COLS, GRID_SPACING, SPRING_STIFFNESS])
			if x < GRID_COLS - 1 and y < GRID_ROWS - 1:
				_shear_connections.append([idx, idx + GRID_COLS + 1, GRID_SPACING * sqrt(2), SHEAR_STIFFNESS])
			if x > 0 and y < GRID_ROWS - 1:
				_shear_connections.append([idx, idx + GRID_COLS - 1, GRID_SPACING * sqrt(2), SHEAR_STIFFNESS])

func _setup_multi_mouse() -> void:
	if not Engine.has_singleton("MultiMouseServer"):
		return
	_multi_node = get_node_or_null("/root/MultiMouse")
	if _multi_node == null:
		return
	if _multi_node.motion.is_connected(_on_multi_motion) == false:
		_multi_node.motion.connect(_on_multi_motion)
	if _multi_node.button.is_connected(_on_multi_button) == false:
		_multi_node.button.connect(_on_multi_button)
	if _multi_node.device_disconnected.is_connected(_on_multi_device_disconnected) == false:
		_multi_node.device_disconnected.connect(_on_multi_device_disconnected)
	if _multi_node.has_method("attach_to_window"):
		_multi_node.attach_to_window(0)
	if _multi_node.has_method("enable"):
		_multi_node.enable()
	_multi_enabled = true

func _disable_multi_mouse() -> void:
	if _multi_node:
		if _multi_node.motion.is_connected(_on_multi_motion):
			_multi_node.motion.disconnect(_on_multi_motion)
		if _multi_node.button.is_connected(_on_multi_button):
			_multi_node.button.disconnect(_on_multi_button)
		if _multi_node.device_disconnected.is_connected(_on_multi_device_disconnected):
			_multi_node.device_disconnected.disconnect(_on_multi_device_disconnected)
		if _multi_node.has_method("disable"):
			_multi_node.disable()
	_multi_node = null
	_multi_enabled = false
	_device_pointer_keys.clear()
	_remove_non_default_pointers()

func _remove_non_default_pointers() -> void:
	for key in _pointer_map.keys():
		if key != DEFAULT_POINTER_ID:
			_pointer_map.erase(key)

func _physics_process(delta: float) -> void:
	_update_default_pointer_target()
	_apply_forces()
	_apply_connections(delta)
	_apply_pointer_forces(delta)
	_integrate(delta)
	queue_redraw()

func _update_default_pointer_target() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var pointer := _primary_pointer()
	pointer.target = _screen_to_sim(viewport.get_mouse_position())

func _apply_forces() -> void:
	for p: SlimePoint in _points:
		p.force = GRAVITY * p.mass
		if p.anchor_strength > 0.0:
			var offset := p.anchor - p.position
			p.force += offset * p.anchor_strength

func _apply_connections(_delta: float) -> void:
	for conn in _connections:
		_apply_spring(conn)
	for conn in _shear_connections:
		_apply_spring(conn)

func _apply_spring(conn: Array) -> void:
	var a: SlimePoint = _points[conn[0]]
	var b: SlimePoint = _points[conn[1]]
	var rest_len: float = conn[2]
	var stiffness: float = conn[3]
	var delta := b.position - a.position
	var dist := delta.length()
	if dist == 0.0:
		return
	var n := delta / dist
	var displacement := dist - rest_len
	var force := n * (displacement * stiffness)
	a.force += force
	b.force -= force

func _apply_pointer_forces(delta: float) -> void:
	for pointer: PointerState in _pointer_states():
		pointer.velocity = (pointer.velocity * (1.0 - POINTER_DAMPING)) + (pointer.target - pointer.position)
		pointer.position += pointer.velocity * delta * 8.0
		if not pointer.pressed:
			continue
		for p: SlimePoint in _points:
			var offset := p.position - pointer.position
			var dist := offset.length()
			if dist < POINTER_RADIUS and dist > 0.001:
				var strength := pow(1.0 - dist / POINTER_RADIUS, 2)
				var push := offset.normalized() * POINTER_STRENGTH * strength
				p.force += push

func _integrate(delta: float) -> void:
	for p: SlimePoint in _points:
		var accel := p.force / p.mass
		p.velocity += accel * delta
		p.velocity *= SPRING_DAMPING
		p.position += p.velocity * delta

func _screen_to_sim(screen_pos: Vector2) -> Vector2:
	return screen_pos - get_viewport_rect().size * 0.5

func _pointer_states() -> Array:
	return _pointer_map.values()

func _primary_pointer() -> PointerState:
	return _ensure_pointer(DEFAULT_POINTER_ID)

func _ensure_pointer(key: Variant) -> PointerState:
	if not _pointer_map.has(key):
		var state := PointerState.new()
		state.color = _color_for_pointer(key)
		_pointer_map[key] = state
	return _pointer_map[key]

func _color_for_pointer(key: Variant) -> Color:
	if key == DEFAULT_POINTER_ID:
		return Color(0.4, 0.8, 1.0)
	var hue := float(abs(hash(key)) % 360) / 360.0
	return Color.from_hsv(hue, 0.6, 0.9)

func _remove_pointer(key: Variant) -> void:
	if key == DEFAULT_POINTER_ID:
		return
	if _pointer_map.has(key):
		_pointer_map.erase(key)

func _input(event: InputEvent) -> void:
	var pointer := _primary_pointer()
	if event is InputEventMouseMotion:
		pointer.target = _screen_to_sim(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			pointer.pressed = event.pressed

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var offset := get_viewport_rect().size * 0.5
	for conn in _connections:
		var a := _points[conn[0]].position + offset
		var b := _points[conn[1]].position + offset
		draw_line(a, b, Color(0.05, 0.05, 0.2), 4)
	for conn in _shear_connections:
		var a := _points[conn[0]].position + offset
		var b := _points[conn[1]].position + offset
		draw_line(a, b, Color(0.09, 0.09, 0.3), 2)
	for p in _points:
		draw_circle(p.position + offset, 6, Color(0.7, 0.7, 0.8))

	for pointer: PointerState in _pointer_states():
		var pointer_screen := pointer.position + offset
		var halo := pointer.color
		halo.a = 0.1
		draw_circle(pointer_screen, 12, pointer.color)
		draw_circle(pointer_screen, POINTER_RADIUS, halo)

func _on_multi_motion(event: InputEventMouseMotion) -> void:
	var pointer := _ensure_pointer(_pointer_key_from_event(event))
	pointer.target += event.relative

func _on_multi_button(event: InputEventMouseButton) -> void:
	var pointer := _ensure_pointer(_pointer_key_from_event(event))
	if event.button_index == MOUSE_BUTTON_LEFT:
		pointer.pressed = event.pressed

func _on_multi_device_disconnected(device_id: int) -> void:
	if _device_pointer_keys.has(device_id):
		var key := _device_pointer_keys[device_id]
		_device_pointer_keys.erase(device_id)
		_remove_pointer(key)

func _pointer_key_from_event(event: InputEvent) -> String:
	var key := "device_%s" % event.device
	if event.has_meta("device_guid"):
		key = str(event.get_meta("device_guid"))
	_device_pointer_keys[event.device] = key
	return key
