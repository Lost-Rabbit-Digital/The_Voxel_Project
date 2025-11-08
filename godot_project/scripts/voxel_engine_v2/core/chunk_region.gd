## ChunkRegion - Groups multiple chunks into a single mesh for batched rendering
## Dramatically reduces draw calls by combining 8x8x8 chunks into one mesh
## Inspired by Sodium's region-based rendering approach
##
## Performance Impact:
## - Before: 100 chunks = 100 draw calls
## - After:  100 chunks in ~2 regions = 2 draw calls (98% reduction!)
class_name ChunkRegion
extends Node3D

## Region dimensions in chunks (8x8x8 = 512 chunks per region)
const REGION_SIZE := 8

## Region position in region coordinates (not chunk or world coordinates)
var region_position: Vector3i = Vector3i.ZERO

## Chunks contained in this region (chunk_pos -> Chunk)
var chunks: Dictionary = {}

## Combined mesh instance for all chunks in this region
var mesh_instance: MeshInstance3D = null

## Is the combined mesh dirty and needs rebuilding?
var is_dirty: bool = true

## Material to use for the combined mesh (shared across all regions)
var material: Material = null

## Statistics
var chunk_count: int = 0
var vertex_count: int = 0
var last_rebuild_time_ms: float = 0.0

## Initialize region at given position
func _init(pos: Vector3i = Vector3i.ZERO):
	region_position = pos
	name = "Region_%d_%d_%d" % [pos.x, pos.y, pos.z]

## Add a chunk to this region
func add_chunk(chunk: Chunk) -> void:
	if not chunk:
		return

	chunks[chunk.position] = chunk
	chunk_count = chunks.size()
	mark_dirty()

## Remove a chunk from this region
func remove_chunk(chunk_pos: Vector3i) -> void:
	if chunks.erase(chunk_pos):
		chunk_count = chunks.size()
		mark_dirty()

## Check if region contains a chunk
func has_chunk(chunk_pos: Vector3i) -> bool:
	return chunk_pos in chunks

## Get chunk at position (if in this region)
func get_chunk(chunk_pos: Vector3i) -> Chunk:
	return chunks.get(chunk_pos)

## Mark region mesh as dirty (needs rebuild)
func mark_dirty() -> void:
	is_dirty = true

## Check if region needs mesh rebuild
func needs_rebuild() -> bool:
	return is_dirty and chunk_count > 0

## Frame time budget for region rebuilds (milliseconds)
## If rebuilding takes longer than this, we should reduce the rate
const REBUILD_TIME_BUDGET_MS: float = 8.0  # Target 16ms frame time, use max 8ms for rebuilds

## Rebuild the combined mesh from all chunks in this region
## This is the core optimization - combines many chunks into one draw call
func rebuild_combined_mesh(mesh_builder) -> void:
	if not mesh_builder:
		push_error("[ChunkRegion] No mesh builder provided for rebuild")
		return

	var start_time := Time.get_ticks_usec()  # Use microseconds for better precision

	# Clear existing mesh
	if mesh_instance:
		remove_child(mesh_instance)
		mesh_instance.queue_free()
		mesh_instance = null

	# If no chunks, nothing to build
	if chunks.is_empty():
		is_dirty = false
		return

	# Combine all chunk meshes into one
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

	# Process each chunk in the region
	for chunk in chunks.values():
		# Skip invalid or empty chunks
		if not chunk or not is_instance_valid(chunk) or chunk.is_empty():
			continue

		# Skip chunks that aren't fully ready
		if chunk.state != Chunk.State.ACTIVE:
			continue

		# Use cached mesh arrays if available (MAJOR OPTIMIZATION)
		# This avoids rebuilding the mesh from voxel data every time
		var chunk_arrays: Array = []
		if not chunk.cached_mesh_arrays.is_empty():
			# Cache hit - use pre-built arrays (FAST!)
			chunk_arrays = chunk.cached_mesh_arrays
			cache_hits += 1
		else:
			# Cache miss - build mesh arrays and cache them (SLOW!)
			# This should only happen during the first region rebuild after chunk load
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
		var chunk_offset: Vector3 = chunk.get_world_position() - get_region_world_position()

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

	# If no geometry was generated, we're done
	if vertices.is_empty():
		is_dirty = false
		return

	# Build the combined mesh - only include arrays that have proper data
	combined_arrays[Mesh.ARRAY_VERTEX] = vertices

	# Only include normals if we have them for all vertices
	if normals.size() == vertices.size():
		combined_arrays[Mesh.ARRAY_NORMAL] = normals
	elif normals.size() > 0:
		print("[ChunkRegion] Warning: Normal count (%d) doesn't match vertex count (%d)" % [normals.size(), vertices.size()])

	# Only include colors if we have them for all vertices
	if colors.size() == vertices.size():
		combined_arrays[Mesh.ARRAY_COLOR] = colors
	elif colors.size() > 0:
		print("[ChunkRegion] Warning: Color count (%d) doesn't match vertex count (%d)" % [colors.size(), vertices.size()])

	# Only include UVs if we have them for all vertices
	if uvs.size() == vertices.size():
		combined_arrays[Mesh.ARRAY_TEX_UV] = uvs
	elif uvs.size() > 0:
		print("[ChunkRegion] Warning: UV count (%d) doesn't match vertex count (%d)" % [uvs.size(), vertices.size()])

	# Always include indices if we have them
	if not indices.is_empty():
		combined_arrays[Mesh.ARRAY_INDEX] = indices

	# Create ArrayMesh
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, combined_arrays)

	# Create MeshInstance3D
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = array_mesh

	# Apply material if available
	if material:
		mesh_instance.material_override = material

	# Position at region origin
	mesh_instance.position = Vector3.ZERO  # Vertices are already offset

	# Add to scene
	add_child(mesh_instance)

	# Update stats
	vertex_count = vertices.size()
	is_dirty = false
	var rebuild_time_us := Time.get_ticks_usec() - start_time
	last_rebuild_time_ms = rebuild_time_us / 1000.0

	# Log performance (always show during initial load to demonstrate improvement)
	var cache_hit_rate := (cache_hits * 100.0 / total_chunks_processed) if total_chunks_processed > 0 else 0.0
	if last_rebuild_time_ms > REBUILD_TIME_BUDGET_MS or cache_misses > 0:
		print("[ChunkRegion] Region %s: %.1fms, %d chunks (%d vertices), cache: %d hits/%d misses (%.0f%% hit rate)" % [
			region_position, last_rebuild_time_ms, total_chunks_processed, vertex_count,
			cache_hits, cache_misses, cache_hit_rate
		])

