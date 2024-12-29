# game_world.gd
extends Node3D

@onready var chunk_manager: ChunkManager = $ChunkManager
@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	# Add debug prints
	print("game_world _ready()")
	print("Camera position:", camera.global_position if camera else "Camera not found")
	print("ChunkManager present:", chunk_manager != null)
	
	# Wait a frame for initialization
	await get_tree().process_frame
	
	if chunk_manager:
		# Try creating a single test chunk
		chunk_manager.create_chunk(Vector3.ZERO)
		print("Initial chunk created")
		
		# Update chunks around camera
		chunk_manager.update_chunks(camera.global_position)
		print("Initial chunks updated")
		print("Active chunks:", chunk_manager.get_active_chunk_count())
	else:
		print("ERROR: ChunkManager not found!")

func _process(_delta: float) -> void:
	if chunk_manager and camera:
		chunk_manager.update_chunks(camera.global_position)

func _exit_tree() -> void:
	if chunk_manager:
		chunk_manager.cleanup()
