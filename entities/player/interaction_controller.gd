extends Node3D

@export var interaction_distance: float = 5.0
@export var raycast_path: NodePath
## Enable debug axes at mount points (toggle with F3 in-game)
@export var debug_mounts: bool = false

## How far in front of the spine the item is held (local Z of CarryMarker)
const CARRY_DISTANCE: float = 0.4
## Minimum carry distance when pushed back by walls
const MIN_CARRY_DISTANCE: float = 0.15
## Margin added to each side for hand placement (approximate hand thickness)
const HAND_MARGIN: float = 0.08

signal item_picked_up(item: PickableItem)
signal item_dropped(item: PickableItem)

@onready var player: CharacterBody3D = owner
@onready var skeleton: Skeleton3D = player.get_node("Model/Scene/Armature/Skeleton3D")
@onready var camera: Camera3D = player.get_node("CameraPivot/SpringArm3D/Camera3D")
@onready var state_machine: Node = player.get_node("StateMachine")

@onready var carry_pivot: Node3D = $CarryPivot
@onready var carry_marker: Marker3D = $CarryPivot/CarryMarker
@onready var left_hand_target: Marker3D = $CarryPivot/LeftHandTarget
@onready var right_hand_target: Marker3D = $CarryPivot/RightHandTarget

@onready var left_arm_ik: SkeletonIK3D = player.get_node("Model/Scene/Armature/Skeleton3D/LeftArmIK")
@onready var right_arm_ik: SkeletonIK3D = player.get_node("Model/Scene/Armature/Skeleton3D/RightArmIK")

# Bone attachments for one-handed items
@onready var right_hand_attach: BoneAttachment3D = player.get_node("Model/Scene/Armature/Skeleton3D/RightHandAttachment")
@onready var left_hand_attach: BoneAttachment3D = player.get_node("Model/Scene/Armature/Skeleton3D/LeftHandAttachment")

var held_item: PickableItem = null
var _ik_tween: Tween
var _hovered_item: PickableItem = null

# Cached item extents (half-sizes), calculated on pickup
var _item_half_extents: Vector3 = Vector3(0.25, 0.25, 0.25)
# Collision shape for wall checks
var _collision_shape: BoxShape3D

# Debug visualization nodes
var _debug_axes: Array[Node3D] = []
var _debug_toggled: bool = false

# Debug adjustment mode (F4)
var _adjust_mode: bool = false
var _adjust_axis: int = 0  # 0=X, 1=Y, 2=Z
var _adjust_is_rotation: bool = false  # false=position, true=rotation
var _adjust_step: float = 0.01  # position step in meters
var _adjust_rot_step: float = 5.0  # rotation step in degrees
var _adjust_label: Label = null

