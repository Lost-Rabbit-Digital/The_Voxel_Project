## LoadingManager - Singleton for tracking and reporting loading progress
## Manages loading screen state and progress updates
extends Node

## Signals
signal progress_changed(current: float, total: float, message: String)
signal loading_complete()
signal loading_started()

## Loading state
var is_loading: bool = false
var current_progress: float = 0.0
var total_progress: float = 100.0
var current_message: String = ""

## Loading tasks tracking
var tasks: Array[Dictionary] = []
var completed_tasks: int = 0

func _ready() -> void:
	print("[LoadingManager] Initialized")

## Start a new loading session
func start_loading(task_count: int = 1) -> void:
	is_loading = true
	current_progress = 0.0
	total_progress = float(task_count)
	completed_tasks = 0
	tasks.clear()
	current_message = "Starting..."
	loading_started.emit()
	print("[LoadingManager] Loading started - %d tasks" % task_count)

## Report progress for a task
func update_progress(message: String, progress: float = -1.0) -> void:
	current_message = message

	if progress >= 0.0:
		current_progress = progress

	progress_changed.emit(current_progress, total_progress, message)
	print("[LoadingManager] %s (%.1f%%)" % [message, get_progress_percentage()])

## Complete a task and advance progress
func complete_task(task_name: String) -> void:
	completed_tasks += 1
	current_progress = float(completed_tasks)
	current_message = "Completed: %s" % task_name
	progress_changed.emit(current_progress, total_progress, current_message)
	print("[LoadingManager] Task completed: %s (%d/%d)" % [task_name, completed_tasks, int(total_progress)])

## Finish loading
func finish_loading() -> void:
	current_progress = total_progress
	current_message = "Loading complete!"
	is_loading = false
	progress_changed.emit(current_progress, total_progress, current_message)
	print("[LoadingManager] Loading finished!")

	# Emit complete signal after a short delay to show 100%
	await get_tree().create_timer(0.5).timeout
	loading_complete.emit()

## Get loading progress as percentage (0-100)
func get_progress_percentage() -> float:
	if total_progress <= 0:
		return 100.0
	return (current_progress / total_progress) * 100.0

## Get current loading message
func get_current_message() -> String:
	return current_message
