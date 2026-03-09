extends Node2D

const GRID_COLS := 12
const GRID_ROWS := 12
const GRID_SPACING := 32.0 # was 36.0
const POINT_MASS := 1.0
const SPRING_STIFFNESS := 18.0
const SHEAR_STIFFNESS := 10.0
const SPRING_DAMPING := 0.95
const GRAVITY := Vector2.ZERO # was something, but we don't want it
const POINTER_RADIUS := 110.0
const POINTER_STRENGTH := 3300.0
const POINTER_MULTI_BUTTON_STRENGTH := 3.0
const POINTER_DAMPING := 0.25
const EDGE_RESTORING_FORCE := 0.0 # was 2.0 applied to top row but we don't want it
const DEFAULT_POINTER_ID := "default"

var _points: Array[SlimePoint] = []
var _connections: Array = []
var _shear_connections: Array = []
var _pointer_map: Dictionary = {}
var _device_pointer_keys: Dictionary[int, String] = {}
var _multi_mouse: Node = null
var _multi_enabled := false
var _mesh_enabled := false
var _mesh_instance: MeshInstance2D
var _mesh: ImmediateMesh
var _mesh_triangles: Array = []
@export var mesh_texture: Texture2D
var _show_nodes := true
var _show_connections := true

class SlimePoint:
	var position: Vector2
	var velocity: Vector2 = Vector2.ZERO
	var force: Vector2 = Vector2.ZERO
	var mass: float = 1.0
	var anchor: Vector2
	var anchor_strength: float = 0.0
	var uv: Vector2 = Vector2.ZERO

class PointerState:
	var position := Vector2.ZERO
	var target := Vector2.ZERO
	var velocity := Vector2.ZERO
	var pressed_left := false
	var pressed_right := false
	var color := Color(0.4, 0.8, 1.0)

func _ready() -> void:
	_build_radial_net()
	#_build_grid()
	
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
	
	_mesh_instance = MeshInstance2D.new()
	_mesh = ImmediateMesh.new()
	_mesh_instance.mesh = _mesh
	_mesh_instance.z_index = -1
	add_child(_mesh_instance)
	_update_mesh_origin()
	if mesh_texture:
		_mesh_instance.texture = mesh_texture
		_mesh_instance.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	
	_setup_multi_mouse("MultiMouse")
	if not _multi_enabled:
		_ensure_pointer(DEFAULT_POINTER_ID)
	set_physics_process(true)
	
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_close_dialog"):
		get_tree().quit()
	if Input.is_action_just_pressed("slime_circle"):
		_build_radial_net()
	if Input.is_action_just_pressed("slime_grid"):
		_build_grid()
	if Input.is_action_just_pressed("slime_show_nodes"):
		_show_nodes = not _show_nodes
	if Input.is_action_just_pressed("slime_show_connections"):
		_show_connections = not _show_connections

func _exit_tree() -> void:
	_disable_multi_mouse()

