extends Control

func _ready() -> void:
	# Ensure mouse is visible in main menu
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_play_button_pressed() -> void:
	SceneManager.load_scene("res://levels/test_world.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()
