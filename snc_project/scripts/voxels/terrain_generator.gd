# terrain_generator.gd
class_name TerrainGenerator
extends Resource

var noise: FastNoiseLite
var surface_level: float = 0.0

func _init() -> void:
	_setup_noise()

func _setup_noise() -> void:
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = randi()
	noise.frequency = 0.02  # Lower frequency for smoother terrain
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3  # Reduced octaves for less detail variation
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.4  # Reduced gain for less extreme variations

func generate_chunk_data(chunk_pos: Vector3) -> ChunkData:
	var chunk = ChunkData.new(chunk_pos)
	chunk.position = chunk_pos
	
	# Calculate chunk world bounds
	var chunk_start = chunk_pos * ChunkData.CHUNK_SIZE
	
	# For each position in the chunk
	for x in range(ChunkData.CHUNK_SIZE):
		for z in range(ChunkData.CHUNK_SIZE):
			# Get terrain height once for this column
			var world_x = chunk_start.x + x
			var world_z = chunk_start.z + z
			var terrain_height = get_terrain_height(world_x, world_z)
			
			# Fill column from bottom to terrain height
			for y in range(ChunkData.CHUNK_SIZE):
				var world_y = chunk_start.y + y
				
				# Skip if this Y level is in another chunk
				if world_y > terrain_height + 1:
					continue
					
				var world_pos = Vector3(world_x, world_y, world_z)
				var voxel_type = _get_voxel_type_for_height(world_pos)
				
				if voxel_type != VoxelTypes.Type.AIR:
					chunk.set_voxel(Vector3(x, y, z), voxel_type)
	
	return chunk if chunk.voxels.size() > 0 else null

func get_terrain_height(world_x: float, world_z: float) -> int:
	# Get base noise value (-1 to 1)
	var noise_value = noise.get_noise_2d(world_x, world_z)
	
	# Calculate height consistently
	var BASE_HEIGHT = 16
	var HEIGHT_VARIATION = 16
	var height = BASE_HEIGHT + (noise_value * HEIGHT_VARIATION)
	return int(clampf(height, 4, 32))


func _get_voxel_type_for_height(world_pos: Vector3) -> VoxelTypes.Type:
	# Get the actual terrain height at this x,z coordinate
	var terrain_height = get_terrain_height(world_pos.x, world_pos.z)
	
	# Compare world_pos.y against terrain height
	if world_pos.y > terrain_height:
		return VoxelTypes.Type.AIR
	elif world_pos.y == terrain_height:
		# Only place grass at exact surface height
		return VoxelTypes.Type.GRASS
	elif world_pos.y > terrain_height - 4:
		return VoxelTypes.Type.DIRT
	else:
		return VoxelTypes.Type.STONE
