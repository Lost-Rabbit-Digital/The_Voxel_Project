# game_world.gd
extends Node3D

@onready var chunk_manager: ChunkManager = $ChunkManager
@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	# Wait a frame for the chunk manager to initialize
	await get_tree().process_frame
	# Initialize starting chunks around origin
	if chunk_manager:
		chunk_manager._ready()  # This will start the generation thread
		chunk_manager.update_chunks(Vector3.ZERO)

func _process(delta: float) -> void:
	# Update chunks based on camera position
	if chunk_manager and camera:
		chunk_manager.update_chunks(camera.global_position)

# Clean up when the scene exits
func _exit_tree() -> void:
	if chunk_manager:
		chunk_manager._exit_tree()  # This will clean up the thread
