## ChunkManager - Manages chunk lifecycle, pooling, and spatial queries
## Responsible for loading/unloading chunks based on player position
## Uses object pooling to minimize garbage collection pressure
##
## Threading Model:
## - Terrain generation: Always threaded (worker threads via ChunkThreadPool)
## - Mesh building:
##   - Region batching ENABLED (default): Fully threaded
##     Individual chunks build mesh arrays on worker threads
##     Region mesh combining also happens on worker threads
##     Only final mesh instance creation happens on main thread
##   - Region batching DISABLED: Threaded via ChunkThreadPool
##     Each chunk gets its own mesh built on worker thread
class_name ChunkManager
extends Node3D

## Signals
signal initial_chunks_ready()  # Emitted once when first batch of chunks is visible

## Configuration
@export var render_distance: int = 8
@export var vertical_render_distance: int = 4
@export var enable_pooling: bool = true
@export var pool_size: int = 128
@export var enable_chunk_cache: bool = true
@export var cache_size_limit_mb: int = 500
@export var enable_threading: bool = true
@export var worker_thread_count: int = 4
@export var max_jobs_per_frame: int = 4  # Process fewer jobs per frame to reduce main thread blocking
@export var enable_region_batching: bool = true  # Enable region-based mesh batching

## Minimum chunks to consider "initial load" complete
const INITIAL_CHUNKS_THRESHOLD: int = 10

## Tracking for initial load
var _initial_chunks_ready: bool = false

## Active chunks in the world (Vector3i chunk_pos -> Chunk)
var active_chunks: Dictionary = {}

## Chunk object pool for reuse
var chunk_pool: Array[Chunk] = []

## Chunks pending loading (Vector3i -> priority)
var load_queue: Array[Vector3i] = []

## Chunks currently being generated (Vector3i -> true)
var generating_chunks: Dictionary = {}

## Chunks currently being meshed (Vector3i -> Chunk)
var meshing_chunks: Dictionary = {}

## Region-based rendering (Vector3i region_pos -> ChunkRegion)
var active_regions: Dictionary = {}

## Regions that need mesh rebuilding
var dirty_regions: Dictionary = {}  # Vector3i -> true

## Regions currently being rebuilt (to avoid duplicate jobs)
var rebuilding_regions: Dictionary = {}  # Vector3i -> true

## Maximum regions to rebuild per frame (adaptive based on performance)
var max_region_rebuilds_per_frame: int = 4  # Start conservative, will adapt
const MIN_REGION_REBUILDS_PER_FRAME: int = 1  # Never go below this
const MAX_REGION_REBUILDS_PER_FRAME: int = 8  # Never go above this
const TARGET_FRAME_TIME_MS: float = 16.0  # Target 60 FPS

## Chunks pending neighbor mesh rebuild (Vector3i -> true) - batched to avoid duplicates
var pending_neighbor_rebuilds: Dictionary = {}

## Last player position used for chunk updates
var last_update_position: Vector3 = Vector3.ZERO

## Distance threshold before triggering chunk update
const UPDATE_THRESHOLD: float = 8.0

## Maximum chunks to load per frame (prevents stuttering)
const MAX_CHUNKS_PER_FRAME: int = 4  # Match region rebuild rate to avoid bottleneck

## Maximum pending jobs in thread pool before we stop queuing new chunks
const MAX_PENDING_JOBS: int = 32  # Don't overwhelm the workers

## References to other systems (set by VoxelWorld)
var terrain_generator = null
var mesh_builder = null
var chunk_cache: ChunkCache = null
var thread_pool: ChunkThreadPool = null
var occlusion_culler: OcclusionCuller = null

## Statistics
var stats_active_chunks: int = 0
var stats_pooled_chunks: int = 0
var stats_chunks_generated: int = 0
var stats_chunks_meshed: int = 0

func _ready() -> void:
	print("[ChunkManager] _ready() called")
	print("[ChunkManager] Configuration:")
	print("  - render_distance: %d" % render_distance)
	print("  - vertical_render_distance: %d" % vertical_render_distance)
	print("  - enable_pooling: %s" % enable_pooling)
	print("  - pool_size: %d" % pool_size)
	print("  - enable_chunk_cache: %s" % enable_chunk_cache)
	print("  - cache_size_limit_mb: %d MB" % cache_size_limit_mb)
	print("  - enable_threading: %s" % enable_threading)
	print("  - worker_thread_count: %d" % worker_thread_count)

	# Initialize VoxelTypes registry
	print("[ChunkManager] Initializing VoxelTypes registry...")
	VoxelTypes.initialize()
	print("[ChunkManager] VoxelTypes initialized with %d block types" % VoxelTypes.Type.size())

	# Initialize thread pool for async chunk generation
	if enable_threading:
		print("[ChunkManager] Initializing thread pool...")
		thread_pool = ChunkThreadPool.new(worker_thread_count)
		thread_pool.max_jobs_per_frame = max_jobs_per_frame
		print("[ChunkManager] Thread pool initialized with %d workers" % worker_thread_count)

	# Initialize chunk cache (seed will be set by VoxelWorld)
	if enable_chunk_cache:
		print("[ChunkManager] Initializing chunk cache...")
		chunk_cache = ChunkCache.new(0, true)
		chunk_cache.max_cache_size_mb = cache_size_limit_mb
		print("[ChunkManager] Chunk cache initialized")

	# Pre-populate chunk pool
	if enable_pooling:
		print("[ChunkManager] Pre-populating chunk pool with %d chunks..." % pool_size)
		for i in range(pool_size):
			chunk_pool.append(Chunk.new())
		stats_pooled_chunks = chunk_pool.size()
		print("[ChunkManager] Chunk pool ready: %d chunks" % stats_pooled_chunks)
	else:
		print("[ChunkManager] Chunk pooling disabled")

	# Initialize occlusion culler
	print("[ChunkManager] Initializing occlusion culler...")
	occlusion_culler = OcclusionCuller.new(self)
	occlusion_culler.mode = OcclusionCuller.Mode.FLOOD_FILL
	print("[ChunkManager] Occlusion culler initialized")

	# Print adaptive chunk sizing configuration
	print("[ChunkManager] Adaptive chunk sizing enabled:")
	ChunkHeightZones.print_zone_config()

	print("[ChunkManager] Ready!")

