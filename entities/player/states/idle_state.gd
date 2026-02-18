extends PlayerState

const GRAVITY: float = 9.8

func enter() -> void:
	if player.animation_player:
		player.animation_player.play("StandingW_BriefcaseIdle", 0.2)

func physics_update(delta: float) -> void:
	# Noclip mode - transition to walk for flight handling
	if player.collision_mask == 0 and player.is_multiplayer_authority():
		var has_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward") != Vector2.ZERO
		var has_vertical = Input.is_action_pressed("jump") or Input.is_action_pressed("crouch")
		if has_input or has_vertical:
			transitioned.emit(self, "walk")
			return
	
	if not player.is_on_floor() and player.collision_mask != 0:
		player.velocity.y -= GRAVITY * delta
		if player.velocity.y < 0:
			transitioned.emit(self, "fall")
			return

	# Only authority processes input
	if player.is_multiplayer_authority():
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