func _ready() -> void:
	if not skeleton:
		push_error("InteractionController: Skeleton not found!")
	
	if not left_arm_ik or not right_arm_ik:
		push_error("InteractionController: SkeletonIK3D nodes not found!")
	else:
		left_arm_ik.stop()
		right_arm_ik.stop()
	
	# Fix BoneAttachment bone indices (in case .tscn didn't set them correctly)
	if skeleton and right_hand_attach:
		var ridx = skeleton.find_bone("RightHand")
		if ridx >= 0:
			right_hand_attach.bone_idx = ridx
			print("RightHand bone_idx = ", ridx)
	
	if skeleton and left_hand_attach:
		var lidx = skeleton.find_bone("LeftHand")
		if lidx >= 0:
			left_hand_attach.bone_idx = lidx
			print("LeftHand bone_idx = ", lidx)
	
	_collision_shape = BoxShape3D.new()
	
	# Create UI hint
	var canvas = CanvasLayer.new()
	canvas.name = "InteractionUI"
	add_child(canvas)
	
	var hint = Label.new()
	hint.name = "InteractionHint"
	hint.text = "[E] Interact"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.anchors_preset = Control.PRESET_CENTER
	hint.position = Vector2(get_viewport().size.x / 2, get_viewport().size.y / 2 + 50)
	hint.visible = false
	canvas.add_child(hint)
	
	# Adjust mode HUD
	_adjust_label = Label.new()
	_adjust_label.name = "AdjustHUD"
	_adjust_label.text = ""
	_adjust_label.position = Vector2(10, 10)
	_adjust_label.visible = false
	_adjust_label.add_theme_font_size_override("font_size", 16)
	canvas.add_child(_adjust_label)
	
	# Start with debug if enabled in inspector
	if debug_mounts:
		_create_debug_axes()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	
	match event.keycode:
		KEY_F3:
			# Toggle debug axes
			debug_mounts = !debug_mounts
			if debug_mounts:
				_create_debug_axes()
				print("=== DEBUG MOUNT POINTS ON ===")
				print("Red = X | Green = Y | Blue = Z")
			else:
				_destroy_debug_axes()
				print("=== DEBUG MOUNT POINTS OFF ===")
		
		KEY_F4:
			# Toggle adjustment mode
			if not held_item:
				print(">>> Hold an item first, then press F4!")
				return
			_adjust_mode = !_adjust_mode
			_adjust_label.visible = _adjust_mode
			if _adjust_mode:
				print("=== ADJUST MODE ON ===")
				print("Controls:")
				print("  Tab        = switch axis (X → Y → Z)")
				print("  Shift      = toggle Position / Rotation")
				print("  PgUp/PgDn  = adjust value +/-")
				print("  [ / ]      = change step size")
				print("  F5         = PRINT final values (copy-paste)")
				print("  F4         = exit adjust mode")
				_update_adjust_hud()
			else:
				print("=== ADJUST MODE OFF ===")
		
		KEY_F5:
			# Print current values for copy-paste
			if held_item and _adjust_mode:
				print("")
				print("╔══════════════════════════════════════════╗")
				print("║  ITEM: ", held_item.name)
				print("║  hold_offset = Vector3(%.3f, %.3f, %.3f)" % [held_item.hold_offset.x, held_item.hold_offset.y, held_item.hold_offset.z])
				print("║  hold_rotation = Vector3(%.1f, %.1f, %.1f)" % [held_item.hold_rotation.x, held_item.hold_rotation.y, held_item.hold_rotation.z])
				print("╚══════════════════════════════════════════╝")
				print("")
		
		KEY_TAB:
			if _adjust_mode:
				_adjust_axis = (_adjust_axis + 1) % 3
				var axis_name = ["X", "Y", "Z"][_adjust_axis]
				print("Axis: ", axis_name)
				_update_adjust_hud()
		
		KEY_SHIFT:
			if _adjust_mode:
				_adjust_is_rotation = !_adjust_is_rotation
				var mode_name = "ROTATION" if _adjust_is_rotation else "POSITION"
				print("Mode: ", mode_name)
				_update_adjust_hud()
		
		KEY_PAGEUP:
			if _adjust_mode and held_item:
				_adjust_value(1.0)
		
		KEY_PAGEDOWN:
			if _adjust_mode and held_item:
				_adjust_value(-1.0)
		
		KEY_BRACKETLEFT:  # [
			if _adjust_mode:
				if _adjust_is_rotation:
					_adjust_rot_step = max(1.0, _adjust_rot_step / 2.0)
					print("Rotation step: ", _adjust_rot_step, "°")
				else:
					_adjust_step = max(0.001, _adjust_step / 2.0)
					print("Position step: ", _adjust_step, "m")
				_update_adjust_hud()
		
		KEY_BRACKETRIGHT:  # ]
			if _adjust_mode:
				if _adjust_is_rotation:
					_adjust_rot_step = min(45.0, _adjust_rot_step * 2.0)
					print("Rotation step: ", _adjust_rot_step, "°")
				else:
					_adjust_step = min(0.5, _adjust_step * 2.0)
					print("Position step: ", _adjust_step, "m")
				_update_adjust_hud()

func _adjust_value(direction: float) -> void:
	if not held_item:
		return
	
	if _adjust_is_rotation:
		var rot = held_item.hold_rotation
		rot[_adjust_axis] += _adjust_rot_step * direction
		held_item.hold_rotation = rot
		held_item.rotation_degrees = rot
	else:
		var pos = held_item.hold_offset
		pos[_adjust_axis] += _adjust_step * direction
		held_item.hold_offset = pos
		held_item.position = pos
	
	_update_adjust_hud()

