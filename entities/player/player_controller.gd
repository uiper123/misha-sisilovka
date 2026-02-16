extends CharacterBody3D

@onready var animation_player: AnimationPlayer = $Model/AnimationPlayer
@onready var state_machine: StateMachine = $StateMachine
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var radial_menu: Control = %RadialMenu
@onready var dance_state: Node = $StateMachine/Dance
@onready var interaction_controller: Node3D = $InteractionController

@onready var model: Node3D = $Model
@onready var skeleton: Skeleton3D = $Model/Scene/Armature/Skeleton3D

@export var mouse_sensitivity: float = 0.005
@export_group("Zoom")
@export var zoom_min: float = 2.0
@export var zoom_max: float = 10.0
@export var zoom_speed: float = 0.5
@export var zoom_smoothness: float = 10.0

@export_group("Upper Body")
## How much the spine tilts based on camera pitch (0 = none, 1 = full)
@export var spine_pitch_influence: float = 0.4
## Maximum spine tilt angle in degrees
@export var spine_pitch_max: float = 35.0

@export_group("Stats")
@export var base_speed: float = 5.0
var speed_multiplier: float = 1.0

var target_zoom: float = 3.0
var _cam_yaw: float = 0.0
var _cam_pitch: float = 0.0

# Spine bone index (cached)
var _spine2_bone_idx: int = -1
var _spine2_rest: Transform3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	target_zoom = spring_arm.spring_length
	
	# Detach camera from player rotation
	camera_pivot.set_as_top_level(true)
	
	# Exclude player from SpringArm collision
	spring_arm.add_excluded_object(self.get_rid())
	
	# Initialize rotation
	_cam_yaw = camera_pivot.rotation.y
	_cam_pitch = camera_pivot.rotation.x
	
	radial_menu.animation_selected.connect(_on_dance_selected)
	
	if interaction_controller:
		interaction_controller.item_picked_up.connect(_on_item_picked_up)
		interaction_controller.item_dropped.connect(_on_item_dropped)
	
	# Cache spine bone index
	if skeleton:
		_spine2_bone_idx = skeleton.find_bone("Spine2")
		if _spine2_bone_idx >= 0:
			_spine2_rest = skeleton.get_bone_rest(_spine2_bone_idx)

func _on_item_picked_up(item: PickableItem) -> void:
	if item.weight > 0:
		var weight_factor = clamp(item.weight / 20.0, 0.0, 0.8)
		speed_multiplier = 1.0 - weight_factor
		print("Player: Speed reduced to ", speed_multiplier * 100, "% due to weight: ", item.weight, "kg")
	else:
		speed_multiplier = 1.0

func _on_item_dropped(_item: PickableItem) -> void:
	speed_multiplier = 1.0
	print("Player: Speed restored")

func _physics_process(delta: float) -> void:
	camera_pivot.global_position = global_position + Vector3(0, 1.2, 0)
	
	_align_model_with_floor(delta)
	_update_spine_pitch(delta)

func _align_model_with_floor(delta: float) -> void:
	if not model:
		return
		
	var target_normal = Vector3.UP
	if is_on_floor():
		target_normal = get_floor_normal()
	
	var max_tilt = deg_to_rad(30.0)
	var angle_to_up = target_normal.angle_to(Vector3.UP)
	
	if angle_to_up > max_tilt:
		var axis = Vector3.UP.cross(target_normal).normalized()
		target_normal = Vector3.UP.rotated(axis, max_tilt)

	var current_transform = model.global_transform
	var desired_up = target_normal
	
	var current_up = current_transform.basis.y
	var next_up = current_up.lerp(desired_up, delta * 5.0).normalized()
	
	var axis = current_up.cross(next_up)
	if axis.length_squared() < 0.0001:
		return
		
	axis = axis.normalized()
	var angle = current_up.angle_to(next_up)
	
	model.global_rotate(axis, angle)

## Tilt the upper body (Spine2 bone) based on camera pitch
func _update_spine_pitch(_delta: float) -> void:
	if not skeleton or _spine2_bone_idx < 0:
		return
	
	# Only tilt during these states — skip Dance, Attack, WakeUp, Jump, Fall
	var allowed_states = ["Idle", "Walk", "Crouch"]
	var current_state_name = ""
	if state_machine and state_machine.current_state:
		current_state_name = state_machine.current_state.name
	
	if current_state_name not in allowed_states:
		# Reset override when not in allowed state
		skeleton.set_bone_global_pose_override(_spine2_bone_idx, Transform3D.IDENTITY, 0.0, true)
		return
	
	# Camera pitch: negative = looking down, positive = looking up
	var target_pitch = _cam_pitch * spine_pitch_influence
	target_pitch = clamp(target_pitch, deg_to_rad(-spine_pitch_max), deg_to_rad(spine_pitch_max))
	
	# Apply as global pose override (doesn't accumulate, blends with animation)
	var pitch_quat = Quaternion(Vector3.RIGHT, -target_pitch)
	var current_global_pose = skeleton.get_bone_global_pose(_spine2_bone_idx)
	var modified_pose = Transform3D(Basis(pitch_quat) * current_global_pose.basis, current_global_pose.origin)
	
	skeleton.set_bone_global_pose_override(_spine2_bone_idx, modified_pose, 0.5, true)

func _on_dance_selected(anim_name: String) -> void:
	if not is_on_floor():
		return
		
	state_machine.on_child_transition(state_machine.current_state, "dance")
	dance_state.play_dance(anim_name)

func _process(delta: float) -> void:
	spring_arm.spring_length = lerp(spring_arm.spring_length, target_zoom, delta * zoom_smoothness)

func _unhandled_input(event: InputEvent) -> void:
	# Special handling for WakeUp state: only allow camera rotation
	if state_machine.current_state.name == "WakeUp":
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_handle_camera_rotation(event)
		return

	if event.is_action_pressed("open_radial_menu"):
		if is_on_floor():
			radial_menu.open_menu()
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_handle_camera_rotation(event)
		
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				target_zoom = clamp(target_zoom - zoom_speed, zoom_min, zoom_max)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				target_zoom = clamp(target_zoom + zoom_speed, zoom_min, zoom_max)

func _handle_camera_rotation(event: InputEventMouseMotion) -> void:
	_cam_yaw -= event.relative.x * mouse_sensitivity
	_cam_pitch -= event.relative.y * mouse_sensitivity
	_cam_pitch = clamp(_cam_pitch, deg_to_rad(-90), deg_to_rad(30))
	
	camera_pivot.rotation.y = _cam_yaw
	camera_pivot.rotation.x = _cam_pitch
	camera_pivot.rotation.z = 0


# This script handles Inputs that are global to the character (like camera look),
# while movement logic is in the State Machine.
