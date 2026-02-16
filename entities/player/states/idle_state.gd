extends PlayerState

const GRAVITY: float = 9.8

func enter() -> void:
	# Example: player.animation_player.play("idle")
	pass

func physics_update(_delta: float) -> void:
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * _delta
		player.move_and_slide()
		return

	# Transitions
	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		transitioned.emit(self, "jump")
		return
	if Input.is_action_pressed("crouch"):
		transitioned.emit(self, "crouch")
		return
	if Input.get_vector("move_left", "move_right", "move_forward", "move_backward"):
		transitioned.emit(self, "walk")
		return
	
	# Reset velocity X/Z to 0 to stop sliding
	player.velocity.x = move_toward(player.velocity.x, 0, 0.5)
	player.velocity.z = move_toward(player.velocity.z, 0, 0.5)
	player.move_and_slide()
