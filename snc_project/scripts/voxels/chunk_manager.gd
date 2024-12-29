class_name ChunkManager
extends Node3D

const RENDER_DISTANCE_HORIZONTAL := 4
const RENDER_DISTANCE_VERTICAL := 2
const MAX_CHUNKS_PER_FRAME := 4  # Limit chunks generated per frame
const CHUNK_GENERATION_BATCH_SIZE = 2  # Process multiple chunks per thread iteration

var chunk_retry_queue: Array[Dictionary] = []
const MAX_RETRY_ATTEMPTS := 3
const CHUNK_TIMEOUT_MS := 100 

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
var chunk_cache: ChunkCache
var save_chunks_timer: Timer

func _init() -> void:
	terrain_generator = TerrainGenerator.new()
	mesh_builder = ChunkMeshBuilder.new(MaterialFactory.new(), self)
	mutex = Mutex.new()
	generation_thread = Thread.new()
	chunk_cache = ChunkCache.new()
	
	# Setup autosave timer
	save_chunks_timer = Timer.new()
	save_chunks_timer.wait_time = 30.0  # Save chunks every 30 seconds
	save_chunks_timer.timeout.connect(_on_save_chunks_timer_timeout)
	add_child(save_chunks_timer)
	save_chunks_timer.start()

func _on_save_chunks_timer_timeout() -> void:
	# Save all active chunks to cache
	for chunk_pos in active_chunks:
		var chunk = active_chunks[chunk_pos]
		chunk_cache.save_chunk(chunk_pos, chunk.data)

func _ready() -> void:
	# Start the generation thread
	thread_running = true
	generation_thread.start(_thread_function)

func _exit_tree() -> void:
	# Save all chunks before exiting
	for chunk_pos in active_chunks:
		var chunk = active_chunks[chunk_pos]
		chunk_cache.save_chunk(chunk_pos, chunk.data)
	
	# Clean up thread
	thread_running = false
	generation_thread.wait_to_finish()
	
	# Clean old cache files
	chunk_cache.clean_cache()
	
func _thread_function() -> void:
	while thread_running:
		mutex.lock()
		var current_queue = chunk_generation_queue.slice(0, CHUNK_GENERATION_BATCH_SIZE - 1)
		chunk_generation_queue = chunk_generation_queue.slice(CHUNK_GENERATION_BATCH_SIZE)
		mutex.unlock()
		
		var batch_results = []
		for chunk_pos in current_queue:
			if not thread_running:
				break
				
			if chunk_pos in active_chunks:
				continue
			
			# Try to load from cache first
			var chunk_data = chunk_cache.load_chunk(chunk_pos)
			
			# If not in cache, generate new
			if not chunk_data:
				chunk_data = terrain_generator.generate_chunk_data(chunk_pos)
			
			if chunk_data:
				batch_results.append({
					"pos": chunk_pos,
					"data": chunk_data
				})
			else:
				# If generation failed, re-queue with lower priority
				mutex.lock()
				chunk_generation_queue.append(chunk_pos)
				mutex.unlock()
		
		if not batch_results.is_empty():
			mutex.lock()
			chunks_to_add.append_array(batch_results)
			mutex.unlock()
		
		OS.delay_msec(5)

