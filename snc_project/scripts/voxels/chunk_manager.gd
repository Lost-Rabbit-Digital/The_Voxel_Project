class_name ChunkManager
extends Node3D

const RENDER_DISTANCE_HORIZONTAL := 4
const RENDER_DISTANCE_VERTICAL := 2
const MAX_CHUNKS_PER_FRAME := 4  # Limit chunks generated per frame
const CHUNK_GENERATION_BATCH_SIZE = 2  # Process multiple chunks per thread iteration
const CHUNK_LOAD_PRIORITY_DISTANCE := 2  # High priority for chunks very close to player
const CHUNK_UNLOAD_MARGIN := 2  # Extra distance before unloading chunks

var chunk_retry_queue: Array[Dictionary] = []
const MAX_RETRY_ATTEMPTS := 3
const CHUNK_TIMEOUT_MS := 100 

var terrain_generator: TerrainGenerator
var mesh_builder: ChunkMeshBuilder
var active_chunks: Dictionary = {}
var _generation_queue: Array = []
var debug_enabled: bool = true
var last_center_chunk := Vector3.ZERO
var generation_thread: Thread
var mutex: Mutex
var thread_running := false
var chunks_to_add: Array = []
var chunk_cache: ChunkCache
var save_chunks_timer: Timer

var _generation_semaphore := Semaphore.new()
var _exit_thread := false
var material_factory: MaterialFactory

# Chunk loading states
enum ChunkState { QUEUED, GENERATING, READY, FAILED }
var _chunk_states: Dictionary = {}

# Priority queue for chunk generation
var _chunk_priorities: Dictionary = {}

func _init() -> void:
	# Initialize variables once
	mutex = Mutex.new()
	active_chunks = {}
	chunk_retry_queue = []
	_generation_queue = []
	chunks_to_add = []
	_chunk_states = {}
	_generation_queue = []
	_chunk_priorities = {}
	debug_enabled = true
	
	# Initialize core components once
	material_factory = MaterialFactory.new()
	terrain_generator = TerrainGenerator.new()
	chunk_cache = ChunkCache.new()
	mesh_builder = ChunkMeshBuilder.new(material_factory, self)

func _ready() -> void:
	# Start generation thread
	generation_thread = Thread.new()
	thread_running = true
	generation_thread.start(_thread_function)
	

func _get_debug_info() -> String:
	var info = ""
	info += "Active chunks: %d\n" % active_chunks.size()
	info += "Generation queue: %d\n" % _generation_queue.size()
	info += "Thread running: %s\n" % str(thread_running)
	return info

func _generate_chunk(chunk_info: Dictionary) -> void:
	if not chunk_info:
		return
		
	var chunk_pos: Vector3 = chunk_info.pos
	
	# Skip if chunk already exists
	if chunk_pos in active_chunks:
		return
	
	# Try to load from cache first
	var chunk_data = chunk_cache.load_chunk(chunk_pos)
	
	# If not in cache, generate new chunk
	if not chunk_data:
		chunk_data = terrain_generator.generate_chunk_data(chunk_pos)
	
	if chunk_data:
		mutex.lock()
		chunks_to_add.append({
			"pos": chunk_pos,
			"data": chunk_data
		})
		mutex.unlock()
		
		if debug_enabled:
			print("Generated chunk at: ", chunk_pos)
	else:
		# If generation failed, add to retry queue with attempt counter
		mutex.lock()
		chunk_retry_queue.append({
			"pos": chunk_pos,
			"retries": 0,
			"timestamp": Time.get_ticks_msec()
		})
		mutex.unlock()

func _chunk_generation_thread() -> void:
	while not _exit_thread:
		_generation_semaphore.wait()
		if _exit_thread:
			break
			
		var chunk_info = _get_next_chunk_to_generate()
		if chunk_info:
			_generate_chunk(chunk_info)

