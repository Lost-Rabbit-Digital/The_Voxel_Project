## VoxelData - Efficient voxel storage using PackedByteArray
## Stores a 3D grid of voxels (16x16x16) in a compact 1D array
## Each voxel is 1 byte = 256 possible block types
## Total memory per chunk: 16x16x16 = 4096 bytes = 4KB
class_name VoxelData
extends RefCounted

## Chunk dimensions (cubic for simplicity)
const CHUNK_SIZE: int = 16

## Total number of voxels in a chunk (16^3)
const CHUNK_VOLUME: int = CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE

## Voxel data storage (4096 bytes per chunk)
## Index formula: index = x + y * CHUNK_SIZE + z * CHUNK_SIZE * CHUNK_SIZE
var data: PackedByteArray

## Chunk position in chunk coordinates (not world coordinates)
var chunk_position: Vector3i

## Initialize with all air (0)
func _init(chunk_pos: Vector3i = Vector3i.ZERO) -> void:
	chunk_position = chunk_pos
	data = PackedByteArray()
	data.resize(CHUNK_VOLUME)
	data.fill(VoxelTypes.Type.AIR)

## Get voxel type at local position (0-15 on each axis)
## Returns VoxelTypes.Type enum value
func get_voxel(local_pos: Vector3i) -> int:
	if not is_position_valid(local_pos):
		return VoxelTypes.Type.AIR

	var index := get_index(local_pos)
	return data[index]

## Set voxel type at local position (0-15 on each axis)
func set_voxel(local_pos: Vector3i, voxel_type: int) -> void:
	if not is_position_valid(local_pos):
		return

	var index := get_index(local_pos)
	data[index] = voxel_type

## Check if a local position is within valid chunk bounds (0-15 on each axis)
func is_position_valid(local_pos: Vector3i) -> bool:
	return (local_pos.x >= 0 and local_pos.x < CHUNK_SIZE and
			local_pos.y >= 0 and local_pos.y < CHUNK_SIZE and
			local_pos.z >= 0 and local_pos.z < CHUNK_SIZE)

## Convert 3D local position to 1D array index
## Formula: index = x + y * CHUNK_SIZE + z * CHUNK_SIZE * CHUNK_SIZE
func get_index(local_pos: Vector3i) -> int:
	return local_pos.x + local_pos.y * CHUNK_SIZE + local_pos.z * CHUNK_SIZE * CHUNK_SIZE

## Convert 1D array index back to 3D local position
func get_position_from_index(index: int) -> Vector3i:
	var z := index / (CHUNK_SIZE * CHUNK_SIZE)
	var remainder := index % (CHUNK_SIZE * CHUNK_SIZE)
	var y := remainder / CHUNK_SIZE
	var x := remainder % CHUNK_SIZE
	return Vector3i(x, y, z)

## Convert local position to world position
func local_to_world(local_pos: Vector3i) -> Vector3i:
	return chunk_position * CHUNK_SIZE + local_pos

## Convert world position to local position within this chunk
func world_to_local(world_pos: Vector3i) -> Vector3i:
	return world_pos - (chunk_position * CHUNK_SIZE)

## Check if the chunk is completely empty (all AIR)
func is_empty() -> bool:
	for i in range(CHUNK_VOLUME):
		if data[i] != VoxelTypes.Type.AIR:
			return false
	return true

## Check if the chunk is completely solid (no AIR)
func is_full() -> bool:
	for i in range(CHUNK_VOLUME):
		if data[i] == VoxelTypes.Type.AIR:
			return false
	return true

## Count non-air voxels in the chunk
func count_solid_voxels() -> int:
	var count := 0
	for i in range(CHUNK_VOLUME):
		if data[i] != VoxelTypes.Type.AIR:
			count += 1
	return count

## Fill entire chunk with a specific voxel type
func fill(voxel_type: int) -> void:
	data.fill(voxel_type)

## Fill a rectangular region with a specific voxel type
func fill_region(from_pos: Vector3i, to_pos: Vector3i, voxel_type: int) -> void:
	var min_x := mini(from_pos.x, to_pos.x)
	var max_x := maxi(from_pos.x, to_pos.x)
	var min_y := mini(from_pos.y, to_pos.y)
	var max_y := maxi(from_pos.y, to_pos.y)
	var min_z := mini(from_pos.z, to_pos.z)
	var max_z := maxi(from_pos.z, to_pos.z)

	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			for z in range(min_z, max_z + 1):
				var pos := Vector3i(x, y, z)
				if is_position_valid(pos):
					set_voxel(pos, voxel_type)

## Clone this voxel data (deep copy)
func clone() -> VoxelData:
	var cloned := VoxelData.new(chunk_position)
	cloned.data = data.duplicate()
	return cloned

## Serialize voxel data to bytes for saving/networking
func serialize() -> PackedByteArray:
	# For now, just return the raw data
	# In the future, we can add compression here
	return data.duplicate()

## Deserialize voxel data from bytes
static func deserialize(bytes: PackedByteArray, chunk_pos: Vector3i) -> VoxelData:
	var voxel_data := VoxelData.new(chunk_pos)
	if bytes.size() == CHUNK_VOLUME:
		voxel_data.data = bytes.duplicate()
	return voxel_data

## Get memory usage in bytes
func get_memory_usage() -> int:
	return data.size()

## Debug: Print chunk info
func print_info() -> void:
	print("Chunk at %s: %d solid voxels, %d bytes" % [
		chunk_position,
		count_solid_voxels(),
		get_memory_usage()
	])
