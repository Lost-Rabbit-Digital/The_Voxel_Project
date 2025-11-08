## OcclusionCuller - Hides chunks that are occluded by terrain
## Implements two occlusion culling strategies:
## 1. Simple raycast-based occlusion (fast, less accurate)
## 2. Graph-based flood-fill visibility (more accurate, cached)
##
## Inspired by Sodium mod's occlusion culling approach
class_name OcclusionCuller
extends RefCounted

## Occlusion culling mode
enum Mode {
	DISABLED,     # No occlusion culling
	RAYCAST,      # Simple raycast from camera to chunk
	FLOOD_FILL    # Graph-based flood-fill visibility (Sodium-style)
}

## Current culling mode
var mode: Mode = Mode.FLOOD_FILL

## Chunk manager reference
var chunk_manager: ChunkManager = null

## Visibility graph: chunk_pos -> array of visible neighbor positions
## This represents which chunks can "see" each other (have exposed faces)
var visibility_graph: Dictionary = {}

## Currently visible chunks (updated each frame)
var visible_chunks: Dictionary = {}  # Vector3i -> true

## Cache of last camera chunk position (to avoid rebuilding every frame)
var last_camera_chunk_pos: Vector3i = Vector3i(999999, 999999, 999999)

## Performance stats
var stats_visible_chunks: int = 0
var stats_occluded_chunks: int = 0
var stats_graph_updates: int = 0

## Configuration
var max_visibility_distance: int = 16  # Maximum chunks to check
var enable_caching: bool = true         # Cache visibility results
var rebuild_graph_interval: int = 30    # Rebuild graph every N frames (when dirty)

## Internal state
var frame_counter: int = 0
var graph_dirty: bool = true  # Graph needs rebuilding

func _init(manager: ChunkManager = null):
	chunk_manager = manager
	print("[OcclusionCuller] Initialized with mode: %s" % Mode.keys()[mode])

## Update visibility for all chunks based on camera position
func update_visibility(camera_position: Vector3, active_chunks: Dictionary) -> void:
	if mode == Mode.DISABLED:
		# Mark all chunks visible
		visible_chunks.clear()
		for chunk_pos in active_chunks.keys():
			visible_chunks[chunk_pos] = true
		stats_visible_chunks = visible_chunks.size()
		stats_occluded_chunks = 0
		return

	# Get camera chunk position
	var camera_chunk_pos := _world_to_chunk_position(camera_position)

	# Check if camera moved to a different chunk
	var camera_moved := camera_chunk_pos != last_camera_chunk_pos

	if mode == Mode.RAYCAST:
		_update_visibility_raycast(camera_position, active_chunks)
	elif mode == Mode.FLOOD_FILL:
		# Only rebuild if camera moved or graph is dirty
		if camera_moved or graph_dirty or not enable_caching:
			_update_visibility_flood_fill(camera_chunk_pos, active_chunks)
			last_camera_chunk_pos = camera_chunk_pos
		# Else use cached visibility

	# Update stats
	stats_visible_chunks = visible_chunks.size()
	stats_occluded_chunks = active_chunks.size() - visible_chunks.size()

	frame_counter += 1

## Simple raycast-based occlusion culling
## Fast but less accurate - checks if a ray from camera to chunk center hits another chunk
func _update_visibility_raycast(camera_position: Vector3, active_chunks: Dictionary) -> void:
	visible_chunks.clear()

	for chunk_pos in active_chunks.keys():
		var chunk: Chunk = active_chunks[chunk_pos]
		if not chunk:
			continue

		# Get chunk center in world space
		var chunk_center := chunk.get_world_position() + Vector3.ONE * (VoxelData.CHUNK_SIZE * 0.5)

		# Check if chunk is occluded by raycasting
		if _is_chunk_visible_raycast(camera_position, chunk_center, chunk_pos, active_chunks):
			visible_chunks[chunk_pos] = true

