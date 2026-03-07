extends Node2D

const GRID_COLS := 10
const GRID_ROWS := 8
const GRID_SPACING := 36.0
const POINT_MASS := 1.0
const SPRING_STIFFNESS := 18.0
const SHEAR_STIFFNESS := 10.0
const SPRING_DAMPING := 0.95
const GRAVITY := Vector2.ZERO #Vector2(0, 350)
const POINTER_RADIUS := 110.0
const POINTER_STRENGTH := 2200.0
const POINTER_DAMPING := 0.25
const EDGE_RESTORING_FORCE := 2.0

var _points: Array[SlimePoint] = []
var _connections: Array = []
var _shear_connections: Array = []
var _rest_positions: PackedVector2Array

class PointerState:
	var position := Vector2.ZERO
	var target := Vector2.ZERO
	var velocity := Vector2.ZERO
	var pressed := false

var _pointers: Array[PointerState] = []

class SlimePoint:
	var position: Vector2
	var velocity: Vector2 = Vector2.ZERO
	var force: Vector2 = Vector2.ZERO
	var mass: float = 1.0
	var anchor: Vector2
	var anchor_strength: float = 0.0

func _ready() -> void:
	_build_grid()
	_ensure_default_pointer()
	set_physics_process(true)

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
			# pin the top row lightly so the blob doesn't drift away
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

func _ensure_default_pointer() -> void:
	if _pointers.is_empty():
		_pointers.append(PointerState.new())

func _primary_pointer() -> PointerState:
	if _pointers.is_empty():
		_ensure_default_pointer()
	return _pointers[0]

func _update_pointer_target() -> void:
	var viewport := get_viewport()
	if viewport:
		var local_mouse := viewport.get_mouse_position()
		_primary_pointer().target = _screen_to_sim(local_mouse)

func _physics_process(delta: float) -> void:
	_update_pointer_target()
	_apply_forces()
	_apply_connections(delta)
	_apply_pointer(delta)
	_integrate(delta)
	queue_redraw()

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

func _apply_pointer(delta: float) -> void:
	for pointer in _pointers:
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

	for pointer in _pointers:
		var pointer_screen := pointer.position + offset
		var pointer_color := Color(1, 0.8, 0.2) if pointer.pressed else Color(0.4, 0.8, 1.0)
		var pointer_color_with_alpha := pointer_color
		pointer_color_with_alpha.a = 0.1
		draw_circle(pointer_screen, 12, pointer_color)
		draw_circle(pointer_screen, POINTER_RADIUS, pointer_color_with_alpha)
