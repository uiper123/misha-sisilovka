extends Control

signal animation_selected(anim_name: String)

@export var radius: float = 200.0
@export var inner_radius: float = 50.0
@export var line_color: Color = Color.WHITE
@export var selection_color: Color = Color(1, 0.5, 0, 0.5)
@export var text_color: Color = Color.WHITE

var options: Array[Dictionary] = [
	{"name": "Breakdance", "anim": "Breakdance1990"},
	{"name": "Hip Hop 1", "anim": "HipHopDancing(1)"},
	{"name": "Hip Hop 2", "anim": "HipHopDancing(2)"},
	{"name": "Jazz", "anim": "JazzDancing"},
	{"name": "Thriller", "anim": "ThrillerPart4"},
	{"name": "Cow Milking", "anim": "CowMilking"},
	{"name": "Flair", "anim": "Flair(1)"},
	{"name": "Freeze", "anim": "BreakdanceFreezeVar2"},
	{"name": "Uprock", "anim": "BreakdanceUprockVar2"},
	{"name": "Convulsing", "anim": "Convulsing"},
	{"name": "Dance Pose", "anim": "FemaleDancePose"},
	{"name": "Laying", "anim": "FemaleLayingPose"},
	{"name": "Taunt", "anim": "TauntGesture"},
	{"name": "Battlecry", "anim": "StandingTauntBattlecry(1)"}
]

var selected_index: int = -1
var player: Node = null

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if visible and event is InputEventMouseMotion:
		var center = get_viewport_rect().size / 2
		var mouse_pos = event.position
		var dir = mouse_pos - center
		
		if dir.length() > inner_radius:
			var angle = dir.angle() + PI / 2 # Rotate so 0 is up
			if angle < 0: angle += TAU
			
			var sector_size = TAU / options.size()
			selected_index = int(angle / sector_size) % options.size()
		else:
			selected_index = -1
			
		queue_redraw()
		
	if visible and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Consume the input so attack doesn't trigger
			get_viewport().set_input_as_handled()
			
			if selected_index != -1:
				emit_signal("animation_selected", options[selected_index].anim)
			close_menu()

func open_menu() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	selected_index = -1
	queue_redraw()

func close_menu() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false
	
	# Block attack for a few frames to prevent accidental hits
	if player:
		player._attack_blocked_frames = 5

func _draw() -> void:
	var center = get_viewport_rect().size / 2
	var sector_size = TAU / options.size()
	
	for i in range(options.size()):
		var start_angle = i * sector_size - PI / 2
		var end_angle = (i + 1) * sector_size - PI / 2
		var mid_angle = (start_angle + end_angle) / 2
		
		# Draw Selection
		if i == selected_index:
			var points = PackedVector2Array()
			points.append(center)
			for j in range(21):
				var a = start_angle + (end_angle - start_angle) * j / 20.0
				points.append(center + Vector2(cos(a), sin(a)) * radius)
			draw_colored_polygon(points, selection_color)
		
		# Draw Lines
		draw_line(center, center + Vector2(cos(start_angle), sin(start_angle)) * radius, line_color, 2.0)
		
		# Draw Text
		var text_pos = center + Vector2(cos(mid_angle), sin(mid_angle)) * (radius * 0.7)
		var string_size = get_theme_default_font().get_string_size(options[i].name)
		draw_string(get_theme_default_font(), text_pos - Vector2(string_size.x / 2, -5), options[i].name, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, text_color)
		
	# Draw Circle Outline
	draw_arc(center, radius, 0, TAU, 64, line_color, 2.0)
	draw_arc(center, inner_radius, 0, TAU, 64, line_color, 2.0)
