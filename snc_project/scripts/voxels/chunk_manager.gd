class_name ChunkManager
extends Node3D

const RENDER_DISTANCE_HORIZONTAL := 4
const RENDER_DISTANCE_VERTICAL := 2
const MAX_CHUNKS_PER_FRAME := 4  # Limit chunks generated per frame
const CHUNK_GENERATION_BATCH_SIZE = 2  # Process multiple chunks per thread iteration
const CHUNK_LOAD_PRIORITY_DISTANCE := 2  # High priority for chunks very close to player
const CHUNK_UNLOAD_MARGIN := 2  # Extra distance before unloading chunks

const MESH_GENERATION_BATCH_SIZE := 2
const MAX_CONCURRENT_MESH_UPDATES := 4

var chunk_retry_queue: Array[Dictionary] = []
const MAX_RETRY_ATTEMPTS := 3
const CHUNK_TIMEOUT_MS := 100 

var _active_threads: Array[Thread] = []
const MAX_CONCURRENT_THREADS := 4

var retry_count = 0

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

signal mesh_generated(mesh: ArrayMesh, chunk_position: Vector3)

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

func _generate_chunk_threaded(chunk_pos: Vector3) -> void:
	if chunk_pos in active_chunks:
		return
		
	var chunk_data = chunk_cache.load_chunk(chunk_pos)
	if not chunk_data:
		chunk_data = terrain_generator.generate_chunk_data(chunk_pos)
		
	mutex.lock()
	chunks_to_add.append({
		"pos": chunk_pos,
		"data": chunk_data
	})
	mutex.unlock()

func _generate_chunk(chunk_info: Dictionary) -> void:
	if not chunk_info or not chunk_info.has("pos"):
		push_error("Invalid chunk info in _generate_chunk")
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
	
	if chunk_data and is_instance_valid(chunk_data):
		mutex.lock()
		chunks_to_add.append({
			"pos": chunk_pos,
			"data": chunk_data
		})
		mutex.unlock()
		
		if debug_enabled:
			print("Generated chunk at: ", chunk_pos)
	else:
		push_error("Failed to generate chunk data for position: " + str(chunk_pos))
		# Add to retry queue with attempt counter
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
	
	mutex.lock()
	var chunks_to_generate := []
	
	# First, collect all chunks within render distance
	for x in range(-RENDER_DISTANCE_HORIZONTAL, RENDER_DISTANCE_HORIZONTAL + 1):
		for y in range(-RENDER_DISTANCE_VERTICAL, RENDER_DISTANCE_VERTICAL + 1):
			for z in range(-RENDER_DISTANCE_HORIZONTAL, RENDER_DISTANCE_HORIZONTAL + 1):
				var check_pos = player_chunk + Vector3(x, y, z)
				if not active_chunks.has(check_pos) and not _chunk_states.has(check_pos):
					chunks_to_generate.append(check_pos)
	
	# Sort by Manhattan distance for more even loading
	chunks_to_generate.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		var dist_a = abs(a.x - player_chunk.x) + abs(a.y - player_chunk.y) + abs(a.z - player_chunk.z)
		var dist_b = abs(b.x - player_chunk.x) + abs(b.y - player_chunk.y) + abs(b.z - player_chunk.z)
		return dist_a < dist_b
	)
	
	# Clear and repopulate generation queue
	_generation_queue.clear()
	_generation_queue.append_array(chunks_to_generate)
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
		
func _process_chunk_queue() -> void:
	# Clean up completed threads
	_active_threads = _active_threads.filter(func(thread: Thread) -> bool:
		if not thread.is_alive():
			thread.wait_to_finish()
			return false
		return true
	)
	
	# Only start new threads if under limit
	while not _generation_queue.is_empty() and _active_threads.size() < MAX_CONCURRENT_THREADS:
		var chunk_pos = _generation_queue.pop_front()
		var thread = Thread.new()
		thread.start(_generate_chunk_threaded.bind(chunk_pos))
		_active_threads.append(thread)

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
			
		await _finalize_chunk(chunk_info.pos, chunk_info.data)
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
				var h_distance = sqrt(pow(x, 2) + pow(z, 2))
				var v_distance = abs(y)
				
				if h_distance <= RENDER_DISTANCE_HORIZONTAL + 0.5 and \
				   v_distance <= RENDER_DISTANCE_VERTICAL + 0.5:
					needed_chunks[new_chunk_pos] = true
					if not active_chunks.has(new_chunk_pos) and \
					   not _chunk_states.has(new_chunk_pos):
						_queue_chunk_generation(new_chunk_pos, h_distance)
	
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

