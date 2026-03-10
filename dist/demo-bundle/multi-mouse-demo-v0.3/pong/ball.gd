extends CharacterBody2D

var SPEED = 400.0
var speed = 0.0
var direction = Vector2.ZERO

func _ready():
	# Start by moving toward one of the players
	direction.x = [1, -1].pick_random()
	direction.y = [0.5, -0.5].pick_random()
	direction = direction.normalized()
	
	
func start():
	reset_ball()
	
	
func _physics_process(delta):
	# move_and_collide returns info if we hit something
	var collision = move_and_collide(direction * speed * delta)
	
	if collision:
		# 'bounce' the direction vector based on the surface normal
		direction = direction.bounce(collision.get_normal())
		# Optional: Increase speed slightly on each hit to make it harder
		speed += 10

	return
	
	# Check for out of bounds (Scoring)
	var screen_width = get_viewport_rect().size.x
	if position.x < 0:
		print("Right Player Scores!")
		reset_ball()
	elif position.x > screen_width:
		print("Left Player Scores!")
		reset_ball()

func reset_ball():
	position = get_viewport_rect().size / 2
	speed = SPEED
	direction.x *= -1 # Send it toward the player who just lost