## Update chunks based on player position
## Only updates if player has moved significantly
func update_chunks(player_position: Vector3, camera_forward: Vector3 = Vector3.FORWARD) -> void:
	# Always update stats even if we don't recalculate chunks
	stats_active_chunks = active_chunks.size()
	stats_pooled_chunks = chunk_pool.size()

	# Check if we need to update chunk loading
	var distance := last_update_position.distance_to(player_position)
	if distance < UPDATE_THRESHOLD:
		# Still process any pending chunks from the load queue
		_process_load_queue()
		return

	last_update_position = player_position
	tracked_position = player_position

	# Get player's chunk position
	var player_chunk_pos := world_to_chunk_position(player_position)

	# Determine which chunks should be loaded
	var needed_chunks: Dictionary = {}
	_calculate_needed_chunks(player_chunk_pos, needed_chunks)

	# Remove chunks that are too far
	_unload_distant_chunks(needed_chunks)

	# Load new chunks with prioritization
	_load_new_chunks_prioritized(needed_chunks, player_position, camera_forward)

	# Update stats
	stats_active_chunks = active_chunks.size()
	stats_pooled_chunks = chunk_pool.size()

## Process completed threaded jobs each frame
func _process(delta: float) -> void:
	if thread_pool:
		# Process completed jobs
		thread_pool.process_completed_jobs(_on_job_completed, max_jobs_per_frame)

	# Process batched neighbor rebuilds (prevents duplicate rebuilds in same frame)
	_process_pending_neighbor_rebuilds()

	# Rebuild dirty regions if region batching is enabled
	if enable_region_batching:
		_process_dirty_regions()

## Handle completed job from thread pool
func _on_job_completed(job) -> void:
	if job.job_type == ChunkThreadPool.JobType.GENERATE_TERRAIN:
		_on_generation_completed(job)
	elif job.job_type == ChunkThreadPool.JobType.BUILD_MESH:
		_on_meshing_completed(job)
	elif job.job_type == ChunkThreadPool.JobType.BUILD_REGION_MESH:
		_on_region_rebuild_completed(job)

## Handle completed terrain generation job
func _on_generation_completed(job) -> void:
	var chunk_pos: Vector3i = job.chunk_pos

	# Remove from generating set
	generating_chunks.erase(chunk_pos)

	# Check for errors
	if job.error:
		push_error("[ChunkManager] Generation error for chunk %s: %s" % [chunk_pos, job.error])
		return

	# Get generated voxel data
	var voxel_data: VoxelData = job.result
	if not voxel_data:
		return

	# Check if chunk is empty
	if voxel_data.is_empty():
		return

	# Create chunk and set data
	var chunk := _get_chunk_from_pool()
	chunk.initialize(chunk_pos)
	chunk.voxel_data = voxel_data
	chunk.state = Chunk.State.GENERATING
	stats_chunks_generated += 1

	# Add to active chunks
	active_chunks[chunk_pos] = chunk

	# Update neighbor references
	_update_chunk_neighbors(chunk_pos, chunk)

	# Handle meshing based on batching mode
	if enable_region_batching:
		# Region batching mode: Queue mesh array building on worker thread
		# This is CRITICAL - we must NOT block the main thread
		chunk.state = Chunk.State.MESHING
		meshing_chunks[chunk_pos] = chunk

		if thread_pool and mesh_builder:
			var priority: float = 1.0 / max(tracked_position.distance_to(chunk.get_world_position()), 1.0)
			thread_pool.queue_meshing_job(chunk, mesh_builder, priority)
		else:
			# Fallback to synchronous meshing (should not happen with threading enabled)
			chunk.cached_mesh_arrays = mesh_builder.build_mesh_arrays(chunk)
			chunk.state = Chunk.State.ACTIVE
			stats_chunks_meshed += 1
			_add_chunk_to_region(chunk)
			_check_initial_chunks_ready()
	else:
		# Traditional mode: Build individual chunk mesh (potentially threaded)
		chunk.state = Chunk.State.MESHING
		meshing_chunks[chunk_pos] = chunk

		if thread_pool:
			var priority: float = 1.0 / max(tracked_position.distance_to(chunk.get_world_position()), 1.0)
			thread_pool.queue_meshing_job(chunk, mesh_builder, priority)
		else:
			# Fallback to synchronous meshing
			_build_chunk_mesh_sync(chunk)

## Handle completed mesh building job
func _on_meshing_completed(job) -> void:
	var chunk_pos: Vector3i = job.chunk_pos

	# Remove from meshing set
	var chunk: Chunk = meshing_chunks.get(chunk_pos)
	meshing_chunks.erase(chunk_pos)

	if not chunk:
		return

	# CRITICAL: Check if chunk is still valid (might have been freed during async meshing)
	if not is_instance_valid(chunk):
		# Chunk was unloaded while mesh was being built - discard the mesh
		return

	# Check for errors
	if job.error:
		push_error("[ChunkManager] Meshing error for chunk %s: %s" % [chunk_pos, job.error])
		return

	# Get mesh data
	var mesh_data: Dictionary = job.result
	if mesh_data.is_empty():
		return

	# Handle mesh creation based on batching mode
	if enable_region_batching:
		# Region batching mode: Cache the mesh arrays for fast region rebuilding
		# Extract arrays from mesh_data if available
		if mesh_data.has("arrays") and mesh_data.arrays is Array:
			chunk.cached_mesh_arrays = mesh_data.arrays

		# Activate chunk
		chunk.state = Chunk.State.ACTIVE
		stats_chunks_meshed += 1

		# Add chunk to region (will use cached arrays)
		_add_chunk_to_region(chunk)

		# Check if initial chunks are ready
		_check_initial_chunks_ready()
	else:
		# Traditional mode: Create individual mesh instance per chunk
		# Get old mesh instance if this is a rebuild
		var old_mesh: MeshInstance3D = null
		if chunk.has_meta("old_mesh_instance"):
			var meta_mesh = chunk.get_meta("old_mesh_instance")
			# CRITICAL: Validate the mesh instance - it might have been freed!
			if meta_mesh and is_instance_valid(meta_mesh):
				old_mesh = meta_mesh
			else:
				# Stale reference - clean it up
				chunk.remove_meta("old_mesh_instance")

		var mesh_instance: MeshInstance3D = mesh_builder.create_mesh_instance_from_data(mesh_data)
		if mesh_instance:
			chunk.mesh_instance = mesh_instance
			mesh_instance.position = chunk.get_world_position()
			add_child(mesh_instance)
			stats_chunks_meshed += 1

		# Now remove old mesh after new one is visible (prevents flashing)
		if old_mesh and is_instance_valid(old_mesh):
			remove_child(old_mesh)
			old_mesh.queue_free()
			chunk.remove_meta("old_mesh_instance")

		# Activate chunk
		chunk.state = Chunk.State.ACTIVE

		# Add chunk to region (if somehow needed)
		_add_chunk_to_region(chunk)

	# Mark occlusion graph as dirty (new chunk added)
	if occlusion_culler:
		occlusion_culler.mark_graph_dirty()

	# Only rebuild neighbors if this was a new chunk load, not a neighbor rebuild
	var is_rebuild: bool = chunk.get_meta("is_rebuild", false)
	if not is_rebuild:
		_rebuild_neighbor_meshes(chunk_pos)