## Check if chunk is visible via raycast (simple approach)
func _is_chunk_visible_raycast(from: Vector3, to: Vector3, target_chunk_pos: Vector3i, active_chunks: Dictionary) -> bool:
	# Calculate ray direction
	var direction := (to - from).normalized()
	var max_distance := from.distance_to(to)

	# Step along ray and check for blocking chunks
	var step_size := float(VoxelData.CHUNK_SIZE) * 0.5  # Half chunk size steps
	var steps := int(max_distance / step_size)

	for i in range(1, steps):  # Start at 1 to skip camera's own chunk
		var test_pos := from + direction * (i * step_size)
		var test_chunk_pos := _world_to_chunk_position(test_pos)

		# Skip if this is the target chunk
		if test_chunk_pos == target_chunk_pos:
			continue

		# Check if there's a chunk here that could block visibility
		if test_chunk_pos in active_chunks:
			var blocking_chunk: Chunk = active_chunks[test_chunk_pos]

			# If blocking chunk is not empty and not fully transparent, it blocks visibility
			if blocking_chunk and not blocking_chunk.is_empty():
				# Additional check: is the ray actually inside this blocking chunk?
				var blocking_aabb := blocking_chunk.get_aabb()
				if blocking_aabb.has_point(test_pos):
					return false  # Occluded

	return true  # Visible

## Graph-based flood-fill visibility (Sodium-style approach)
## More accurate - builds connectivity graph and flood-fills from camera position
func _update_visibility_flood_fill(camera_chunk_pos: Vector3i, active_chunks: Dictionary) -> void:
	visible_chunks.clear()

	# Rebuild visibility graph if dirty (only periodically for performance)
	if graph_dirty and (frame_counter % rebuild_graph_interval == 0):
		_rebuild_visibility_graph(active_chunks)
		graph_dirty = false
		stats_graph_updates += 1

	# Flood-fill from camera position to find visible chunks
	var open_set: Array[Vector3i] = [camera_chunk_pos]
	var closed_set: Dictionary = {}  # Vector3i -> true

	# Camera's chunk is always visible
	visible_chunks[camera_chunk_pos] = true

	while not open_set.is_empty():
		var current_pos: Vector3i = open_set.pop_front()

		# Skip if already processed
		if current_pos in closed_set:
			continue

		closed_set[current_pos] = true

		# Mark as visible
		visible_chunks[current_pos] = true

		# Get neighbors that this chunk can see
		var visible_neighbors := _get_visible_neighbors(current_pos, active_chunks)

		# Add unprocessed neighbors to open set
		for neighbor_pos in visible_neighbors:
			if neighbor_pos not in closed_set and neighbor_pos not in open_set:
				# Distance check to limit propagation
				var distance := _manhattan_distance(camera_chunk_pos, neighbor_pos)
				if distance <= max_visibility_distance:
					open_set.append(neighbor_pos)

## Get neighbors that can be seen from a chunk position
## A neighbor is visible if there's an exposed face between them (not fully solid border)
func _get_visible_neighbors(chunk_pos: Vector3i, active_chunks: Dictionary) -> Array[Vector3i]:
	var result: Array[Vector3i] = []

	# Check if we have cached visibility data
	if chunk_pos in visibility_graph:
		return visibility_graph[chunk_pos]

	# If not in graph, check all 6 neighbors
	var neighbor_offsets := [
		Vector3i(1, 0, 0),   # East
		Vector3i(-1, 0, 0),  # West
		Vector3i(0, 1, 0),   # Up
		Vector3i(0, -1, 0),  # Down
		Vector3i(0, 0, 1),   # North
		Vector3i(0, 0, -1)   # South
	]

	for offset in neighbor_offsets:
		var neighbor_pos: Vector3i = chunk_pos + offset

		# Check if neighbor exists and is active
		if neighbor_pos in active_chunks:
			# Assume visibility if either chunk is not full (has exposed faces)
			var current_chunk: Chunk = active_chunks.get(chunk_pos)
			var neighbor_chunk: Chunk = active_chunks.get(neighbor_pos)

			if current_chunk and neighbor_chunk:
				# If current chunk is empty (all air), skip it
				if current_chunk.is_empty():
					continue

				# If neighbor is empty (all air), we can see through
				if neighbor_chunk.is_empty():
					result.append(neighbor_pos)
					continue

				# If both chunks exist and neither is full, assume visibility through the shared face
				if not current_chunk.is_full() or not neighbor_chunk.is_full():
					result.append(neighbor_pos)

	return result

