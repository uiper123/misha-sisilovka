extends PlayerState

const USE_ROOT_MOTION: bool = true  # Использовать движение из анимации

var previous_root_position: Vector3 = Vector3.ZERO

func enter() -> void:
	if not player:
		return
		
	# Drop any held item
	if player.has_node("InteractionController"):
		player.get_node("InteractionController").drop_item()
		
	if player.animation_player:
		player.animation_player.play("HitToSideOfBody", 0.1)
		player.animation_player.speed_scale = 1.0
		# Сохраняем начальную позицию root для root motion
		if USE_ROOT_MOTION and player.model:
			previous_root_position = player.model.position

func physics_update(delta: float) -> void:
	# Apply gravity
	if not player.is_on_floor():
		player.velocity.y -= 9.8 * delta
	
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
		
		# Сбрасываем позицию модели, чтобы она не смещалась
		player.model.position = Vector3.ZERO
		previous_root_position = Vector3.ZERO
	else:
		# Стандартное движение без root motion
		# Retain some momentum but apply friction
		player.velocity.x = move_toward(player.velocity.x, 0, 2.0 * delta)
		player.velocity.z = move_toward(player.velocity.z, 0, 2.0 * delta)
	
	player.move_and_slide()
	
	# Check if animation finished
	if player.animation_player and not player.animation_player.is_playing():
		transitioned.emit(self, "idle")
