# game_world.gd
extends Node3D

@onready var chunk_manager: ChunkManager = $ChunkManager
@onready var camera: Camera3D = $Camera3D
var previous_camera_position = Vector3.ZERO  # Store the camera position from the previous frame

func _ready() -> void:
	# Add debug prints
	print("game_world _ready()")
	print("Camera position:", camera.global_position if camera else "Camera not found")
	print("ChunkManager present:", chunk_manager != null)
	
	# Wait a frame for initialization
	await get_tree().process_frame
	
	if chunk_manager:
		# TEST: Try creating a single test chunk
		#chunk_manager.create_chunk(Vector3.ZERO)
		#print("Initial demo chunk created")
		
		# Set camera to a good starting position to see chunks load
		camera.position = Vector3(0, 32, 0)
		
		# Update chunks around camera
		chunk_manager.update_chunks(camera.global_position)
		print("Initial chunks updated")
		print("Active chunks:", chunk_manager.get_active_chunk_count())
	else:
		print("ERROR: ChunkManager not found!")

func _physics_process(delta):
	var current_camera_position = camera.get_global_position()  # Get current camera position
	if current_camera_position != previous_camera_position and chunk_manager:
		# Camera is moving
		chunk_manager.update_chunks(camera.global_position)
	previous_camera_position = current_camera_position  # Update previous position for next frame

func _exit_tree() -> void:
	if chunk_manager:
		chunk_manager.cleanup()
