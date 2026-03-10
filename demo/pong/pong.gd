extends Node2D

@onready var paddle_left = $PaddleLeft
@onready var paddle_right = $PaddleRight
@onready var label_left = $ScoreLeft
@onready var label_right = $ScoreRight
@onready var ball = $Ball

var player_left_id: int = -1
var player_right_id: int = -1
var score_left := 0
var score_right := 0

@onready var _multi_mouse = $MultiMouse
var _multi_enabled := false

func _ready() -> void:
	if not Engine.has_singleton("MultiMouseServer"):
		label_left.add_theme_font_size_override("font_size", 24)
		label_left.text = "Missing native library."
		label_right.add_theme_font_size_override("font_size", 24)
		label_right.text = "Build + copy the GDExtension."
		return
		
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
	_setup_multi_mouse()
	update_score_display()

func _setup_multi_mouse() -> void:
	if not Engine.has_singleton("MultiMouseServer"):
		return
	if _multi_mouse == null:
		return
	if _multi_mouse.motion.is_connected(_on_mouse_motion) == false:
		_multi_mouse.motion.connect(_on_mouse_motion)
	if _multi_mouse.button.is_connected(_on_mouse_button) == false:
		_multi_mouse.button.connect(_on_mouse_button)
	if _multi_mouse.has_method("attach_to_window"):
		_multi_mouse.attach_to_window(0)
	if _multi_mouse.has_method("enable"):
		_multi_mouse.enable()
	_multi_enabled = true

func _disable_multi_mouse() -> void:
	if _multi_mouse:
		if _multi_mouse.motion.is_connected(_on_mouse_motion):
			_multi_mouse.motion.disconnect(_on_mouse_motion)
		if _multi_mouse.button.is_connected(_on_mouse_button):
			_multi_mouse.button.disconnect(_on_mouse_button)
		if _multi_mouse.has_method("disable"):
			_multi_mouse.disable()
	_multi_enabled = false

func _process(_delta: float) -> void:
	if ball.position.x < 0:
		score_right += 1
		reset_game_round()
	elif ball.position.x > get_viewport_rect().size.x:
		score_left += 1
		reset_game_round()
	if Input.is_action_just_pressed("ui_close_dialog"):
		get_tree().quit()

func _exit_tree() -> void:
	_disable_multi_mouse();
	
func update_score_display() -> void:
	if player_left_id == -1:
		label_left.text = "L-Click to join"
	else:
		label_left.text = str(score_left)
	if player_right_id == -1:
		label_right.text = "R-Click to join"
	else:
		label_right.text = str(score_right)

func reset_game_round() -> void:
	update_score_display()
	ball.position = get_viewport_rect().size / 2
	if ball.has_method("reset_ball"):
		ball.reset_ball()

func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	if event.device == player_left_id:
		paddle_left.position.y += event.relative.y
	if event.device == player_right_id:
		paddle_right.position.y += event.relative.y

	var h = get_viewport_rect().size.y
	paddle_left.position.y = clamp(paddle_left.position.y, 0, h)
	paddle_right.position.y = clamp(paddle_right.position.y, 0, h)

func _on_mouse_button(event: InputEventMouseButton) -> void:
	if not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_LEFT:
		if player_left_id == -1:
			player_left_id = event.device
			print("Mouse", event.device, "claimed LEFT paddle")
			update_score_display()
			if player_right_id > -1:
				reset_game_round()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if player_right_id == -1:
			player_right_id = event.device
			print("Mouse", event.device, "claimed RIGHT paddle")
			update_score_display()
			if player_left_id > -1:
				reset_game_round()