func _build_radial_net() -> void:
	_points.clear()
	_connections.clear()
	_shear_connections.clear()
	_mesh_triangles.clear()
	_mesh_enabled = true

	var origin := Vector2.ZERO
	var ring_count := 6
	var base_segments := 6

	var center := SlimePoint.new()
	center.position = origin
	center.anchor = origin
	center.mass = POINT_MASS
	center.anchor_strength = EDGE_RESTORING_FORCE
	center.uv = Vector2(0.5, 0.5)
	_points.append(center)

	var ring_start_index: Array[int] = [0]

	for r in range(1, ring_count + 1):
		ring_start_index.append(_points.size())
		var radius := r * GRID_SPACING
		var segments := base_segments * r
		for s in range(segments):
			var p := SlimePoint.new()
			var angle := (TAU / segments) * s
			var dir := Vector2(cos(angle), sin(angle))
			p.position = origin + dir * radius
			p.anchor = p.position
			p.mass = POINT_MASS
			p.uv = Vector2(dir.x * 0.5 + 0.5, dir.y * 0.5 + 0.5)
			_points.append(p)

	for r in range(ring_count + 1):
		var current_ring_start := ring_start_index[r]
		var current_ring_size := 1 if r == 0 else base_segments * r
		for s in range(current_ring_size):
			var i := current_ring_start + s
			if r > 0:
				var next_s := (s + 1) % current_ring_size
				_connections.append([i, current_ring_start + next_s, radius_dist(i, current_ring_start + next_s), SPRING_STIFFNESS])
			if r > 0 and r <= ring_count:
				var inner_ring_start := ring_start_index[r - 1]
				var inner_ring_size := max(1, base_segments * (r - 1))
				var inner_ratio := float(inner_ring_size) / current_ring_size
				var inner_idx := inner_ring_start + int(floor(s * inner_ratio) % inner_ring_size)
				_shear_connections.append([i, inner_idx, GRID_SPACING * 1.2, SHEAR_STIFFNESS])
				if r > 1:
					var inner_next := inner_ring_start + int((floor(s * inner_ratio) + 1) % inner_ring_size)
					_shear_connections.append([i, inner_next, GRID_SPACING * 1.2, SHEAR_STIFFNESS])

	for r in range(1, ring_count + 1):
		var ring_start := ring_start_index[r]
		var prev_ring_start := ring_start_index[r - 1]
		var ring_segments := base_segments * r
		var prev_segments := 1 if r - 1 == 0 else base_segments * (r - 1)
		for s in range(ring_segments):
			var curr_idx := ring_start + s
			var curr_next := ring_start + ((s + 1) % ring_segments)
			if r == 1:
				_mesh_triangles.append([prev_ring_start, curr_idx, curr_next])
			else:
				var ratio := float(prev_segments) / ring_segments
				var prev_pos := prev_ring_start + int(floor(s * ratio) % prev_segments)
				var prev_next := prev_ring_start + int(floor((s + 1) * ratio) % prev_segments)
				_mesh_triangles.append([curr_idx, curr_next, prev_pos])
				if prev_next != prev_pos:
					_mesh_triangles.append([curr_next, prev_next, prev_pos])
func _build_grid() -> void:
	_points.clear()
	_connections.clear()
	_shear_connections.clear()
	_mesh_triangles.clear()
	var origin := Vector2(-((GRID_COLS - 1) * GRID_SPACING) * 0.5, -((GRID_ROWS - 1) * GRID_SPACING) * 0.5)
	for y in range(GRID_ROWS):
		for x in range(GRID_COLS):
			var p := SlimePoint.new()
			var pos := origin + Vector2(x, y) * GRID_SPACING
			p.position = pos
			p.anchor = pos
			p.mass = POINT_MASS
			if y == 0:
				p.anchor_strength = EDGE_RESTORING_FORCE
			p.uv = Vector2(float(x) / (GRID_COLS - 1), float(y) / (GRID_ROWS - 1))
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

	_mesh_enabled = true
	_update_mesh()

func _setup_multi_mouse(path: NodePath = "/root/MultiMouse") -> void:
	# Default path is for autoload	
	if not Engine.has_singleton("MultiMouseServer"):
		return
	_multi_mouse = get_node_or_null(path)
	if _multi_mouse == null:
		return
	if _multi_mouse.motion.is_connected(_on_multi_motion) == false:
		_multi_mouse.motion.connect(_on_multi_motion)
	if _multi_mouse.button.is_connected(_on_multi_button) == false:
		_multi_mouse.button.connect(_on_multi_button)
	if _multi_mouse.device_disconnected.is_connected(_on_multi_device_disconnected) == false:
		_multi_mouse.device_disconnected.connect(_on_multi_device_disconnected)
	if _multi_mouse.has_method("attach_to_window"):
		_multi_mouse.attach_to_window(0)
	if _multi_mouse.has_method("enable"):
		_multi_mouse.enable()
	_multi_enabled = true

func _disable_multi_mouse() -> void:
	if _multi_mouse:
		if _multi_mouse.motion.is_connected(_on_multi_motion):
			_multi_mouse.motion.disconnect(_on_multi_motion)
		if _multi_mouse.button.is_connected(_on_multi_button):
			_multi_mouse.button.disconnect(_on_multi_button)
		if _multi_mouse.device_disconnected.is_connected(_on_multi_device_disconnected):
			_multi_mouse.device_disconnected.disconnect(_on_multi_device_disconnected)
		if _multi_mouse.has_method("disable"):
			_multi_mouse.disable()
	_multi_mouse = null
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
	_update_mesh()
	queue_redraw()

