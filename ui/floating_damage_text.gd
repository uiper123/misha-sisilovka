extends Label3D
class_name FloatingDamageText

func _ready() -> void:
	pixel_size = 0.005
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	outline_render_priority = 0
	outline_modulate = Color(0, 0, 0)
	font_size = 64
	modulate = Color(1, 0, 0)
	outline_size = 12
	no_depth_test = true
	render_priority = 10 # Draw on top

	# Float up and fade
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y + 1.5, 1.0)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(queue_free)

func set_amount(amount: float) -> void:
	text = str(int(amount))
