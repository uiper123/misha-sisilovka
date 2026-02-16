extends Node
class_name HealthComponent

signal health_changed(current: float, max: float)
signal damage_taken(amount: float, current_health: float)
signal died

@export var max_health: float = 100.0
var current_health: float

func _ready() -> void:
	current_health = max_health

func damage(amount: float) -> void:
	if is_multiplayer_authority():
		_apply_damage(amount)
	else:
		rpc_id(get_multiplayer_authority(), "_apply_damage_rpc", amount)

@rpc("any_peer", "call_local", "reliable")
func _apply_damage_rpc(amount: float) -> void:
	_apply_damage(amount)

func _apply_damage(amount: float) -> void:
	var old_health = current_health
	current_health = max(0.0, current_health - amount)
	
	if old_health != current_health:
		health_changed.emit(current_health, max_health)
		damage_taken.emit(amount, current_health)
		print("Took damage: ", amount, " Current HP: ", current_health)
	
		if current_health <= 0 and old_health > 0:
			died.emit()

func heal(amount: float) -> void:
	if is_multiplayer_authority():
		_heal(amount)
	else:
		rpc_id(get_multiplayer_authority(), "_heal_rpc", amount)

@rpc("any_peer", "call_local", "reliable")
func _heal_rpc(amount: float) -> void:
	_heal(amount)

func _heal(amount: float) -> void:
	var old_health = current_health
	current_health = min(max_health, current_health + amount)
	
	if old_health != current_health:
		health_changed.emit(current_health, max_health)
