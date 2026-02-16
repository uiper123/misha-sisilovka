extends PlayerState

const AIR_SPEED: float = 3.0
const GRAVITY: float = 9.8

func enter() -> void:
	if player.animation_player:
		player.animation_player.play("JumpingDown", 0.2)

func physics_update(delta: float) -> void:
	player.velocity.y -= GRAVITY * delta

	# Allow air control
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	if input_dir != Vector2.ZERO:
		# Air movement relative to camera
		var cam_rot = player.camera_pivot.global_rotation.y
		var target_angle = input_dir.angle() * -1 + cam_rot - PI/2
		var direction = Vector3.FORWARD.rotated(Vector3.UP, target_angle)
		
		player.velocity.x = move_toward(player.velocity.x, direction.x * AIR_SPEED, 0.5)
		player.velocity.z = move_toward(player.velocity.z, direction.z * AIR_SPEED, 0.5)
		
		# Optional: Rotate character in air?
		# var current_rot = player.global_rotation.y
		# player.global_rotation.y = lerp_angle(current_rot, target_angle, 5.0 * delta)

	player.move_and_slide()

	if player.is_on_floor():
		if input_dir != Vector2.ZERO:
			transitioned.emit(self, "walk")
		else:
			transitioned.emit(self, "idle")
