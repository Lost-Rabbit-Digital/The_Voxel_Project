class_name TerrainGenerator
extends Resource

var noise: FastNoiseLite
var height_cache := {}
const CACHE_SIZE := 1000

func _init() -> void:
	_setup_noise()

func _setup_noise() -> void:
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = randi()
	noise.frequency = 0.02
	noise.fractal_octaves = 2  # Reduced octaves
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.4

func generate_chunk_data(chunk_pos: Vector3) -> ChunkData:
	var chunk = ChunkData.new(chunk_pos)
	var chunk_start = chunk_pos * ChunkData.CHUNK_SIZE
	
	# Pre-calculate heights for the entire chunk
	var heights := {}
	for x in range(ChunkData.CHUNK_SIZE):
		for z in range(ChunkData.CHUNK_SIZE):
			var world_x = chunk_start.x + x
			var world_z = chunk_start.z + z
			heights[Vector2(x, z)] = get_terrain_height(world_x, world_z)
	
	# Fill voxels using pre-calculated heights
	for x in range(ChunkData.CHUNK_SIZE):
		for z in range(ChunkData.CHUNK_SIZE):
			var height = heights[Vector2(x, z)]
			var world_x = chunk_start.x + x
			var world_z = chunk_start.z + z
			
			# Only process Y values that could be visible
			var start_y = maxi(0, chunk_start.y)
			var end_y = mini(ChunkData.CHUNK_SIZE, height - chunk_start.y + 1)
			
			for y in range(start_y, end_y):
				var world_y = chunk_start.y + y
				var world_pos = Vector3(world_x, world_y, world_z)
				var voxel_type = _get_voxel_type_for_height(world_pos, height)
				
				if voxel_type != VoxelTypes.Type.AIR:
					chunk.set_voxel(Vector3(x, y, z), voxel_type)
	
	# Clear old entries from height cache
	while height_cache.size() > CACHE_SIZE:
		height_cache.erase(height_cache.keys()[0])
	
	return chunk if chunk.voxels.size() > 0 else null

func get_terrain_height(world_x: float, world_z: float) -> int:
	var cache_key = Vector2(world_x, world_z)
	if height_cache.has(cache_key):
		return height_cache[cache_key]
		
	var noise_value = noise.get_noise_2d(world_x, world_z)
	var height = int(16 + (noise_value * 16))
	height = clampi(height, 4, 32)
	
	height_cache[cache_key] = height
	return height

func _get_voxel_type_for_height(world_pos: Vector3, terrain_height: int) -> VoxelTypes.Type:
	if world_pos.y > terrain_height:
		return VoxelTypes.Type.AIR
	elif world_pos.y == terrain_height:
		return VoxelTypes.Type.GRASS
	elif world_pos.y > terrain_height - 4:
		return VoxelTypes.Type.DIRT
	else:
		return VoxelTypes.Type.STONE
