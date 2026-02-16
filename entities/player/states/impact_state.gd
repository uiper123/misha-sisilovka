extends PlayerState

func enter() -> void:
	# Drop any held item
	if player.has_node("InteractionController"):
		player.get_node("InteractionController").drop_item()
		
	if player.animation_player:
		player.animation_player.play("SweepFall", 0.1) # Fast blend
		player.animation_player.speed_scale = 1.0

func physics_update(delta: float) -> void:
	# Apply gravity and friction
	if not player.is_on_floor():
		player.velocity.y -= 9.8 * delta
	
	player.velocity.x = move_toward(player.velocity.x, 0, 5.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, 0, 5.0 * delta)
	
	player.move_and_slide()
	
	# Check if animation finished
	if player.animation_player and not player.animation_player.is_playing():
		transitioned.emit(self, "idle")

func exit() -> void:
	pass
