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
	noise.frequency = 0.03  # Reduced frequency for smoother terrain
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5

func generate_chunk_data(chunk_pos: Vector3) -> ChunkData:
	var data = ChunkData.new(chunk_pos)
	var world_offset = chunk_pos * ChunkData.CHUNK_SIZE
	
	# First pass: Generate base terrain
	for x in range(ChunkData.CHUNK_SIZE):
		for z in range(ChunkData.CHUNK_SIZE):
			var world_x = world_offset.x + x
			var world_z = world_offset.z + z
			
			# Generate height using 2D noise for better terrain
			var height_noise = noise.get_noise_2d(world_x * 0.8, world_z * 0.8)
			var terrain_height = int((height_noise + 1.0) * 8.0) + 8  # Scale to reasonable height
			
			for y in range(ChunkData.CHUNK_SIZE):
				var world_y = world_offset.y + y
				
				if world_y < terrain_height:
					# Generate different layers based on depth
					var voxel_type = _get_voxel_type_for_height(world_y, terrain_height)
					data.set_voxel(Vector3(x, y, z), voxel_type)
	
	# Second pass: Generate caves using 3D noise
	for x in range(ChunkData.CHUNK_SIZE):
		for y in range(ChunkData.CHUNK_SIZE):
			for z in range(ChunkData.CHUNK_SIZE):
				var world_x = world_offset.x + x
				var world_y = world_offset.y + y
				var world_z = world_offset.z + z
				
				# Only process points that are solid
				if data.get_voxel(Vector3(x, y, z)) != VoxelTypes.Type.AIR:
					var cave_noise = noise.get_noise_3d(
						world_x * 0.1,
						world_y * 0.1,
						world_z * 0.1
					)
					
					# Create caves where noise value is very high
					if cave_noise > 0.75:
						data.set_voxel(Vector3(x, y, z), VoxelTypes.Type.AIR)
	
	return data

func _get_voxel_type_for_height(world_y: int, terrain_height: int) -> VoxelTypes.Type:
	# Surface layer
	if world_y == terrain_height - 1:
		return VoxelTypes.Type.GRASS
	# Dirt layer
	elif world_y > terrain_height - 4:
		return VoxelTypes.Type.DIRT
	# Stone layer
	else:
		return VoxelTypes.Type.STONE
