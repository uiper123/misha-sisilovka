extends PlayerState

var _has_started_wakeup: bool = false
var _target_anim_name: String = "StandingUp"

func enter() -> void:
	print("WakeUpState: Entered")
	_has_started_wakeup = false
	
	# Ensure game is not paused
	if get_tree().paused:
		get_tree().paused = false
		
	if player.animation_player:
		# Force reset
		player.animation_player.active = true
		player.animation_player.speed_scale = 1.0
		
		if not player.animation_player.has_animation(_target_anim_name):
			push_error("WakeUpState: Animation 'StandingUp' not found! Falling back to timer.")
			await get_tree().create_timer(2.0).timeout
			transitioned.emit(self, "idle")
			return

		# If already on floor, start immediately
		if player.is_on_floor():
			call_deferred("_start_animation", _target_anim_name)
		else:
			print("WakeUpState: Player in air, waiting for landing...")
			# Play fall loop while waiting? Or just pose
			if player.animation_player.has_animation("Fall"):
				player.animation_player.play("Fall")

func _start_animation(anim_name: String) -> void:
	if _has_started_wakeup:
		return
		
	_has_started_wakeup = true
	
	if not player.animation_player:
		return
		
	# Connect signal first
	if not player.animation_player.animation_finished.is_connected(_on_animation_finished):
		player.animation_player.animation_finished.connect(_on_animation_finished)
	
	print("WakeUpState: Starting ", anim_name)
	player.animation_player.play(anim_name)
	player.animation_player.speed_scale = 1.0
	
	# Safety timer
	var anim = player.animation_player.get_animation(anim_name)
	if anim:
		anim.loop_mode = Animation.LOOP_NONE
		await get_tree().create_timer(anim.length + 0.5).timeout
	else:
		await get_tree().create_timer(2.0).timeout
		
	if player.state_machine.current_state == self:
		print("WakeUpState: Safety timer triggered")
		transitioned.emit(self, "idle")

func exit() -> void:
	print("WakeUpState: Exiting")
	if player.animation_player:
		if player.animation_player.animation_finished.is_connected(_on_animation_finished):
			player.animation_player.animation_finished.disconnect(_on_animation_finished)

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == _target_anim_name:
		print("WakeUpState: Animation finished")
		transitioned.emit(self, "idle")

func physics_update(delta: float) -> void:
	# Apply gravity so player falls to ground if spawned in air
	if not player.is_on_floor():
		player.velocity.y -= 9.8 * delta
		player.move_and_slide()
	elif not _has_started_wakeup:
		# Landed! Start animation
		print("WakeUpState: Landed on floor!")
		call_deferred("_start_animation", _target_anim_name)
		
	# No movement input handling here, effectively disabling controls
