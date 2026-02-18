extends PlayerState

const SLIDE_SPEED: float = 6.0  # Reduced speed to prevent crazy sliding
const SLIDE_DECELERATION: float = 6.0 # Reduced deceleration to slide longer but slower
const MIN_SLIDE_SPEED: float = 1.0
const GRAVITY: float = 9.8
const USE_ROOT_MOTION: bool = false  # Disabled root motion for reliability

var slide_direction: Vector3 = Vector3.ZERO
var current_slide_speed: float = SLIDE_SPEED
var previous_root_position: Vector3 = Vector3.ZERO
var hips_bone_id: int = -1
var initial_hips_pos: Vector3 = Vector3.ZERO
var has_moved_model: bool = false

func enter() -> void:
	if not player:
		return
		
	if player.animation_player:
		player.animation_player.play("RunningSlide", 0.1)
		# Сохраняем начальную позицию root для root motion
		if USE_ROOT_MOTION and player.model:
			previous_root_position = player.model.position
			
	# Find Hips bone for centering
	if player.skeleton:
		hips_bone_id = player.skeleton.find_bone("Hips")
		if hips_bone_id == -1:
			hips_bone_id = player.skeleton.find_bone("Pelvis")
		if hips_bone_id == -1:
			hips_bone_id = player.skeleton.find_bone("Root")
			
	if hips_bone_id != -1:
		initial_hips_pos = player.skeleton.get_bone_pose(hips_bone_id).origin
		has_moved_model = true # We will move it
	
	# Запоминаем направление движения в момент начала подката
	if player.velocity.length() > 0.1:
		slide_direction = Vector3(player.velocity.x, 0, player.velocity.z).normalized()
	else:
		# Если нет скорости, используем направление взгляда модели (Model) или игрока
		# Важно: если игрок крутил камерой, но не двигался, rotation.y мог не обновиться.
		# Лучше брать transform.basis.z (куда смотрит нода CharacterBody3D)
		
		# Обычно CharacterBody3D вращается только при движении.
		# Если мы стоим и смотрим камерой, то тело может смотреть в другую сторону.
		# Но для подката мы хотим катиться ТУДА, КУДА СМОТРИТ МОДЕЛЬ.
		
		var forward = -player.model.global_transform.basis.z
		slide_direction = Vector3(forward.x, 0, forward.z).normalized()
	
	# Fix: Ensure slide direction is aligned with current input if moving
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input_dir != Vector2.ZERO:
		var cam_rot = player.camera_pivot.global_rotation.y
		var target_angle = input_dir.angle() * -1 + cam_rot - PI/2
		var direction = Vector3.FORWARD.rotated(Vector3.UP, target_angle)
		slide_direction = direction.normalized()
	
	# Начинаем с текущей скорости или минимальной скорости подката
	# Clamp max speed to avoid crazy launch
	var horizontal_speed = Vector3(player.velocity.x, 0, player.velocity.z).length()
	current_slide_speed = clamp(horizontal_speed, SLIDE_SPEED, SLIDE_SPEED * 1.5)
	
	print("Slide started! Direction: ", slide_direction, " Speed: ", current_slide_speed)

func exit() -> void:
	# Reset model position
	if player.model and has_moved_model:
		player.model.position = Vector3.ZERO
		has_moved_model = false

