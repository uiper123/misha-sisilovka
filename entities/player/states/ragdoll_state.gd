extends PlayerState
class_name RagdollState

@export var impulse_strength: float = 10.0

func enter() -> void:
	if not player.skeleton:
		push_warning("RagdollState: No skeleton found!")
		return

	print("Entering Ragdoll State")
	
	var has_physical_bones = false
	for child in player.skeleton.get_children():
		if child is PhysicalBone3D:
			has_physical_bones = true
			break
	
	if has_physical_bones:
		# Disable CharacterBody3D collision so bones take over
		player.collision_layer = 0
		player.collision_mask = 0
		player.skeleton.physical_bones_start_simulation()
	else:
		print("No PhysicalBones found! Using fallback animation.")
	
	# Fallback visual (always play to ensure they look dead even if sim fails or is subtle)
	# Only if no physical bones, or as an initial impulse?
	# Actually, if we use physical bones, we shouldn't tween the model rotation, the bones will handle it.
	# But user said "nothing happens".
	
	if not has_physical_bones:
		var tween = create_tween()
		tween.tween_property(player.model, "rotation_degrees:x", -90.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(player.model, "position:y", 0.2, 0.5)
	
	# Disable processing on player (State Machine handles logic)
	# We should NOT disable player.physics_process if the state machine relies on it?
	# Actually, PlayerController._physics_process handles movement.
	# Ragdoll means NO movement control.
	
	# Instead of disabling player completely (which might stop RPCs or other logic),
	# let's just ensure we don't process inputs in PlayerController.
	# The PlayerController._perform_death already disables input.
	
	# But let's be safe.
	player.velocity = Vector3.ZERO

func exit() -> void:
	# Re-enable collision
	player.collision_layer = 1
	player.collision_mask = 1
	
	if player.skeleton:
		player.skeleton.physical_bones_stop_simulation()
	
	# Reset model transform
	player.model.rotation_degrees.x = 0
	player.model.position.y = 0
	
	player.set_physics_process(true)
	player.set_process_input(true)
	player.set_process(true)
