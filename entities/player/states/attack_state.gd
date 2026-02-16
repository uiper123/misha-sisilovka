extends PlayerState

var attack_anims: Array[String] = ["Punching", "HookPunch", "StandingMeleeAttackDownward(1)"]
var current_attack_index: int = 0

func enter() -> void:
	if player.animation_player:
		# Pick random or sequential attack
		var anim = attack_anims.pick_random()
		player.animation_player.play(anim, 0.1)
		# Don't loop attacks
		player.animation_player.get_animation(anim).loop_mode = Animation.LOOP_NONE
		
		# Connect to finished signal to exit state
		if not player.animation_player.animation_finished.is_connected(_on_animation_finished):
			player.animation_player.animation_finished.connect(_on_animation_finished)

func exit() -> void:
	if player.animation_player and player.animation_player.animation_finished.is_connected(_on_animation_finished):
		player.animation_player.animation_finished.disconnect(_on_animation_finished)

func _on_animation_finished(anim_name: String) -> void:
	transitioned.emit(self, "idle")

func physics_update(delta: float) -> void:
	# Stop movement during attack? Or allow sliding?
	# Let's stop for now
	player.velocity.x = move_toward(player.velocity.x, 0, 1.0)
	player.velocity.z = move_toward(player.velocity.z, 0, 1.0)
	player.move_and_slide()
