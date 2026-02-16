extends PlayerState

const GRAVITY: float = 9.8

func enter() -> void:
	if player.animation_player:
		player.animation_player.play("StandingW_BriefcaseIdle", 0.2)

func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta
		if player.velocity.y < 0:
			transitioned.emit(self, "fall")
			return

	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		transitioned.emit(self, "jump")
		return
	if Input.is_action_pressed("crouch"):
		transitioned.emit(self, "crouch")
		return
	if Input.is_action_just_pressed("attack"):
		transitioned.emit(self, "attack")
		return
	if Input.get_vector("move_left", "move_right", "move_forward", "move_backward"):
		transitioned.emit(self, "walk")
		return
	
	# Reset velocity X/Z to 0 to stop sliding
	player.velocity.x = move_toward(player.velocity.x, 0, 0.5)
	player.velocity.z = move_toward(player.velocity.z, 0, 0.5)
	player.move_and_slide()
