class_name ChunkManager
extends Node3D

const RENDER_DISTANCE_HORIZONTAL := 4
const RENDER_DISTANCE_VERTICAL := 2
const MAX_CHUNKS_PER_FRAME := 2  # Limit chunks generated per frame

var terrain_generator: TerrainGenerator
var mesh_builder: ChunkMeshBuilder
var active_chunks: Dictionary = {}
var chunk_generation_queue: Array[Vector3] = []
var debug_enabled: bool = true
var last_center_chunk := Vector3.ZERO
var generation_thread: Thread
var mutex: Mutex
var thread_running := false
var chunks_to_add: Array = []

func _init() -> void:
	terrain_generator = TerrainGenerator.new()
	mesh_builder = ChunkMeshBuilder.new(MaterialFactory.new(), self)
	mutex = Mutex.new()
	generation_thread = Thread.new()

func _ready() -> void:
	# Start the generation thread
	thread_running = true
	generation_thread.start(_thread_function)

func _exit_tree() -> void:
	# Clean up thread on exit
	thread_running = false
	generation_thread.wait_to_finish()

func _thread_function() -> void:
	while thread_running:
		mutex.lock()
		var current_queue = chunk_generation_queue.duplicate()
		chunk_generation_queue.clear()
		mutex.unlock()
		
		for chunk_pos in current_queue:
			if not thread_running:
				break
				
			if chunk_pos in active_chunks:
				continue
				
			var chunk_data = terrain_generator.generate_chunk_data(chunk_pos)
			
			mutex.lock()
			chunks_to_add.append({"pos": chunk_pos, "data": chunk_data})
			mutex.unlock()
			
			OS.delay_msec(1)  # Prevent thread from hogging CPU

func _process(_delta: float) -> void:
	# Process queued chunks
	mutex.lock()
	var chunks_to_process = chunks_to_add.duplicate()
	chunks_to_add.clear()
	mutex.unlock()
	
	var chunks_added := 0
	for chunk_info in chunks_to_process:
		if chunks_added >= MAX_CHUNKS_PER_FRAME:
			# Re-queue remaining chunks
			mutex.lock()
			chunks_to_add.append_array(chunks_to_process.slice(chunks_added))
			mutex.unlock()
			break
			
		_finalize_chunk(chunk_info.pos, chunk_info.data)
		chunks_added += 1

func update_chunks(center_pos: Vector3) -> void:
	var chunk_pos = get_chunk_position(center_pos)
	
	if chunk_pos == last_center_chunk:
		return
	
	last_center_chunk = chunk_pos
	
	# Calculate needed chunks
	var needed_chunks := {}
	for x in range(-RENDER_DISTANCE_HORIZONTAL, RENDER_DISTANCE_HORIZONTAL + 1):
		for y in range(-RENDER_DISTANCE_VERTICAL, RENDER_DISTANCE_VERTICAL + 1):
			for z in range(-RENDER_DISTANCE_HORIZONTAL, RENDER_DISTANCE_HORIZONTAL + 1):
				var new_chunk_pos = chunk_pos + Vector3(x, y, z)
				if new_chunk_pos.distance_to(chunk_pos) <= RENDER_DISTANCE_HORIZONTAL:
					needed_chunks[new_chunk_pos] = true
	
	# Queue new chunks for generation
	mutex.lock()
	for new_pos in needed_chunks:
		if not active_chunks.has(new_pos) and not new_pos in chunk_generation_queue:
			chunk_generation_queue.append(new_pos)
	mutex.unlock()
	
	# Remove far chunks
	var to_remove := []
	for existing_pos in active_chunks:
		if not needed_chunks.has(existing_pos):
			to_remove.append(existing_pos)
	
	for pos in to_remove:
		remove_chunk(pos)

func _finalize_chunk(chunk_pos: Vector3, chunk_data: ChunkData) -> void:
	if chunk_pos in active_chunks:
		return
		
	var mesh_instance = mesh_builder.build_mesh(chunk_data)
	if mesh_instance:
		mesh_instance.position = chunk_pos * ChunkData.CHUNK_SIZE
		add_child(mesh_instance)
		active_chunks[chunk_pos] = {
			"data": chunk_data,
			"mesh": mesh_instance
		}
		
		# Update neighbors
		call_deferred("_update_chunk_neighbors", chunk_pos)

func _update_chunk_neighbors(chunk_pos: Vector3) -> void:
	var neighbors = [
		Vector3(1, 0, 0), Vector3(-1, 0, 0),
		Vector3(0, 1, 0), Vector3(0, -1, 0),
		Vector3(0, 0, 1), Vector3(0, 0, -1)
	]
	
	for offset in neighbors:
		var neighbor_pos = chunk_pos + offset
		if neighbor_pos in active_chunks:
			# Rebuild neighbor's mesh to update face culling
			var neighbor = active_chunks[neighbor_pos]
			var new_mesh = mesh_builder.build_mesh(neighbor.data)
			if new_mesh:
				neighbor.mesh.queue_free()
				neighbor.mesh = new_mesh
				neighbor.mesh.position = neighbor_pos * ChunkData.CHUNK_SIZE
				add_child(neighbor.mesh)

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
		if debug_enabled:
			print("Created chunk at: ", chunk_pos)

func remove_chunk(chunk_pos: Vector3) -> void:
	if chunk_pos in active_chunks:
		var chunk = active_chunks[chunk_pos]
		chunk.mesh.queue_free()
		active_chunks.erase(chunk_pos)
		if debug_enabled:
			print("Removed chunk at: ", chunk_pos)

func get_chunk_position(world_pos: Vector3) -> Vector3:
	return Vector3(
		floor(world_pos.x / ChunkData.CHUNK_SIZE),
		floor(world_pos.y / ChunkData.CHUNK_SIZE),
		floor(world_pos.z / ChunkData.CHUNK_SIZE)
	)

func get_chunk_at_position(world_pos: Vector3) -> ChunkData:
	var chunk_pos = get_chunk_position(world_pos)
	return active_chunks.get(chunk_pos, {}).get("data")
