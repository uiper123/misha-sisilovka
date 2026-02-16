extends Node3D
class_name OverheadHP

var bg_sprite: Sprite3D
var fg_sprite: Sprite3D
var max_width: float = 100.0 # Pixel width reference

func _ready() -> void:
	# Create Background (Black)
	bg_sprite = Sprite3D.new()
	bg_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bg_sprite.no_depth_test = true
	bg_sprite.render_priority = 10
	bg_sprite.modulate = Color(0, 0, 0, 0.6)
	bg_sprite.texture = _create_texture(104, 14) # Slightly larger
	add_child(bg_sprite)
	
	# Create Foreground (Health Color)
	fg_sprite = Sprite3D.new()
	fg_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fg_sprite.no_depth_test = true
	fg_sprite.render_priority = 11 # On top of BG
	fg_sprite.modulate = Color(0, 1, 0) # Green start
	fg_sprite.texture = _create_texture(100, 10)
	add_child(fg_sprite)
	
	position.y = 2.3 # Height

func update_health(current: float, max_hp: float) -> void:
	var percent = clamp(current / max_hp, 0.0, 1.0)
	
	# Scale X axis of the foreground sprite
	# Note: Sprite3D scaling scales the texture drawing, which is what we want.
	# But we need it to scale from left? Sprite3D centers by default.
	# We can use 'offset' or just scale and accept center scaling?
	# Center scaling looks okay for a floating bar, or we can adjust offset.
	
	# Let's try simple scaling first.
	fg_sprite.scale.x = percent
	
	# Color Gradient: Green -> Yellow -> Red
	fg_sprite.modulate = Color.RED.lerp(Color.GREEN, percent)
	
	# Hide if full health? Optional. Let's keep it visible for now.
	visible = current < max_hp and current > 0

func _create_texture(w: int, h: int) -> Texture2D:
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)