## Handle completed region mesh building job
func _on_region_rebuild_completed(job) -> void:
	var region_pos: Vector3i = job.region_pos

	# Remove from rebuilding set
	rebuilding_regions.erase(region_pos)

	# Remove from dirty regions
	dirty_regions.erase(region_pos)

	# Check for errors
	if job.error:
		push_error("[ChunkManager] Region rebuild error for region %s: %s" % [region_pos, job.error])
		return

	# Get region
	if not region_pos in active_regions:
		# Region was unloaded while being rebuilt
		return

	var region: ChunkRegion = active_regions[region_pos]
	if not region or not is_instance_valid(region):
		# Region was freed
		return

	# Get result data
	var result: Dictionary = job.result
	if not result or result.is_empty():
		# No mesh data - region might be empty
		region.is_dirty = false
		return

	var combined_arrays: Array = result.get("combined_arrays", [])
	if combined_arrays.is_empty() or combined_arrays[Mesh.ARRAY_VERTEX] == null:
		# No geometry - region is empty
		region.is_dirty = false
		return

	# Create the mesh on the main thread (must be done here, not on worker thread)
	# Clear existing mesh
	if region.mesh_instance:
		region.remove_child(region.mesh_instance)
		region.mesh_instance.queue_free()
		region.mesh_instance = null

	# Create ArrayMesh
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, combined_arrays)

	# Create MeshInstance3D
	region.mesh_instance = MeshInstance3D.new()
	region.mesh_instance.mesh = array_mesh

	# Apply material if available
	if region.material:
		region.mesh_instance.material_override = region.material

	# Position at region origin
	region.mesh_instance.position = Vector3.ZERO  # Vertices are already offset

	# Add to scene
	region.add_child(region.mesh_instance)

	# Update region stats
	region.vertex_count = result.get("vertex_count", 0)
	region.chunk_count = result.get("chunk_count", 0)
	region.is_dirty = false

	# Log performance stats
	var cache_hits: int = result.get("cache_hits", 0)
	var cache_misses: int = result.get("cache_misses", 0)
	var total_chunks: int = result.get("chunk_count", 0)
	var cache_hit_rate := (cache_hits * 100.0 / total_chunks) if total_chunks > 0 else 0.0

	# Only log if there were cache misses (indicates first-time builds)
	if cache_misses > 0 or total_chunks > 15:
		print("[ChunkRegion] Region %s: %d chunks (%d vertices), cache: %d hits/%d misses (%.0f%% hit rate) [ASYNC]" % [
			region_pos, total_chunks, region.vertex_count,
			cache_hits, cache_misses, cache_hit_rate
		])

## Tracked position for priority calculations (set by update_chunks)
var tracked_position: Vector3 = Vector3.ZERO

## Update frustum culling for all active chunks
## Shows/hides chunks based on camera frustum visibility
## Also applies occlusion culling if enabled
func update_frustum_culling(camera: Camera3D) -> void:
	if not camera:
		return

	var frustum := camera.get_frustum()

	# Update occlusion culling first
	if occlusion_culler and occlusion_culler.mode != OcclusionCuller.Mode.DISABLED:
		occlusion_culler.update_visibility(camera.global_position, active_chunks)

	# Region batching mode: Cull at region level
	if enable_region_batching:
		_update_region_culling(frustum)
	else:
		# Traditional mode: Cull individual chunks
		_update_chunk_culling(frustum)

## Update culling for regions (batched mode)
func _update_region_culling(frustum: Array[Plane]) -> void:
	var visible_count := 0
	var hidden_count := 0

	for region in active_regions.values():
		if not region or not region.mesh_instance:
			continue

		# Get region AABB
		var aabb: AABB = region.get_aabb()

		# Check frustum visibility
		var is_frustum_visible := _aabb_intersects_frustum(aabb, frustum)

		# For regions, occlusion culling is less useful (regions are large)
		# We'll keep it simple and only use frustum culling at region level

		# Update visibility
		if region.mesh_instance.visible != is_frustum_visible:
			region.mesh_instance.visible = is_frustum_visible

		if is_frustum_visible:
			visible_count += 1
		else:
			hidden_count += 1

## Update culling for individual chunks (traditional mode)
func _update_chunk_culling(frustum: Array[Plane]) -> void:
	var frustum_visible_count := 0
	var frustum_hidden_count := 0
	var occlusion_hidden_count := 0

	for chunk in active_chunks.values():
		if not chunk or not chunk.mesh_instance:
			continue

		# Get chunk AABB
		var aabb: AABB = chunk.get_aabb()

		# Check frustum visibility
		var is_frustum_visible := _aabb_intersects_frustum(aabb, frustum)

		# Check occlusion visibility (if enabled)
		var is_occluded := false
		if occlusion_culler and occlusion_culler.mode != OcclusionCuller.Mode.DISABLED:
			is_occluded = not occlusion_culler.is_chunk_visible(chunk.position)

		# Final visibility = frustum visible AND not occluded
		var is_visible := is_frustum_visible and not is_occluded

		# Update visibility
		if chunk.mesh_instance.visible != is_visible:
			chunk.mesh_instance.visible = is_visible

		# Track stats
		if is_frustum_visible:
			frustum_visible_count += 1
			if is_occluded:
				occlusion_hidden_count += 1
		else:
			frustum_hidden_count += 1

	# Optionally log culling stats (can be disabled for performance)
	# print("[ChunkManager] Culling: %d frustum visible, %d frustum hidden, %d occluded" % [frustum_visible_count, frustum_hidden_count, occlusion_hidden_count])

