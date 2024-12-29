class_name ChunkManager
extends Node3D

var terrain_generator: TerrainGenerator
var mesh_builder: ChunkMeshBuilder
var active_chunks: Dictionary = {}

func _init() -> void:
	terrain_generator = TerrainGenerator.new()
	mesh_builder = ChunkMeshBuilder.new(MaterialFactory.new())

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

func update_chunk(chunk_pos: Vector3) -> void:
	if not chunk_pos in active_chunks:
		return
		
	var chunk = active_chunks[chunk_pos]
	if chunk.data.needs_remesh:
		var new_mesh = mesh_builder.build_mesh(chunk.data)
		if new_mesh:
			chunk.mesh.queue_free()
			chunk.mesh = new_mesh
			chunk.mesh.position = chunk_pos * ChunkData.CHUNK_SIZE
			add_child(chunk.mesh)
			chunk.data.needs_remesh = false
