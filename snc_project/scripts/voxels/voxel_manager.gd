# voxel_manager.gd
# Manages voxel creation, updates, and rendering in the game world
# Handles individual voxel operations and will be expanded for chunk management

extends Node3D

# Constants for voxel properties
const VOXEL_SIZE: float = 1.0  # Size of each voxel cube
const MAX_VOXELS: int = 1000   # Safety limit for development

# Enums for voxel types (will be expanded as needed)
enum VoxelType {
	AIR,
	DIRT,
	STONE,
	METAL
}

# Dictionary to store active voxels
# Key: Vector3 position, Value: Dictionary with voxel data
var active_voxels: Dictionary = {}

# Resource preloading
var voxel_materials: Dictionary = {
	VoxelType.DIRT: preload_material(Color(0.6, 0.4, 0.2)),  # Brown
	VoxelType.STONE: preload_material(Color(0.7, 0.7, 0.7)), # Gray
	VoxelType.METAL: preload_material(Color(0.8, 0.8, 0.9))  # Light metallic
}

# Debug settings
@export var debug_enabled: bool = true
@export var show_voxel_coords: bool = true

# Called when the node enters the scene tree
func _ready() -> void:
	if debug_enabled:
		print("VoxelManager: Initializing...")
	
	# Create a test pattern of voxels
	_create_test_pattern()

# Creates a material with specified color
func preload_material(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	material.metallic = 0.0
	return material

# Creates a test pattern of voxels for development
func _create_test_pattern() -> void:
	# Create a small 2x2x2 cube of different materials
	var positions = [
		Vector3(0, 0, 0), Vector3(1, 0, 0),
		Vector3(0, 1, 0), Vector3(1, 1, 0),
		Vector3(0, 0, 1), Vector3(1, 0, 1)
	]
	
	var types = [
		VoxelType.DIRT, VoxelType.STONE,
		VoxelType.METAL, VoxelType.DIRT,
		VoxelType.STONE, VoxelType.METAL
	]
	
	for i in range(positions.size()):
		create_voxel(positions[i], types[i])

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
	mesh_instance.position = position
	mesh_instance.name = "Voxel_" + str(position.x) + "_" + str(position.y) + "_" + str(position.z)
	
	# Add collision (optional but useful for interaction)
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
	
	# Add to scene tree
	add_child(mesh_instance)
	
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
