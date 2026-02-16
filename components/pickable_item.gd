extends RigidBody3D
class_name PickableItem

enum HoldMode {
	TWO_HANDED,
	ONE_HANDED
}

enum HoldHand {
	RIGHT,
	LEFT
}

@export_category("Hold Settings")
@export var hold_mode: HoldMode = HoldMode.TWO_HANDED
## Which hand holds the item (only for ONE_HANDED mode)
@export var hold_hand: HoldHand = HoldHand.RIGHT
## Distance between hands when holding two-handed (centered).
@export var grip_width: float = 0.5 
## Position offset when held
@export var hold_offset: Vector3 = Vector3.ZERO
## Rotation offset when held (degrees)
@export var hold_rotation: Vector3 = Vector3.ZERO
## Weight of the item in kg (affects player speed)
@export var weight: float = 0.0

var _outline_mat: ShaderMaterial
var _original_mesh: GeometryInstance3D

func set_highlight(enabled: bool) -> void:
	if not _original_mesh:
		return
		
	if enabled:
		if not _original_mesh.material_overlay:
			_original_mesh.material_overlay = _outline_mat
	else:
		_original_mesh.material_overlay = null

func interact(interactor: Node3D) -> void:
	if interactor.has_method("pickup_item"):
		interactor.pickup_item(self)

func _ready() -> void:
	# Ensure this item is interactable on the correct layers
	collision_layer = 1 | 4 # Layer 1 (World) | Layer 3 (Interactable - assuming 3)
	# Let's check project settings or assume default
	# If we want raycast to hit it, it must be on a layer the raycast checks
	# InteractionController checks collide_with_bodies=true
	
	_find_mesh(self)
	
	if _original_mesh:
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = load("res://assets/shaders/outline.gdshader")
		_outline_mat.set_shader_parameter("outline_color", Color(1.0, 1.0, 0.0, 0.5))
		_outline_mat.set_shader_parameter("outline_width", 5.0)
		_outline_mat.set_shader_parameter("pulse", true)

func _find_mesh(node: Node) -> void:
	for child in node.get_children():
		if child is GeometryInstance3D:
			_original_mesh = child
			return
		_find_mesh(child)