## Check if an AABB intersects with a camera frustum
func _aabb_intersects_frustum(aabb: AABB, frustum: Array[Plane]) -> bool:
	# Test AABB against each frustum plane
	for plane in frustum:
		var p := aabb.position
		var s := aabb.size

		# Calculate the n-vertex (nearest point to the plane)
		# This is the corner of the AABB closest to the plane
		var n_vertex := Vector3(
			p.x + (0 if plane.normal.x > 0 else s.x),
			p.y + (0 if plane.normal.y > 0 else s.y),
			p.z + (0 if plane.normal.z > 0 else s.z)
		)

		# If the nearest vertex is outside the plane, the entire AABB is outside
		if plane.is_point_over(n_vertex):
			return false

	# AABB intersects or is inside the frustum
	return true

## Calculate which chunks should be loaded based on render distance
func _calculate_needed_chunks(center_pos: Vector3i, result: Dictionary) -> void:
	var rd := render_distance
	var vrd := vertical_render_distance

	for x in range(-rd, rd + 1):
		for y in range(-vrd, vrd + 1):
			for z in range(-rd, rd + 1):
				var offset := Vector3i(x, y, z)
				var chunk_pos := center_pos + offset

				# Use manhattan distance for circular loading pattern
				var manhattan_dist := absi(x) + absi(y) + absi(z)
				if manhattan_dist <= rd:
					result[chunk_pos] = true

## Unload chunks that are too far from player
func _unload_distant_chunks(needed_chunks: Dictionary) -> void:
	var chunks_to_remove: Array[Vector3i] = []

	for chunk_pos in active_chunks.keys():
		if not needed_chunks.has(chunk_pos):
			chunks_to_remove.append(chunk_pos)

	for chunk_pos in chunks_to_remove:
		unload_chunk(chunk_pos)

## Load chunks that aren't loaded yet (old version, kept for compatibility)
func _load_new_chunks(needed_chunks: Dictionary) -> void:
	for chunk_pos in needed_chunks.keys():
		if not active_chunks.has(chunk_pos):
			load_chunk(chunk_pos)

## Load chunks with prioritization based on camera direction and distance
func _load_new_chunks_prioritized(needed_chunks: Dictionary, player_position: Vector3, camera_forward: Vector3) -> void:
	# Find chunks that need to be loaded
	var chunks_to_load: Array[Vector3i] = []
	for chunk_pos in needed_chunks.keys():
		if not active_chunks.has(chunk_pos):
			chunks_to_load.append(chunk_pos)

	# If no chunks to load, clear queue and return
	if chunks_to_load.is_empty():
		load_queue.clear()
		return

	# Calculate priority for each chunk
	var chunk_priorities: Array[Dictionary] = []
	for chunk_pos in chunks_to_load:
		var priority := _calculate_chunk_priority(chunk_pos, player_position, camera_forward)
		chunk_priorities.append({
			"pos": chunk_pos,
			"priority": priority
		})

	# Sort by priority (higher priority first)
	chunk_priorities.sort_custom(func(a, b): return a.priority > b.priority)

	# Load the highest priority chunks immediately (up to MAX_CHUNKS_PER_FRAME)
	var loaded_count := 0
	load_queue.clear()

	for i in range(chunk_priorities.size()):
		var chunk_data: Dictionary = chunk_priorities[i]
		var chunk_pos: Vector3i = chunk_data.pos

		if loaded_count < MAX_CHUNKS_PER_FRAME:
			load_chunk(chunk_pos)
			loaded_count += 1
		else:
			# Add remaining chunks to queue for next frame
			load_queue.append(chunk_pos)

## Process pending chunks from the load queue
func _process_load_queue() -> void:
	if load_queue.is_empty():
		return

	# CRITICAL: Don't overwhelm the thread pool!
	# If workers are backed up, don't queue more chunks
	if thread_pool and thread_pool.get_pending_job_count() > MAX_PENDING_JOBS:
		return

	var loaded_count := 0
	var chunks_to_remove: Array[Vector3i] = []

	for chunk_pos in load_queue:
		# Skip if already loaded or being processed
		if chunk_pos in active_chunks or chunk_pos in generating_chunks or chunk_pos in meshing_chunks:
			chunks_to_remove.append(chunk_pos)
			continue

		# Load chunk
		load_chunk(chunk_pos)
		chunks_to_remove.append(chunk_pos)
		loaded_count += 1

		# Limit chunks per frame
		if loaded_count >= MAX_CHUNKS_PER_FRAME:
			break

		# Stop if thread pool is getting full
		if thread_pool and thread_pool.get_pending_job_count() > MAX_PENDING_JOBS:
			break

	# Remove loaded chunks from queue
	for chunk_pos in chunks_to_remove:
		load_queue.erase(chunk_pos)

	# Log queue progress periodically
	if load_queue.size() > 100 and loaded_count > 0:
		var pending_jobs := thread_pool.get_pending_job_count() if thread_pool else 0
		print("[ChunkManager] Load queue: %d chunks remaining, %d pending jobs" % [load_queue.size(), pending_jobs])

## Calculate priority for a chunk based on distance and camera direction
## Higher priority = should be loaded sooner
func _calculate_chunk_priority(chunk_pos: Vector3i, player_position: Vector3, camera_forward: Vector3) -> float:
	# Get chunk center in world space
	var chunk_world_pos := Vector3(chunk_pos * VoxelData.CHUNK_SIZE) + Vector3.ONE * (VoxelData.CHUNK_SIZE * 0.5)

	# Calculate distance from player (inverse priority - closer is higher)
	var distance := player_position.distance_to(chunk_world_pos)
	var distance_priority: float = 1.0 / max(distance, 1.0)  # Avoid division by zero

	# Calculate direction from player to chunk
	var to_chunk := (chunk_world_pos - player_position).normalized()

	# Calculate dot product with camera forward (1.0 = directly ahead, -1.0 = directly behind)
	var direction_alignment := camera_forward.dot(to_chunk)

	# Boost priority for chunks in front of camera
	var direction_priority: float = max(direction_alignment, 0.0)  # 0.0 to 1.0

	# Combined priority (weighted sum)
	# Distance is more important (weight 2.0), direction is secondary (weight 1.0)
	var priority: float = (distance_priority * 2.0) + (direction_priority * 1.0)

	return priority