func _add_chunk_mesh(mesh: ArrayMesh, chunk_pos: Vector3, chunk_data: ChunkData) -> void:
	if not is_instance_valid(mesh) or not is_instance_valid(chunk_data):
		return
		
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material_factory.get_default_material()
	mesh_instance.position = chunk_pos * ChunkData.CHUNK_SIZE
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	
	# Add collision
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(16, 16, 16)
	collision.shape = shape
	var body = StaticBody3D.new()
	body.add_child(collision)
	mesh_instance.add_child(body)
	
	mutex.lock()
	if chunk_pos in active_chunks:
		var existing = active_chunks[chunk_pos]
		if existing.mesh and is_instance_valid(existing.mesh):
			existing.mesh.queue_free()
	
	active_chunks[chunk_pos] = {
		"data": chunk_data,
		"mesh": mesh_instance
	}
	mutex.unlock()
	
	add_child(mesh_instance)

func _finalize_chunk(chunk_pos: Vector3, chunk_data: ChunkData) -> void:
	if not is_instance_valid(chunk_data):
		push_error("Invalid chunk data for position: " + str(chunk_pos))
		return
		
	mutex.lock()
	if chunk_pos in active_chunks:
		var existing_chunk = active_chunks[chunk_pos]
		if existing_chunk.mesh and is_instance_valid(existing_chunk.mesh):
			existing_chunk.mesh.queue_free()
		active_chunks.erase(chunk_pos)
	mutex.unlock()
	
	# Use a simpler retry approach
	_attempt_mesh_generation(chunk_data, chunk_pos, 0)
	

func _attempt_mesh_generation(chunk_data: ChunkData, chunk_pos: Vector3, current_retry: int) -> void:
	mesh_builder.build_mesh_threaded(chunk_data, func(mesh: ArrayMesh, pos: Vector3):
		if not mesh:
			if current_retry < MAX_RETRY_ATTEMPTS:
				print("Retrying mesh generation for chunk: ", chunk_pos, " attempt: ", current_retry + 1)
				# Wait a frame before retrying
				await get_tree().create_timer(0.1).timeout
				_attempt_mesh_generation(chunk_data, chunk_pos, current_retry + 1)
			else:
				push_error("Failed to generate mesh after " + str(MAX_RETRY_ATTEMPTS) + " attempts for chunk: " + str(chunk_pos))
			return
		
		call_deferred("_add_chunk_mesh", mesh, chunk_pos, chunk_data)
	)
	
func _on_mesh_generated(mesh: ArrayMesh, chunk_pos: Vector3, chunk_data: ChunkData) -> void:
	# Create and setup the mesh instance
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material_factory.get_default_material()
	mesh_instance.position = chunk_pos * ChunkData.CHUNK_SIZE
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	
	# Add collision
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(16, 16, 16)
	collision.shape = shape
	var body = StaticBody3D.new()
	body.add_child(collision)
	mesh_instance.add_child(body)
	
	# Update the active chunks dictionary
	if chunk_pos in active_chunks:
		# Remove old mesh if it exists
		if active_chunks[chunk_pos].mesh != null:
			active_chunks[chunk_pos].mesh.queue_free()
			
		active_chunks[chunk_pos] = {
			"data": chunk_data,
			"mesh": mesh_instance
		}
		
		add_child(mesh_instance)
		_update_chunk_neighbors(chunk_pos)

func _update_chunk_neighbors(chunk_pos: Vector3) -> void:
	for offset in [
		Vector3(1, 0, 0), Vector3(-1, 0, 0),
		Vector3(0, 1, 0), Vector3(0, -1, 0),
		Vector3(0, 0, 1), Vector3(0, 0, -1)
	]:
		var neighbor_pos = chunk_pos + offset
		if neighbor_pos in active_chunks:
			var neighbor = active_chunks[neighbor_pos]
			mesh_builder.build_mesh_threaded(neighbor.data, func(mesh: ArrayMesh, pos: Vector3):
				_on_mesh_generated.call_deferred(mesh, neighbor_pos, neighbor.data)
			)

func create_chunk(chunk_pos: Vector3) -> void:
	if chunk_pos in active_chunks:
		return
	
	var chunk_data = terrain_generator.generate_chunk_data(chunk_pos)
	mesh_builder.build_mesh_threaded(chunk_data, func(mesh: ArrayMesh, pos: Vector3):
		_on_mesh_generated.call_deferred(mesh, chunk_pos, chunk_data)
	)
	
	if debug_enabled:
		print("Created chunk at: ", chunk_pos)

func remove_chunk(chunk_pos: Vector3) -> void:
	mutex.lock()
	if chunk_pos in active_chunks:
		var chunk = active_chunks[chunk_pos]
		# Save chunk data to cache before removing
		if is_instance_valid(chunk.data):
			chunk_cache.save_chunk(chunk_pos, chunk.data)
		# Free the mesh instance
		if chunk.mesh and is_instance_valid(chunk.mesh):
			chunk.mesh.queue_free()
		active_chunks.erase(chunk_pos)
	mutex.unlock()
	
	# Clear neighbor cache to force mesh updates
	mesh_builder.clear_neighbor_cache()

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
