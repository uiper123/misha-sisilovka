extends Control

func _get_port() -> int:
	var port_text = $VBoxContainer/PortInput.text
	if port_text == "":
		return 7000
	return int(port_text)

func _on_host_pressed():
	MultiplayerManager.start_host(_get_port())
	SceneManager.load_scene("res://levels/test_world.tscn")

func _on_join_pressed():
	var ip = $VBoxContainer/IPAddress.text
	if ip == "":
		ip = "127.0.0.1"
	
	# This will now just set pending mode
	MultiplayerManager.join_game(ip, _get_port())
	
	# Load scene first
	SceneManager.load_scene("res://levels/test_world.tscn")
