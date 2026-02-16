extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect

func _ready() -> void:
	visible = false # Disable by default

func toggle_effect() -> void:
	visible = !visible
