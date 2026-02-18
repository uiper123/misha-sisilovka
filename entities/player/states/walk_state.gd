extends PlayerState

const WALK_SPEED: float = 3.5
const SPRINT_SPEED: float = 6.5
const NOCLIP_SPEED: float = 15.0
const GRAVITY: float = 9.8
const ACCELERATION: float = 8.0
const DECELERATION: float = 12.0

func enter() -> void:
	if player.animation_player:
		player.animation_player.play("Walking", 0.2)

func physics_update(delta: float) -> void:
	# Noclip mode - free flight
	if player.collision_mask == 0:
		_handle_noclip(delta)
		return
	
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta
		if player.velocity.y < 0:
			transitioned.emit(self, "fall")
			return

	# Only authority processes input and movement
	if not player.is_multiplayer_authority():
		# Puppets just apply physics
		player.move_and_slide()
		return

	# State Transitions
	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		transitioned.emit(self, "jump")
		return
	
	# Check sprint state once for all checks
	var is_sprinting = Input.is_action_pressed("sprint")
	var horizontal_speed = Vector3(player.velocity.x, 0, player.velocity.z).length()
	
	# Slide: если бежим на спринте и нажали присед
	# Temporarily disabled slide as per user request
	if Input.is_action_just_pressed("crouch") and is_sprinting and horizontal_speed > 3.5:
		# Подкат только если бежим достаточно быстро
		# print("Transitioning to Slide! Speed: ", horizontal_speed)
		# transitioned.emit(self, "slide")
		# return
		pass
	elif Input.is_action_just_pressed("crouch"):
		# Обычное приседание
		transitioned.emit(self, "crouch")
		return
	
	if Input.is_action_just_pressed("attack"):
		transitioned.emit(self, "attack")
		return

	# Movement - use sprint state determined above
	var base_speed = SPRINT_SPEED if is_sprinting else WALK_SPEED
	var current_speed = base_speed * player.speed_multiplier
	
	# Animation
	if player.animation_player:
		if is_sprinting:
			if player.animation_player.current_animation != "UnarmedRunForward":
				player.animation_player.play("UnarmedRunForward", 0.3)
				player.animation_player.speed_scale = 1.0 # Normal speed for run
		else:
			if player.animation_player.current_animation != "StrutWalking":
				player.animation_player.play("StrutWalking", 0.3)
				# Slow down walk animation slightly to match slower movement
				player.animation_player.speed_scale = 0.9 

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	if input_dir != Vector2.ZERO:
		# Rotate Player to face camera direction
		var cam_rot = player.camera_pivot.global_rotation.y
		var target_angle = input_dir.angle() * -1 + cam_rot - PI/2
		
		# Smooth rotation
		var current_rot = player.global_rotation.y
		player.global_rotation.y = lerp_angle(current_rot, target_angle, 10.0 * delta)
		
		var direction = Vector3.FORWARD.rotated(Vector3.UP, player.global_rotation.y)
		
		# Sharp Turn Detection
		if is_sprinting and player.velocity.length() > SPRINT_SPEED * 0.8:
			var current_dir = player.velocity.normalized()
			# Ignore Y for direction check
			current_dir.y = 0
			current_dir = current_dir.normalized()
			
			var new_dir = direction
			new_dir.y = 0
			new_dir = new_dir.normalized()
			
			var dot = current_dir.dot(new_dir)
			# If dot is < 0, angle is > 90 degrees (sharp turn)
			if dot < 0.0:
				transitioned.emit(self, "stumble")
				return
		
		player.velocity.x = move_toward(player.velocity.x, direction.x * current_speed, ACCELERATION * delta)
		player.velocity.z = move_toward(player.velocity.z, direction.z * current_speed, ACCELERATION * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, DECELERATION * delta)
		player.velocity.z = move_toward(player.velocity.z, 0, DECELERATION * delta)
		
		# Only transition to idle if stopped
		if player.velocity.length_squared() < 0.1:
			transitioned.emit(self, "idle")

	# High Speed Slope/Loss of Control Detection
	# Check if velocity is significantly higher than normal sprint speed (e.g., from gravity on slopes)
	# But allow falling (not on floor)
	if player.is_on_floor() and player.velocity.length() > SPRINT_SPEED * 1.5:
		transitioned.emit(self, "stumble")
		return

	# Store velocity before move to detect impact speed correctly
	var velocity_before_move = player.velocity
	player.move_and_slide()
	
	# Check for wall impact while sprinting
	# Must have sufficient speed to trigger impact (avoid triggering when just pressing sprint against wall)
	# Use velocity_before_move because move_and_slide() zeroes velocity on impact
	if is_sprinting and velocity_before_move.length() > SPRINT_SPEED * 0.5 and player.get_slide_collision_count() > 0:
		for i in range(player.get_slide_collision_count()):
			var collision = player.get_slide_collision(i)
			var normal = collision.get_normal()
			
			# Check if it's a wall (vertical surface)
			if abs(normal.y) < 0.5:
				# Check if we hit it head-on (dot product < -0.5)
				var forward = -player.global_transform.basis.z
				if forward.dot(normal) < -0.5:
					transitioned.emit(self, "impact")
					return

## Noclip flight mode
func _handle_noclip(delta: float) -> void:
	if not player.is_multiplayer_authority():
		return
	
	var fly_speed = NOCLIP_SPEED * player.speed_multiplier
	if Input.is_action_pressed("sprint"):
		fly_speed *= 2.0
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var vertical = 0.0
	
	if Input.is_action_pressed("jump"):
		vertical = 1.0
	if Input.is_action_pressed("crouch"):
		vertical = -1.0
	
	# Get camera direction for movement
	var cam_basis = player.camera_pivot.global_transform.basis
	var forward = -cam_basis.z
	var right = cam_basis.x
	
	var direction = Vector3.ZERO
	direction += forward * -input_dir.y  # Forward/back
	direction += right * input_dir.x     # Left/right
	direction.y += vertical              # Up/down
	
	if direction.length() > 0:
		direction = direction.normalized()
		player.velocity = direction * fly_speed
	else:
		player.velocity = player.velocity.lerp(Vector3.ZERO, delta * 10.0)
	
	player.global_position += player.velocity * delta
