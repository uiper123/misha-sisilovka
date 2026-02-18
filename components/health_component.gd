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
	# Always apply damage through server for consistency
	if multiplayer.is_server():
		_apply_damage(amount)
	else:
		# Client requests damage from server
		rpc_id(1, "_request_damage_rpc", amount)

@rpc("any_peer", "call_remote", "reliable")
func _request_damage_rpc(amount: float) -> void:
	# Only server processes damage requests
	if not multiplayer.is_server():
		return
	_apply_damage(amount)

func _apply_damage(amount: float) -> void:
	var old_health = current_health
	current_health = max(0.0, current_health - amount)
	
	if old_health != current_health:
		# Broadcast health change to all clients
		rpc("_sync_health_rpc", current_health)
		health_changed.emit(current_health, max_health)
		damage_taken.emit(amount, current_health)
		print("Took damage: ", amount, " Current HP: ", current_health)
	
		if current_health <= 0 and old_health > 0:
			died.emit()

@rpc("authority", "call_remote", "reliable")
func _sync_health_rpc(new_health: float) -> void:
	# Clients receive health updates from server
	var old_health = current_health
	current_health = new_health
	if old_health != current_health:
		health_changed.emit(current_health, max_health)
		if current_health <= 0 and old_health > 0:
			died.emit()

func heal(amount: float) -> void:
	# Always apply healing through server for consistency
	if multiplayer.is_server():
		_heal(amount)
	else:
		# Client requests healing from server
		rpc_id(1, "_request_heal_rpc", amount)

@rpc("any_peer", "call_remote", "reliable")
func _request_heal_rpc(amount: float) -> void:
	# Only server processes heal requests
	if not multiplayer.is_server():
		return
	_heal(amount)

func _heal(amount: float) -> void:
	var old_health = current_health
	current_health = min(max_health, current_health + amount)
	
	if old_health != current_health:
		# Broadcast health change to all clients
		rpc("_sync_health_rpc", current_health)
		health_changed.emit(current_health, max_health)
