## ChunkThreadPool - Manages worker threads for chunk generation and meshing
## Offloads CPU-intensive operations from the main thread to prevent stuttering
class_name ChunkThreadPool
extends RefCounted

## Job types
enum JobType {
	GENERATE_TERRAIN,  ## Generate terrain data for a chunk
	BUILD_MESH,        ## Build mesh for a chunk
	BUILD_REGION_MESH  ## Build combined mesh for a region (batched chunks)
}

## Job data structure
class ChunkJob extends RefCounted:
	var job_type: JobType
	var chunk_pos: Vector3i
	var priority: float = 0.0
	var chunk: Chunk = null
	var region = null  # For region mesh building jobs
	var region_pos: Vector3i = Vector3i.ZERO  # For region mesh building jobs
	var terrain_generator = null
	var mesh_builder = null
	var result = null
	var completed: bool = false
	var error: String = ""

## Configuration
var worker_count: int = 4
var max_jobs_per_frame: int = 8

## Worker threads
var workers: Array[Thread] = []
var worker_running: Array[bool] = []

## Job queues (shared between threads - requires mutex)
var pending_jobs: Array[ChunkJob] = []
var completed_jobs: Array[ChunkJob] = []

## Thread synchronization
var jobs_mutex: Mutex = Mutex.new()
var should_exit: bool = false

## Statistics
var stats_jobs_queued: int = 0
var stats_jobs_completed: int = 0
var stats_generation_jobs: int = 0
var stats_meshing_jobs: int = 0
var stats_active_workers: int = 0

func _init(num_workers: int = 4) -> void:
	worker_count = num_workers
	print("[ChunkThreadPool] Initializing with %d workers..." % worker_count)

	# Start worker threads
	_start_workers()

	print("[ChunkThreadPool] Thread pool ready with %d workers" % worker_count)

## Start all worker threads
func _start_workers() -> void:
	for i in range(worker_count):
		var thread := Thread.new()
		var error := thread.start(_worker_thread_function.bind(i))

		if error == OK:
			workers.append(thread)
			worker_running.append(true)
			print("[ChunkThreadPool]   Worker %d started" % i)
		else:
			print("[ChunkThreadPool]   ERROR: Failed to start worker %d: %d" % [i, error])

## Worker thread main loop
func _worker_thread_function(worker_id: int) -> void:
	print("[ChunkThreadPool] Worker %d running" % worker_id)

	while true:
		# Check if we should exit
		jobs_mutex.lock()
		var should_stop := should_exit
		jobs_mutex.unlock()

		if should_stop:
			break

		# Get next job from queue
		var job: ChunkJob = null

		jobs_mutex.lock()
		if pending_jobs.size() > 0:
			# OPTIMIZATION: Don't sort every time! Jobs are inserted in priority order.
			# Just take the first job (highest priority already at front)
			job = pending_jobs.pop_front()
		jobs_mutex.unlock()

		# Process job if we got one
		if job:
			_process_job(job, worker_id)

			# Add to completed queue
			jobs_mutex.lock()
			completed_jobs.append(job)
			stats_jobs_completed += 1
			jobs_mutex.unlock()
		else:
			# No jobs available, sleep briefly to avoid busy-waiting
			# OPTIMIZATION: Could use semaphore here, but 1ms is acceptable for now
			OS.delay_msec(1)

	print("[ChunkThreadPool] Worker %d exiting" % worker_id)

## Process a single job
func _process_job(job: ChunkJob, worker_id: int) -> void:
	match job.job_type:
		JobType.GENERATE_TERRAIN:
			_process_generation_job(job, worker_id)
		JobType.BUILD_MESH:
			_process_meshing_job(job, worker_id)
		JobType.BUILD_REGION_MESH:
			_process_region_rebuild_job(job, worker_id)

## Process terrain generation job
func _process_generation_job(job: ChunkJob, worker_id: int) -> void:
	if not job.terrain_generator:
		job.error = "No terrain generator provided"
		job.completed = true
		return

	# Generate terrain data (thread-safe - noise generation is stateless)
	var voxel_data: VoxelData = job.terrain_generator.generate_chunk(job.chunk_pos)

	job.result = voxel_data
	job.completed = true

## Process mesh building job
func _process_meshing_job(job: ChunkJob, worker_id: int) -> void:
	if not job.mesh_builder or not job.chunk:
		job.error = "No mesh builder or chunk provided"
		job.completed = true
		return

	# Build mesh data (thread-safe - reads chunk data without modification)
	# Note: We build the mesh data but don't create MeshInstance3D (that must be on main thread)
	var mesh_data: Dictionary = job.mesh_builder.build_mesh_data(job.chunk)

	job.result = mesh_data
	job.completed = true

