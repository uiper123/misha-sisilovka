extends CanvasLayer
class_name DamageOverlay

@onready var color_rect: ColorRect = $ColorRect

func _ready() -> void:
	color_rect.color = Color(1, 0, 0, 0) # Transparent red
	# Make sure it covers the screen
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func flash() -> void:
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0.4, 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(color_rect, "color:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