func _process(_delta: float) -> void:
	# Clean up expired retry attempts
	chunk_retry_queue = chunk_retry_queue.filter(func(chunk): return chunk.retries < MAX_RETRY_ATTEMPTS)
	
	# Process queued chunks
	mutex.lock()
	var chunks_to_process = chunks_to_add.duplicate()
	chunks_to_add.clear()
	mutex.unlock()
	
	# Sort by distance and process
	chunks_to_process.sort_custom(func(a, b): 
		var manhattan_dist_a = abs(a.pos.x - last_center_chunk.x) + abs(a.pos.y - last_center_chunk.y) + abs(a.pos.z - last_center_chunk.z)
		var manhattan_dist_b = abs(b.pos.x - last_center_chunk.x) + abs(b.pos.y - last_center_chunk.y) + abs(b.pos.z - last_center_chunk.z)
		return manhattan_dist_a < manhattan_dist_b
	)
	
	var chunks_added := 0
	for chunk_info in chunks_to_process:
		if chunks_added >= MAX_CHUNKS_PER_FRAME:
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
	
	# Calculate needed chunks using spherical distance
	var chunks_to_generate = []
	for x in range(-RENDER_DISTANCE_HORIZONTAL, RENDER_DISTANCE_HORIZONTAL + 1):
		for y in range(-RENDER_DISTANCE_VERTICAL, RENDER_DISTANCE_VERTICAL + 1):
			for z in range(-RENDER_DISTANCE_HORIZONTAL, RENDER_DISTANCE_HORIZONTAL + 1):
				var new_chunk_pos = chunk_pos + Vector3(x, y, z)
				var distance = new_chunk_pos.distance_to(chunk_pos)
				
				# Add a small buffer to ensure complete coverage
				if distance <= RENDER_DISTANCE_HORIZONTAL + 0.5:
					chunks_to_generate.append({
						"pos": new_chunk_pos,
						"distance": distance
					})
	
	# Sort by exact distance for more uniform loading
	chunks_to_generate.sort_custom(func(a, b): return a.distance < b.distance)
	
	# Track needed chunks
	var needed_chunks := {}
	for chunk in chunks_to_generate:
		needed_chunks[chunk.pos] = true
	
	# Remove out-of-range chunks
	for existing_chunk_pos in active_chunks.keys():
		if not needed_chunks.has(existing_chunk_pos):
			remove_chunk(existing_chunk_pos)
	
	# Update generation queue
	mutex.lock()
	chunk_generation_queue.clear()  # Start fresh
	
	# First add chunks adjacent to existing chunks
	for chunk in chunks_to_generate:
		if not active_chunks.has(chunk.pos):
			var has_neighbor = false
			for offset in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
				if active_chunks.has(chunk.pos + offset):
					has_neighbor = true
					break
			if has_neighbor:
				chunk_generation_queue.append(chunk.pos)
	
	# Then add remaining chunks
	for chunk in chunks_to_generate:
		if not active_chunks.has(chunk.pos) and not chunk.pos in chunk_generation_queue:
			chunk_generation_queue.append(chunk.pos)
	
	mutex.unlock()

func _finalize_chunk(chunk_pos: Vector3, chunk_data: ChunkData) -> void:
	# If chunk already exists, remove it first
	if chunk_pos in active_chunks:
		var existing_chunk = active_chunks[chunk_pos]
		existing_chunk.mesh.queue_free()
		active_chunks.erase(chunk_pos)
		
	var mesh_instance = mesh_builder.build_mesh(chunk_data)
	if mesh_instance:
		mesh_instance.position = chunk_pos * ChunkData.CHUNK_SIZE
		add_child(mesh_instance)
		active_chunks[chunk_pos] = {
			"data": chunk_data,
			"mesh": mesh_instance
		}
		
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
		# Save chunk data to cache before removing
		chunk_cache.save_chunk(chunk_pos, chunk.data)
		# Free the mesh instance
		if chunk.mesh:
			chunk.mesh.queue_free()
		active_chunks.erase(chunk_pos)
		# Clear neighbor cache to force mesh updates
		mesh_builder.clear_neighbor_cache()
		if debug_enabled:
			print("Removed chunk at: ", chunk_pos)

func get_active_chunk_count() -> int:
	return active_chunks.size()

func get_chunk_position(world_pos: Vector3) -> Vector3:
	return Vector3(
		floor(world_pos.x / ChunkData.CHUNK_SIZE),
		floor(world_pos.y / ChunkData.CHUNK_SIZE),
		floor(world_pos.z / ChunkData.CHUNK_SIZE)
	)

func get_chunk_at_position(world_pos: Vector3) -> ChunkData:
	var chunk_pos = get_chunk_position(world_pos)
	return active_chunks.get(chunk_pos, {}).get("data")