## Load a single chunk at the given position
func load_chunk(chunk_pos: Vector3i) -> Chunk:
	# Check if already loaded, generating, or meshing
	if chunk_pos in active_chunks:
		return active_chunks[chunk_pos]

	if chunk_pos in generating_chunks or chunk_pos in meshing_chunks:
		return null  # Already being processed

	# Try threading path first
	if thread_pool and terrain_generator:
		return _load_chunk_threaded(chunk_pos)
	else:
		# Fallback to synchronous loading
		return _load_chunk_sync(chunk_pos)

## Load chunk using threaded path
func _load_chunk_threaded(chunk_pos: Vector3i) -> Chunk:
	# CRITICAL: Don't overwhelm the thread pool!
	# If we have too many pending jobs, skip loading this chunk for now
	if thread_pool and thread_pool.get_pending_job_count() > MAX_PENDING_JOBS:
		return null

	# Try to load from cache first
	var chunk: Chunk = null

	if chunk_cache and chunk_cache.has_cached_chunk(chunk_pos):
		chunk = chunk_cache.load_chunk(chunk_pos)
		if chunk:
			# Cached chunk loaded - skip generation, go straight to meshing
			active_chunks[chunk_pos] = chunk
			_update_chunk_neighbors(chunk_pos, chunk)

			# Queue mesh building
			chunk.state = Chunk.State.MESHING
			meshing_chunks[chunk_pos] = chunk
			var priority: float = 1.0 / max(tracked_position.distance_to(chunk.get_world_position()), 1.0)
			thread_pool.queue_meshing_job(chunk, mesh_builder, priority)
			return chunk

	# Not cached - queue terrain generation
	generating_chunks[chunk_pos] = true
	var priority: float = 1.0 / max(tracked_position.distance_to(Vector3(chunk_pos * VoxelData.CHUNK_SIZE_XZ)), 1.0)
	thread_pool.queue_generation_job(chunk_pos, terrain_generator, priority)
	return null

## Load chunk synchronously (fallback when threading disabled)
func _load_chunk_sync(chunk_pos: Vector3i) -> Chunk:
	# Try to load from cache first
	var chunk: Chunk = null
	var loaded_from_cache := false

	if chunk_cache and chunk_cache.has_cached_chunk(chunk_pos):
		chunk = chunk_cache.load_chunk(chunk_pos)
		if chunk:
			loaded_from_cache = true

	# If not cached, create new chunk and generate terrain
	if not chunk:
		# Get chunk from pool or create new
		chunk = _get_chunk_from_pool()
		chunk.initialize(chunk_pos)
		chunk.state = Chunk.State.GENERATING

		# Generate terrain data
		if terrain_generator:
			chunk.voxel_data = terrain_generator.generate_chunk(chunk_pos)
			stats_chunks_generated += 1
		else:
			print("[ChunkManager]   WARNING: No terrain generator, using test pattern")
			_generate_test_chunk(chunk)

	# Skip empty chunks
	if chunk.is_empty():
		# print("[ChunkManager]   Chunk is empty, returning to pool")
		_return_chunk_to_pool(chunk)
		return null

	# Add to active chunks first (before neighbor updates)
	active_chunks[chunk_pos] = chunk

	# Update neighbor references BEFORE building mesh
	# This allows proper face culling at chunk boundaries
	# print("[ChunkManager]   Updating neighbor references...")
	_update_chunk_neighbors(chunk_pos, chunk)

	# Generate mesh
	chunk.state = Chunk.State.MESHING
	if mesh_builder:
		# Only create individual mesh instances if region batching is disabled
		if not enable_region_batching:
			var mesh_instance: MeshInstance3D = mesh_builder.build_mesh(chunk)
			if mesh_instance:
				chunk.mesh_instance = mesh_instance
				mesh_instance.position = chunk.get_world_position()
				add_child(mesh_instance)
				stats_chunks_meshed += 1

	# Activate chunk
	chunk.state = Chunk.State.ACTIVE

	# Add chunk to region (if region batching enabled)
	if enable_region_batching:
		_add_chunk_to_region(chunk)

	# Mark occlusion graph as dirty (new chunk added)
	if occlusion_culler:
		occlusion_culler.mark_graph_dirty()

	# Rebuild neighbor meshes to remove faces that are now hidden by this chunk
	_rebuild_neighbor_meshes(chunk_pos)

	# Reduce console spam
	# print("[ChunkManager] ✓ Chunk %s loaded successfully" % chunk_pos)
	return chunk

## Build chunk mesh synchronously
func _build_chunk_mesh_sync(chunk: Chunk) -> void:
	if not mesh_builder or not chunk:
		return

	var mesh_instance: MeshInstance3D = mesh_builder.build_mesh(chunk)
	if mesh_instance:
		chunk.mesh_instance = mesh_instance
		mesh_instance.position = chunk.get_world_position()
		add_child(mesh_instance)
		stats_chunks_meshed += 1

	chunk.state = Chunk.State.ACTIVE
	meshing_chunks.erase(chunk.position)

	# Check if initial chunks are ready
	_check_initial_chunks_ready()

	# Rebuild neighbor meshes to remove faces that are now hidden by this chunk
	_rebuild_neighbor_meshes(chunk.position)

## Unload a chunk at the given position
func unload_chunk(chunk_pos: Vector3i) -> void:
	if chunk_pos not in active_chunks:
		return

	var chunk: Chunk = active_chunks[chunk_pos]
	chunk.state = Chunk.State.UNLOADING

	# Save to cache before unloading (if not empty)
	if chunk_cache and not chunk.is_empty():
		if not chunk_cache.is_cache_full():
			chunk_cache.save_chunk(chunk)
			# print("[ChunkManager]   Saved chunk to cache")
		# else:
		# 	print("[ChunkManager]   WARNING: Cache is full, not saving chunk")

	# Remove chunk from region (if region batching enabled)
	if enable_region_batching:
		_remove_chunk_from_region(chunk_pos)

	# Remove mesh from scene (only if region batching disabled)
	if not enable_region_batching and chunk.mesh_instance:
		remove_child(chunk.mesh_instance)
		chunk.mesh_instance.queue_free()
		chunk.mesh_instance = null

	# Clear neighbor references
	_clear_chunk_neighbors(chunk_pos)

	# Remove from active chunks
	active_chunks.erase(chunk_pos)

	# Mark occlusion graph as dirty (chunk removed)
	if occlusion_culler:
		occlusion_culler.mark_graph_dirty()

	# Rebuild neighbor meshes so they can render boundary faces again
	_rebuild_neighbor_meshes(chunk_pos)

	# Return to pool
	_return_chunk_to_pool(chunk)

