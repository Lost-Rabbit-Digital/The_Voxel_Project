## Chunk - Represents a single chunk in the world
## Combines voxel data with rendering mesh and state management
## Designed for object pooling to minimize GC pressure
class_name Chunk
extends RefCounted

## Chunk states for lifecycle management
enum State {
	INACTIVE,      # In pool, not being used
	GENERATING,    # Terrain generation in progress
	MESHING,       # Mesh generation in progress
	ACTIVE,        # Active in world, rendering
	UNLOADING      # Being removed from world
}

## Chunk position in chunk coordinates
var position: Vector3i = Vector3i.ZERO

## Voxel data storage
var voxel_data: VoxelData = null

## Mesh instance for rendering (created by ChunkManager)
var mesh_instance: MeshInstance3D = null

## Collision shape (if needed)
var collision_shape: CollisionShape3D = null

## Current state
var state: State = State.INACTIVE

## Is the mesh dirty and needs rebuilding?
var is_mesh_dirty: bool = false

## Cached references to neighboring chunks (for cross-chunk face culling)
var neighbors: Dictionary = {
	"north": null,  # +Z
	"south": null,  # -Z
	"east": null,   # +X
	"west": null,   # -X
	"up": null,     # +Y
	"down": null    # -Y
}

## Last time this chunk was accessed (for LRU cache management)
var last_access_time: int = 0

## Initialize/reset chunk for reuse (called when getting from pool)
func initialize(chunk_pos: Vector3i) -> void:
	position = chunk_pos
	state = State.INACTIVE
	is_mesh_dirty = true
	last_access_time = Time.get_ticks_msec()

	# Create or reset voxel data
	if voxel_data == null:
		voxel_data = VoxelData.new(chunk_pos)
	else:
		voxel_data.chunk_position = chunk_pos
		voxel_data.fill(VoxelTypes.Type.AIR)

	# Clear neighbor references
	for key in neighbors.keys():
		neighbors[key] = null

## Clean up chunk for return to pool
func cleanup() -> void:
	state = State.INACTIVE
	is_mesh_dirty = false

	# Clear neighbor references
	for key in neighbors.keys():
		neighbors[key] = null

	# Note: We keep voxel_data allocated for reuse
	# Note: Mesh instance is managed by ChunkManager

## Get voxel at local position
func get_voxel(local_pos: Vector3i) -> int:
	if voxel_data:
		return voxel_data.get_voxel(local_pos)
	return VoxelTypes.Type.AIR

## Set voxel at local position and mark mesh as dirty
func set_voxel(local_pos: Vector3i, voxel_type: int) -> void:
	if voxel_data:
		voxel_data.set_voxel(local_pos, voxel_type)
		is_mesh_dirty = true

## Convert local position to world position
func local_to_world(local_pos: Vector3i) -> Vector3i:
	return position * VoxelData.CHUNK_SIZE + local_pos

## Convert world position to local position
func world_to_local(world_pos: Vector3i) -> Vector3i:
	return world_pos - (position * VoxelData.CHUNK_SIZE)

## Get the world position of this chunk's origin
func get_world_position() -> Vector3:
	return Vector3(position * VoxelData.CHUNK_SIZE)

## Check if this chunk is empty (all air)
func is_empty() -> bool:
	if voxel_data:
		return voxel_data.is_empty()
	return true

## Check if this chunk is full (no air)
func is_full() -> bool:
	if voxel_data:
		return voxel_data.is_full()
	return false

## Get neighbor chunk in a direction
func get_neighbor(direction: String) -> Chunk:
	if direction in neighbors:
		return neighbors[direction]
	return null

## Set neighbor chunk reference
func set_neighbor(direction: String, neighbor: Chunk) -> void:
	if direction in neighbors:
		neighbors[direction] = neighbor

## Get all valid neighbor chunks
func get_all_neighbors() -> Array[Chunk]:
	var result: Array[Chunk] = []
	for neighbor in neighbors.values():
		if neighbor != null:
			result.append(neighbor)
	return result

## Check if we have all 6 neighbors loaded
func has_all_neighbors() -> bool:
	for neighbor in neighbors.values():
		if neighbor == null:
			return false
	return true

## Calculate distance to a position (squared, for performance)
func distance_squared_to(pos: Vector3) -> float:
	var chunk_center := get_world_position() + Vector3.ONE * (VoxelData.CHUNK_SIZE * 0.5)
	return chunk_center.distance_squared_to(pos)

## Get axis-aligned bounding box for this chunk
func get_aabb() -> AABB:
	var world_pos := get_world_position()
	var size := Vector3.ONE * VoxelData.CHUNK_SIZE
	return AABB(world_pos, size)

## Update last access time (for LRU management)
func update_access_time() -> void:
	last_access_time = Time.get_ticks_msec()

## Mark mesh as needing rebuild
func mark_dirty() -> void:
	is_mesh_dirty = true

## Mark mesh as clean (after rebuild)
func mark_clean() -> void:
	is_mesh_dirty = false

## Check if chunk needs mesh rebuild
func needs_mesh_rebuild() -> bool:
	return is_mesh_dirty and state == State.ACTIVE

## Serialize chunk data for saving
func serialize() -> Dictionary:
	return {
		"position": {"x": position.x, "y": position.y, "z": position.z},
		"voxel_data": voxel_data.serialize() if voxel_data else PackedByteArray()
	}

## Deserialize chunk data from save
static func deserialize(data: Dictionary) -> Chunk:
	var chunk := Chunk.new()
	var pos: Dictionary = data.get("position", {"x": 0, "y": 0, "z": 0})
	chunk.position = Vector3i(pos.x, pos.y, pos.z)

	var voxel_bytes: PackedByteArray = data.get("voxel_data", PackedByteArray())
	chunk.voxel_data = VoxelData.deserialize(voxel_bytes, chunk.position)

	return chunk

## Get memory usage in bytes
func get_memory_usage() -> int:
	var total := 0
	if voxel_data:
		total += voxel_data.get_memory_usage()
	# Add mesh memory if needed (mesh size can be calculated from vertex count)
	return total

## Debug: Print chunk info
func print_info() -> void:
	var state_name: String = State.keys()[state]
	print("Chunk %s [%s]: %d voxels, dirty=%s, neighbors=%d" % [
		position,
		state_name,
		voxel_data.count_solid_voxels() if voxel_data else 0,
		is_mesh_dirty,
		get_all_neighbors().size()
	])
