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

## OPTIMIZATION: Uniform chunk optimization (Zylann technique)
## If entire chunk has same value, store just that value instead of 4KB array
## Saves massive memory for empty air chunks and solid stone chunks
var is_uniform: bool = true
var uniform_value: int = VoxelTypes.Type.AIR

## Initialize with all air (0)
func _init(chunk_pos: Vector3i = Vector3i.ZERO) -> void:
	chunk_position = chunk_pos
	# Start as uniform air chunk (no array allocation!)
	is_uniform = true
	uniform_value = VoxelTypes.Type.AIR
	# data will be allocated lazily when first non-uniform write happens

## Get voxel type at local position (0-15 on each axis)
## Returns VoxelTypes.Type enum value
func get_voxel(local_pos: Vector3i) -> int:
	if not is_position_valid(local_pos):
		return VoxelTypes.Type.AIR

	# OPTIMIZATION: Fast path for uniform chunks
	if is_uniform:
		return uniform_value

	var index := get_index(local_pos)
	return data[index]

## Set voxel type at local position (0-15 on each axis)
func set_voxel(local_pos: Vector3i, voxel_type: int) -> void:
	if not is_position_valid(local_pos):
		return

	# OPTIMIZATION: Handle uniform chunks
	if is_uniform:
		if voxel_type == uniform_value:
			return  # No change needed
		# Need to expand to full array
		_expand_uniform_chunk()

	var index := get_index(local_pos)
	data[index] = voxel_type

## Expand a uniform chunk into a full array (called when first non-uniform write happens)
func _expand_uniform_chunk() -> void:
	data = PackedByteArray()
	data.resize(CHUNK_VOLUME)
	data.fill(uniform_value)
	is_uniform = false

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
	# OPTIMIZATION: O(1) check for uniform chunks instead of O(4096)
	if is_uniform:
		return uniform_value == VoxelTypes.Type.AIR

	for i in range(CHUNK_VOLUME):
		if data[i] != VoxelTypes.Type.AIR:
			return false
	return true

## Check if the chunk is completely solid (no AIR)
func is_full() -> bool:
	# OPTIMIZATION: O(1) check for uniform chunks
	if is_uniform:
		return uniform_value != VoxelTypes.Type.AIR

	for i in range(CHUNK_VOLUME):
		if data[i] == VoxelTypes.Type.AIR:
			return false
	return true

## Count non-air voxels in the chunk
func count_solid_voxels() -> int:
	# OPTIMIZATION: O(1) for uniform chunks
	if is_uniform:
		return 0 if uniform_value == VoxelTypes.Type.AIR else CHUNK_VOLUME

	var count := 0
	for i in range(CHUNK_VOLUME):
		if data[i] != VoxelTypes.Type.AIR:
			count += 1
	return count

## Fill entire chunk with a specific voxel type
func fill(voxel_type: int) -> void:
	# OPTIMIZATION: Convert to uniform chunk
	is_uniform = true
	uniform_value = voxel_type
	# Free the array to save memory
	data = PackedByteArray()

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
	cloned.is_uniform = is_uniform
	cloned.uniform_value = uniform_value
	if not is_uniform:
		cloned.data = data.duplicate()
	return cloned

## Serialize voxel data to bytes for saving/networking
func serialize() -> PackedByteArray:
	# OPTIMIZATION: For uniform chunks, store efficiently
	if is_uniform:
		var bytes := PackedByteArray()
		bytes.resize(2)
		bytes[0] = 1  # Uniform flag
		bytes[1] = uniform_value
		return bytes

	# Non-uniform: prefix with flag + data
	var bytes := PackedByteArray()
	bytes.resize(1 + CHUNK_VOLUME)
	bytes[0] = 0  # Non-uniform flag
	for i in range(CHUNK_VOLUME):
		bytes[i + 1] = data[i]
	return bytes

## Deserialize voxel data from bytes
static func deserialize(bytes: PackedByteArray, chunk_pos: Vector3i) -> VoxelData:
	var voxel_data := VoxelData.new(chunk_pos)

	if bytes.size() == 2 and bytes[0] == 1:
		# Uniform chunk
		voxel_data.is_uniform = true
		voxel_data.uniform_value = bytes[1]
	elif bytes.size() == CHUNK_VOLUME + 1 and bytes[0] == 0:
		# Non-uniform chunk
		voxel_data.is_uniform = false
		voxel_data.data = PackedByteArray()
		voxel_data.data.resize(CHUNK_VOLUME)
		for i in range(CHUNK_VOLUME):
			voxel_data.data[i] = bytes[i + 1]
	elif bytes.size() == CHUNK_VOLUME:
		# Legacy format (no uniform flag)
		voxel_data.is_uniform = false
		voxel_data.data = bytes.duplicate()

	return voxel_data

## Get memory usage in bytes
func get_memory_usage() -> int:
	if is_uniform:
		return 2  # Just the two flags
	return data.size()

## Debug: Print chunk info
func print_info() -> void:
	print("Chunk at %s: %d solid voxels, %d bytes" % [
		chunk_position,
		count_solid_voxels(),
		get_memory_usage()
	])