## Process region mesh building job
## This builds the combined mesh arrays for a region on a worker thread
func _process_region_rebuild_job(job: ChunkJob, worker_id: int) -> void:
	if not job.mesh_builder or not job.region:
		job.error = "No mesh builder or region provided"
		job.completed = true
		return

	var region = job.region
	var mesh_builder = job.mesh_builder

	# Build combined mesh arrays on worker thread
	# This is the expensive operation we want to offload from main thread
	var combined_arrays: Array = []
	combined_arrays.resize(Mesh.ARRAY_MAX)

	# Initialize arrays
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var vertex_offset := 0
	var total_chunks_processed := 0
	var cache_hits := 0
	var cache_misses := 0

	# Get chunks from region (thread-safe since we're just reading)
	var chunks_snapshot := region.chunks.values()

	# Process each chunk in the region
	for chunk in chunks_snapshot:
		# Skip invalid or empty chunks
		if not chunk or not is_instance_valid(chunk) or chunk.is_empty():
			continue

		# Skip chunks that aren't fully ready
		if chunk.state != Chunk.State.ACTIVE:
			continue

		# Use cached mesh arrays if available (MAJOR OPTIMIZATION)
		var chunk_arrays: Array = []
		if not chunk.cached_mesh_arrays.is_empty():
			# Cache hit - use pre-built arrays (FAST!)
			chunk_arrays = chunk.cached_mesh_arrays
			cache_hits += 1
		else:
			# Cache miss - build mesh arrays and cache them (SLOW!)
			chunk_arrays = mesh_builder.build_mesh_arrays(chunk)
			chunk.cached_mesh_arrays = chunk_arrays
			cache_misses += 1

		if chunk_arrays.is_empty():
			continue

		# Get the arrays from the chunk mesh data (handle null values)
		var chunk_vertices: PackedVector3Array = chunk_arrays[Mesh.ARRAY_VERTEX] if (chunk_arrays.size() > Mesh.ARRAY_VERTEX and chunk_arrays[Mesh.ARRAY_VERTEX] != null) else PackedVector3Array()
		var chunk_normals: PackedVector3Array = chunk_arrays[Mesh.ARRAY_NORMAL] if (chunk_arrays.size() > Mesh.ARRAY_NORMAL and chunk_arrays[Mesh.ARRAY_NORMAL] != null) else PackedVector3Array()
		var chunk_colors: PackedColorArray = chunk_arrays[Mesh.ARRAY_COLOR] if (chunk_arrays.size() > Mesh.ARRAY_COLOR and chunk_arrays[Mesh.ARRAY_COLOR] != null) else PackedColorArray()
		var chunk_uvs: PackedVector2Array = chunk_arrays[Mesh.ARRAY_TEX_UV] if (chunk_arrays.size() > Mesh.ARRAY_TEX_UV and chunk_arrays[Mesh.ARRAY_TEX_UV] != null) else PackedVector2Array()
		var chunk_indices: PackedInt32Array = chunk_arrays[Mesh.ARRAY_INDEX] if (chunk_arrays.size() > Mesh.ARRAY_INDEX and chunk_arrays[Mesh.ARRAY_INDEX] != null) else PackedInt32Array()

		if chunk_vertices.is_empty():
			continue

		# Offset vertices by chunk position (relative to region origin)
		var chunk_offset: Vector3 = chunk.get_world_position() - region.get_region_world_position()

		for i in range(chunk_vertices.size()):
			vertices.append(chunk_vertices[i] + chunk_offset)

		# Append normals
		normals.append_array(chunk_normals)

		# Append colors
		colors.append_array(chunk_colors)

		# Append UVs
		uvs.append_array(chunk_uvs)

		# Append indices (with vertex offset applied)
		for idx in chunk_indices:
			indices.append(idx + vertex_offset)

		vertex_offset += chunk_vertices.size()
		total_chunks_processed += 1

	# Build the combined arrays - only include arrays that have proper data
	if not vertices.is_empty():
		combined_arrays[Mesh.ARRAY_VERTEX] = vertices

		# Only include normals if we have them for all vertices
		if normals.size() == vertices.size():
			combined_arrays[Mesh.ARRAY_NORMAL] = normals

		# Only include colors if we have them for all vertices
		if colors.size() == vertices.size():
			combined_arrays[Mesh.ARRAY_COLOR] = colors

		# Only include UVs if we have them for all vertices
		if uvs.size() == vertices.size():
			combined_arrays[Mesh.ARRAY_TEX_UV] = uvs

		# Always include indices if we have them
		if not indices.is_empty():
			combined_arrays[Mesh.ARRAY_INDEX] = indices

	# Store results
	job.result = {
		"combined_arrays": combined_arrays,
		"vertex_count": vertices.size(),
		"chunk_count": total_chunks_processed,
		"cache_hits": cache_hits,
		"cache_misses": cache_misses
	}
	job.completed = true

## Queue a terrain generation job
func queue_generation_job(chunk_pos: Vector3i, terrain_generator, priority: float = 0.0) -> void:
	var job := ChunkJob.new()
	job.job_type = JobType.GENERATE_TERRAIN
	job.chunk_pos = chunk_pos
	job.terrain_generator = terrain_generator
	job.priority = priority

	jobs_mutex.lock()
	# OPTIMIZATION: Insert job in priority order to avoid sorting on every fetch
	_insert_job_sorted(job)
	stats_jobs_queued += 1
	stats_generation_jobs += 1
	jobs_mutex.unlock()

