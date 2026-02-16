extends Control

@onready var log_label: RichTextLabel = %Log
@onready var input_field: LineEdit = %Input
@onready var console_panel: PanelContainer = $ConsolePanel

# Command History
var history: Array[String] = []
var history_index: int = -1

# Commands
var commands: Dictionary = {
	"help": "Displays available commands",
	"clear": "Clears the log",
	"echo": "Prints text to log",
	"psx_effect": "Toggles PSX post-process effect",
	"set_resolution": "Usage: set_resolution <w> <h> - Sets window size",
	"set_fullscreen": "Usage: set_fullscreen <true/false> - Toggles fullscreen",
	"quit": "Exits the game"
}

var custom_commands: Dictionary = {}

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Load custom commands
	custom_commands = DevConsoleHandler.custom_functions
	
	# Connect signals
	input_field.text_submitted.connect(_on_text_submitted)
	
	# Style Input
	input_field.context_menu_enabled = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_console"):
		toggle_console()
		get_viewport().set_input_as_handled()
	
	if visible and event.is_action_pressed("ui_up"):
		navigate_history(-1)
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_down"):
		navigate_history(1)
		get_viewport().set_input_as_handled()

func toggle_console() -> void:
	visible = !visible
	if visible:
		# Reset position just in case
		console_panel.position.y = get_viewport_rect().size.y - console_panel.size.y
		
		input_field.grab_focus()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true
	else:
		input_field.release_focus()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().paused = false

func _on_text_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
		
	input_field.clear()
	print_to_log("> " + text)
	
	# Add to history
	if history.is_empty() or history.back() != text:
		history.append(text)
	history_index = history.size()
	
	execute_command(text)

func execute_command(cmd_line: String) -> void:
	var args = split_arguments(cmd_line)
	if args.is_empty(): return
	
	var cmd = args[0]
	args.remove_at(0)
	
	if commands.has(cmd):
		match cmd:
			"help":
				print_to_log("[color=yellow]--- Standard Commands ---[/color]")
				for c in commands:
					print_to_log("[color=cyan]" + c + "[/color]: " + commands[c])
				print_to_log("[color=yellow]--- Custom Commands ---[/color]")
				for c in custom_commands:
					print_to_log("[color=cyan]" + c + "[/color]: " + custom_commands[c])
			"clear":
				log_label.text = ""
			"echo":
				print_to_log(" ".join(args))
			"psx_effect":
				if PostProcessManager:
					PostProcessManager.toggle_effect()
					print_to_log("PSX Effect toggled.")
				else:
					print_error("PostProcessManager not found.")
			"set_resolution":
				if args.size() >= 2:
					var w = int(args[0])
					var h = int(args[1])
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
					DisplayServer.window_set_size(Vector2i(w, h))
					var screen_size = DisplayServer.screen_get_size()
					var pos = (screen_size - Vector2i(w, h)) / 2
					DisplayServer.window_set_position(pos)
					print_to_log("Resolution set to " + str(w) + "x" + str(h))
				else:
					print_error("Usage: set_resolution <w> <h>")
			"set_fullscreen":
				if args.size() >= 1:
					var mode = args[0].to_lower() == "true"
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if mode else DisplayServer.WINDOW_MODE_WINDOWED)
					print_to_log("Fullscreen: " + str(mode))
				else:
					print_error("Usage: set_fullscreen <true/false>")
			"quit":
				get_tree().quit()
	elif custom_commands.has(cmd):
		if DevConsoleHandler.has_method(cmd):
			# DevConsoleHandler expects (PackedStringArray, String)
			# Reconstruct PackedStringArray including command name at 0
			var full_args = PackedStringArray([cmd])
			full_args.append_array(PackedStringArray(args))
			DevConsoleHandler.call(cmd, full_args, cmd_line)
			print_to_log("Executed custom command: " + cmd)
		else:
			print_error("Handler for command '" + cmd + "' not found in DevConsoleHandler.")
	else:
		print_error("Unknown command: " + cmd)

func navigate_history(direction: int) -> void:
	if history.is_empty(): return
	
	history_index = clamp(history_index + direction, 0, history.size())
	
	if history_index < history.size():
		input_field.text = history[history_index]
		input_field.caret_column = input_field.text.length()
	else:
		input_field.text = ""

func print_to_log(text: String) -> void:
	log_label.append_text(text + "\n")

func print_error(text: String) -> void:
	print_to_log("[color=red]" + text + "[/color]")

# Splits string by spaces but respects quotes
func split_arguments(text: String) -> PackedStringArray:
	var args = PackedStringArray()
	var current_arg = ""
	var in_quote = false
	
	for i in text.length():
		var char = text[i]
		if char == '"':
			in_quote = !in_quote
			continue
		
		if char == ' ' and !in_quote:
			if current_arg.length() > 0:
				args.append(current_arg)
				current_arg = ""
		else:
			current_arg += char
			
	if current_arg.length() > 0:
		args.append(current_arg)
		
	return args
