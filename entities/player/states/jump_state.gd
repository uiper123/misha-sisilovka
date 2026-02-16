extends PlayerState

const JUMP_VELOCITY: float = 4.5
const AIR_SPEED: float = 3.0
const SPRINT_AIR_SPEED: float = 6.0 # Match sprint speed or slightly less
const GRAVITY: float = 9.8

var is_winding_up: bool = false

func enter() -> void:
	# Determine if we are sprinting
	var is_sprinting = false
	if is_multiplayer_authority():
		is_sprinting = Input.is_action_pressed("sprint")
	else:
		# Puppet logic: Check horizontal velocity
		var h_vel = Vector3(player.velocity.x, 0, player.velocity.z).length()
		is_sprinting = h_vel > 4.5 # Threshold slightly below sprint speed
		
	is_winding_up = false
	
	if player.animation_player:
		if is_sprinting:
			player.animation_player.play("UnarmedJumpRunning", 0.1)
			if is_multiplayer_authority():
				player.velocity.y = JUMP_VELOCITY
		else:
			is_winding_up = true
			player.animation_player.play("JoyfulJump", 0.1)
			# Add delay for normal jump
			await get_tree().create_timer(0.2).timeout
			# Check if player is still valid and in Jump state
			if not is_instance_valid(player) or player.state_machine.current_state != self:
				return
			
			is_winding_up = false
			if is_multiplayer_authority():
				player.velocity.y = JUMP_VELOCITY
	else:
		if is_multiplayer_authority():
			player.velocity.y = JUMP_VELOCITY

func physics_update(delta: float) -> void:
	if is_winding_up:
		# Don't fall, just wait
		# Stop movement or allow slight movement? Let's stop to be safe or keep momentum
		player.velocity.x = move_toward(player.velocity.x, 0, 0.5)
		player.velocity.z = move_toward(player.velocity.z, 0, 0.5)
		player.move_and_slide()
		return

	player.velocity.y -= GRAVITY * delta

	if player.velocity.y < 0:
		transitioned.emit(self, "fall")
		return

	# Allow air control
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction: Vector3 = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var current_speed = AIR_SPEED
	if Input.is_action_pressed("sprint"):
		current_speed = SPRINT_AIR_SPEED
	
	if direction:
		# Use current horizontal velocity magnitude to preserve momentum if it's higher
		# Or just allow acceleration to sprint speed
		player.velocity.x = move_toward(player.velocity.x, direction.x * current_speed, 0.5)
		player.velocity.z = move_toward(player.velocity.z, direction.z * current_speed, 0.5)

	player.move_and_slide()

	if player.is_on_floor():
		if input_dir:
			transitioned.emit(self, "walk")
		else:
			transitioned.emit(self, "idle")
