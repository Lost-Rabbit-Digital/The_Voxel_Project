## TerrainGenerator - Generates terrain using multi-layer Perlin noise
## Creates interesting, varied terrain with hills, valleys, and caves
class_name TerrainGenerator
extends RefCounted

## Noise generators for different scales
var continent_noise: FastNoiseLite  # Large-scale land masses
var terrain_noise: FastNoiseLite    # Medium-scale hills and valleys
var detail_noise: FastNoiseLite     # Small-scale variation
var cave_noise: FastNoiseLite       # 3D caves

## World seed for consistent generation
var world_seed: int = 0

## Terrain parameters
@export var base_height: int = 64           # Sea level
@export var height_scale: float = 32.0     # Max terrain height variation
@export var continent_frequency: float = 0.0005  # Very large features
@export var terrain_frequency: float = 0.02      # Hills and valleys
@export var detail_frequency: float = 0.08       # Small bumps
@export var cave_frequency: float = 0.05         # Cave size
@export var cave_threshold: float = 0.6          # Cave density (higher = more caves)

## Height cache for performance (avoid recalculating same columns)
var height_cache: Dictionary = {}
const MAX_CACHE_SIZE: int = 2000

## Mutex for thread-safe cache access
var cache_mutex: Mutex = Mutex.new()

func _init(seed_value: int = 0) -> void:
	print("[TerrainGenerator] Initializing with seed: %d" % seed_value)
	if seed_value == 0:
		seed_value = randi()
		print("[TerrainGenerator] Generated random seed: %d" % seed_value)

	world_seed = seed_value
	print("[TerrainGenerator] Setting up noise generators...")
	_setup_noise_generators()
	print("[TerrainGenerator] Noise generators ready")

## Initialize all noise generators with seed
func _setup_noise_generators() -> void:
	# Continent noise - very large scale features
	continent_noise = FastNoiseLite.new()
	continent_noise.seed = world_seed
	continent_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	continent_noise.frequency = continent_frequency
	continent_noise.fractal_octaves = 2
	continent_noise.fractal_lacunarity = 2.0
	continent_noise.fractal_gain = 0.5

	# Terrain noise - hills and valleys
	terrain_noise = FastNoiseLite.new()
	terrain_noise.seed = world_seed + 1
	terrain_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	terrain_noise.frequency = terrain_frequency
	terrain_noise.fractal_octaves = 4
	terrain_noise.fractal_lacunarity = 2.0
	terrain_noise.fractal_gain = 0.5

	# Detail noise - small variations
	detail_noise = FastNoiseLite.new()
	detail_noise.seed = world_seed + 2
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail_noise.frequency = detail_frequency
	detail_noise.fractal_octaves = 2
	detail_noise.fractal_lacunarity = 2.0
	detail_noise.fractal_gain = 0.5

	# Cave noise - 3D Perlin for caves
	cave_noise = FastNoiseLite.new()
	cave_noise.seed = world_seed + 3
	cave_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	cave_noise.frequency = cave_frequency
	cave_noise.fractal_octaves = 2

## Generate a complete chunk of voxel data
func generate_chunk(chunk_pos: Vector3i) -> VoxelData:
	print("[TerrainGen] Generating chunk %s..." % chunk_pos)
	var voxel_data := VoxelData.new(chunk_pos)
	var chunk_start := chunk_pos * VoxelData.CHUNK_SIZE

	# OPTIMIZATION: Pre-calculate heights using PackedInt32Array instead of Dictionary
	# Avoids Vector2i allocations and is cache-friendly
	var column_heights := PackedInt32Array()
	column_heights.resize(VoxelData.CHUNK_SIZE * VoxelData.CHUNK_SIZE)

	for x in range(VoxelData.CHUNK_SIZE):
		for z in range(VoxelData.CHUNK_SIZE):
			var world_x := chunk_start.x + x
			var world_z := chunk_start.z + z
			var index := x * VoxelData.CHUNK_SIZE + z
			column_heights[index] = get_terrain_height(world_x, world_z)

	# Fill voxels
	for x in range(VoxelData.CHUNK_SIZE):
		for z in range(VoxelData.CHUNK_SIZE):
			var index := x * VoxelData.CHUNK_SIZE + z
			var terrain_height: int = column_heights[index]

			for y in range(VoxelData.CHUNK_SIZE):
				var world_x := chunk_start.x + x
				var world_y := chunk_start.y + y
				var world_z := chunk_start.z + z
				var world_pos := Vector3i(world_x, world_y, world_z)

				# Determine voxel type
				var voxel_type := _get_voxel_at_position(world_pos, terrain_height)

				# Only set non-air voxels (sparse storage)
				if voxel_type != VoxelTypes.Type.AIR:
					voxel_data.set_voxel(Vector3i(x, y, z), voxel_type)

	# Manage cache size
	if height_cache.size() > MAX_CACHE_SIZE:
		_clear_old_cache_entries()

	return voxel_data

