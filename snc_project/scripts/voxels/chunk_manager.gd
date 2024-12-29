class_name ChunkManager
extends Node3D

# Configuration
const RENDER_DISTANCE := 5  # Number of chunks in each direction
const MAX_CHUNKS := 100     # Safety limit for total chunks

# Components
var terrain_generator: TerrainGenerator
var mesh_builder: ChunkMeshBuilder
var active_chunks: Dictionary = {}
var debug_enabled: bool = true

func _init() -> void:
	terrain_generator = TerrainGenerator.new()
	mesh_builder = ChunkMeshBuilder.new(MaterialFactory.new())

func _ready() -> void:
	# Initialize starting chunks in a controlled manner
	generate_initial_chunks()

func generate_initial_chunks() -> void:
	# Start with just the center chunk and immediate neighbors
	var center = Vector3.ZERO
	var chunks_to_generate = [center]
	
	# Add immediate neighbors (6 directions)
	for x in range(-1, 2):
		for z in range(-1, 2):
			var pos = Vector3(x, 0, z)
			if pos != Vector3.ZERO:  # Skip center chunk as it's already included
				chunks_to_generate.append(pos)
	
	# Generate chunks in a controlled order
	for chunk_pos in chunks_to_generate:
		if active_chunks.size() < MAX_CHUNKS:
			create_single_chunk(chunk_pos)

func create_single_chunk(chunk_pos: Vector3) -> void:
	if chunk_pos in active_chunks:
		return
	
	if debug_enabled:
		print("Creating chunk at: ", chunk_pos)
	
	var chunk_data = terrain_generator.generate_chunk_data(chunk_pos)
	var mesh_instance = mesh_builder.build_mesh(chunk_data)
	
	if mesh_instance:
		mesh_instance.position = chunk_pos * ChunkData.CHUNK_SIZE
		add_child(mesh_instance)
		active_chunks[chunk_pos] = {
			"data": chunk_data,
			"mesh": mesh_instance
		}

func get_chunk_at_position(world_pos: Vector3) -> ChunkData:
	var chunk_pos = Vector3(
		floor(world_pos.x / ChunkData.CHUNK_SIZE),
		floor(world_pos.y / ChunkData.CHUNK_SIZE),
		floor(world_pos.z / ChunkData.CHUNK_SIZE)
	)
	
	return active_chunks.get(chunk_pos, {}).get("data")

func is_chunk_loaded(chunk_pos: Vector3) -> bool:
	return chunk_pos in active_chunks

func unload_distant_chunks(center_pos: Vector3) -> void:
	var chunks_to_remove = []
	
	for chunk_pos in active_chunks:
		var distance = chunk_pos.distance_to(center_pos)
		if distance > RENDER_DISTANCE:
			chunks_to_remove.append(chunk_pos)
	
	for chunk_pos in chunks_to_remove:
		if chunk_pos in active_chunks:
			var chunk = active_chunks[chunk_pos]
			chunk.mesh.queue_free()
			active_chunks.erase(chunk_pos)
			if debug_enabled:
				print("Unloaded chunk at: ", chunk_pos)

func update_chunk_visibility(center_pos: Vector3) -> void:
	# Hide chunks beyond render distance
	for chunk in active_chunks.values():
		var distance = (chunk.mesh.position / ChunkData.CHUNK_SIZE).distance_to(center_pos)
		chunk.mesh.visible = distance <= RENDER_DISTANCE
