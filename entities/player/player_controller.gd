extends CharacterBody3D

@onready var animation_player: AnimationPlayer = $Model/AnimationPlayer
@onready var state_machine: StateMachine = $StateMachine
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var radial_menu: Control = %RadialMenu
@onready var dance_state: Node = $StateMachine/Dance

@onready var model: Node3D = $Model

@export var mouse_sensitivity: float = 0.005
@export_group("Zoom")
@export var zoom_min: float = 1.0
@export var zoom_max: float = 10.0
@export var zoom_speed: float = 0.5
@export var zoom_smoothness: float = 10.0

var target_zoom: float = 3.0
var _cam_yaw: float = 0.0
var _cam_pitch: float = 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	target_zoom = spring_arm.spring_length
	
	# Detach camera from player rotation
	camera_pivot.set_as_top_level(true)
	
	# Initialize rotation
	_cam_yaw = camera_pivot.rotation.y
	_cam_pitch = camera_pivot.rotation.x
	
	radial_menu.animation_selected.connect(_on_dance_selected)

	# Force initial animation
	if animation_player:
		animation_player.play("StandingW_BriefcaseIdle")

func _physics_process(delta: float) -> void:
	# Update camera position to follow player (with offset)
	# Original offset was (0, 1.5, 0) relative to player
	camera_pivot.global_position = global_position + Vector3(0, 1.5, 0)
	
	_align_model_with_floor(delta)

func _align_model_with_floor(delta: float) -> void:
	if not model:
		return
		
	var target_normal = Vector3.UP
	if is_on_floor():
		target_normal = get_floor_normal()
	
	# Clamp the tilt angle (max 30 degrees)
	# This prevents extreme leaning on steep slopes
	var max_tilt = deg_to_rad(30.0)
	var angle_to_up = target_normal.angle_to(Vector3.UP)
	
	if angle_to_up > max_tilt:
		var axis = Vector3.UP.cross(target_normal).normalized()
		target_normal = Vector3.UP.rotated(axis, max_tilt)

	# We want the model's Y axis to align with target_normal
	# But we want to preserve the model's forward direction (relative to character rotation)
	
	var current_transform = model.global_transform
	var desired_up = target_normal
	
	# Interpolate Up vector (Slower speed for smoother movement)
	var current_up = current_transform.basis.y
	var next_up = current_up.lerp(desired_up, delta * 5.0).normalized()
	
	# Calculate the new basis
	# Simple quaternion rotation from current up to next up
	var axis = current_up.cross(next_up)
	if axis.length_squared() < 0.0001:
		return
		
	axis = axis.normalized()
	var angle = current_up.angle_to(next_up)
	
	model.global_rotate(axis, angle) 

func _on_dance_selected(anim_name: String) -> void:
	# Only allow dancing if on floor
	if not is_on_floor():
		return
		
	# Transition to Dance State
	state_machine.on_child_transition(state_machine.current_state, "dance")
	dance_state.play_dance(anim_name)

func _process(delta: float) -> void:
	spring_arm.spring_length = lerp(spring_arm.spring_length, target_zoom, delta * zoom_smoothness)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_radial_menu"):
		# Only open menu if on floor
		if is_on_floor():
			radial_menu.open_menu()
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_cam_yaw -= event.relative.x * mouse_sensitivity
		_cam_pitch -= event.relative.y * mouse_sensitivity
		_cam_pitch = clamp(_cam_pitch, deg_to_rad(-90), deg_to_rad(30))
		
		camera_pivot.rotation.y = _cam_yaw
		camera_pivot.rotation.x = _cam_pitch
		camera_pivot.rotation.z = 0 # Force no roll

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


# This script handles Inputs that are global to the character (like camera look),
# while movement logic is in the State Machine.
