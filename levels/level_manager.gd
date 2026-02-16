extends Node3D

@export var player_scene: PackedScene

func _ready():
	# Check if we have a pending join
	if MultiplayerManager._pending_mode == "CLIENT":
		MultiplayerManager.execute_pending_join()
	
	# Server logic
	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(_on_player_disconnected)
		_spawn_player(1) # Spawn host
	else:
		# Client logic: Notify server we are ready to receive the player
		# Wait for connection to be established
		if multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			_notify_server_ready()
		else:
			multiplayer.connected_to_server.connect(_notify_server_ready)

func _notify_server_ready():
	rpc_id(1, "player_loaded")

@rpc("any_peer", "call_local", "reliable")
func player_loaded():
	# Only server can spawn players
	if not multiplayer.is_server(): return
	
	var id = multiplayer.get_remote_sender_id()
	# Prevent duplicate spawns
	if $Players.has_node(str(id)):
		print("Player ", id, " already exists, skipping spawn.")
		return
		
	print("Spawning player for ID: ", id)
	_spawn_player(id)

func _on_player_connected(id):
	# Deprecated: We use player_loaded RPC now
	pass

func _on_player_disconnected(id):
	# Only server should delete nodes to sync with clients
	if not multiplayer.is_server(): return
	
	if $Players.has_node(str(id)):
		$Players.get_node(str(id)).queue_free()

func _spawn_player(id):
	var player = player_scene.instantiate()
	player.name = str(id)
	player.position = Vector3(0, 2, 0)
	$Players.add_child(player, true) # Force readable name for sync