func _update_adjust_hud() -> void:
	if not _adjust_label or not held_item:
		return
	
	var axis_names = ["X", "Y", "Z"]
	var mode_str = "ROT" if _adjust_is_rotation else "POS"
	var step_str = "%.1f°" % _adjust_rot_step if _adjust_is_rotation else "%.3fm" % _adjust_step
	var current_axis = axis_names[_adjust_axis]
	
	var pos = held_item.hold_offset
	var rot = held_item.hold_rotation
	
	var text = "[F4] ADJUST MODE\n"
	text += "Mode: %s | Axis: %s | Step: %s\n" % [mode_str, current_axis, step_str]
	text += "─────────────────────────────\n"
	text += "Offset:   X=%.3f  Y=%.3f  Z=%.3f\n" % [pos.x, pos.y, pos.z]
	text += "Rotation: X=%.1f  Y=%.1f  Z=%.1f\n" % [rot.x, rot.y, rot.z]
	text += "─────────────────────────────\n"
	text += "Tab=axis  Shift=pos/rot  PgUp/PgDn=adjust\n"
	text += "[/]=step  F5=print values"
	
	# Highlight current axis
	_adjust_label.text = text

func _process(_delta: float) -> void:
	# Visual updates that should run on all clients for correctness
	_update_carry_pivot_height()
	
	# Only authority handles interaction inputs and highlighting
	if is_multiplayer_authority():
		if Input.is_action_just_pressed("interact"):
			if held_item:
				drop_item()
			else:
				try_pickup_item()
		
		_update_wall_collision()
		_update_hover_highlight()
	else:
		# Disable highlight on puppets if any was active
		if _hovered_item:
			_hovered_item.set_highlight(false)
			_hovered_item = null
		
		var hint_node = get_node_or_null("InteractionUI/InteractionHint")
		if hint_node:
			hint_node.visible = false

# ─────────────────────────────────────────────
# Debug visualization (F3 toggle)
# ─────────────────────────────────────────────

func _create_debug_axes() -> void:
	_destroy_debug_axes()
	_debug_axes.append(_make_axis_gizmo(right_hand_attach))
	_debug_axes.append(_make_axis_gizmo(left_hand_attach))
	_debug_axes.append(_make_axis_gizmo(carry_marker))

func _destroy_debug_axes() -> void:
	for ax in _debug_axes:
		if is_instance_valid(ax):
			ax.queue_free()
	_debug_axes.clear()

func _make_axis_gizmo(parent: Node3D) -> Node3D:
	var root = Node3D.new()
	root.name = "DebugGizmo"
	parent.add_child(root)
	
	var length = 0.15
	var thick = 0.008
	
	# X - RED
	var xb = CSGBox3D.new()
	xb.size = Vector3(length, thick, thick)
	xb.position = Vector3(length / 2.0, 0, 0)
	var xm = StandardMaterial3D.new()
	xm.albedo_color = Color.RED
	xm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	xb.material = xm
	root.add_child(xb)
	
	# Y - GREEN
	var yb = CSGBox3D.new()
	yb.size = Vector3(thick, length, thick)
	yb.position = Vector3(0, length / 2.0, 0)
	var ym = StandardMaterial3D.new()
	ym.albedo_color = Color.GREEN
	ym.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	yb.material = ym
	root.add_child(yb)
	
	# Z - BLUE
	var zb = CSGBox3D.new()
	zb.size = Vector3(thick, thick, length)
	zb.position = Vector3(0, 0, length / 2.0)
	var zm = StandardMaterial3D.new()
	zm.albedo_color = Color.BLUE
	zm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	zb.material = zm
	root.add_child(zb)
	
	# Origin - WHITE sphere
	var sp = CSGSphere3D.new()
	sp.radius = 0.015
	var sm = StandardMaterial3D.new()
	sm.albedo_color = Color.WHITE
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sp.material = sm
	root.add_child(sp)
	
	return root

# ─────────────────────────────────────────────
# AABB / Extents helpers
# ─────────────────────────────────────────────

func _get_item_half_extents(item: PickableItem) -> Vector3:
	var mesh_instance = _find_mesh_recursive(item)
	if not mesh_instance:
		return Vector3(0.25, 0.25, 0.25)
	
	var aabb = mesh_instance.get_aabb()
	
	var total_scale = Vector3.ONE
	var current: Node3D = mesh_instance
	while current and current != carry_marker and current != right_hand_attach and current != left_hand_attach:
		total_scale *= current.scale
		if current.get_parent() is Node3D:
			current = current.get_parent() as Node3D
		else:
			break
	
	var half = aabb.size * 0.5
	half.x *= abs(total_scale.x)
	half.y *= abs(total_scale.y)
	half.z *= abs(total_scale.z)
	
	return half

# ─────────────────────────────────────────────
# Wall collision
# ─────────────────────────────────────────────

