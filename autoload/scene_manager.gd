extends Node

var _target_scene_path: String
var loading_screen_scene: PackedScene = preload("res://gui/loading_screen.tscn")

func load_scene(path: String) -> void:
	_target_scene_path = path
	get_tree().change_scene_to_packed(loading_screen_scene)

func get_target_scene_path() -> String:
	return _target_scene_path