func _get_next_chunk_to_generate() -> Dictionary:
	mutex.lock()
	var result = null
	if not _generation_queue.is_empty():
		result = _generation_queue.pop_front()
	mutex.unlock()
	return result

func _on_save_chunks_timer_timeout() -> void:
	# Save all active chunks to cache
	for chunk_pos in active_chunks:
		var chunk = active_chunks[chunk_pos]
		chunk_cache.save_chunk(chunk_pos, chunk.data)

func _update_chunk_priorities(player_pos: Vector3) -> void:
	var player_chunk = get_chunk_position(player_pos)
	
	# Update priorities for all queued chunks
	mutex.lock()
	for chunk_info in _generation_queue:
		var pos: Vector3 = chunk_info.pos
		var distance = pos.distance_to(player_chunk)
		var priority = _calculate_chunk_priority(distance)
		chunk_info.priority = priority
	
	# Sort queue by priority
	_generation_queue.sort_custom(func(a, b): return a.priority > b.priority)
	mutex.unlock()

func _calculate_chunk_priority(distance: float) -> float:
	# Higher priority for closer chunks
	if distance <= CHUNK_LOAD_PRIORITY_DISTANCE:
		return 1000.0 - distance  # Highest priority
	return 100.0 - distance  # Normal priority

func cleanup() -> void:
	thread_running = false
	_exit_thread = true
	
func _thread_function() -> void:
	print("Thread started")
	while thread_running:
		#print("Thread iteration, queue size: ", _generation_queue.size())
		mutex.lock()
		var current_queue = _generation_queue.slice(0, CHUNK_GENERATION_BATCH_SIZE - 1)
		_generation_queue = _generation_queue.slice(CHUNK_GENERATION_BATCH_SIZE)
		mutex.unlock()
		
		var batch_results = []
		for chunk_pos in current_queue:
			if not thread_running:
				print("Thread not running, break.")
				break
				
			if chunk_pos in active_chunks:
				print("Chunk in active chunks")
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
				_generation_queue.append(chunk_pos)
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
	_update_chunk_priorities(center_pos)
	
	# Calculate needed chunks using spherical distance
	var needed_chunks := {}
	for x in range(-RENDER_DISTANCE_HORIZONTAL - CHUNK_UNLOAD_MARGIN, 
				   RENDER_DISTANCE_HORIZONTAL + CHUNK_UNLOAD_MARGIN + 1):
		for y in range(-RENDER_DISTANCE_VERTICAL - CHUNK_UNLOAD_MARGIN,
					   RENDER_DISTANCE_VERTICAL + CHUNK_UNLOAD_MARGIN + 1):
			for z in range(-RENDER_DISTANCE_HORIZONTAL - CHUNK_UNLOAD_MARGIN,
						   RENDER_DISTANCE_HORIZONTAL + CHUNK_UNLOAD_MARGIN + 1):
				var new_chunk_pos = chunk_pos + Vector3(x, y, z)
				#print("New chunk position acquired: ", new_chunk_pos)
				var distance = new_chunk_pos.distance_to(chunk_pos)
				
				if distance <= RENDER_DISTANCE_HORIZONTAL + 0.5:
					needed_chunks[new_chunk_pos] = true
					if not active_chunks.has(new_chunk_pos) and \
					   not _chunk_states.has(new_chunk_pos):
						_queue_chunk_generation(new_chunk_pos, distance)
	
	# Remove out-of-range chunks
	for existing_chunk_pos in active_chunks.keys():
		if not needed_chunks.has(existing_chunk_pos):
			remove_chunk(existing_chunk_pos)

func _queue_chunk_generation(chunk_pos: Vector3, distance: float) -> void:
	mutex.lock()
	print("Queueing chunk: ", chunk_pos)  # Debug print
	if not _chunk_states.has(chunk_pos):
		# Are we using _generation_queue or _generation_queue?
		_generation_queue.append(chunk_pos)  # This might be wrong
		_chunk_states[chunk_pos] = ChunkState.QUEUED
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
