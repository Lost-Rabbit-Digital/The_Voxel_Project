class_name ChunkManager
extends Node3D

# Configuration
const RENDER_DISTANCE := 2  # Number of chunks in each direction
const MAX_CHUNKS := 100     # Safety limit for total chunks

var terrain_generator: TerrainGenerator
var mesh_builder: ChunkMeshBuilder
var active_chunks: Dictionary = {}
var debug_enabled: bool = true

func _init() -> void:
	terrain_generator = TerrainGenerator.new()
	mesh_builder = ChunkMeshBuilder.new(MaterialFactory.new(), self)

func generate_initial_chunks() -> void:
	# Start with center chunk
	var center = Vector3.ZERO
	
	# Generate chunks in a square around the center
	for x in range(-RENDER_DISTANCE, RENDER_DISTANCE + 1):
		for z in range(-RENDER_DISTANCE, RENDER_DISTANCE + 1):
			var chunk_pos = Vector3(x, 0, z)
			if active_chunks.size() < MAX_CHUNKS:
				create_chunk(chunk_pos)
				if debug_enabled:
					print("Created initial chunk at: ", chunk_pos)

func get_chunk_at_position(world_pos: Vector3) -> ChunkData:
	var chunk_pos = Vector3(
		floor(world_pos.x / ChunkData.CHUNK_SIZE),
		floor(world_pos.y / ChunkData.CHUNK_SIZE),
		floor(world_pos.z / ChunkData.CHUNK_SIZE)
	)
	
	return active_chunks.get(chunk_pos, {}).get("data")

func create_chunk(chunk_pos: Vector3) -> void:
	if chunk_pos in active_chunks:
		return
	
	var chunk_data = terrain_generator.generate_chunk_data(chunk_pos)
	var mesh_instance = mesh_builder.build_mesh(chunk_data)
	
	if mesh_instance:
		mesh_instance.position = chunk_pos * ChunkData.CHUNK_SIZE
		add_child(mesh_instance)
		active_chunks[chunk_pos] = {
			"data": chunk_data,
			"mesh": mesh_instance
		}
		
		# Update meshes of this chunk and its neighbors
		update_chunk_meshes(chunk_pos)

func update_chunk_meshes(chunk_pos: Vector3) -> void:
	# Update the target chunk
	if chunk_pos in active_chunks:
		var chunk = active_chunks[chunk_pos]
		var new_mesh = mesh_builder.build_mesh(chunk.data)
		if new_mesh:
			chunk.mesh.queue_free()
			chunk.mesh = new_mesh
			chunk.mesh.position = chunk_pos * ChunkData.CHUNK_SIZE
			add_child(chunk.mesh)

	# Update neighboring chunks
	var neighbors = [
		Vector3(1, 0, 0), Vector3(-1, 0, 0),
		Vector3(0, 1, 0), Vector3(0, -1, 0),
		Vector3(0, 0, 1), Vector3(0, 0, -1)
	]
	
	for offset in neighbors:
		var neighbor_pos = chunk_pos + offset
		if neighbor_pos in active_chunks:
			var neighbor = active_chunks[neighbor_pos]
			var new_mesh = mesh_builder.build_mesh(neighbor.data)
			if new_mesh:
				neighbor.mesh.queue_free()
				neighbor.mesh = new_mesh
				neighbor.mesh.position = neighbor_pos * ChunkData.CHUNK_SIZE
				add_child(neighbor.mesh)

func update_chunk_visibility(center_pos: Vector3) -> void:
	# Hide chunks beyond render distance
	for chunk_pos in active_chunks:
		var distance = chunk_pos.distance_to(center_pos)
		if distance <= RENDER_DISTANCE:
			active_chunks[chunk_pos].mesh.visible = true
		else:
			active_chunks[chunk_pos].mesh.visible = false
			# Optionally unload very distant chunks
			if distance > RENDER_DISTANCE * 2:
				active_chunks[chunk_pos].mesh.queue_free()
				active_chunks.erase(chunk_pos)
