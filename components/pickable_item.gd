@tool
extends RigidBody3D
class_name PickableItem
## Предмет, который игрок может подобрать и держать в руках.
##
## === КАК НАСТРОИТЬ ПРЕДМЕТ ===
## 1. Создай модель предмета (меш) как child этого узла
## 2. Расположи модель так, чтобы ТОЧКА ХВАТА была в центре (0,0,0)
## 3. Выбери hold_mode: ONE_HANDED (меч, бутылка) или TWO_HANDED (ящик, бревно)
## 4. Запусти игру, подними предмет, нажми F4 для режима настройки:
##    - Tab = переключить ось (X → Y → Z)
##    - Shift = переключить позиция/вращение  
##    - PgUp/PgDn = изменить значение
##    - [ ] = изменить шаг
##    - F5 = напечатать готовые значения (скопируй в инспектор)
##    - F3 = показать оси координат
##
## === ОСИ КООРДИНАТ (при ONE_HANDED, правая рука) ===
## X+ = вправо (от персонажа)
## Y+ = вверх
## Z+ = вперёд (от ладони)
##
## === ТИПИЧНЫЕ ЗНАЧЕНИЯ ===
## Меч:      hold_offset=(0, 0.1, 0), hold_rotation=(-90, 0, 0)
## Бутылка:  hold_offset=(0, 0.05, 0), hold_rotation=(0, 0, 0)
## Ящик:     hold_offset=(0, 0, 0), hold_rotation=(0, 0, 0)

enum HoldMode {
	TWO_HANDED,  ## Двумя руками (ящики, большие предметы) - используется IK
	ONE_HANDED   ## Одной рукой (оружие, инструменты) - крепится к кости руки
}

enum HoldHand {
	RIGHT,  ## Правая рука (основная)
	LEFT    ## Левая рука
}

@export_category("Hold Settings")
@export var hold_mode: HoldMode = HoldMode.TWO_HANDED:
	set(v):
		hold_mode = v
		_update_preview()

## Какая рука держит предмет (только для ONE_HANDED)
@export var hold_hand: HoldHand = HoldHand.RIGHT:
	set(v):
		hold_hand = v
		_update_preview()

## Ширина хвата для двуручных предметов (расстояние между руками)
@export var grip_width: float = 0.5

@export_subgroup("Position & Rotation")
## Смещение позиции в руке. Используй F4 в игре для настройки!
@export var hold_offset: Vector3 = Vector3.ZERO:
	set(v):
		hold_offset = v
		_update_preview()

## Поворот в руке (градусы). Используй F4 в игре для настройки!
@export var hold_rotation: Vector3 = Vector3.ZERO:
	set(v):
		hold_rotation = v
		_update_preview()

@export_subgroup("Physics")
## Вес предмета в кг. Влияет на скорость игрока (>10кг замедляет)
@export var weight: float = 0.0

@export_category("Editor Preview")
## Показать превью позиции в редакторе
@export var show_preview_gizmo: bool = false:
	set(v):
		show_preview_gizmo = v
		_update_preview()

var _outline_mat: ShaderMaterial
var _original_mesh: GeometryInstance3D
var _preview_gizmo: Node3D = null

func _update_preview() -> void:
	"""Updates editor preview gizmo"""
	if not Engine.is_editor_hint():
		return
	
	# Remove old gizmo
	if _preview_gizmo:
		_preview_gizmo.queue_free()
		_preview_gizmo = null
	
	if not show_preview_gizmo:
		return
	
	# Create gizmo showing hold position/rotation
	_preview_gizmo = Node3D.new()
	_preview_gizmo.name = "_HoldPreview"
	add_child(_preview_gizmo)
	
	# Apply hold transform
	_preview_gizmo.position = hold_offset
	_preview_gizmo.rotation_degrees = hold_rotation
	
	# Create axis indicators
	var axis_length = 0.15
	
	# X axis (red)
	var x_axis = _create_axis_mesh(Color.RED, Vector3(axis_length, 0, 0))
	_preview_gizmo.add_child(x_axis)
	
	# Y axis (green)  
	var y_axis = _create_axis_mesh(Color.GREEN, Vector3(0, axis_length, 0))
	_preview_gizmo.add_child(y_axis)
	
	# Z axis (blue)
	var z_axis = _create_axis_mesh(Color.BLUE, Vector3(0, 0, axis_length))
	_preview_gizmo.add_child(z_axis)
	
	# Hand indicator (sphere)
	var hand = CSGSphere3D.new()
	hand.radius = 0.03
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.YELLOW
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hand.material = mat
	_preview_gizmo.add_child(hand)

func _create_axis_mesh(color: Color, direction: Vector3) -> CSGBox3D:
	var axis = CSGBox3D.new()
	var thickness = 0.008
	
	if direction.x != 0:
		axis.size = Vector3(abs(direction.x), thickness, thickness)
		axis.position = direction / 2
	elif direction.y != 0:
		axis.size = Vector3(thickness, abs(direction.y), thickness)
		axis.position = direction / 2
	else:
		axis.size = Vector3(thickness, thickness, abs(direction.z))
		axis.position = direction / 2
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	axis.material = mat
	return axis

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
	# Skip runtime setup in editor
	if Engine.is_editor_hint():
		_update_preview()
		return
	
	# Ensure this item is interactable on the correct layers
	collision_layer = 1 | 4 # Layer 1 (World) | Layer 3 (Interactable)
	
	_find_mesh(self)
	
	if _original_mesh:
		_outline_mat = ShaderMaterial.new()
		var shader = load("res://assets/shaders/outline.gdshader")
		if shader:
			_outline_mat.shader = shader
			_outline_mat.set_shader_parameter("outline_color", Color(1.0, 1.0, 0.0, 0.5))
			_outline_mat.set_shader_parameter("outline_width", 5.0)
			_outline_mat.set_shader_parameter("pulse", true)

func _find_mesh(node: Node) -> void:
	for child in node.get_children():
		if child is GeometryInstance3D:
			_original_mesh = child
			return
		_find_mesh(child)
