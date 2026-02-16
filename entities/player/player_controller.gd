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

var health_component: HealthComponent
var hitbox_component: HitboxComponent
var attack_shapecast: ShapeCast3D

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
var _last_position: Vector3 = Vector3.ZERO
var _smoothed_puppet_vel: Vector3 = Vector3.ZERO

func _enter_tree() -> void:
	# Ensure multiplayer authority is set before _ready
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	if interaction_controller:
		interaction_controller.item_picked_up.connect(_on_item_picked_up)
		interaction_controller.item_dropped.connect(_on_item_dropped)
	
	# Cache spine bone index
	if skeleton:
		_spine2_bone_idx = skeleton.find_bone("Spine2")
		if _spine2_bone_idx >= 0:
			_spine2_rest = skeleton.get_bone_rest(_spine2_bone_idx)
	
	# Initialize Health and Hitbox
	_setup_combat_components()
	
	# Multiplayer setup
	var synchronizer = $MultiplayerSynchronizer
	
	# If we are the host or single player, we are authority
	# If we are a client, the synchronizer will handle it
	
	# Disable camera and input for non-local players
	if not is_multiplayer_authority():
		$CameraPivot/SpringArm3D/Camera3D.current = false
		set_process_input(false)
		set_physics_process(true)
		set_process_unhandled_input(false)
		
		# Disable StateMachine logic for puppets to prevent input bleeding
		state_machine.set_process(false)
		state_machine.set_physics_process(false)
		state_machine.set_process_unhandled_input(false)
		return
	else:
		$CameraPivot/SpringArm3D/Camera3D.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		target_zoom = spring_arm.spring_length
		
		# Detach camera from player rotation
		camera_pivot.set_as_top_level(true)
		
		# Exclude player from SpringArm collision
		spring_arm.add_excluded_object(self.get_rid())
		
		# Initialize rotation
	_cam_yaw = camera_pivot.rotation.y
	_cam_pitch = camera_pivot.rotation.x
	
	_last_position = global_position

	# Setup Input for Attack if missing
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var ev = InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		InputMap.action_add_event("attack", ev)
	
	# Ensure AttackState exists
	if not state_machine.states.has("attack"):
		var attack_state = load("res://entities/player/states/attack_state.gd").new()
		attack_state.name = "Attack"
		attack_state.player = self
		state_machine.add_child(attack_state)
		state_machine.states["attack"] = attack_state
		attack_state.transitioned.connect(state_machine.on_child_transition)

	radial_menu.animation_selected.connect(_on_dance_selected)

func _setup_combat_components() -> void:
	# Add HealthComponent if missing
	if has_node("HealthComponent"):
		health_component = $HealthComponent
	else:
		health_component = HealthComponent.new()
		health_component.name = "HealthComponent"
		health_component.max_health = 100
		add_child(health_component)
	
	health_component.died.connect(_on_died)
	health_component.damage_taken.connect(_on_damaged)
	health_component.health_changed.connect(_on_health_changed)
	
	# Create Overhead HP
	if not has_node("OverheadHP"):
		var hp_node = load("res://ui/overhead_hp.gd").new()
		hp_node.name = "OverheadHP"
		add_child(hp_node)
		# Initialize
		hp_node.update_health(health_component.current_health, health_component.max_health)
	
	# Add Damage Overlay
	if is_multiplayer_authority():
		var overlay = load("res://ui/damage_overlay.tscn").instantiate()
		overlay.name = "DamageOverlay"
		add_child(overlay)

	# Add HitboxComponent if missing
	if has_node("HitboxComponent"):
		hitbox_component = $HitboxComponent
	else:
		hitbox_component = HitboxComponent.new()
		hitbox_component.name = "HitboxComponent"
		hitbox_component.health_component = health_component
		add_child(hitbox_component)
		
		# Create collision shape for hitbox (approximate body size)
		var shape = CollisionShape3D.new()
		var capsule = CapsuleShape3D.new()
		capsule.radius = 0.3
		capsule.height = 1.8
		shape.shape = capsule
		shape.position.y = 0.9 # Center of body
		hitbox_component.add_child(shape)
		
		# Set collision layer/mask for hitbox
		# Usually hitboxes are on a specific layer (e.g. 4) and hurtboxes check that layer
		# For simplicity, we put hitbox on layer 2 (which is typically WorldBody, but we can use it for hits too or separate)
		# Let's say Layer 4 is "Hitboxes"
		hitbox_component.collision_layer = 8 # Layer 4
		hitbox_component.collision_mask = 0
	
	# Create Attack ShapeCast
	attack_shapecast = ShapeCast3D.new()
	attack_shapecast.name = "AttackShapeCast"
	var attack_shape = SphereShape3D.new()
	attack_shape.radius = 0.8
	attack_shapecast.shape = attack_shape
	attack_shapecast.collision_mask = 8 # Only hit Layer 4 (Hitboxes)
	attack_shapecast.collide_with_areas = true
	attack_shapecast.collide_with_bodies = false
	attack_shapecast.max_results = 8
	attack_shapecast.enabled = false # Enable only during attack
	add_child(attack_shapecast)
	attack_shapecast.position = Vector3(0, 1.0, 0) # Center
	attack_shapecast.target_position = Vector3(0, 0, -1.5) # Reach forward

func _on_died() -> void:
	if is_multiplayer_authority():
		rpc("die_rpc")
		_perform_death()

func _on_damaged(amount: float, current_health: float) -> void:
	rpc("spawn_damage_text_rpc", amount)