func _update_wall_collision() -> void:
	if not held_item or held_item.hold_mode != PickableItem.HoldMode.TWO_HANDED:
		return
	
	var space_state = get_world_3d().direct_space_state
	
	var exclude_rids: Array[RID] = [player.get_rid()]
	if held_item:
		exclude_rids.append(held_item.get_rid())
		_add_children_to_exclude(held_item, exclude_rids)
	
	_collision_shape.size = _item_half_extents * 2.0
	_collision_shape.size += Vector3(0.05, 0.05, 0.05)
	
	var target_z = CARRY_DISTANCE
	var ideal_local_pos = Vector3(carry_marker.position.x, carry_marker.position.y, target_z)
	var ideal_global_pos = carry_pivot.global_transform * ideal_local_pos
	
	var shape_query = PhysicsShapeQueryParameters3D.new()
	shape_query.shape = _collision_shape
	shape_query.transform = Transform3D(carry_pivot.global_transform.basis, ideal_global_pos)
	shape_query.collision_mask = 1
	shape_query.exclude = exclude_rids
	
	var results = space_state.intersect_shape(shape_query, 4)
	var final_z = target_z
	
	if results.size() > 0:
		var lo = MIN_CARRY_DISTANCE
		var hi = target_z
		for i in range(6):
			var mid = (lo + hi) / 2.0
			var test_local = Vector3(carry_marker.position.x, carry_marker.position.y, mid)
			var test_global = carry_pivot.global_transform * test_local
			shape_query.transform = Transform3D(carry_pivot.global_transform.basis, test_global)
			var test_results = space_state.intersect_shape(shape_query, 1)
			if test_results.size() > 0:
				hi = mid
			else:
				lo = mid
		final_z = lo
	
	var ray_from = carry_pivot.global_position
	ray_from.y = carry_marker.global_position.y
	var ray_dir = carry_pivot.global_transform.basis.z.normalized()
	var right_vec = carry_pivot.global_transform.basis.x.normalized()
	var up_vec = carry_pivot.global_transform.basis.y.normalized()
	var hw = _item_half_extents.x
	var hh = _item_half_extents.y
	
	var ray_origins = [ray_from, ray_from + right_vec * hw, ray_from - right_vec * hw, ray_from + up_vec * hh, ray_from - up_vec * hh]
	
	for origin in ray_origins:
		var to = origin + ray_dir * (final_z + _item_half_extents.z + 0.05)
		var query = PhysicsRayQueryParameters3D.create(origin, to)
		query.collide_with_bodies = true
		query.collide_with_areas = false
		query.exclude = exclude_rids
		var result = space_state.intersect_ray(query)
		if result:
			var hit_dist = origin.distance_to(result.position) - _item_half_extents.z - 0.02
			if hit_dist < final_z:
				final_z = max(MIN_CARRY_DISTANCE, hit_dist)
	
	carry_marker.position.z = lerp(carry_marker.position.z, final_z, 0.3)
	left_hand_target.position.z = lerp(left_hand_target.position.z, final_z, 0.3)
	right_hand_target.position.z = lerp(right_hand_target.position.z, final_z, 0.3)

func _add_children_to_exclude(node: Node, exclude_array: Array) -> void:
	for child in node.get_children():
		if child is CollisionObject3D:
			exclude_array.append(child.get_rid())
		_add_children_to_exclude(child, exclude_array)

# ─────────────────────────────────────────────
# Carry pivot height (crouching)
# ─────────────────────────────────────────────

func _update_carry_pivot_height() -> void:
	if not held_item or held_item.hold_mode != PickableItem.HoldMode.TWO_HANDED:
		return
	
	var is_crouching = false
	if state_machine and state_machine.current_state:
		if state_machine.current_state.name == "Crouch":
			is_crouching = true
	
	var target_local_y = 0.2
	if is_crouching:
		target_local_y = -0.2
	
	carry_marker.position.y = lerp(carry_marker.position.y, target_local_y, 0.1)
	left_hand_target.position.y = lerp(left_hand_target.position.y, target_local_y, 0.1)
	right_hand_target.position.y = lerp(right_hand_target.position.y, target_local_y, 0.1)

# ─────────────────────────────────────────────
# Hover highlight
# ─────────────────────────────────────────────

func _update_hover_highlight() -> void:
	var hint_label = get_node_or_null("InteractionUI/InteractionHint")
	if not hint_label: return
	
	if held_item:
		if _hovered_item:
			_hovered_item.set_highlight(false)
			_hovered_item = null
		hint_label.visible = true
		hint_label.text = "[E] Drop"
		return
	
	var item = _get_raycast_item()
	if item != _hovered_item:
		if _hovered_item:
			_hovered_item.set_highlight(false)
		_hovered_item = item
		if _hovered_item:
			_hovered_item.set_highlight(true)
	
	hint_label.visible = (_hovered_item != null)
	if _hovered_item:
		hint_label.text = "[E] Pick Up"

