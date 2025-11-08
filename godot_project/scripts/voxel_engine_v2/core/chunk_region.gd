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

## Rebuild the combined mesh from all chunks in this region
## This is the core optimization - combines many chunks into one draw call
func rebuild_combined_mesh(mesh_builder) -> void:
	if not mesh_builder:
		push_error("[ChunkRegion] No mesh builder provided for rebuild")
		return

	var start_time := Time.get_ticks_msec()

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

	# Process each chunk in the region
	for chunk in chunks.values():
		if not chunk or chunk.is_empty():
			continue

		# Build mesh arrays for this chunk
		var chunk_arrays: Array = mesh_builder.build_mesh_arrays(chunk)

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

	# Build the combined mesh
	combined_arrays[Mesh.ARRAY_VERTEX] = vertices
	combined_arrays[Mesh.ARRAY_NORMAL] = normals
	combined_arrays[Mesh.ARRAY_COLOR] = colors
	combined_arrays[Mesh.ARRAY_TEX_UV] = uvs
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
	last_rebuild_time_ms = Time.get_ticks_msec() - start_time

	# print("[ChunkRegion] Rebuilt region %s: %d chunks, %d vertices, %.1f ms" % [
	# 	region_position, total_chunks_processed, vertex_count, last_rebuild_time_ms
	# ])

## Get the world position of this region's origin
func get_region_world_position() -> Vector3:
	return Vector3(region_position * REGION_SIZE * VoxelData.CHUNK_SIZE)

## Get axis-aligned bounding box for this entire region
func get_aabb() -> AABB:
	var world_pos := get_region_world_position()
	var size := Vector3.ONE * (REGION_SIZE * VoxelData.CHUNK_SIZE)
	return AABB(world_pos, size)

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
