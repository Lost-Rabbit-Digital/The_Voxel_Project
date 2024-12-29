class_name ChunkData
extends Resource

const CHUNK_SIZE = 16

var voxels: Dictionary = {}
var position: Vector3
var needs_remesh: bool = true

func _init(chunk_pos: Vector3) -> void:
	position = chunk_pos

func set_voxel(local_pos: Vector3, type: VoxelTypes.Type) -> void:
	if type == VoxelTypes.Type.AIR:
		voxels.erase(local_pos)
	else:
		voxels[local_pos] = type
	needs_remesh = true

func get_voxel(local_pos: Vector3) -> VoxelTypes.Type:
	return voxels.get(local_pos, VoxelTypes.Type.AIR)
