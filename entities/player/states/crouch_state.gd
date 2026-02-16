extends PlayerState

const CROUCH_SPEED: float = 2.0
const GRAVITY: float = 9.8

# Assuming standard height is 2.0, crouch is 1.0
const NORMAL_HEIGHT: float = 2.0
const CROUCH_HEIGHT: float = 1.0

var collision_shape: CollisionShape3D
var original_mesh_scale: Vector3

func enter() -> void:
	# Example: player.animation_player.play("crouch")
	
	# Shrink collider
	if player.has_node("CollisionShape3D"):
		collision_shape = player.get_node("CollisionShape3D")
		if collision_shape.shape is CapsuleShape3D:
			collision_shape.shape.height = CROUCH_HEIGHT
			collision_shape.position.y = CROUCH_HEIGHT / 2.0 # Adjust pivot if needed

	# Visual feedback (if using simple mesh)
	if player.has_node("MeshInstance3D"):
		var mesh = player.get_node("MeshInstance3D")
		original_mesh_scale = mesh.scale
		mesh.scale.y = 0.5
		mesh.position.y = CROUCH_HEIGHT / 2.0

func exit() -> void:
	# Restore collider
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		collision_shape.shape.height = NORMAL_HEIGHT
		collision_shape.position.y = 0.0 # Reset pivot

	# Restore visual
	if player.has_node("MeshInstance3D"):
		var mesh = player.get_node("MeshInstance3D")
		mesh.scale = original_mesh_scale
		mesh.position.y = 0.0

func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta

	if not Input.is_action_pressed("crouch"):
		# Check if can uncrouch (raycast check would be better here)
		transitioned.emit(self, "idle")
		return

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction: Vector3 = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		player.velocity.x = direction.x * CROUCH_SPEED
		player.velocity.z = direction.z * CROUCH_SPEED
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, CROUCH_SPEED)
		player.velocity.z = move_toward(player.velocity.z, 0, CROUCH_SPEED)
	
	player.move_and_slide()
