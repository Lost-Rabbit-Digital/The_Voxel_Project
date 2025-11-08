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
func update_chunks(player_position: Vector3) -> void:
	# Check if we need to update
	var distance := last_update_position.distance_to(player_position)
	if distance < UPDATE_THRESHOLD:
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

	# Load new chunks
	chunks_before = active_chunks.size()
	_load_new_chunks(needed_chunks)
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

## Load chunks that aren't loaded yet
func _load_new_chunks(needed_chunks: Dictionary) -> void:
	for chunk_pos in needed_chunks.keys():
		if not active_chunks.has(chunk_pos):
			load_chunk(chunk_pos)

## Load a single chunk at the given position
func load_chunk(chunk_pos: Vector3i) -> Chunk:
	# Check if already loaded
	if chunk_pos in active_chunks:
		print("[ChunkManager] Chunk %s already loaded, skipping" % chunk_pos)
		return active_chunks[chunk_pos]

	print("[ChunkManager] Loading chunk at %s..." % chunk_pos)

	# Get chunk from pool or create new
	var chunk := _get_chunk_from_pool()
	print("[ChunkManager]   Got chunk from pool (pooled: %d)" % chunk_pool.size())
	chunk.initialize(chunk_pos)
	chunk.state = Chunk.State.GENERATING

	# Generate terrain data
	if terrain_generator:
		print("[ChunkManager]   Generating terrain...")
		chunk.voxel_data = terrain_generator.generate_chunk(chunk_pos)
		stats_chunks_generated += 1
		var solid_count := chunk.voxel_data.count_solid_voxels()
		print("[ChunkManager]   Generated %d solid voxels" % solid_count)
	else:
		print("[ChunkManager]   WARNING: No terrain generator, using test pattern")
		_generate_test_chunk(chunk)

	# Skip empty chunks
	if chunk.is_empty():
		print("[ChunkManager]   Chunk is empty, returning to pool")
		_return_chunk_to_pool(chunk)
		return null

	# Add to active chunks first (before neighbor updates)
	active_chunks[chunk_pos] = chunk

	# Update neighbor references BEFORE building mesh
	# This allows proper face culling at chunk boundaries
	print("[ChunkManager]   Updating neighbor references...")
	_update_chunk_neighbors(chunk_pos, chunk)

	# Generate mesh
	chunk.state = Chunk.State.MESHING
	if mesh_builder:
		print("[ChunkManager]   Building mesh...")
		var mesh_instance: MeshInstance3D = mesh_builder.build_mesh(chunk)
		if mesh_instance:
			chunk.mesh_instance = mesh_instance
			mesh_instance.position = chunk.get_world_position()
			add_child(mesh_instance)
			stats_chunks_meshed += 1
			var vertex_count := mesh_instance.mesh.get_surface_count() if mesh_instance.mesh else 0
			print("[ChunkManager]   Mesh built with %d surfaces" % vertex_count)
		else:
			print("[ChunkManager]   WARNING: Mesh builder returned null")
	else:
		print("[ChunkManager]   WARNING: No mesh builder available")

	# Rebuild meshes of neighboring chunks (they now have a new neighbor)
	print("[ChunkManager]   Rebuilding neighboring chunk meshes...")
	_rebuild_neighbor_meshes(chunk_pos)

	# Activate chunk
	chunk.state = Chunk.State.ACTIVE

	print("[ChunkManager] ✓ Chunk %s loaded successfully" % chunk_pos)
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

	# Rebuild neighboring chunks (they may need to show faces that were previously culled)
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