# ─────────────────────────────────────────────
# Raycast item detection
# ─────────────────────────────────────────────

func _get_raycast_item() -> PickableItem:
	var space_state = get_world_3d().direct_space_state
	
	# Fix for CAPTURED mouse mode: use screen center
	var mouse_pos = get_viewport().get_mouse_position()
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_pos = get_viewport().get_visible_rect().size / 2.0
		
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * interaction_distance
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	# Ensure we check the layers where items are
	query.collision_mask = 0xFFFFFFFF # Check all layers for now to be safe
	
	# Exclude self and held items (and all child colliders like HitboxComponent)
	var excluded_rids = []
	_collect_collision_rids(player, excluded_rids)
	
	if held_item:
		excluded_rids.append(held_item.get_rid())
		_collect_collision_rids(held_item, excluded_rids)
		
	query.exclude = excluded_rids
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.collider
		# print("Raycast hit: ", collider.name) # Debug print
		if collider is PickableItem:
			return collider
		elif collider.get_parent() is PickableItem:
			return collider.get_parent()
	
	return null

func _collect_collision_rids(node: Node, arr: Array) -> void:
	if node is CollisionObject3D:
		arr.append(node.get_rid())
	
	for child in node.get_children():
		_collect_collision_rids(child, arr)

func try_pickup_item() -> void:
	var item = _get_raycast_item()
	if item:
		# If multiplayer, verify ownership/authority before picking up?
		# Actually, items are usually server-owned.
		# But 'PickableItem' is a RigidBody.
		# We should check if we can pick it up.
		# item.interact(self)
		
		# Directly call pickup_item to ensure we use our controller logic
		pickup_item(item)
	else:
		# print("No item found to pickup") # Debug print
		pass

func pickup_item(item: PickableItem) -> void:
	if held_item:
		return
	
	# Only authority can initiate pickup for synchronization
	if is_multiplayer_authority():
		# If we are the server, we just do it and tell others.
		if multiplayer.is_server():
			rpc("pickup_rpc", item.get_path())
			_perform_pickup(item)
		else:
			# If we are a client, we tell the server "I want to pick this up"
			rpc_id(1, "request_pickup_rpc", item.get_path())

@rpc("any_peer", "call_remote", "reliable")
func request_pickup_rpc(item_path: NodePath) -> void:
	# Only server should receive this
	if not multiplayer.is_server():
		return
		
	var item = get_node_or_null(item_path)
	if item and item is PickableItem:
		# If someone else is holding it, don't pick it up
		if item.get_parent() is Marker3D or item.get_parent() is BoneAttachment3D:
			return
			
		# Broadcast pickup to all clients (including the requester)
		rpc("pickup_rpc", item_path)
		_perform_pickup(item)

@rpc("any_peer", "call_remote", "reliable")
func pickup_rpc(item_path: NodePath) -> void:
	var item = get_node_or_null(item_path)
	if item and item is PickableItem:
		# If someone else is holding it, don't pick it up?
		# Or force steal? Let's check parent
		if item.get_parent() is Marker3D or item.get_parent() is BoneAttachment3D:
			# Already held
			return
			
		_perform_pickup(item)

func _perform_pickup(item: PickableItem) -> void:
	held_item = item
	
	item.freeze = true
	item.collision_layer = 0
	item.collision_mask = 0
	
	if item.hold_mode == PickableItem.HoldMode.TWO_HANDED:
		_pickup_two_handed(item)
	elif item.hold_mode == PickableItem.HoldMode.ONE_HANDED:
		_pickup_one_handed(item)

func _pickup_two_handed(item: PickableItem) -> void:
	item.get_parent().remove_child(item)
	carry_marker.add_child(item)
	
	item.transform = Transform3D.IDENTITY
	item.position = item.hold_offset
	item.rotation_degrees = item.hold_rotation
	
	_item_half_extents = _get_item_half_extents(item)
	
	var hand_x = _item_half_extents.x + HAND_MARGIN
	left_hand_target.position.x = hand_x
	right_hand_target.position.x = -hand_x
	
	_start_ik(true, true)
	item_picked_up.emit(item)

