extends Control

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var status_label: Label = $StatusLabel

var target_scene_path: String
var loading_status: int
var progress: Array[float]

func _ready() -> void:
	target_scene_path = SceneManager.get_target_scene_path()
	if target_scene_path == "":
		push_error("LoadingScreen: No target scene path set!")
		return
		
	ResourceLoader.load_threaded_request(target_scene_path)
	
func _process(delta: float) -> void:
	if target_scene_path == "":
		return
		
	loading_status = ResourceLoader.load_threaded_get_status(target_scene_path, progress)
	
	if loading_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		progress_bar.value = progress[0] * 100
		status_label.text = "Loading... " + str(int(progress[0] * 100)) + "%"
	elif loading_status == ResourceLoader.THREAD_LOAD_LOADED:
		progress_bar.value = 100
		status_label.text = "Loading Complete!"
		set_process(false)
		
		# Slight delay to show 100%
		await get_tree().create_timer(0.2).timeout
		
		var new_scene = ResourceLoader.load_threaded_get(target_scene_path)
		if new_scene:
			print("Loading Screen: Transitioning to ", target_scene_path)
			var err = get_tree().change_scene_to_packed(new_scene)
			if err != OK:
				push_error("Loading Screen: Failed to change scene! Error code: ", err)
		else:
			push_error("Loading Screen: Failed to get packed scene resource!")
	elif loading_status == ResourceLoader.THREAD_LOAD_FAILED:
		status_label.text = "Loading Failed!"
		set_process(false)
