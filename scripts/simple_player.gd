extends CharacterBody2D

@export var SPEED = 1000.0

const auto_move = true

func _physics_process(_delta):
	if auto_move:
		velocity.x = SPEED
	else:
		var direction = Input.get_axis("ui_left", "ui_right")
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