## Get terrain height at a specific XZ position
func get_terrain_height(world_x: int, world_z: int) -> int:
	# OPTIMIZATION: Use integer hash instead of Vector2i to avoid allocations
	var cache_key := _hash_position(world_x, world_z)

	# Check cache first (thread-safe)
	cache_mutex.lock()
	var cached_height: Variant = height_cache.get(cache_key)
	cache_mutex.unlock()

	if cached_height != null:
		return cached_height

	# Calculate using layered noise
	var continent_value := continent_noise.get_noise_2d(world_x, world_z)
	var terrain_value := terrain_noise.get_noise_2d(world_x, world_z)
	var detail_value := detail_noise.get_noise_2d(world_x, world_z)

	# Combine noise layers with different weights
	var combined := continent_value * 0.5 + terrain_value * 0.35 + detail_value * 0.15

	# Convert to height (-1 to 1 -> height range)
	var height := int(base_height + combined * height_scale)

	# Clamp to reasonable values
	height = clampi(height, 0, 255)

	# Cache the result (thread-safe)
	cache_mutex.lock()
	height_cache[cache_key] = height
	cache_mutex.unlock()

	return height

## Determine voxel type at a specific world position
func _get_voxel_at_position(world_pos: Vector3i, terrain_height: int) -> int:
	var y := world_pos.y

	# Above terrain - air
	if y > terrain_height:
		return VoxelTypes.Type.AIR

	# Check for caves underground
	if y < terrain_height - 5:
		var cave_value := cave_noise.get_noise_3d(
			world_pos.x,
			world_pos.y,
			world_pos.z
		)

		# Create cave if noise value is above threshold
		if cave_value > cave_threshold:
			return VoxelTypes.Type.AIR

	# At surface - grass
	if y == terrain_height:
		return VoxelTypes.Type.GRASS

	# Just below surface - dirt (3-4 blocks)
	if y > terrain_height - 4:
		return VoxelTypes.Type.DIRT

	# Check for ores in stone layer
	if y < terrain_height - 4:
		var ore_type := _generate_ore(world_pos, y)
		if ore_type != VoxelTypes.Type.STONE:
			return ore_type

	# Default - stone
	return VoxelTypes.Type.STONE

## Generate ore veins at specific positions
func _generate_ore(world_pos: Vector3i, y: int) -> int:
	# Use a separate noise for ore distribution
	var ore_noise_value := detail_noise.get_noise_3d(
		world_pos.x * 0.5,
		world_pos.y * 0.5,
		world_pos.z * 0.5
	)

	# Coal ore (common, anywhere underground)
	if ore_noise_value > 0.85 and y < base_height:
		return VoxelTypes.Type.COAL_ORE

	# Iron ore (less common, medium depth)
	if ore_noise_value > 0.90 and y < base_height - 20:
		return VoxelTypes.Type.IRON_ORE

	# Gold ore (rare, deep)
	if ore_noise_value > 0.95 and y < base_height - 40:
		return VoxelTypes.Type.GOLD_ORE

	# Default to stone
	return VoxelTypes.Type.STONE

## Clear old entries from height cache
func _clear_old_cache_entries() -> void:
	cache_mutex.lock()
	var keys := height_cache.keys()
	var to_remove := keys.size() - MAX_CACHE_SIZE / 2

	for i in range(to_remove):
		height_cache.erase(keys[i])
	cache_mutex.unlock()

## Set new world seed (clears cache)
func set_world_seed(new_seed: int) -> void:
	world_seed = new_seed
	cache_mutex.lock()
	height_cache.clear()
	cache_mutex.unlock()
	_setup_noise_generators()

## Get current world seed
func get_world_seed() -> int:
	return world_seed

## Clear height cache (useful when changing parameters)
func clear_cache() -> void:
	height_cache.clear()

## Hash function for XZ coordinates to avoid Vector2i allocations
## Uses cantor pairing function for perfect hashing
func _hash_position(x: int, z: int) -> int:
	# Cantor pairing function: uniquely maps two integers to one
	# Handles negative numbers by offsetting to positive space
	var a := x + 32768  # Offset to handle negative coords
	var b := z + 32768
	return ((a + b) * (a + b + 1)) / 2 + b
