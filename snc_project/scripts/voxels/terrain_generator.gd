class_name TerrainGenerator
extends Resource

var noise: FastNoiseLite
var surface_level: float = 0.0

func _init() -> void:
	_setup_noise()

func _setup_noise() -> void:
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = randi()
	noise.frequency = 0.05
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4

func generate_chunk_data(chunk_pos: Vector3) -> ChunkData:
	var data = ChunkData.new(chunk_pos)
	
	for x in range(ChunkData.CHUNK_SIZE):
		for y in range(ChunkData.CHUNK_SIZE):
			for z in range(ChunkData.CHUNK_SIZE):
				var world_pos = chunk_pos * ChunkData.CHUNK_SIZE + Vector3(x, y, z)
				var noise_value = noise.get_noise_3d(world_pos.x, world_pos.y, world_pos.z)
				var voxel_type = _get_voxel_type_for_terrain(noise_value, world_pos.y)
				
				if voxel_type != VoxelTypes.Type.AIR:
					data.set_voxel(Vector3(x, y, z), voxel_type)
	
	return data

func _get_voxel_type_for_terrain(noise_value: float, height: float) -> VoxelTypes.Type:
	# First check if it should be air
	var adjusted_surface_level = surface_level - (height / ChunkData.CHUNK_SIZE) * 0.3
	if noise_value < adjusted_surface_level:
		return VoxelTypes.Type.AIR
	
	# Calculate height fraction for terrain layers
	var height_fraction = height / ChunkData.CHUNK_SIZE
	
	# Determine terrain layers based on height and noise
	if height_fraction > 0.8:
		return VoxelTypes.Type.GRASS if noise_value > adjusted_surface_level + 0.2 else VoxelTypes.Type.DIRT
	elif height_fraction > 0.5:
		return VoxelTypes.Type.DIRT if noise_value > adjusted_surface_level + 0.1 else VoxelTypes.Type.STONE
	else:
		return VoxelTypes.Type.STONE  # Base layer is always stone
