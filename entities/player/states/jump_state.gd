extends PlayerState

const JUMP_VELOCITY: float = 4.5
const AIR_SPEED: float = 3.0
const GRAVITY: float = 9.8

func enter() -> void:
	# Example: player.animation_player.play("jump")
	player.velocity.y = JUMP_VELOCITY

func physics_update(delta: float) -> void:
	player.velocity.y -= GRAVITY * delta

	# Allow air control
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction: Vector3 = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		player.velocity.x = move_toward(player.velocity.x, direction.x * AIR_SPEED, 0.5)
		player.velocity.z = move_toward(player.velocity.z, direction.z * AIR_SPEED, 0.5)

	player.move_and_slide()

	if player.is_on_floor():
		if input_dir:
			transitioned.emit(self, "walk")
		else:
			transitioned.emit(self, "idle")
