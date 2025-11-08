## ChunkManager - Manages chunk lifecycle, pooling, and spatial queries
## Responsible for loading/unloading chunks based on player position
## Uses object pooling to minimize garbage collection pressure
class_name ChunkManager
extends Node3D

## Configuration
@export var render_distance: int = 8
@export var vertical_render_distance: int = 4
@export var enable_pooling: bool = true
@export var pool_size: int = 128

## Active chunks in the world (Vector3i chunk_pos -> Chunk)
var active_chunks: Dictionary = {}

## Chunk object pool for reuse
var chunk_pool: Array[Chunk] = []

## Chunks pending loading (Vector3i -> priority)
var load_queue: Array[Vector3i] = []

## Last player position used for chunk updates
var last_update_position: Vector3 = Vector3.ZERO

## Distance threshold before triggering chunk update
const UPDATE_THRESHOLD: float = 8.0

## Maximum chunks to load per frame (prevents stuttering)
const MAX_CHUNKS_PER_FRAME: int = 4

## References to other systems (set by VoxelWorld)
var terrain_generator = null
var mesh_builder = null

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

	# Initialize VoxelTypes registry
	print("[ChunkManager] Initializing VoxelTypes registry...")
	VoxelTypes.initialize()
	print("[ChunkManager] VoxelTypes initialized with %d block types" % VoxelTypes.Type.size())

	# Pre-populate chunk pool
	if enable_pooling:
		print("[ChunkManager] Pre-populating chunk pool with %d chunks..." % pool_size)
		for i in range(pool_size):
			chunk_pool.append(Chunk.new())
		stats_pooled_chunks = chunk_pool.size()
		print("[ChunkManager] Chunk pool ready: %d chunks" % stats_pooled_chunks)
	else:
		print("[ChunkManager] Chunk pooling disabled")

	print("[ChunkManager] Ready!")

## Update chunks based on player position
## Only updates if player has moved significantly
func update_chunks(player_position: Vector3, camera_forward: Vector3 = Vector3.FORWARD) -> void:
	# Check if we need to update
	var distance := last_update_position.distance_to(player_position)
	if distance < UPDATE_THRESHOLD:
		# Still process any pending chunks from the load queue
		_process_load_queue()
		return

	print("[ChunkManager] Player moved %.1f units, updating chunks..." % distance)
	last_update_position = player_position

	# Get player's chunk position
	var player_chunk_pos := world_to_chunk_position(player_position)
	print("[ChunkManager] Player chunk position: %s" % player_chunk_pos)

	# Determine which chunks should be loaded
	var needed_chunks: Dictionary = {}
	_calculate_needed_chunks(player_chunk_pos, needed_chunks)
	print("[ChunkManager] Calculated %d chunks needed" % needed_chunks.size())

	# Remove chunks that are too far
	var chunks_before := active_chunks.size()
	_unload_distant_chunks(needed_chunks)
	var chunks_unloaded := chunks_before - active_chunks.size()
	if chunks_unloaded > 0:
		print("[ChunkManager] Unloaded %d chunks" % chunks_unloaded)

	# Load new chunks with prioritization
	chunks_before = active_chunks.size()
	_load_new_chunks_prioritized(needed_chunks, player_position, camera_forward)
	var chunks_loaded := active_chunks.size() - chunks_before
	if chunks_loaded > 0:
		print("[ChunkManager] Loaded %d new chunks" % chunks_loaded)

	# Update stats
	stats_active_chunks = active_chunks.size()
	stats_pooled_chunks = chunk_pool.size()
	print("[ChunkManager] Active: %d, Pooled: %d, Total generated: %d, Total meshed: %d" % [
		stats_active_chunks,
		stats_pooled_chunks,
		stats_chunks_generated,
		stats_chunks_meshed
	])

## Update frustum culling for all active chunks
## Shows/hides chunks based on camera frustum visibility
func update_frustum_culling(camera: Camera3D) -> void:
	if not camera:
		return

	var frustum := camera.get_frustum()
	var visible_count := 0
	var hidden_count := 0

	for chunk in active_chunks.values():
		if not chunk or not chunk.mesh_instance:
			continue

		# Get chunk AABB
		var aabb := chunk.get_aabb()

		# Check if AABB intersects frustum
		var is_visible := _aabb_intersects_frustum(aabb, frustum)

		# Update visibility
		if chunk.mesh_instance.visible != is_visible:
			chunk.mesh_instance.visible = is_visible

		if is_visible:
			visible_count += 1
		else:
			hidden_count += 1

	# Optionally log culling stats (can be disabled for performance)
	# print("[ChunkManager] Frustum culling: %d visible, %d hidden" % [visible_count, hidden_count])

