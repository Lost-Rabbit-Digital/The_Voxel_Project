# voxel_manager.gd
extends Node3D

const VOXEL_SIZE: float = 1.0
const CHUNK_SIZE: int = 16
const MAX_VOXELS: int = 16384

enum VoxelType {
	AIR,
	DIRT,
	STONE,
	METAL,
	GRASS
}

# Face direction vectors for neighbor checking
const FACE_DIRECTIONS = {
	"top": Vector3(0, 1, 0),
	"bottom": Vector3(0, -1, 0),
	"right": Vector3(1, 0, 0),
	"left": Vector3(-1, 0, 0),
	"front": Vector3(0, 0, 1),
	"back": Vector3(0, 0, -1)
}

var active_voxels: Dictionary = {}
var noise: FastNoiseLite
var current_chunk_position: Vector3 = Vector3.ZERO
var chunk_node: Node3D

# Materials
var voxel_materials: Dictionary = {}

# Debug settings
@export var debug_enabled: bool = true
@export var show_voxel_coords: bool = true

# Noise settings
@export_group("Noise Settings")
@export var use_random_seed: bool = true
@export var noise_seed: int = 1234
@export var noise_frequency: float = 0.05
@export var noise_octaves: int = 4
@export var surface_level: float = 0.0

func _ready() -> void:
	if debug_enabled:
		print("VoxelManager: Initializing...")
	
	_setup_materials()
	_setup_noise()
	create_chunk(current_chunk_position)

func _setup_materials() -> void:
	voxel_materials = {
		VoxelType.DIRT: _create_material(Color(0.6, 0.4, 0.2)),
		VoxelType.STONE: _create_material(Color(0.7, 0.7, 0.7)),
		VoxelType.METAL: _create_material(Color(0.8, 0.8, 0.9)),
		VoxelType.GRASS: _create_material(Color(0.3, 0.7, 0.3))
	}