func _update_default_pointer_target() -> void:
	if _multi_enabled:
		return
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
		if not (pointer.pressed_left or pointer.pressed_right):
			continue
		for p: SlimePoint in _points:
			var offset := p.position - pointer.position
			var dist := offset.length()
			if dist < POINTER_RADIUS and dist > 0.001:
				var strength := pow(1.0 - dist / POINTER_RADIUS, 2)
				if pointer.pressed_left and pointer.pressed_right:
					strength = strength * POINTER_MULTI_BUTTON_STRENGTH
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
func _sim_to_screen(sim_pos: Vector2) -> Vector2:
	return sim_pos + get_viewport_rect().size * 0.5

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
	var hue := float(abs(hash(key)) % 8) / 8.0
	return Color.from_hsv(hue, 0.6, 0.9)

func _remove_pointer(key: Variant) -> void:
	if key == DEFAULT_POINTER_ID:
		return
	if _pointer_map.has(key):
		_pointer_map.erase(key)

func _input(event: InputEvent) -> void:
	if _multi_enabled:
		return
	var pointer := _primary_pointer()
	if event is InputEventMouseMotion:
		pointer.target = _screen_to_sim(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			pointer.pressed_left = event.pressed
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			pointer.pressed_right = event.pressed

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var offset := get_viewport_rect().size * 0.5
	if _show_connections:
		for conn in _connections:
			var a := _points[conn[0]].position + offset
			var b := _points[conn[1]].position + offset
			draw_line(a, b, Color(0.05, 0.05, 0.2), 4)
		for conn in _shear_connections:
			var a := _points[conn[0]].position + offset
			var b := _points[conn[1]].position + offset
			draw_line(a, b, Color(0.09, 0.09, 0.3), 2)
	if _show_nodes:
		for p in _points:
			draw_circle(p.position + offset, 6, Color(0.7, 0.7, 0.8))

	for pointer: PointerState in _pointer_states():
		var pointer_screen := pointer.position + offset
		var halo := pointer.color
		halo.a = 0.1
		draw_circle(pointer_screen, 12, pointer.color)
		draw_circle(pointer_screen, POINTER_RADIUS, halo)

func _confine_pointer_target(pointer: PointerState) -> void:
	var target = _sim_to_screen(pointer.target)
	var x = target.x;
	var y = target.y;
	if x < 0:
		x = 0
	if x >= get_viewport_rect().size.x:
		x = get_viewport_rect().size.x - 1
	if y < 0:
		y = 0
	if y >= get_viewport_rect().size.y:
		y = get_viewport_rect().size.y - 1
	pointer.target = _screen_to_sim(Vector2(x, y))

func _on_multi_motion(event: InputEventMouseMotion) -> void:
	var pointer := _ensure_pointer(_pointer_key_from_event(event))
	pointer.target += event.relative
	_confine_pointer_target(pointer)

func _on_multi_button(event: InputEventMouseButton) -> void:
	var pointer := _ensure_pointer(_pointer_key_from_event(event))
	if event.button_index == MOUSE_BUTTON_LEFT:
		pointer.pressed_left = event.pressed
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		pointer.pressed_right = event.pressed

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

func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		_update_mesh_origin()

func _update_mesh_origin() -> void:
	if _mesh_instance:
		_mesh_instance.position = get_viewport_rect().size * 0.5

func _update_mesh() -> void:
	if _mesh == null or _mesh_instance == null:
		return
	_mesh.clear_surfaces()
	if not _mesh_enabled:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	if _mesh_triangles.is_empty():
		for y in range(GRID_ROWS - 1):
			for x in range(GRID_COLS - 1):
				var idx00 := y * GRID_COLS + x
				var idx10 := y * GRID_COLS + (x + 1)
				var idx01 := (y + 1) * GRID_COLS + x
				var idx11 := (y + 1) * GRID_COLS + (x + 1)
				_mesh_triangles.append([idx00, idx10, idx11])
				_mesh_triangles.append([idx00, idx11, idx01])
	for tri in _mesh_triangles:
		_add_mesh_triangle(tri[0], tri[1], tri[2])
	_mesh.surface_end()

func _add_mesh_triangle(a: int, b: int, c: int) -> void:
	_add_mesh_vertex(a)
	_add_mesh_vertex(b)
	_add_mesh_vertex(c)

func _add_mesh_vertex(idx: int) -> void:
	if idx < 0 or idx >= _points.size():
		return
	var p: SlimePoint = _points[idx]
	var pos := Vector3(p.position.x, p.position.y, 0.0)
	_mesh.surface_set_normal(Vector3(0, 0, 1))
	_mesh.surface_set_color(Color(1, 1, 1, 1))
	_mesh.surface_set_uv(p.uv)
	_mesh.surface_add_vertex(pos)
