extends PlayerState

const WALK_SPEED: float = 5.0
const SPRINT_SPEED: float = 8.0
const GRAVITY: float = 9.8

func enter() -> void:
	if player.animation_player:
		player.animation_player.play("Walking", 0.2)

func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta
		if player.velocity.y < 0:
			transitioned.emit(self, "fall")
			return

	# State Transitions
	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		transitioned.emit(self, "jump")
		return
	if Input.is_action_pressed("crouch"):
		transitioned.emit(self, "crouch")
		return
	if Input.is_action_just_pressed("attack"):
		transitioned.emit(self, "attack")
		return

	# Movement
	var is_sprinting = Input.is_action_pressed("sprint")
	var current_speed = SPRINT_SPEED if is_sprinting else WALK_SPEED
	
	# Animation
	if player.animation_player:
		if is_sprinting:
			if player.animation_player.current_animation != "UnarmedRunForward":
				player.animation_player.play("UnarmedRunForward", 0.2)
		else:
			if player.animation_player.current_animation != "StrutWalking":
				player.animation_player.play("StrutWalking", 0.2)
	
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	if input_dir != Vector2.ZERO:
		# Rotate Player to face camera direction
		var cam_rot = player.camera_pivot.global_rotation.y
		var target_angle = input_dir.angle() * -1 + cam_rot - PI/2
		
		# Smooth rotation
		var current_rot = player.global_rotation.y
		player.global_rotation.y = lerp_angle(current_rot, target_angle, 10.0 * delta)
		
		var direction = Vector3.FORWARD.rotated(Vector3.UP, player.global_rotation.y)
		
		player.velocity.x = direction.x * current_speed
		player.velocity.z = direction.z * current_speed
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, current_speed)
		player.velocity.z = move_toward(player.velocity.z, 0, current_speed)
		transitioned.emit(self, "idle")

	player.move_and_slide()