@rpc("call_local", "reliable")
func spawn_damage_text_rpc(amount: float) -> void:
	# Spawn floating text
	var text = load("res://ui/floating_damage_text.gd").new()
	# Add to world to avoid moving with player
	get_parent().add_child(text)
	
	var offset = Vector3(randf_range(-0.5, 0.5), randf_range(0.0, 0.3), randf_range(-0.5, 0.5))
	text.global_position = global_position + Vector3(0, 1.8, 0) + offset
	text.set_amount(amount)

func _on_health_changed(current: float, max_hp: float) -> void:
	rpc("sync_health_ui_rpc", current, max_hp)

@rpc("any_peer", "call_local", "reliable")
func sync_health_ui_rpc(current: float, max_hp: float) -> void:
	if has_node("OverheadHP"):
		var hp_label = get_node("OverheadHP")
		if hp_label.has_method("update_health"):
			hp_label.update_health(current, max_hp)

@rpc("any_peer", "call_remote", "reliable")
func die_rpc() -> void:
	_perform_death()

func _perform_death() -> void:
	print("Player died! Entering Ragdoll...")
	
	# Disable input processing immediately
	set_process_unhandled_input(false)
	set_physics_process(false)
	
	# Add Ragdoll state dynamically if not present in scene
	if not state_machine.states.has("ragdoll"):
		var ragdoll_state = RagdollState.new()
		ragdoll_state.name = "Ragdoll"
		state_machine.add_child(ragdoll_state)
		
		# Manual registration
		state_machine.states["ragdoll"] = ragdoll_state
		ragdoll_state.transitioned.connect(state_machine.on_child_transition)
		ragdoll_state.player = self # Ensure reference is set if StateMachine usually sets it? 
		# StateMachine doesn't set 'player' automatically in _ready loop shown earlier?
		# Let's check StateMachine.gd
	
	state_machine.on_child_transition(state_machine.current_state, "ragdoll")

func _respawn() -> void:
	if is_multiplayer_authority():
		rpc("respawn_rpc")

@rpc("call_local", "reliable")
func respawn_rpc() -> void:
	print("Respawning...")
	
	# Restore State
	if health_component:
		health_component.heal(health_component.max_health)
	
	# Reset Position (Move up a bit to avoid stuck)
	global_position = _last_position + Vector3(0, 2, 0) # Simple respawn at death spot + offset
	# ideally respawn at spawn point, but we don't have one yet.
	
	model.rotation = Vector3.ZERO
	model.position = Vector3.ZERO
	
	# Restore Input
	set_process_unhandled_input(true)
	set_physics_process(true)
	
	# Transition to Idle
	state_machine.on_child_transition(state_machine.current_state, "idle")

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
	if not is_multiplayer_authority():
		# Puppet animation logic
		# Calculate real velocity from position change to fix sync issues
		var current_pos = global_position
		
		# Handle teleport or first frame
		if _last_position.distance_to(current_pos) > 5.0:
			_last_position = current_pos
			return
			
		var raw_vel = (current_pos - _last_position) / delta
		_last_position = current_pos
		
		# Smooth velocity to filter network jitter
		_smoothed_puppet_vel = _smoothed_puppet_vel.lerp(raw_vel, delta * 15.0)
		
		# Only override if we are in a movement-based state (Idle, Walk, Crouch)
		var current_state_name = ""
		if state_machine and state_machine.current_state:
			current_state_name = state_machine.current_state.name
		
		var movement_states = ["Idle", "Walk", "Jump", "Fall"] # Jump/Fall are also moving states
		
		# If state name is empty (not synced yet) or in allowed list
		if current_state_name == "" or current_state_name.to_lower() in ["idle", "walk", "jump", "fall"]:
			var h_vel = Vector3(_smoothed_puppet_vel.x, 0, _smoothed_puppet_vel.z).length()
			
			# Increased threshold to avoid jitter-walk
			if h_vel > 0.5:
				if h_vel > 5.5: # Sprint threshold
					if animation_player.current_animation != "UnarmedRunForward":
						animation_player.play("UnarmedRunForward", 0.3)
				else:
					if animation_player.has_animation("StrutWalking") and animation_player.current_animation != "StrutWalking":
						animation_player.play("StrutWalking", 0.3)
			else:
				# Only play Idle if we are NOT in jump/fall state (which have their own anims synced via state machine)
				# Actually, State Machine syncs the state change, but physics_update in JumpState might not run for puppets?
				# Wait, we disabled physics_process for StateMachine on puppets.
				# So puppets ONLY get state transitions via RPC.
				
				# If we are in Jump/Fall state, we should let the state's enter() play the animation?
				# But enter() plays once.
				
				# If we are in Idle/Walk, we control anims by speed.
				if current_state_name.to_lower() in ["idle", "walk"] or current_state_name == "":
					if animation_player.has_animation("Idle") and animation_player.current_animation != "Idle":
						animation_player.play("Idle", 0.3)
		
		return

	# Attack Input
	if Input.is_action_just_pressed("attack"):
		# Block attack if radial menu is open
		if radial_menu and radial_menu.visible:
			return
			
		# Block attack if already attacking or dead
		var current_state = state_machine.current_state.name.to_lower()
		if current_state == "attack" or current_state == "ragdoll" or current_state == "die":
			return
			
		state_machine.on_child_transition(state_machine.current_state, "attack")

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
	
	if is_multiplayer_authority():
		rpc("sync_dance_rpc", anim_name)
		_perform_dance(anim_name)

@rpc("any_peer", "call_remote", "reliable")
func sync_dance_rpc(anim_name: String) -> void:
	_perform_dance(anim_name)

func _perform_dance(anim_name: String) -> void:
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
