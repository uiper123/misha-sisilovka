extends PlayerState

const CROUCH_SPEED: float = 2.0
const GRAVITY: float = 9.8

# Assuming standard height is 2.0, crouch is 1.0
const NORMAL_HEIGHT: float = 2.0
const CROUCH_HEIGHT: float = 1.0

var collision_shape: CollisionShape3D
var original_mesh_scale: Vector3

func enter() -> void:
	# Shrink collider
	# player.collision_shape.shape.height = 1.0 # Logic handled elsewhere or keep simple
	if player.animation_player:
		player.animation_player.play("CrouchIdle(1)", 0.2)

func exit() -> void:
	# Restore collider
	pass

func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta

	# Only authority processes input and movement
	if not player.is_multiplayer_authority():
		# Puppets just apply physics
		player.move_and_slide()
		return

	if not Input.is_action_pressed("crouch"):
		transitioned.emit(self, "idle")
		return

	# Movement
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	if player.animation_player:
		if input_dir != Vector2.ZERO:
			if player.animation_player.current_animation != "CrouchWalkForward(1)":
				player.animation_player.play("CrouchWalkForward(1)", 0.2)
		else:
			if player.animation_player.current_animation != "CrouchIdle(1)":
				player.animation_player.play("CrouchIdle(1)", 0.2)
	
	if input_dir != Vector2.ZERO:
		# Rotate Player to face camera direction
		var cam_rot = player.camera_pivot.global_rotation.y
		var target_angle = input_dir.angle() * -1 + cam_rot - PI/2
		
		# Smooth rotation
		var current_rot = player.global_rotation.y
		player.global_rotation.y = lerp_angle(current_rot, target_angle, 10.0 * delta)
		
		var direction = Vector3.FORWARD.rotated(Vector3.UP, player.global_rotation.y)

		player.velocity.x = move_toward(player.velocity.x, direction.x * CROUCH_SPEED, 8.0 * delta)
		player.velocity.z = move_toward(player.velocity.z, direction.z * CROUCH_SPEED, 8.0 * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, CROUCH_SPEED)
		player.velocity.z = move_toward(player.velocity.z, 0, CROUCH_SPEED)
	
	player.move_and_slide()
