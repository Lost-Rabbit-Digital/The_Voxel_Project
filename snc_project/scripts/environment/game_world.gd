extends Node3D

@onready var chunk_manager: ChunkManager = $ChunkManager
@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	# Initialize the world with a controlled number of chunks
	chunk_manager.generate_initial_chunks()

func _process(_delta: float) -> void:
	# Get camera position in chunk coordinates
	var camera_chunk_pos = Vector3(
		floor(camera.position.x / ChunkData.CHUNK_SIZE),
		floor(camera.position.y / ChunkData.CHUNK_SIZE),
		floor(camera.position.z / ChunkData.CHUNK_SIZE)
	)
	
	# Update chunk visibility based on camera position
	chunk_manager.update_chunk_visibility(camera_chunk_pos)