## Get a chunk from the pool or create a new one
func _get_chunk_from_pool() -> Chunk:
	if enable_pooling and chunk_pool.size() > 0:
		return chunk_pool.pop_back()
	return Chunk.new()

## Return a chunk to the pool
func _return_chunk_to_pool(chunk: Chunk) -> void:
	if enable_pooling:
		chunk.cleanup()
		chunk_pool.append(chunk)

## Update neighbor references for a chunk and its neighbors
func _update_chunk_neighbors(chunk_pos: Vector3i, chunk: Chunk) -> void:
	# Define neighbor offsets
	var neighbor_offsets := {
		"north": Vector3i(0, 0, 1),
		"south": Vector3i(0, 0, -1),
		"east": Vector3i(1, 0, 0),
		"west": Vector3i(-1, 0, 0),
		"up": Vector3i(0, 1, 0),
		"down": Vector3i(0, -1, 0)
	}

	# Set this chunk's neighbors
	for direction in neighbor_offsets.keys():
		var neighbor_pos: Vector3i = chunk_pos + neighbor_offsets[direction]
		if neighbor_pos in active_chunks:
			chunk.set_neighbor(direction, active_chunks[neighbor_pos])

	# Update neighbors to reference this chunk
	var opposite := {
		"north": "south",
		"south": "north",
		"east": "west",
		"west": "east",
		"up": "down",
		"down": "up"
	}

	for direction in neighbor_offsets.keys():
		var neighbor_pos: Vector3i = chunk_pos + neighbor_offsets[direction]
		if neighbor_pos in active_chunks:
			var neighbor: Chunk = active_chunks[neighbor_pos]
			neighbor.set_neighbor(opposite[direction], chunk)

## Clear neighbor references when unloading a chunk
func _clear_chunk_neighbors(chunk_pos: Vector3i) -> void:
	var chunk: Chunk = active_chunks.get(chunk_pos)
	if not chunk:
		return

	# Clear this chunk's neighbor references
	for key in chunk.neighbors.keys():
		chunk.neighbors[key] = null

	# Remove references from neighbors pointing to this chunk
	var neighbor_offsets := {
		"north": Vector3i(0, 0, 1),
		"south": Vector3i(0, 0, -1),
		"east": Vector3i(1, 0, 0),
		"west": Vector3i(-1, 0, 0),
		"up": Vector3i(0, 1, 0),
		"down": Vector3i(0, -1, 0)
	}

	var opposite := {
		"north": "south",
		"south": "north",
		"east": "west",
		"west": "east",
		"up": "down",
		"down": "up"
	}

	for direction in neighbor_offsets.keys():
		var neighbor_pos: Vector3i = chunk_pos + neighbor_offsets[direction]
		if neighbor_pos in active_chunks:
			var neighbor: Chunk = active_chunks[neighbor_pos]
			neighbor.set_neighbor(opposite[direction], null)

## Rebuild meshes of neighboring chunks
## Called when a new chunk is loaded to ensure proper face culling at boundaries
## Now uses batched rebuilds to prevent duplicate work in the same frame
func _rebuild_neighbor_meshes(chunk_pos: Vector3i) -> void:
	# OPTIMIZATION: In region batching mode, don't rebuild individual chunk meshes!
	# Instead, mark the affected neighbor regions as dirty
	if enable_region_batching:
		var neighbor_offsets := {
			"north": Vector3i(0, 0, 1),
			"south": Vector3i(0, 0, -1),
			"east": Vector3i(1, 0, 0),
			"west": Vector3i(-1, 0, 0),
			"up": Vector3i(0, 1, 0),
			"down": Vector3i(0, -1, 0)
		}

		for direction in neighbor_offsets.keys():
			var neighbor_pos: Vector3i = chunk_pos + neighbor_offsets[direction]
			if neighbor_pos in active_chunks:
				# Mark the neighbor chunk's cached mesh arrays as invalid
				var neighbor: Chunk = active_chunks[neighbor_pos]
				if neighbor and neighbor.state == Chunk.State.ACTIVE:
					neighbor.cached_mesh_arrays.clear()

				# Mark the region containing this neighbor as dirty
				var neighbor_region_pos := ChunkRegion.chunk_to_region_position(neighbor_pos)
				if neighbor_region_pos in active_regions:
					var region: ChunkRegion = active_regions[neighbor_region_pos]
					if region:
						region.mark_dirty()
		return

	# Traditional mode: Queue individual chunk mesh rebuilds
	var neighbor_offsets := {
		"north": Vector3i(0, 0, 1),
		"south": Vector3i(0, 0, -1),
		"east": Vector3i(1, 0, 0),
		"west": Vector3i(-1, 0, 0),
		"up": Vector3i(0, 1, 0),
		"down": Vector3i(0, -1, 0)
	}

	# Instead of rebuilding immediately, queue neighbors for batched rebuild
	# This prevents the same neighbor from being rebuilt multiple times in one frame
	for direction in neighbor_offsets.keys():
		var neighbor_pos: Vector3i = chunk_pos + neighbor_offsets[direction]
		if neighbor_pos in active_chunks:
			var neighbor: Chunk = active_chunks[neighbor_pos]
			if neighbor and neighbor.state == Chunk.State.ACTIVE:
				# Add to pending rebuilds (dictionary acts as a set, avoids duplicates)
				pending_neighbor_rebuilds[neighbor_pos] = true

