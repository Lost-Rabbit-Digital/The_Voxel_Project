class_name ChunkManager
extends Node3D

const RENDER_DISTANCE := 4
const CHUNK_SIZE := 16

var active_chunks: Dictionary = {}
var terrain_generator: TerrainGenerator
var mesh_builder: ChunkMeshBuilder
var material_factory: MaterialFactory

func _init() -> void:
	material_factory = MaterialFactory.new()
	terrain_generator = TerrainGenerator.new()
	mesh_builder = ChunkMeshBuilder.new(material_factory, self)

var last_update_pos: Vector3
const UPDATE_THRESHOLD := 8.0  # Only update chunks when moved this many units

func update_chunks(center_pos: Vector3) -> void:
	# Only update if moved significant distance
	if last_update_pos and center_pos.distance_to(last_update_pos) < UPDATE_THRESHOLD:
		return
		
	var chunk_pos = get_chunk_position(center_pos)
	last_update_pos = center_pos
	
	# Pre-calculate needed chunks
	var needed_chunks := {}
	var chunks_to_remove := []
	
	# Calculate manhattan distance for better performance
	for x in range(-RENDER_DISTANCE, RENDER_DISTANCE + 1):
		for y in range(-2, 3):  # Reduced vertical range
			for z in range(-RENDER_DISTANCE, RENDER_DISTANCE + 1):
				var check_pos = chunk_pos + Vector3(x, y, z)
				var manhattan_dist = abs(x) + abs(y) + abs(z)
				if manhattan_dist <= RENDER_DISTANCE:
					needed_chunks[check_pos] = true
	
	# Remove distant chunks
	for existing_pos in active_chunks.keys():
		if not needed_chunks.has(existing_pos):
			chunks_to_remove.append(existing_pos)
	
	# Process removals in batch
	for pos in chunks_to_remove:
		remove_chunk(pos)
	
	# Add new chunks
	for new_pos in needed_chunks:
		if not active_chunks.has(new_pos):
			create_chunk(new_pos)

func create_chunk(chunk_pos: Vector3) -> void:
	if chunk_pos in active_chunks:
		return
		
	var chunk_data = terrain_generator.generate_chunk_data(chunk_pos)
	if not chunk_data:
		return
		
	var mesh_instance = mesh_builder.build_mesh(chunk_data)
	if not mesh_instance:
		return
		
	mesh_instance.position = chunk_pos * CHUNK_SIZE
	
	active_chunks[chunk_pos] = {
		"data": chunk_data,
		"mesh": mesh_instance
	}
	
	add_child(mesh_instance)

func remove_chunk(chunk_pos: Vector3) -> void:
	if chunk_pos in active_chunks:
		var chunk = active_chunks[chunk_pos]
		if chunk.mesh:
			chunk.mesh.queue_free()
		active_chunks.erase(chunk_pos)

func get_chunk_position(world_pos: Vector3) -> Vector3:
	return Vector3(
		floori(world_pos.x / CHUNK_SIZE),
		floori(world_pos.y / CHUNK_SIZE),
		floori(world_pos.z / CHUNK_SIZE)
	)

func cleanup() -> void:
	for chunk_pos in active_chunks.keys():
		remove_chunk(chunk_pos)
	active_chunks.clear()