## Queue a mesh building job
func queue_meshing_job(chunk: Chunk, mesh_builder, priority: float = 0.0) -> void:
	var job := ChunkJob.new()
	job.job_type = JobType.BUILD_MESH
	job.chunk_pos = chunk.position
	job.chunk = chunk
	job.mesh_builder = mesh_builder
	job.priority = priority

	jobs_mutex.lock()
	# OPTIMIZATION: Insert job in priority order to avoid sorting on every fetch
	_insert_job_sorted(job)
	stats_jobs_queued += 1
	stats_meshing_jobs += 1
	jobs_mutex.unlock()

## Queue a region mesh building job
func queue_region_rebuild_job(region, region_pos: Vector3i, mesh_builder, priority: float = 0.0) -> void:
	var job := ChunkJob.new()
	job.job_type = JobType.BUILD_REGION_MESH
	job.region_pos = region_pos
	job.region = region
	job.mesh_builder = mesh_builder
	job.priority = priority

	jobs_mutex.lock()
	# OPTIMIZATION: Insert job in priority order to avoid sorting on every fetch
	_insert_job_sorted(job)
	stats_jobs_queued += 1
	jobs_mutex.unlock()

## Insert job in priority order (higher priority at front)
## O(n) insertion is much better than O(n log n) sorting on every fetch
func _insert_job_sorted(job: ChunkJob) -> void:
	# Find insertion point using binary search for O(log n) insertion
	var left := 0
	var right := pending_jobs.size()

	while left < right:
		var mid := (left + right) / 2
		if pending_jobs[mid].priority < job.priority:
			right = mid
		else:
			left = mid + 1

	pending_jobs.insert(left, job)

## Get completed jobs (call from main thread)
func get_completed_jobs(max_count: int = -1) -> Array[ChunkJob]:
	var jobs: Array[ChunkJob] = []

	jobs_mutex.lock()

	if max_count < 0:
		max_count = completed_jobs.size()

	var count := mini(max_count, completed_jobs.size())
	for i in range(count):
		jobs.append(completed_jobs.pop_front())

	jobs_mutex.unlock()

	return jobs

## Process completed jobs (call from main thread each frame)
func process_completed_jobs(callback: Callable, max_per_frame: int = -1) -> int:
	if max_per_frame < 0:
		max_per_frame = max_jobs_per_frame

	var completed := get_completed_jobs(max_per_frame)

	for job in completed:
		callback.call(job)

	return completed.size()

## Get number of pending jobs
func get_pending_job_count() -> int:
	jobs_mutex.lock()
	var count := pending_jobs.size()
	jobs_mutex.unlock()
	return count

## Get number of completed jobs waiting to be processed
func get_completed_job_count() -> int:
	jobs_mutex.lock()
	var count := completed_jobs.size()
	jobs_mutex.unlock()
	return count

## Clear all pending jobs
func clear_pending_jobs() -> void:
	jobs_mutex.lock()
	pending_jobs.clear()
	jobs_mutex.unlock()

## Get statistics
func get_stats() -> Dictionary:
	jobs_mutex.lock()
	var pending_count := pending_jobs.size()
	var completed_count := completed_jobs.size()
	jobs_mutex.unlock()

	return {
		"worker_count": worker_count,
		"pending_jobs": pending_count,
		"completed_jobs": completed_count,
		"total_queued": stats_jobs_queued,
		"total_completed": stats_jobs_completed,
		"generation_jobs": stats_generation_jobs,
		"meshing_jobs": stats_meshing_jobs
	}

## Print statistics
func print_stats() -> void:
	var stats := get_stats()
	print("========================================")
	print("[ChunkThreadPool] Statistics:")
	print("  Workers: %d" % stats.worker_count)
	print("  Pending Jobs: %d" % stats.pending_jobs)
	print("  Completed Jobs: %d" % stats.completed_jobs)
	print("  Total Queued: %d" % stats.total_queued)
	print("  Total Completed: %d" % stats.total_completed)
	print("  Generation Jobs: %d" % stats.generation_jobs)
	print("  Meshing Jobs: %d" % stats.meshing_jobs)
	print("========================================")

## Shutdown thread pool (call before freeing)
func shutdown() -> void:
	print("[ChunkThreadPool] Shutting down thread pool...")

	# Signal workers to exit
	jobs_mutex.lock()
	should_exit = true
	jobs_mutex.unlock()

	# Wait for all workers to finish
	for i in range(workers.size()):
		if workers[i].is_alive():
			workers[i].wait_to_finish()
			print("[ChunkThreadPool]   Worker %d stopped" % i)

	workers.clear()
	worker_running.clear()

	# Clear job queues
	jobs_mutex.lock()
	pending_jobs.clear()
	completed_jobs.clear()
	jobs_mutex.unlock()

	print("[ChunkThreadPool] Thread pool shutdown complete")

## Destructor - ensure threads are stopped
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if not should_exit:
			shutdown()
