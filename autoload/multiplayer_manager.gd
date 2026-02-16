extends Node

const PORT = 7000
const MAX_CLIENTS = 10

var peer = ENetMultiplayerPeer.new()

# Pending connection info
var _pending_mode = ""
var _pending_ip = ""
var _pending_port = 0

func _ready() -> void:
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.connected_to_server.connect(_on_connected_to_server)

func start_host(port: int = PORT):
	# Hosts start immediately
	var error = peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		push_error("Failed to start server: " + str(error))
		return
	multiplayer.multiplayer_peer = peer
	print("Server started on port " + str(port))

func join_game(address: String = "127.0.0.1", port: int = PORT):
	# Clients wait for scene load
	_pending_mode = "CLIENT"
	_pending_ip = address
	_pending_port = port
	print("Pending join to " + address + ":" + str(port))

func execute_pending_join():
	if _pending_mode == "CLIENT":
		var error = peer.create_client(_pending_ip, _pending_port)
		if error != OK:
			push_error("Failed to join server: " + str(error))
			_pending_mode = ""
			return
		multiplayer.multiplayer_peer = peer
		print("Joining server at " + _pending_ip + ":" + str(_pending_port))
		# Clear mode after connection attempt, but we might want to keep it if we need to retry
		_pending_mode = ""

func _on_server_disconnected():
	print("Disconnected from server")
	multiplayer.multiplayer_peer = null
	_pending_mode = ""
	SceneManager.change_scene("res://gui/main_menu.tscn")

func _on_connection_failed():
	print("Connection failed")
	multiplayer.multiplayer_peer = null
	_pending_mode = ""
	SceneManager.change_scene("res://gui/main_menu.tscn")

func _on_connected_to_server():
	print("Connected to server!")
