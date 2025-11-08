## PauseMenu - Handles pause menu UI and functionality
extends Control

@onready var resume_button: Button = $Panel/VBoxContainer/ResumeButton
@onready var clear_data_button: Button = $Panel/VBoxContainer/ClearDataButton
@onready var exit_button: Button = $Panel/VBoxContainer/ExitButton

var is_paused: bool = false

func _ready() -> void:
	# Initially hidden
	hide()

	# Connect button signals
	resume_button.pressed.connect(_on_resume_pressed)
	clear_data_button.pressed.connect(_on_clear_data_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	# Set anchors to center
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func show_menu() -> void:
	is_paused = true
	show()
	get_tree().paused = true

	# Grab focus on resume button
	resume_button.grab_focus()

	# Release mouse capture so UI works
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_menu() -> void:
	is_paused = false
	hide()
	get_tree().paused = false

	# Re-capture mouse for game
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_resume_pressed() -> void:
	print("[PauseMenu] Resume button pressed")
	hide_menu()

func _on_clear_data_pressed() -> void:
	print("[PauseMenu] Clear game data requested")

	# Show confirmation dialog
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Are you sure you want to clear all game data?\nThis will delete all cached chunks and cannot be undone."
	dialog.title = "Clear Game Data"

	# Add to tree temporarily
	add_child(dialog)

	# Connect confirmed signal
	dialog.confirmed.connect(_on_clear_data_confirmed)
	dialog.canceled.connect(func(): dialog.queue_free())

	# Show dialog
	dialog.popup_centered()

func _on_clear_data_confirmed() -> void:
	print("[PauseMenu] Clear data confirmed, clearing cache...")

	# Find VoxelWorld and clear cache
	var voxel_world := _find_voxel_world()
	if voxel_world and voxel_world.chunk_manager:
		var chunk_manager = voxel_world.chunk_manager

		# Clear cache if available
		if chunk_manager.chunk_cache:
			print("[PauseMenu] Clearing chunk cache...")
			chunk_manager.chunk_cache.clear_all_caches()
			print("[PauseMenu] Chunk cache cleared")

		# Unload all chunks
		print("[PauseMenu] Unloading all chunks...")
		chunk_manager.cleanup_all()
		print("[PauseMenu] All chunks unloaded")

		# Trigger chunk reload
		if voxel_world.has_method("_update_chunks"):
			voxel_world._update_chunks()

	# Close dialog
	for child in get_children():
		if child is ConfirmationDialog:
			child.queue_free()

	# Show feedback message
	print("[PauseMenu] Game data cleared successfully")

	# Resume game
	hide_menu()

func _on_exit_pressed() -> void:
	print("[PauseMenu] Exit button pressed")

	# Unpause before quitting
	get_tree().paused = false

	# Call GameManager quit
	GameManager.quit_game()

## Find VoxelWorld in the scene tree
func _find_voxel_world() -> Node:
	var root := get_tree().root
	if not root:
		return null

	# Search for VoxelWorld node
	var nodes := _get_all_children(root)
	for node in nodes:
		if node.get_class() == "VoxelWorld" or node.name == "VoxelWorld":
			return node

	return null

## Recursively get all children of a node
func _get_all_children(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_get_all_children(child))
	return result
