# voxel_manager.gd
# Manages voxel creation, updates, and rendering in the game world
# Handles chunk-based terrain generation using Simplex noise

extends Node3D

# Constants for voxel and chunk properties
const VOXEL_SIZE: float = 1.0     # Size of each voxel cube
const CHUNK_SIZE: int = 16        # Size of chunk in voxels (16x16x16)
const MAX_VOXELS: int = 16384     # Safety limit for development (16^3 = 4096)

# Enums for voxel types (will be expanded as needed)
enum VoxelType {
	AIR,
	DIRT,
	STONE,
	METAL,
	GRASS
}

# Dictionary to store active voxels in the current chunk
# Key: Vector3 position, Value: Dictionary with voxel data
var active_voxels: Dictionary = {}

# Noise generator for terrain
var noise: FastNoiseLite

# Resource preloading
var voxel_materials: Dictionary = {
	VoxelType.DIRT: preload_material(Color(0.6, 0.4, 0.2)),   # Brown
	VoxelType.STONE: preload_material(Color(0.7, 0.7, 0.7)),  # Gray
	VoxelType.METAL: preload_material(Color(0.8, 0.8, 0.9)),  # Light metallic
	VoxelType.GRASS: preload_material(Color(0.3, 0.7, 0.3))   # Green
}

# Current chunk properties
var current_chunk_position: Vector3 = Vector3.ZERO
var chunk_node: Node3D

# Debug settings
@export var debug_enabled: bool = true
@export var show_voxel_coords: bool = true

# Noise settings
@export_group("Noise Settings")
@export var noise_seed: int = 1234
@export var noise_frequency: float = 0.05
@export var noise_octaves: int = 4
@export var surface_level: float = 0.0  # Threshold for surface generation

func _ready() -> void:
	if debug_enabled:
		print("VoxelManager: Initializing...")
	
	# Initialize noise generator
	_setup_noise()
	
	# Create initial chunk
	create_chunk(current_chunk_position)

func _setup_noise() -> void:
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.seed = noise_seed
	noise.frequency = noise_frequency
	noise.fractal_octaves = noise_octaves
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5

func create_chunk(chunk_pos: Vector3) -> void:
	# Clear any existing chunk
	if chunk_node:
		chunk_node.queue_free()
		active_voxels.clear()
	
	# Create new chunk node
	chunk_node = Node3D.new()
	chunk_node.name = "Chunk_" + str(chunk_pos)
	add_child(chunk_node)
	
	# Generate terrain for chunk
	generate_terrain(chunk_pos)
	
	if debug_enabled:
		print("VoxelManager: Created chunk at ", chunk_pos)

func generate_terrain(chunk_pos: Vector3) -> void:
	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			for z in range(CHUNK_SIZE):
				var world_pos = chunk_pos * CHUNK_SIZE + Vector3(x, y, z)
				var noise_value = noise.get_noise_3d(
					world_pos.x, world_pos.y, world_pos.z
				)
				
				# Determine voxel type based on noise and height
				var voxel_type = _get_voxel_type_for_terrain(noise_value, world_pos.y)
				
				if voxel_type != VoxelType.AIR:
					create_voxel(Vector3(x, y, z), voxel_type)

func _get_voxel_type_for_terrain(noise_value: float, height: float) -> VoxelType:
	# Basic terrain generation rules
	if noise_value < surface_level:
		return VoxelType.AIR
	
	# Surface layer is grass
	if height > CHUNK_SIZE * 0.75:
		return VoxelType.GRASS
	# Upper layer is dirt
	elif height > CHUNK_SIZE * 0.5:
		return VoxelType.DIRT
	# Lower layer is stone
	else:
		return VoxelType.STONE

# Creates a material with specified color
func preload_material(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	material.metallic = 0.0
	return material

# Creates a single voxel at the specified position with given type
func create_voxel(position: Vector3, type: VoxelType) -> void:
	if active_voxels.size() >= MAX_VOXELS:
		push_warning("VoxelManager: Maximum voxel limit reached!")
		return
	
	if active_voxels.has(position):
		if debug_enabled:
			print("VoxelManager: Voxel already exists at ", position)
		return
	
	# Create mesh instance for the voxel
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	
	# Setup mesh properties
	mesh.size = Vector3.ONE * VOXEL_SIZE
	mesh.surface_set_material(0, voxel_materials[type])
	
	# Setup mesh instance
	mesh_instance.mesh = mesh
	mesh_instance.position = position * VOXEL_SIZE  # Scale position by voxel size
	mesh_instance.name = "Voxel_" + str(position.x) + "_" + str(position.y) + "_" + str(position.z)
	
	# Add collision
	var static_body := StaticBody3D.new()
	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3.ONE * VOXEL_SIZE
	collision_shape.shape = box_shape
	static_body.add_child(collision_shape)
	mesh_instance.add_child(static_body)
	
	# Store voxel data
	active_voxels[position] = {
		"type": type,
		"instance": mesh_instance
	}
	
	# Add to chunk node
	chunk_node.add_child(mesh_instance)
	
	if debug_enabled:
		print("VoxelManager: Created voxel of type ", type, " at ", position)

# Removes a voxel at the specified position
func remove_voxel(position: Vector3) -> void:
	if active_voxels.has(position):
		var voxel_data = active_voxels[position]
		voxel_data.instance.queue_free()
		active_voxels.erase(position)
		
		if debug_enabled:
			print("VoxelManager: Removed voxel at ", position)

# Returns the type of voxel at the specified position
func get_voxel_type(position: Vector3) -> VoxelType:
	if active_voxels.has(position):
		return active_voxels[position].type
	return VoxelType.AIR

# Helper function to convert world position to chunk-local position
func world_to_chunk_position(world_pos: Vector3) -> Vector3:
	return Vector3(
		floor(world_pos.x / CHUNK_SIZE),
		floor(world_pos.y / CHUNK_SIZE),
		floor(world_pos.z / CHUNK_SIZE)
	)

# Helper function to convert world position to voxel position within chunk
func world_to_voxel_position(world_pos: Vector3) -> Vector3:
	return Vector3(
		posmod(world_pos.x, CHUNK_SIZE),
		posmod(world_pos.y, CHUNK_SIZE),
		posmod(world_pos.z, CHUNK_SIZE)
	)
