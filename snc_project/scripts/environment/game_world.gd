extends Node3D

@onready var chunk_manager: ChunkManager = $ChunkManager

func _ready() -> void:
	# Create initial chunks around origin
	for x in range(-2, 3):
		for z in range(-2, 3):
			chunk_manager.create_chunk(Vector3(x, 0, z))

func _on_player_moved(new_position: Vector3) -> void:
	# Convert player position to chunk coordinates
	var chunk_pos = Vector3(
		floor(new_position.x / ChunkData.CHUNK_SIZE),
		floor(new_position.y / ChunkData.CHUNK_SIZE),
		floor(new_position.z / ChunkData.CHUNK_SIZE)
	)
	
	# Load new chunks as needed
	chunk_manager.create_chunk(chunk_pos)
