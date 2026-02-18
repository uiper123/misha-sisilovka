extends PlayerState
class_name RagdollState

@export var impulse_strength: float = 10.0
@export var respawn_delay: float = 3.0

var ragdoll_start_position: Vector3 = Vector3.ZERO
var has_physical_bones_active: bool = false
var _respawn_timer: float = 0.0
var _is_dead: bool = false

func enter() -> void:
	if not player.skeleton:
		push_warning("RagdollState: No skeleton found!")
		return

	print("Entering Ragdoll State")
	_respawn_timer = 0.0
	_is_dead = true
	
	# Сохраняем начальную позицию
	ragdoll_start_position = player.global_position
	
	var has_physical_bones = false
	for child in player.skeleton.get_children():
		if child is PhysicalBone3D:
			has_physical_bones = true
			break
	
	has_physical_bones_active = has_physical_bones
	
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

func physics_update(delta: float) -> void:
	# Only authority handles respawn timer
	if not player.is_multiplayer_authority():
		return
	
	if _is_dead:
		_respawn_timer += delta
		if _respawn_timer >= respawn_delay:
			_is_dead = false
			player._respawn()
func exit() -> void:
	_is_dead = false
	_respawn_timer = 0.0

	# Если использовали physical bones, находим финальную позицию
	if has_physical_bones_active and player.skeleton:
		# Находим среднюю позицию physical bones
		var bone_positions: Array[Vector3] = []
		for child in player.skeleton.get_children():
			if child is PhysicalBone3D:
				bone_positions.append(child.global_position)
		
		if bone_positions.size() > 0:
			# Вычисляем центр массы
			var center = Vector3.ZERO
			for pos in bone_positions:
				center += pos
			center /= bone_positions.size()
			
			# Перемещаем персонажа на финальную позицию
			player.global_position = Vector3(center.x, player.global_position.y, center.z)
	
	# Re-enable collision
	player.collision_layer = 1
	player.collision_mask = 1
	
	if player.skeleton:
		player.skeleton.physical_bones_stop_simulation()
		# Reset all bones to rest pose
		for i in range(player.skeleton.get_bone_count()):
			player.skeleton.set_bone_pose_position(i, Vector3.ZERO)
			player.skeleton.set_bone_pose_rotation(i, Quaternion.IDENTITY)
			player.skeleton.set_bone_pose_scale(i, Vector3.ONE)
			player.skeleton.set_bone_global_pose_override(i, Transform3D.IDENTITY, 0.0, false)
		player.skeleton.reset_bone_poses()
	
	# Reset ALL transforms completely
	player.rotation = Vector3.ZERO
	
	# Restore model's initial transform (it's rotated 180° by default)
	if player._model_initial_transform:
		player.model.transform = player._model_initial_transform
	else:
		player.model.rotation = Vector3.ZERO
		player.model.position = Vector3.ZERO
	
	player.set_physics_process(true)
	player.set_process_input(true)
	player.set_process(true)