## Get the world position of this region's origin
## NOTE: Regions span multiple Y heights, so Y position uses the min chunk Y
func get_region_world_position() -> Vector3:
	var world_x := float(region_position.x * REGION_SIZE * VoxelData.CHUNK_SIZE_XZ)
	var world_z := float(region_position.z * REGION_SIZE * VoxelData.CHUNK_SIZE_XZ)

	# For Y, use the minimum chunk Y in this region
	var min_chunk_y := region_position.y * REGION_SIZE
	var world_y := float(ChunkHeightZones.chunk_y_to_world_y(min_chunk_y))

	return Vector3(world_x, world_y, world_z)

## Get axis-aligned bounding box for this entire region
## CRITICAL: Must account for adaptive chunk heights!
func get_aabb() -> AABB:
	if chunks.is_empty():
		# Default fallback for empty regions
		var world_pos := get_region_world_position()
		var size := Vector3.ONE * (REGION_SIZE * VoxelData.CHUNK_SIZE_XZ)
		return AABB(world_pos, size)

	# Calculate actual AABB from all chunks in region (accounts for adaptive heights)
	var min_pos := Vector3(INF, INF, INF)
	var max_pos := Vector3(-INF, -INF, -INF)

	for chunk in chunks.values():
		if chunk and is_instance_valid(chunk):
			var chunk_aabb := chunk.get_aabb()
			var chunk_min := chunk_aabb.position
			var chunk_max := chunk_aabb.position + chunk_aabb.size

			min_pos.x = min(min_pos.x, chunk_min.x)
			min_pos.y = min(min_pos.y, chunk_min.y)
			min_pos.z = min(min_pos.z, chunk_min.z)

			max_pos.x = max(max_pos.x, chunk_max.x)
			max_pos.y = max(max_pos.y, chunk_max.y)
			max_pos.z = max(max_pos.z, chunk_max.z)

	var size := max_pos - min_pos
	return AABB(min_pos, size)

## Convert chunk position to region position
static func chunk_to_region_position(chunk_pos: Vector3i) -> Vector3i:
	return Vector3i(
		floori(float(chunk_pos.x) / REGION_SIZE),
		floori(float(chunk_pos.y) / REGION_SIZE),
		floori(float(chunk_pos.z) / REGION_SIZE)
	)

## Check if a chunk position belongs to this region
func contains_chunk_position(chunk_pos: Vector3i) -> bool:
	var chunk_region_pos := chunk_to_region_position(chunk_pos)
	return chunk_region_pos == region_position

## Get all chunk positions that should be in this region (8x8x8 grid)
func get_chunk_positions_in_region() -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	var base_chunk_pos := region_position * REGION_SIZE

	for x in range(REGION_SIZE):
		for y in range(REGION_SIZE):
			for z in range(REGION_SIZE):
				result.append(base_chunk_pos + Vector3i(x, y, z))

	return result

## Cleanup region resources
func cleanup() -> void:
	if mesh_instance:
		remove_child(mesh_instance)
		mesh_instance.queue_free()
		mesh_instance = null

	chunks.clear()
	chunk_count = 0
	vertex_count = 0

## Get memory usage estimate
func get_memory_usage() -> int:
	var total := 0

	# Mesh data (approximate)
	total += vertex_count * 12  # 3 floats per vertex
	total += vertex_count * 12  # 3 floats per normal
	total += vertex_count * 16  # 4 floats per color
	total += vertex_count * 8   # 2 floats per UV
	total += (vertex_count / 3) * 4  # Indices (assuming triangles)

	return total

## Debug: Print region info
func print_info() -> void:
	print("[ChunkRegion] %s:" % name)
	print("  Position: %s" % region_position)
	print("  Chunks: %d / %d max" % [chunk_count, REGION_SIZE * REGION_SIZE * REGION_SIZE])
	print("  Vertices: %d" % vertex_count)
	print("  Dirty: %s" % is_dirty)
	print("  Last rebuild: %.1f ms" % last_rebuild_time_ms)
	print("  Memory: %.2f KB" % (get_memory_usage() / 1024.0))
