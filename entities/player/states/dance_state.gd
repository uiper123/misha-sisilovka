extends PlayerState

var current_animation: String = ""

func enter() -> void:
	if current_animation != "":
		# Assuming AnimationPlayer is available on player.model.animation_player or similar
		var anim_player = player.get_node("Model/AnimationPlayer")
		if anim_player:
			anim_player.play(current_animation)
			# Loop dance animations usually
			anim_player.get_animation(current_animation).loop_mode = Animation.LOOP_LINEAR

const GRAVITY: float = 9.8

func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta
		player.move_and_slide() # Allow falling
		# If falling too fast or long, maybe transition to fall?
		# For now, just gravity
	
	# Exit dance if moving or jumping
	if Input.get_vector("move_left", "move_right", "move_forward", "move_backward") != Vector2.ZERO:
		transitioned.emit(self, "walk")
	elif Input.is_action_just_pressed("jump"):
		transitioned.emit(self, "jump")
	elif Input.is_action_just_pressed("crouch"):
		transitioned.emit(self, "crouch")

func play_dance(anim_name: String) -> void:
	current_animation = anim_name
	enter() # Re-enter to play new animation if already in state