## Process batched neighbor rebuilds
## Processes up to a limited number per frame to avoid FPS spikes
func _process_pending_neighbor_rebuilds() -> void:
	# Not used in region batching mode
	if enable_region_batching:
		return

	if pending_neighbor_rebuilds.is_empty():
		return

	# Limit rebuilds per frame to prevent FPS drops
	const MAX_REBUILDS_PER_FRAME: int = 6
	var rebuilds_this_frame: int = 0

	# Process pending rebuilds
	var positions_to_remove: Array[Vector3i] = []
	for neighbor_pos in pending_neighbor_rebuilds.keys():
		if rebuilds_this_frame >= MAX_REBUILDS_PER_FRAME:
			break

		# Check if chunk still exists and is active
		if neighbor_pos in active_chunks:
			var neighbor: Chunk = active_chunks[neighbor_pos]
			if neighbor and neighbor.state == Chunk.State.ACTIVE:
				_rebuild_chunk_mesh(neighbor)
				rebuilds_this_frame += 1

		positions_to_remove.append(neighbor_pos)

	# Remove processed rebuilds
	for pos in positions_to_remove:
		pending_neighbor_rebuilds.erase(pos)

## Rebuild a single chunk's mesh
func _rebuild_chunk_mesh(chunk: Chunk) -> void:
	if not chunk or not mesh_builder:
		return

	# IMPORTANT: Don't remove old mesh yet! Keep it visible to prevent flashing
	# The old mesh will be replaced when the new one is ready
	# Store reference to old mesh so we can clean it up later
	chunk.set_meta("old_mesh_instance", chunk.mesh_instance)

	# Build new mesh (use threading if available)
	chunk.state = Chunk.State.MESHING

	if thread_pool:
		# Queue threaded mesh rebuild (mark as rebuild to prevent cascading)
		meshing_chunks[chunk.position] = chunk
		# Store a flag in the chunk to indicate this is a rebuild, not initial load
		chunk.set_meta("is_rebuild", true)
		var priority: float = 1.0 / max(tracked_position.distance_to(chunk.get_world_position()), 1.0)
		thread_pool.queue_meshing_job(chunk, mesh_builder, priority)
	else:
		# Fallback to synchronous rebuild
		var old_mesh = chunk.mesh_instance
		var mesh_instance: MeshInstance3D = mesh_builder.build_mesh(chunk)
		if mesh_instance:
			chunk.mesh_instance = mesh_instance
			mesh_instance.position = chunk.get_world_position()
			add_child(mesh_instance)

		# Now remove old mesh after new one is added
		if old_mesh:
			remove_child(old_mesh)
			old_mesh.queue_free()

		# Restore active state
		chunk.state = Chunk.State.ACTIVE
		chunk.mark_clean()

## Get chunk at a specific chunk position
func get_chunk(chunk_pos: Vector3i) -> Chunk:
	return active_chunks.get(chunk_pos)

## Get voxel at world position
func get_voxel_at_world(world_pos: Vector3i) -> int:
	var chunk_pos := world_to_chunk_position(world_pos)
	var chunk := get_chunk(chunk_pos)

	if chunk:
		var local_pos := chunk.world_to_local(world_pos)
		return chunk.get_voxel(local_pos)

	return VoxelTypes.Type.AIR

## Set voxel at world position (and trigger mesh rebuild)
func set_voxel_at_world(world_pos: Vector3i, voxel_type: int) -> void:
	var chunk_pos := world_to_chunk_position(world_pos)
	var chunk := get_chunk(chunk_pos)

	if chunk:
		var local_pos := chunk.world_to_local(world_pos)
		chunk.set_voxel(local_pos, voxel_type)
		# TODO: Trigger mesh rebuild

## Convert world position to chunk position (uses adaptive chunk heights)
func world_to_chunk_position(world_pos: Vector3) -> Vector3i:
	return ChunkHeightZones.world_to_chunk_position(world_pos)

## Generate a test chunk (fallback if no terrain generator)
func _generate_test_chunk(chunk: Chunk) -> void:
	# Create a simple flat terrain for testing
	var height := 8

	# Get actual chunk dimensions (handle adaptive Y sizing)
	var chunk_height := chunk.voxel_data.chunk_size_y
	var chunk_world_y := ChunkHeightZones.chunk_y_to_world_y(chunk.position.y)

	for x in range(VoxelData.CHUNK_SIZE_XZ):
		for z in range(VoxelData.CHUNK_SIZE_XZ):
			for y in range(chunk_height):
				var world_y := chunk_world_y + y

				if world_y < height - 4:
					chunk.voxel_data.set_voxel(Vector3i(x, y, z), VoxelTypes.Type.STONE)
				elif world_y < height - 1:
					chunk.voxel_data.set_voxel(Vector3i(x, y, z), VoxelTypes.Type.DIRT)
				elif world_y == height - 1:
					chunk.voxel_data.set_voxel(Vector3i(x, y, z), VoxelTypes.Type.GRASS)

## Check if initial chunks are ready and emit signal once
func _check_initial_chunks_ready() -> void:
	# Only check once
	if _initial_chunks_ready:
		return

	# Count active chunks
	var active_count := 0
	for chunk in active_chunks.values():
		if chunk and chunk.state == Chunk.State.ACTIVE:
			active_count += 1

	# Emit signal once we have enough chunks
	if active_count >= INITIAL_CHUNKS_THRESHOLD:
		_initial_chunks_ready = true
		initial_chunks_ready.emit()

## Cleanup all chunks
func cleanup_all() -> void:
	# Shutdown thread pool first
	if thread_pool:
		thread_pool.shutdown()
		thread_pool = null

	# Clear job tracking
	generating_chunks.clear()
	meshing_chunks.clear()

	# Unload all chunks
	var chunks_to_remove := active_chunks.keys()
	for chunk_pos in chunks_to_remove:
		unload_chunk(chunk_pos)

	active_chunks.clear()
	chunk_pool.clear()

	# Cleanup all regions
	for region in active_regions.values():
		if region:
			remove_child(region)
			region.cleanup()

	active_regions.clear()
	dirty_regions.clear()

	# Print cache stats on cleanup
	if chunk_cache:
		chunk_cache.print_stats()