## Rebuild visibility graph for all active chunks
## This is an expensive operation, so we cache results and only rebuild when needed
func _rebuild_visibility_graph(active_chunks: Dictionary) -> void:
	visibility_graph.clear()

	# Build graph for all active chunks
	for chunk_pos in active_chunks.keys():
		var chunk: Chunk = active_chunks[chunk_pos]
		if not chunk or chunk.is_empty():
			continue

		# Calculate visible neighbors
		var visible_neighbors := _calculate_visible_neighbors(chunk_pos, chunk, active_chunks)
		visibility_graph[chunk_pos] = visible_neighbors

## Calculate which neighbors are visible from a chunk
## Checks if there are exposed faces on the border between chunks
func _calculate_visible_neighbors(chunk_pos: Vector3i, chunk: Chunk, active_chunks: Dictionary) -> Array[Vector3i]:
	var result: Array[Vector3i] = []

	# Define neighbor directions
	var directions := {
		"east": Vector3i(1, 0, 0),
		"west": Vector3i(-1, 0, 0),
		"up": Vector3i(0, 1, 0),
		"down": Vector3i(0, -1, 0),
		"north": Vector3i(0, 0, 1),
		"south": Vector3i(0, 0, -1)
	}

	for direction_name in directions.keys():
		var offset: Vector3i = directions[direction_name]
		var neighbor_pos := chunk_pos + offset

		# Check if neighbor exists
		if neighbor_pos not in active_chunks:
			# No neighbor = edge of loaded chunks = visible
			result.append(neighbor_pos)
			continue

		var neighbor: Chunk = active_chunks[neighbor_pos]

		# If neighbor is empty (all air), we can see through it
		if neighbor and neighbor.is_empty():
			result.append(neighbor_pos)
			continue

		# Check if there are exposed faces on the boundary
		# For simplicity, we assume visibility if either chunk is not completely full
		if not chunk.is_full() or (neighbor and not neighbor.is_full()):
			result.append(neighbor_pos)

	return result

## Check if a chunk is visible (according to current visibility data)
func is_chunk_visible(chunk_pos: Vector3i) -> bool:
	return chunk_pos in visible_chunks

## Mark graph as dirty (needs rebuilding)
## Call this when chunks are loaded/unloaded or modified
func mark_graph_dirty() -> void:
	graph_dirty = true

## Get occlusion culling statistics
func get_stats() -> Dictionary:
	return {
		"mode": Mode.keys()[mode],
		"visible_chunks": stats_visible_chunks,
		"occluded_chunks": stats_occluded_chunks,
		"occlusion_rate": (float(stats_occluded_chunks) / max(stats_visible_chunks + stats_occluded_chunks, 1)) * 100.0,
		"graph_updates": stats_graph_updates,
		"graph_size": visibility_graph.size()
	}

## Print debug stats
func print_stats() -> void:
	var stats := get_stats()
	print("[OcclusionCuller] Stats:")
	print("  Mode: %s" % stats.mode)
	print("  Visible chunks: %d" % stats.visible_chunks)
	print("  Occluded chunks: %d" % stats.occluded_chunks)
	print("  Occlusion rate: %.1f%%" % stats.occlusion_rate)
	print("  Graph updates: %d" % stats.graph_updates)
	print("  Graph size: %d entries" % stats.graph_size)

## Set culling mode
func set_mode(new_mode: Mode) -> void:
	if new_mode != mode:
		mode = new_mode
		graph_dirty = true
		visible_chunks.clear()
		print("[OcclusionCuller] Mode changed to: %s" % Mode.keys()[mode])

## Convert world position to chunk position
func _world_to_chunk_position(world_pos: Vector3) -> Vector3i:
	return Vector3i(
		floori(world_pos.x / VoxelData.CHUNK_SIZE),
		floori(world_pos.y / VoxelData.CHUNK_SIZE),
		floori(world_pos.z / VoxelData.CHUNK_SIZE)
	)

## Calculate Manhattan distance between two chunk positions
func _manhattan_distance(a: Vector3i, b: Vector3i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y) + absi(a.z - b.z)
