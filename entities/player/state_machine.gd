class_name StateMachine
extends Node

@export var initial_state: PlayerState

var current_state: PlayerState
var states: Dictionary = {}

# Synchronized state name for puppets
var current_state_name: String = ""

func _ready() -> void:
	for child in get_children():
		if child is PlayerState:
			states[child.name.to_lower()] = child
			child.transitioned.connect(on_child_transition)

	if initial_state:
		initial_state.enter()
		current_state = initial_state

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)

func on_child_transition(state: PlayerState, new_state_name: String) -> void:
	if state != current_state:
		return

	var new_state = states.get(new_state_name.to_lower())
	if !new_state:
		return

	# Only authority can initiate state transitions
	if not is_multiplayer_authority():
		return
	
	# Perform transition locally first for responsiveness
	_perform_transition(new_state)
	
	# Then broadcast to other clients
	rpc("change_state_rpc", new_state_name)

@rpc("any_peer", "call_remote", "reliable")
func change_state_rpc(new_state_name: String) -> void:
	# Clients receive this
	# Only accept state changes from authority (server or owner of player object)
	# The player object's authority should match the sender_id?
	# Actually, usually the player object on client is owned by server (if server auth) or client (if client auth).
	# Here we use 'set_multiplayer_authority(name.to_int())', so each player object is owned by its corresponding peer.
	
	# So we should trust the RPC if it comes from the authority of this node.
	# But wait, 'any_peer' allows anyone. We should check sender.
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != get_multiplayer_authority():
		# Ignore state changes from non-owners
		return

	var new_state = states.get(new_state_name.to_lower())
	if new_state:
		_perform_transition(new_state)

func _perform_transition(new_state: PlayerState) -> void:
	if current_state:
		current_state.exit()

	new_state.enter()
	current_state = new_state
	current_state_name = new_state.name if new_state else ""