func _create_material(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	material.metallic = 0.0
	return material

func _setup_noise() -> void:
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	if use_random_seed:
		randomize()
		noise.seed = randi()
	else:
		noise.seed = noise_seed
	noise.frequency = noise_frequency
	noise.fractal_octaves = noise_octaves
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5

func create_chunk(chunk_pos: Vector3) -> void:
	if chunk_node:
		chunk_node.queue_free()
		active_voxels.clear()
	
	chunk_node = Node3D.new()
	chunk_node.name = "Chunk_" + str(chunk_pos)
	add_child(chunk_node)
	
	# Generate terrain data first
	_generate_terrain_data(chunk_pos)
	
	# Then create optimized meshes
	_create_optimized_chunk_mesh()
	
	if debug_enabled:
		print("VoxelManager: Created optimized chunk at ", chunk_pos)

func _generate_terrain_data(chunk_pos: Vector3) -> void:
	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			for z in range(CHUNK_SIZE):
				var world_pos = chunk_pos * CHUNK_SIZE + Vector3(x, y, z)
				var noise_value = noise.get_noise_3d(
					world_pos.x, world_pos.y, world_pos.z
				)
				
				var voxel_type = _get_voxel_type_for_terrain(noise_value, world_pos.y)
				if voxel_type != VoxelType.AIR:
					active_voxels[Vector3(x, y, z)] = {
						"type": voxel_type,
						"visible_faces": {}  # Will be populated during mesh generation
					}

func _create_optimized_chunk_mesh() -> void:
	# Skip if no voxels to render
	if active_voxels.is_empty():
		if debug_enabled:
			print("No voxels to render in chunk")
		return
		
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Set material before adding vertices
	st.set_material(voxel_materials[VoxelType.STONE])
	
	# Track if we've added any faces
	var faces_added := false
	
	# Process each voxel
	for pos in active_voxels:
		var voxel = active_voxels[pos]
		if _add_visible_faces_st(pos, st):
			faces_added = true
	
	# Only create mesh if we have faces to render
	if not faces_added:
		if debug_enabled:
			print("No visible faces in chunk")
		return
	
	# Generate normals and create the mesh
	st.generate_normals()
	
	# Attempt to commit the mesh
	var array_mesh: ArrayMesh
	
	# Use a try-catch block since commit can fail
	array_mesh = st.commit()
	
	if not array_mesh or array_mesh.get_surface_count() == 0:
		if debug_enabled:
			print("Failed to create valid mesh")
		return
	
	# Create mesh instance
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = array_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	
	# Create collision
	var static_body := StaticBody3D.new()
	var collision_shape := CollisionShape3D.new()
	
	# Get mesh faces for collision
	var faces := array_mesh.get_faces()
	if faces.size() > 0:
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		collision_shape.shape = shape
		static_body.add_child(collision_shape)
		mesh_instance.add_child(static_body)
	
	# Add to chunk
	chunk_node.add_child(mesh_instance)
	
	if debug_enabled:
		print("Successfully created chunk mesh with ", faces.size() / 3, " triangles")

func _add_visible_faces_st(pos: Vector3, st: SurfaceTool) -> bool:
	var added_any := false
	
	for face in FACE_DIRECTIONS:
		var neighbor_pos = pos + FACE_DIRECTIONS[face]
		
		# Check if face should be visible
		if !_has_solid_voxel(neighbor_pos):
			_add_face_st(pos, face, st)
			added_any = true
	
	return added_any

func _add_face_st(pos: Vector3, face: String, st: SurfaceTool) -> void:
	var base_pos = pos * VOXEL_SIZE
	var face_vertices = _get_face_vertices(base_pos, face)
	var face_uvs = _get_face_uvs()
	var face_normal = FACE_DIRECTIONS[face]
	
	# Ensure we have the correct number of vertices
	if face_vertices.size() != 6 or face_uvs.size() != 6:
		push_warning("Invalid number of vertices or UVs for face")
		return
		
	# Add first triangle
	for i in range(3):
		st.set_normal(face_normal)
		st.set_uv(face_uvs[i])
		st.add_vertex(face_vertices[i])
		
	# Add second triangle
	for i in range(3, 6):
		st.set_normal(face_normal)
		st.set_uv(face_uvs[i])
		st.add_vertex(face_vertices[i])

func _get_face_vertices(pos: Vector3, face: String) -> Array:
	var vertices = []
	match face:
		"top":
			vertices = [
				pos + Vector3(0, 1, 0), pos + Vector3(1, 1, 0), pos + Vector3(1, 1, 1),
				pos + Vector3(0, 1, 0), pos + Vector3(1, 1, 1), pos + Vector3(0, 1, 1)
			]
		"bottom":
			vertices = [
				pos + Vector3(0, 0, 1), pos + Vector3(1, 0, 1), pos + Vector3(1, 0, 0),
				pos + Vector3(0, 0, 1), pos + Vector3(1, 0, 0), pos + Vector3(0, 0, 0)
			]
		"right":
			vertices = [
				pos + Vector3(1, 0, 0), pos + Vector3(1, 1, 0), pos + Vector3(1, 1, 1),
				pos + Vector3(1, 0, 0), pos + Vector3(1, 1, 1), pos + Vector3(1, 0, 1)
			]
		"left":
			vertices = [
				pos + Vector3(0, 0, 1), pos + Vector3(0, 1, 1), pos + Vector3(0, 1, 0),
				pos + Vector3(0, 0, 1), pos + Vector3(0, 1, 0), pos + Vector3(0, 0, 0)
			]
		"front":
			vertices = [
				pos + Vector3(0, 0, 1), pos + Vector3(1, 0, 1), pos + Vector3(1, 1, 1),
				pos + Vector3(0, 0, 1), pos + Vector3(1, 1, 1), pos + Vector3(0, 1, 1)
			]
		"back":
			vertices = [
				pos + Vector3(1, 0, 0), pos + Vector3(0, 0, 0), pos + Vector3(0, 1, 0),
				pos + Vector3(1, 0, 0), pos + Vector3(0, 1, 0), pos + Vector3(1, 1, 0)
			]
	return vertices

func _get_face_uvs() -> Array:
	# Simple UV mapping for each face
	return [
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1),
		Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)
	]

func _has_solid_voxel(pos: Vector3) -> bool:
	# Check if position is outside chunk bounds
	if pos.x < 0 or pos.y < 0 or pos.z < 0 or \
	   pos.x >= CHUNK_SIZE or pos.y >= CHUNK_SIZE or pos.z >= CHUNK_SIZE:
		return false
	
	return active_voxels.has(pos)

func _get_voxel_type_for_terrain(noise_value: float, height: float) -> VoxelType:
	if noise_value < surface_level:
		return VoxelType.AIR
	
	if height > CHUNK_SIZE * 0.75:
		return VoxelType.GRASS
	elif height > CHUNK_SIZE * 0.5:
		return VoxelType.DIRT
	else:
		return VoxelType.STONE

# Helper functions for position conversion
func world_to_chunk_position(world_pos: Vector3) -> Vector3:
	return Vector3(
		floor(world_pos.x / CHUNK_SIZE),
		floor(world_pos.y / CHUNK_SIZE),
		floor(world_pos.z / CHUNK_SIZE)
	)

func world_to_voxel_position(world_pos: Vector3) -> Vector3:
	return Vector3(
		posmod(world_pos.x, CHUNK_SIZE),
		posmod(world_pos.y, CHUNK_SIZE),
		posmod(world_pos.z, CHUNK_SIZE)
	)
