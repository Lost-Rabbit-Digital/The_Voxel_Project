## GameManager - Singleton for handling game lifecycle and cleanup
extends Node

## Signals for game lifecycle events
signal game_starting()
signal game_ready()
signal game_exiting()

var is_exiting: bool = false
var pause_menu: Control = null

func _ready() -> void:
	print("[GameManager] Initialized")

	# Connect to notification for quit request
	get_tree().set_auto_accept_quit(false)  # We'll handle quit ourselves

	# Load and add pause menu
	var pause_menu_scene := load("res://scenes/pause_menu.tscn")
	if pause_menu_scene:
		pause_menu = pause_menu_scene.instantiate()
		add_child(pause_menu)
		print("[GameManager] Pause menu loaded")

	print("[GameManager] Ready - Game lifecycle manager active")

func _input(event: InputEvent) -> void:
	# ESC key to toggle pause menu
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if not is_exiting:
				toggle_pause_menu()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("[GameManager] Close request received")
		_handle_quit_request()

	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		print("[GameManager] Back button pressed (Android/etc)")
		_handle_quit_request()

## Toggle pause menu
func toggle_pause_menu() -> void:
	if not pause_menu:
		return

	if pause_menu.is_paused:
		pause_menu.hide_menu()
	else:
		pause_menu.show_menu()

## Handle quit request with proper cleanup
func _handle_quit_request() -> void:
	if is_exiting:
		print("[GameManager] Already exiting, ignoring duplicate quit request")
		return

	is_exiting = true
	print("[GameManager] Starting cleanup sequence...")
	game_exiting.emit()

	# Perform cleanup
	await _cleanup_game()

	print("[GameManager] Cleanup complete, quitting application")
	get_tree().quit()

## Cleanup all game systems before exit
func _cleanup_game() -> void:
	print("[GameManager] Cleaning up game systems...")

	# Find and cleanup VoxelWorld if it exists
	var voxel_world := _find_voxel_world()
	if voxel_world:
		print("[GameManager] Cleaning up VoxelWorld...")
		if voxel_world.has_method("cleanup"):
			voxel_world.cleanup()
		elif voxel_world.chunk_manager:
			print("[GameManager] Cleaning up ChunkManager...")
			voxel_world.chunk_manager.cleanup_all()

	# Wait a frame to ensure cleanup completes
	await get_tree().process_frame

	print("[GameManager] Game systems cleaned up")

## Find VoxelWorld in the scene tree
func _find_voxel_world() -> Node:
	var root := get_tree().root
	if not root:
		return null

	# Search for VoxelWorld node
	var nodes := _get_all_children(root)
	for node in nodes:
		if node is VoxelWorld or node.get_class() == "VoxelWorld":
			return node

	return null

## Recursively get all children of a node
func _get_all_children(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_get_all_children(child))
	return result

## Manual quit function (can be called from pause menu, etc.)
func quit_game() -> void:
	print("[GameManager] Manual quit requested")
	_handle_quit_request()