## Check if an AABB intersects with a camera frustum
func _aabb_intersects_frustum(aabb: AABB, frustum: Array[Plane]) -> bool:
	# Test AABB against each frustum plane
	for plane in frustum:
		# Get the "positive" and "negative" vertices relative to the plane normal
		var p := aabb.position
		var s := aabb.size

		# Calculate the p-vertex (furthest point in the direction of the normal)
		var p_vertex := Vector3(
			p.x + (s.x if plane.normal.x > 0 else 0),
			p.y + (s.y if plane.normal.y > 0 else 0),
			p.z + (s.z if plane.normal.z > 0 else 0)
		)

		# If the p-vertex is behind the plane, the AABB is completely outside
		if plane.is_point_over(p_vertex):
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

	if not load_queue.is_empty():
		print("[ChunkManager] %d chunks queued for later loading" % load_queue.size())

## Process pending chunks from the load queue
func _process_load_queue() -> void:
	if load_queue.is_empty():
		return

	var loaded_count := 0
	var chunks_to_remove: Array[Vector3i] = []

	for chunk_pos in load_queue:
		# Skip if already loaded or out of range
		if chunk_pos in active_chunks:
			chunks_to_remove.append(chunk_pos)
			continue

		# Load chunk
		load_chunk(chunk_pos)
		chunks_to_remove.append(chunk_pos)
		loaded_count += 1

		# Limit chunks per frame
		if loaded_count >= MAX_CHUNKS_PER_FRAME:
			break

	# Remove loaded chunks from queue
	for chunk_pos in chunks_to_remove:
		load_queue.erase(chunk_pos)

	# if loaded_count > 0:
	# 	print("[ChunkManager] Processed %d chunks from queue, %d remaining" % [loaded_count, load_queue.size()])

## Calculate priority for a chunk based on distance and camera direction
## Higher priority = should be loaded sooner
func _calculate_chunk_priority(chunk_pos: Vector3i, player_position: Vector3, camera_forward: Vector3) -> float:
	# Get chunk center in world space
	var chunk_world_pos := Vector3(chunk_pos * VoxelData.CHUNK_SIZE) + Vector3.ONE * (VoxelData.CHUNK_SIZE * 0.5)

	# Calculate distance from player (inverse priority - closer is higher)
	var distance := player_position.distance_to(chunk_world_pos)
	var distance_priority := 1.0 / max(distance, 1.0)  # Avoid division by zero

	# Calculate direction from player to chunk
	var to_chunk := (chunk_world_pos - player_position).normalized()

	# Calculate dot product with camera forward (1.0 = directly ahead, -1.0 = directly behind)
	var direction_alignment := camera_forward.dot(to_chunk)

	# Boost priority for chunks in front of camera
	var direction_priority := max(direction_alignment, 0.0)  # 0.0 to 1.0

	# Combined priority (weighted sum)
	# Distance is more important (weight 2.0), direction is secondary (weight 1.0)
	var priority := (distance_priority * 2.0) + (direction_priority * 1.0)

	return priority

## Load a single chunk at the given position
func load_chunk(chunk_pos: Vector3i) -> Chunk:
	# Check if already loaded
	if chunk_pos in active_chunks:
		print("[ChunkManager] Chunk %s already loaded, skipping" % chunk_pos)
		return active_chunks[chunk_pos]

	# Reduce console spam - only log warnings
	# print("[ChunkManager] Loading chunk at %s..." % chunk_pos)

	# Get chunk from pool or create new
	var chunk := _get_chunk_from_pool()
	# print("[ChunkManager]   Got chunk from pool (pooled: %d)" % chunk_pool.size())
	chunk.initialize(chunk_pos)
	chunk.state = Chunk.State.GENERATING

	# Generate terrain data
	if terrain_generator:
		# print("[ChunkManager]   Generating terrain...")
		chunk.voxel_data = terrain_generator.generate_chunk(chunk_pos)
		stats_chunks_generated += 1
		# var solid_count := chunk.voxel_data.count_solid_voxels()
		# print("[ChunkManager]   Generated %d solid voxels" % solid_count)
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
		# print("[ChunkManager]   Building mesh...")
		var mesh_instance: MeshInstance3D = mesh_builder.build_mesh(chunk)
		if mesh_instance:
			chunk.mesh_instance = mesh_instance
			mesh_instance.position = chunk.get_world_position()
			add_child(mesh_instance)
			stats_chunks_meshed += 1
			# var vertex_count := mesh_instance.mesh.get_surface_count() if mesh_instance.mesh else 0
			# print("[ChunkManager]   Mesh built with %d surfaces" % vertex_count)
		else:
			print("[ChunkManager]   WARNING: Mesh builder returned null")
	else:
		print("[ChunkManager]   WARNING: No mesh builder available")

	# Skip neighbor mesh rebuilds - greedy meshing already handles cross-chunk culling
	# via _should_add_face() which checks neighboring chunks
	# Rebuilding neighbors on every load causes massive performance issues
	# print("[ChunkManager]   Rebuilding neighboring chunk meshes...")
	# _rebuild_neighbor_meshes(chunk_pos)

	# Activate chunk
	chunk.state = Chunk.State.ACTIVE

	# Reduce console spam
	# print("[ChunkManager] ✓ Chunk %s loaded successfully" % chunk_pos)
	return chunk