func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta
		# Если оторвались от земли, переходим в падение
		if player.velocity.y < -1.0:
			transitioned.emit(self, "fall")
			return
	
	# Only authority processes input and movement
	if not player.is_multiplayer_authority():
		# Puppets just apply physics
		player.move_and_slide()
		return
	
	# Применяем root motion из анимации (если включено)
	if USE_ROOT_MOTION and player.model and player.animation_player:
		# Извлекаем движение root из анимации
		var current_root_pos = player.model.position
		var root_delta = current_root_pos - previous_root_position
		previous_root_position = current_root_pos
		
		# Преобразуем root motion в глобальное пространство
		var global_delta = player.global_transform.basis * root_delta
		global_delta.y = 0  # Игнорируем вертикальное движение
		
		# Применяем к скорости
		player.velocity.x = global_delta.x / delta
		player.velocity.z = global_delta.z / delta
		
		# Обновляем текущую скорость для проверок
		current_slide_speed = Vector3(player.velocity.x, 0, player.velocity.z).length()
		
		# Сбрасываем позицию модели, чтобы она не смещалась
		player.model.position = Vector3.ZERO
		previous_root_position = Vector3.ZERO
	else:
		# Manual movement + Hips Centering Logic
		# This solves the issue where animation moves mesh away from body, causing snap-back.
		
		# 1. Apply manual slide speed (Base movement)
		current_slide_speed = move_toward(current_slide_speed, 0, SLIDE_DECELERATION * delta)
		player.velocity.x = slide_direction.x * current_slide_speed
		player.velocity.z = slide_direction.z * current_slide_speed
		
		# 2. Extract Animation Root Motion (Hips offset)
		if hips_bone_id != -1 and player.skeleton:
			var current_hips_pos = player.skeleton.get_bone_pose(hips_bone_id).origin
			
			# Calculate how far hips moved from initial (in Skeleton local space)
			# We assume Skeleton is Z-forward? Or Y-up? Mixamo is usually Y-up.
			# We care about X and Z displacement.
			
			# NOTE: get_bone_pose returns pose relative to parent.
			# If Hips is root, it is relative to Skeleton.
			# If Animation moves Hips forward, Z (or -Z) changes.
			
			# We want to keep Visual Hips Centered on Body.
			# So we must shift Model by -(CurrentHips - InitialHips).
			# This keeps the mesh "in place" visually.
			# AND we add that offset to Body Velocity to actually move the player physically.
			
			var hips_diff = current_hips_pos - initial_hips_pos
			# Flatten Y (height)
			# Hips forward is usually +Z or -Z depending on rig.
			# But we calculate difference in PARENT space (Skeleton space).
			
			# If Animation moves forward in Z, hips_diff.z will be non-zero.
			
			var offset_local = Vector3(hips_diff.x, 0, hips_diff.z)
			
			if offset_local.length() > 0.001:
				# Convert local offset to global direction
				# Model rotation must be applied
				# Use global_transform.basis (without scale)
				var global_offset = player.model.global_transform.basis * offset_local
				
				# Add to velocity?
				# Wait, if we add to velocity, we move the CharacterBody3D.
				# If we slide backwards, it means global_offset is pointing backwards.
				
				# If animation moves hips forward (local +Z), global_offset pushes forward.
				# If player slides backwards, maybe the animation is playing backwards? Or bones are flipped?
				# Or maybe hips_diff calculation is inverted.
				
				# Let's verify: hips_diff = current - initial.
				# If hips move forward (0,0,1), diff is (0,0,1).
				# global_offset pushes (0,0,1) rotated by model.
				# Player moves forward. Correct.
				
				# BUT, if we move CharacterBody3D forward, the model moves forward too (attached).
				# The animation ALSO moves hips forward relative to model.
				# So hips move forward TWICE (once by body, once by anim).
				# That's why we need to shift Model BACKWARDS.
				
				# player.model.position = -offset_local
				# This cancels the visual movement of hips.
				
				# The issue "sliding backwards" might be because slide_direction calculation was wrong (fixed above).
				# Or maybe this root motion logic is fighting the manual slide velocity.
				
				# Let's trust manual slide velocity for MAIN movement direction.
				# And use root motion ONLY to align visual mesh.
				# We should NOT add global_offset to velocity if we already have manual velocity.
				# Adding both might be double dipping or conflicting.
				
				# Let's try: ONLY manual velocity for movement.
				# And use offset_local ONLY for visual correction.
				
				# player.velocity += global_offset / delta  <-- REMOVE THIS
				
				# Shift Model BACK to keep hips in place
				player.model.position = -offset_local
				
				# But wait, if we don't add to velocity, the body moves at constant speed,
				# while animation might accelerate/decelerate.
				# If we want PURE manual slide, we should ignore root motion for velocity.
				# AND we must ensure the model doesn't drift away.
				# Shifting model back (-offset_local) keeps hips at (0,0,0) relative to previous frame?
				# No, relative to Initial Pose.
				
				# So:
				# 1. Body moves by slide_speed (Manual).
				# 2. Animation plays, moving hips forward.
				# 3. We shift Model back so hips stay at body center.
				# Result: Hips stay at body center, Body moves smoothly.
				# This is perfect for "In-Place" animation simulation.
				
				pass
		
	player.move_and_slide()
	
	# Проверяем условия выхода из подката
	if current_slide_speed < MIN_SLIDE_SPEED:
		# Замедлились слишком сильно - переходим в присед или idle
		if Input.is_action_pressed("crouch"):
			transitioned.emit(self, "crouch")
		else:
			transitioned.emit(self, "idle")
		return
	
	# Если отпустили присед и достаточно быстро двигаемся, переходим в бег
	if not Input.is_action_pressed("crouch") and current_slide_speed > 3.0:
		transitioned.emit(self, "walk")
		return
