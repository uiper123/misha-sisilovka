class_name PlayerState
extends Node

signal transitioned(state: PlayerState, new_state_name: String)

var player: CharacterBody3D

func _ready() -> void:
	# Expecting the parent of StateMachine to be the Player
	player = get_parent().get_parent()

func enter() -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass
