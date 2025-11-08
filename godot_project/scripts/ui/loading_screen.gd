## LoadingScreen - Full screen loading UI with progress bar
extends Control

@onready var message_label: RichTextLabel = $MarginContainer/VBoxContainer/MessageLabel
@onready var progress_bar: ProgressBar = $MarginContainer/VBoxContainer/ProgressBar
@onready var background: ColorRect = $Background

var target_scene_path: String = ""

func _ready() -> void:
	# Make sure we're full screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Connect to loading manager signals
	LoadingManager.progress_changed.connect(_on_progress_changed)
	LoadingManager.loading_complete.connect(_on_loading_complete)

	print("[LoadingScreen] Ready")

	# Start loading the game scene after a brief moment
	await get_tree().create_timer(0.2).timeout
	_start_loading_game()

## Update progress display
func _on_progress_changed(current: float, total: float, message: String) -> void:
	if progress_bar:
		progress_bar.max_value = total
		progress_bar.value = current

	if message_label:
		var percentage := LoadingManager.get_progress_percentage()
		message_label.text = "[center]%s\n\n[b]%.0f%%[/b][/center]" % [message, percentage]

## Handle loading completion
func _on_loading_complete() -> void:
	print("[LoadingScreen] Loading complete, transitioning to game...")

	# Fade out or transition to game scene
	if target_scene_path.is_empty():
		target_scene_path = "res://scenes/voxel_test_scene.tscn"

	# Change to the game scene
	get_tree().change_scene_to_file(target_scene_path)

## Set the scene to load after completion
func set_target_scene(scene_path: String) -> void:
	target_scene_path = scene_path

## Start loading the game scene
func _start_loading_game() -> void:
	if target_scene_path.is_empty():
		target_scene_path = "res://scenes/voxel_test_scene.tscn"

	print("[LoadingScreen] Loading game scene: %s" % target_scene_path)

	# Load the scene in the background
	var loader := ResourceLoader.load_threaded_request(target_scene_path)

	# Wait for the scene to load
	while true:
		var status := ResourceLoader.load_threaded_get_status(target_scene_path)

		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			# Update progress
			var progress := []
			ResourceLoader.load_threaded_get_status(target_scene_path, progress)
			if progress.size() > 0:
				var percent := progress[0] * 100.0
				if message_label:
					message_label.text = "[center]Loading game assets...\n\n[b]%.0f%%[/b][/center]" % percent
			await get_tree().process_frame

		elif status == ResourceLoader.THREAD_LOAD_LOADED:
			print("[LoadingScreen] Game scene loaded, instantiating...")
			var packed_scene := ResourceLoader.load_threaded_get(target_scene_path) as PackedScene
			if packed_scene:
				# The game scene will report its own loading progress
				get_tree().change_scene_to_packed(packed_scene)
			break

		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			print("[LoadingScreen] ERROR: Failed to load game scene!")
			if message_label:
				message_label.text = "[center][color=red]Failed to load game![/color][/center]"
			break

		await get_tree().process_frame