## Unload a chunk at the given position
func unload_chunk(chunk_pos: Vector3i) -> void:
	if chunk_pos not in active_chunks:
		return

	var chunk: Chunk = active_chunks[chunk_pos]
	chunk.state = Chunk.State.UNLOADING

	# Remove mesh from scene
	if chunk.mesh_instance:
		remove_child(chunk.mesh_instance)
		chunk.mesh_instance.queue_free()
		chunk.mesh_instance = null

	# Clear neighbor references
	_clear_chunk_neighbors(chunk_pos)

	# Remove from active chunks
	active_chunks.erase(chunk_pos)

	# Skip neighbor mesh rebuilds - causes too many cascading rebuilds
	# When a chunk is unloaded, neighbors will naturally rebuild when updated
	# _rebuild_neighbor_meshes(chunk_pos)

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
func _rebuild_neighbor_meshes(chunk_pos: Vector3i) -> void:
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
			var neighbor: Chunk = active_chunks[neighbor_pos]
			if neighbor and neighbor.state == Chunk.State.ACTIVE:
				print("[ChunkManager]     Rebuilding mesh for neighbor at %s..." % neighbor_pos)
				_rebuild_chunk_mesh(neighbor)

## Rebuild a single chunk's mesh
func _rebuild_chunk_mesh(chunk: Chunk) -> void:
	if not chunk or not mesh_builder:
		return

	# Remove old mesh instance if it exists
	if chunk.mesh_instance:
		remove_child(chunk.mesh_instance)
		chunk.mesh_instance.queue_free()
		chunk.mesh_instance = null

	# Build new mesh
	chunk.state = Chunk.State.MESHING
	var mesh_instance: MeshInstance3D = mesh_builder.build_mesh(chunk)
	if mesh_instance:
		chunk.mesh_instance = mesh_instance
		mesh_instance.position = chunk.get_world_position()
		add_child(mesh_instance)

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

## Convert world position to chunk position
func world_to_chunk_position(world_pos: Vector3) -> Vector3i:
	return Vector3i(
		floori(world_pos.x / VoxelData.CHUNK_SIZE),
		floori(world_pos.y / VoxelData.CHUNK_SIZE),
		floori(world_pos.z / VoxelData.CHUNK_SIZE)
	)

## Generate a test chunk (fallback if no terrain generator)
func _generate_test_chunk(chunk: Chunk) -> void:
	# Create a simple flat terrain for testing
	var height := 8

	for x in range(VoxelData.CHUNK_SIZE):
		for z in range(VoxelData.CHUNK_SIZE):
			for y in range(VoxelData.CHUNK_SIZE):
				var world_y := chunk.position.y * VoxelData.CHUNK_SIZE + y

				if world_y < height - 4:
					chunk.voxel_data.set_voxel(Vector3i(x, y, z), VoxelTypes.Type.STONE)
				elif world_y < height - 1:
					chunk.voxel_data.set_voxel(Vector3i(x, y, z), VoxelTypes.Type.DIRT)
				elif world_y == height - 1:
					chunk.voxel_data.set_voxel(Vector3i(x, y, z), VoxelTypes.Type.GRASS)

## Cleanup all chunks
func cleanup_all() -> void:
	var chunks_to_remove := active_chunks.keys()
	for chunk_pos in chunks_to_remove:
		unload_chunk(chunk_pos)

	active_chunks.clear()
	chunk_pool.clear()

## Get statistics for debugging
func get_stats() -> Dictionary:
	return {
		"active_chunks": stats_active_chunks,
		"pooled_chunks": stats_pooled_chunks,
		"chunks_generated": stats_chunks_generated,
		"chunks_meshed": stats_chunks_meshed
	}

## Print debug info
func print_stats() -> void:
	print("ChunkManager Stats:")
	print("  Active chunks: %d" % stats_active_chunks)
	print("  Pooled chunks: %d" % stats_pooled_chunks)
	print("  Total generated: %d" % stats_chunks_generated)
	print("  Total meshed: %d" % stats_chunks_meshed)
