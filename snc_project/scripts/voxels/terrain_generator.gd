# terrain_generator.gd
class_name TerrainGenerator
extends Resource

# Noise settings
var noise: FastNoiseLite
const BASE_FREQUENCY := 0.8
const DETAIL_FREQUENCY := 4.0
const DETAIL_WEIGHT := 0.3

# Terrain layer heights (relative to terrain height)
const GRASS_LAYER := 0  # Top layer
const DIRT_LAYER := -4
const STONE_LAYER := -8
const DEEP_STONE_LAYER := -16

func _init() -> void:
	noise = FastNoiseLite.new()
	noise.seed = randi()  # Random seed, you might want to make this configurable
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = BASE_FREQUENCY
	
	# Optional: Add octaves for more detailed terrain
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5

func generate_chunk_data(chunk_data: ChunkData, chunk_pos: Vector3) -> void:
	# Generate terrain data directly into the provided chunk_data
	var world_offset = chunk_pos * ChunkData.CHUNK_SIZE
	
	# Generate base terrain height map first
	var height_map = {}
	for x in range(ChunkData.CHUNK_SIZE):
		for z in range(ChunkData.CHUNK_SIZE):
			var world_x = world_offset.x + x
			var world_z = world_offset.z + z
			
			# Generate height using 2D noise
			var height_noise = noise.get_noise_2d(world_x * 0.8, world_z * 0.8)
			var terrain_height = int((height_noise + 1.0) * 8.0) + 8  # Scale to reasonable height
			height_map[Vector2(x, z)] = terrain_height
	
	# Fill voxels based on height map
	for x in range(ChunkData.CHUNK_SIZE):
		for z in range(ChunkData.CHUNK_SIZE):
			var terrain_height = height_map[Vector2(x, z)]
			
			for y in range(ChunkData.CHUNK_SIZE):
				var world_y = world_offset.y + y
				if world_y < terrain_height:
					# Get voxel type based on depth
					var voxel_type = _get_voxel_type_for_height(world_y, terrain_height)
					chunk_data.set_voxel(Vector3(x, y, z), voxel_type)
				else:
					chunk_data.set_voxel(Vector3(x, y, z), VoxelTypes.Type.AIR)

func _get_voxel_type_for_height(relative_height: int, absolute_height: int) -> int:
	# Surface layer
	if relative_height >= GRASS_LAYER:
		# Add snow on high elevations
		if absolute_height > 64:
			return VoxelTypes.Type.SNOW
		return VoxelTypes.Type.GRASS
	
	# Dirt layer
	if relative_height >= DIRT_LAYER:
		return VoxelTypes.Type.DIRT
	
	# Stone layer
	if relative_height >= STONE_LAYER:
		return VoxelTypes.Type.STONE
	
	# Deep stone layer (could be different types of stone or ores)
	if relative_height >= DEEP_STONE_LAYER:
		# Add some variety to deep stone
		if randf() < 0.1:  # 10% chance for special blocks
			return VoxelTypes.Type.METAL
		return VoxelTypes.Type.STONE
	
	# Bedrock or base stone
	return VoxelTypes.Type.STONE