func _pickup_one_handed(item: PickableItem) -> void:
	var is_right = (item.hold_hand == PickableItem.HoldHand.RIGHT)
	var attachment = right_hand_attach if is_right else left_hand_attach
	
	# Reparent directly to BoneAttachment
	item.get_parent().remove_child(item)
	attachment.add_child(item)
	
	# Reset and apply user offsets
	item.transform = Transform3D.IDENTITY
	item.position = item.hold_offset
	item.rotation_degrees = item.hold_rotation
	
	# Debug output
	print("--- ONE-HANDED PICKUP ---")
	print("Hand: ", "RIGHT" if is_right else "LEFT")
	print("Bone: ", attachment.bone_name)
	print("hold_offset: ", item.hold_offset)
	print("hold_rotation: ", item.hold_rotation)
	print("TIP: Press F3 to see axis gizmos. Adjust hold_offset/hold_rotation in inspector.")
	
	# No IK for one-handed items
	_stop_ik()
	item_picked_up.emit(item)

func _find_mesh_recursive(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var res = _find_mesh_recursive(child)
		if res:
			return res
	return null

# ─────────────────────────────────────────────
# IK control
# ─────────────────────────────────────────────

func _start_ik(enable_left: bool, enable_right: bool) -> void:
	if not left_arm_ik or not right_arm_ik:
		return
	
	if enable_left: left_arm_ik.start()
	if enable_right: right_arm_ik.start()
	
	if _ik_tween:
		_ik_tween.kill()
	_ik_tween = create_tween()
	_ik_tween.set_parallel(true)
	
	if enable_left:
		_ik_tween.tween_property(left_arm_ik, "interpolation", 1.0, 0.5).from(0.0)
	if enable_right:
		_ik_tween.tween_property(right_arm_ik, "interpolation", 1.0, 0.5).from(0.0)

# ─────────────────────────────────────────────
# Drop logic
# ─────────────────────────────────────────────

func drop_item() -> void:
	if not held_item:
		return
	
	if is_multiplayer_authority():
		var forward = -camera.global_transform.basis.z
		var impulse = forward * 5.0
		
		if multiplayer.is_server():
			rpc("drop_rpc", held_item.global_transform, impulse)
			_perform_drop(held_item, held_item.global_transform, impulse)
		else:
			rpc_id(1, "request_drop_with_impulse_rpc", impulse, held_item.global_transform)

@rpc("any_peer", "call_remote", "reliable")
func request_drop_rpc() -> void:
	if not multiplayer.is_server(): return
	
	if held_item:
		# Server calculates physics/transform since it has authority over the world
		# But wait, the client's camera direction matters for impulse.
		# Ideally client sends impulse vector.
		# For now, let's just drop it downwards/forwards relative to player model?
		# Or better: let client send impulse in request.
		pass

# Revised request_drop
@rpc("any_peer", "call_remote", "reliable")
func request_drop_with_impulse_rpc(impulse: Vector3, drop_transform: Transform3D) -> void:
	if not multiplayer.is_server(): return
	if held_item:
		rpc("drop_rpc", drop_transform, impulse)
		_perform_drop(held_item, drop_transform, impulse)

@rpc("any_peer", "call_remote", "reliable")
func drop_rpc(final_transform: Transform3D, impulse: Vector3) -> void:
	if held_item:
		_perform_drop(held_item, final_transform, impulse)

func _perform_drop(item: PickableItem, final_transform: Transform3D, impulse: Vector3) -> void:
	held_item = null
	_stop_ik()
	
	# Reparent to world root (TestWorld)
	var world_root = player.get_parent()
	if world_root.get_parent() is Node3D: # Assuming Players -> TestWorld
		world_root = world_root.get_parent()
	
	item.get_parent().remove_child(item)
	world_root.add_child(item)
	
	item.global_transform = final_transform
	
	item.freeze = false
	item.collision_layer = 1
	item.collision_mask = 1
	
	item.apply_impulse(impulse)
	
	item_dropped.emit(item)

func _stop_ik() -> void:
	if not left_arm_ik or not right_arm_ik:
		return
	
	if _ik_tween:
		_ik_tween.kill()
	_ik_tween = create_tween()
	_ik_tween.set_parallel(true)
	_ik_tween.tween_property(left_arm_ik, "interpolation", 0.0, 0.5)
	_ik_tween.tween_property(right_arm_ik, "interpolation", 0.0, 0.5)
	
	await _ik_tween.finished
	if not held_item:
		left_arm_ik.stop()
		right_arm_ik.stop()