## Get statistics for debugging
func get_stats() -> Dictionary:
	var stats := {
		"active_chunks": stats_active_chunks,
		"pooled_chunks": stats_pooled_chunks,
		"chunks_generated": stats_chunks_generated,
		"chunks_meshed": stats_chunks_meshed,
		"generating_chunks": generating_chunks.size(),
		"meshing_chunks": meshing_chunks.size()
	}

	# Add cache stats if available
	if chunk_cache:
		var cache_stats := chunk_cache.get_stats()
		stats["cache_enabled"] = cache_stats.enabled
		stats["cache_hits"] = cache_stats.cache_hits
		stats["cache_misses"] = cache_stats.cache_misses
		stats["cache_hit_rate"] = cache_stats.hit_rate
		stats["cache_size_mb"] = cache_stats.cache_size_mb

	# Add thread pool stats if available
	if thread_pool:
		var thread_stats := thread_pool.get_stats()
		stats["threading_enabled"] = true
		stats["worker_count"] = thread_stats.worker_count
		stats["pending_jobs"] = thread_stats.pending_jobs
		stats["completed_jobs"] = thread_stats.completed_jobs
	else:
		stats["threading_enabled"] = false

	# Add occlusion culling stats if available
	if occlusion_culler:
		var occlusion_stats := occlusion_culler.get_stats()
		stats["occlusion_mode"] = occlusion_stats.mode
		stats["occlusion_visible"] = occlusion_stats.visible_chunks
		stats["occlusion_hidden"] = occlusion_stats.occluded_chunks
		stats["occlusion_rate"] = occlusion_stats.occlusion_rate

	# Add region batching stats if available
	if enable_region_batching:
		stats["region_batching_enabled"] = true
		stats["active_regions"] = active_regions.size()
		stats["dirty_regions"] = dirty_regions.size()
		stats["rebuilding_regions"] = rebuilding_regions.size()
	else:
		stats["region_batching_enabled"] = false

	return stats

## Print debug info
func print_stats() -> void:
	print("ChunkManager Stats:")
	print("  Active chunks: %d" % stats_active_chunks)
	print("  Pooled chunks: %d" % stats_pooled_chunks)
	print("  Generating: %d" % generating_chunks.size())
	print("  Meshing: %d" % meshing_chunks.size())
	print("  Total generated: %d" % stats_chunks_generated)
	print("  Total meshed: %d" % stats_chunks_meshed)

	# Print thread pool stats
	if thread_pool:
		var thread_stats := thread_pool.get_stats()
		print("  Threading enabled: Yes")
		print("  Workers: %d" % thread_stats.worker_count)
		print("  Pending jobs: %d" % thread_stats.pending_jobs)
		print("  Completed jobs: %d" % thread_stats.completed_jobs)

	# Print cache stats
	if chunk_cache:
		var cache_stats := chunk_cache.get_stats()
		print("  Cache enabled: %s" % cache_stats.enabled)
		print("  Cache hits: %d" % cache_stats.cache_hits)
		print("  Cache misses: %d" % cache_stats.cache_misses)
		print("  Cache hit rate: %.1f%%" % cache_stats.hit_rate)
		print("  Cache size: %.2f MB" % cache_stats.cache_size_mb)

	# Print region stats if batching enabled
	if enable_region_batching:
		print("  Region batching: Enabled")
		print("  Active regions: %d" % active_regions.size())
		print("  Dirty regions: %d" % dirty_regions.size())

## Get or create a region for the given chunk position
func _get_or_create_region(chunk_pos: Vector3i) -> ChunkRegion:
	var region_pos := ChunkRegion.chunk_to_region_position(chunk_pos)

	# Return existing region if available
	if region_pos in active_regions:
		return active_regions[region_pos]

	# Create new region
	var region := ChunkRegion.new(region_pos)
	region.material = mesh_builder.default_material if mesh_builder else null
	region.position = region.get_region_world_position()
	add_child(region)

	active_regions[region_pos] = region

	print("[ChunkManager] Created region at %s" % region_pos)
	return region

## Add chunk to its region
func _add_chunk_to_region(chunk: Chunk) -> void:
	if not enable_region_batching:
		return

	var region := _get_or_create_region(chunk.position)
	region.add_chunk(chunk)

	# Mark region as dirty
	dirty_regions[region.region_position] = true

## Remove chunk from its region
func _remove_chunk_from_region(chunk_pos: Vector3i) -> void:
	if not enable_region_batching:
		return

	var region_pos := ChunkRegion.chunk_to_region_position(chunk_pos)

	if region_pos in active_regions:
		var region: ChunkRegion = active_regions[region_pos]
		region.remove_chunk(chunk_pos)

		# Mark region as dirty
		dirty_regions[region_pos] = true

		# If region is now empty, remove it
		if region.chunk_count == 0:
			active_regions.erase(region_pos)
			dirty_regions.erase(region_pos)
			remove_child(region)
			region.cleanup()
			print("[ChunkManager] Removed empty region at %s" % region_pos)

## Process dirty regions (rebuild their combined meshes)
func _process_dirty_regions() -> void:
	if dirty_regions.is_empty():
		return

	# Don't queue more jobs if thread pool is backed up
	if thread_pool and thread_pool.get_pending_job_count() > MAX_PENDING_JOBS:
		return

	var regions_queued := 0

	# Queue dirty regions for async rebuilding (limit per frame to avoid overwhelming thread pool)
	for region_pos in dirty_regions.keys():
		# Stop if we've hit our limit
		if regions_queued >= max_region_rebuilds_per_frame:
			break

		# Skip if already being rebuilt
		if region_pos in rebuilding_regions:
			continue

		# Check if region still exists
		if not region_pos in active_regions:
			dirty_regions.erase(region_pos)
			continue

		var region: ChunkRegion = active_regions[region_pos]
		if not region or not is_instance_valid(region):
			dirty_regions.erase(region_pos)
			continue

		# Skip if region doesn't need rebuild
		if not region.needs_rebuild():
			dirty_regions.erase(region_pos)
			continue

		# Queue region rebuild on worker thread
		if thread_pool and mesh_builder:
			# Calculate priority based on distance to player
			var region_world_pos := region.get_region_world_position()
			var distance := tracked_position.distance_to(region_world_pos)
			var priority: float = 1.0 / max(distance, 1.0)

			# Queue the job
			thread_pool.queue_region_rebuild_job(region, region_pos, mesh_builder, priority)

			# Mark as rebuilding
			rebuilding_regions[region_pos] = true
			regions_queued += 1

	# Log queue status if we have a backlog
	if dirty_regions.size() > 5 and regions_queued > 0:
		print("[ChunkManager] Queued %d regions for async rebuild, %d regions pending, %d rebuilding" % [
			regions_queued, dirty_regions.size(), rebuilding_regions.size()
		])
