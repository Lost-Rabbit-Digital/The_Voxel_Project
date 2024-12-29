class_name ChunkData
extends Resource

const CHUNK_SIZE: int = 16

var voxels: Dictionary = {}
var position: Vector3
var needs_remesh: bool = true

signal voxel_changed(pos: Vector3, type: int)

func _init(chunk_pos: Vector3) -> void:
	position = chunk_pos

func get_voxel(local_pos: Vector3) -> VoxelTypes.Type:
	return voxels.get(local_pos, VoxelTypes.Type.AIR)

func set_voxel(local_pos: Vector3, type: VoxelTypes.Type) -> void:
	if type == VoxelTypes.Type.AIR:
		voxels.erase(local_pos)
	else:
		voxels[local_pos] = type
	
	needs_remesh = true
	voxel_changed.emit(local_pos, type)

func is_position_valid(pos: Vector3) -> bool:
	return pos.x >= 0 and pos.x < CHUNK_SIZE and \
		   pos.y >= 0 and pos.y < CHUNK_SIZE and \
		   pos.z >= 0 and pos.z < CHUNK_SIZE

# Get chunk-space coordinates
func world_to_local(world_pos: Vector3) -> Vector3:
	return Vector3(
		posmod(world_pos.x, CHUNK_SIZE),
		posmod(world_pos.y, CHUNK_SIZE),
		posmod(world_pos.z, CHUNK_SIZE)
	)

# Get world-space coordinates
func local_to_world(local_pos: Vector3) -> Vector3:
	return position * CHUNK_SIZE + local_pos
