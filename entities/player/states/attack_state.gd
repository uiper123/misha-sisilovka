extends PlayerState

var attack_anims: Array[String] = ["Punching", "HookPunch", "StandingMeleeAttackDownward(1)"]
var current_attack_index: int = 0
var hit_targets: Array[Node] = []

func enter() -> void:
	hit_targets.clear()
	print("Entering Attack State")
	
	if player.animation_player:
		# Pick random or sequential attack
		var anim = attack_anims.pick_random()
		player.animation_player.play(anim, 0.1)
		# Don't loop attacks
		player.animation_player.get_animation(anim).loop_mode = Animation.LOOP_NONE
		
		# Connect to finished signal to exit state
		if not player.animation_player.animation_finished.is_connected(_on_animation_finished):
			player.animation_player.animation_finished.connect(_on_animation_finished)
	
	# Enable hitbox after a short delay to match animation?
	# For simplicity, enable immediately but check over time
	if player.attack_shapecast:
		player.attack_shapecast.enabled = true
		player.attack_shapecast.force_shapecast_update()

func exit() -> void:
	if player.animation_player and player.animation_player.animation_finished.is_connected(_on_animation_finished):
		player.animation_player.animation_finished.disconnect(_on_animation_finished)
	
	if player.attack_shapecast:
		player.attack_shapecast.enabled = false
	
	hit_targets.clear()

func _on_animation_finished(anim_name: String) -> void:
	transitioned.emit(self, "idle")

func physics_update(delta: float) -> void:
	# Stop movement during attack
	player.velocity.x = move_toward(player.velocity.x, 0, 1.0)
	player.velocity.z = move_toward(player.velocity.z, 0, 1.0)
	player.move_and_slide()
	
	# Check for hits
	if player.attack_shapecast and player.attack_shapecast.is_colliding():
		for i in range(player.attack_shapecast.get_collision_count()):
			var collider = player.attack_shapecast.get_collider(i)
			if collider and collider != player.hitbox_component and not collider in hit_targets:
				# Check if it's a HitboxComponent
				if collider is HitboxComponent:
					print("Hit something! ", collider.name)
					hit_targets.append(collider)
					collider.damage(10.0) # Base damage
					
					# Spawn hit effect? (Future task)
				elif collider.has_method("damage"): # Support other damageable objects
					hit_targets.append(collider)
					collider.damage(10.0)

