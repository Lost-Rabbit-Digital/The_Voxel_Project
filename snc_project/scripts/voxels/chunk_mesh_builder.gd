# chunk_mesh_builder.gd
class_name ChunkMeshBuilder
extends Resource

const VOXEL_SIZE: float = 1.0
var _neighbor_cache: Dictionary = {}

# Static face normals as Vector3 constants
const NORMAL_TOP := Vector3(0, 1, 0)
const NORMAL_BOTTOM := Vector3(0, -1, 0)
const NORMAL_NORTH := Vector3(0, 0, 1)
const NORMAL_SOUTH := Vector3(0, 0, -1)
const NORMAL_EAST := Vector3(1, 0, 0)
const NORMAL_WEST := Vector3(-1, 0, 0)

const VERTEX_SIZE = 3 # xyz
const NORMAL_SIZE = 3 # xyz
const UV_SIZE = 2 # uv
const VERTEX_COUNT_PER_FACE = 6 # 2 triangles

# Use Arrays instead of PackedArrays for building, then convert at the end
var vertices: Array = []
var normals: Array = []
var uvs: Array = []

# Reuse vectors during mesh building
var _temp_vertex := Vector3()
var _temp_normal := Vector3()
var _temp_uv := Vector2()

# Define base texture coordinates as constants
const BASE_TEXTURE_COORDS := {
	"DIRT": Vector2(2, 0),
	"STONE": Vector2(1, 0),
	"GRASS_TOP": Vector2(0, 0),
	"GRASS_SIDE": Vector2(3, 0),
	"METAL": Vector2(3, 0),
	"SNOW": Vector2(2, 4),
	"SAND": Vector2(2, 1)
}

# Create UV lookup during _init instead of as a constant
var _uv_lookup: Dictionary
var _texture_coords: Dictionary

# Update the texture coordinates to match your actual texture atlas
const TEXTURE_SIZE := 16.0  # Size of each texture in the atlas
const ATLAS_SIZE := 256.0   # Total atlas size in pixels

# Height ranges for biome transitions
const DEEP_UNDERGROUND := -32
const SURFACE_LEVEL := 0
const MOUNTAIN_HEIGHT := 32
const SNOW_HEIGHT := 64

var material_factory: MaterialFactory
var chunk_manager: ChunkManager
var _arrays := []
var _surface_tool: SurfaceTool

# Face data initialized in _init
var _face_data: Dictionary
var _uv_arrays: Dictionary

func _init(mat_factory: MaterialFactory, chunk_mgr: ChunkManager) -> void:
	material_factory = mat_factory
	chunk_manager = chunk_mgr
	
	# Initialize UV lookups
	_uv_lookup = {
		VoxelTypes.Type.DIRT: BASE_TEXTURE_COORDS.DIRT,
		VoxelTypes.Type.STONE: BASE_TEXTURE_COORDS.STONE,
		VoxelTypes.Type.GRASS: BASE_TEXTURE_COORDS.GRASS_TOP,
		VoxelTypes.Type.METAL: BASE_TEXTURE_COORDS.METAL,
		VoxelTypes.Type.SNOW: BASE_TEXTURE_COORDS.SNOW,
		VoxelTypes.Type.SAND: BASE_TEXTURE_COORDS.SAND
	}
	
	# Initialize texture coordinates
	_texture_coords = {
		"grass_top": BASE_TEXTURE_COORDS.GRASS_TOP,
		"grass_side": BASE_TEXTURE_COORDS.GRASS_SIDE,
		"dirt": BASE_TEXTURE_COORDS.DIRT,
		"stone": BASE_TEXTURE_COORDS.STONE,
		"snow": BASE_TEXTURE_COORDS.SNOW,
		"sand": BASE_TEXTURE_COORDS.SAND
	}
	
	_initialize_face_data()
	_initialize_uv_data()
	
	
func _initialize_face_data() -> void:
	_face_data = {
		"top": {
			"vertices": PackedVector3Array([
				Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1),  # Triangle 1
				Vector3(0, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1)   # Triangle 2
			]),
			"normal": NORMAL_TOP,
			"check_dir": NORMAL_TOP
		},
		"bottom": {
			"vertices": PackedVector3Array([
				Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0),  # Triangle 1
				Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, 0)   # Triangle 2
			]),
			"normal": NORMAL_BOTTOM,
			"check_dir": NORMAL_BOTTOM
		},
		"north": {
			"vertices": PackedVector3Array([
				Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1),  # Triangle 1
				Vector3(0, 0, 1), Vector3(1, 1, 1), Vector3(1, 0, 1)   # Triangle 2
			]),
			"normal": NORMAL_NORTH,
			"check_dir": NORMAL_NORTH
		},
		"south": {
			"vertices": PackedVector3Array([
				Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0),  # Triangle 1
				Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 0)   # Triangle 2
			]),
			"normal": NORMAL_SOUTH,
			"check_dir": NORMAL_SOUTH
		},
		"east": {
			"vertices": PackedVector3Array([
				Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(1, 1, 0),  # Triangle 1
				Vector3(1, 0, 1), Vector3(1, 1, 0), Vector3(1, 0, 0)   # Triangle 2
			]),
			"normal": NORMAL_EAST,
			"check_dir": NORMAL_EAST
		},
		"west": {
			"vertices": PackedVector3Array([
				Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 1, 1),  # Triangle 1
				Vector3(0, 0, 0), Vector3(0, 1, 1), Vector3(0, 0, 1)   # Triangle 2
			]),
			"normal": NORMAL_WEST,
			"check_dir": NORMAL_WEST
		}
	}
	
func _initialize_uv_data() -> void:
	_uv_arrays = {
		"default": PackedVector2Array([
			Vector2(0, 1), Vector2(1, 1), Vector2(1, 0),
			Vector2(0, 1), Vector2(1, 0), Vector2(0, 0)
		])
	}

func _get_vertices_for_face(face: String, base_pos: Vector3) -> PackedVector3Array:
	var vertices = PackedVector3Array()
	
	# Common vertices for a quad (2 triangles)
	var v0: Vector3
	var v1: Vector3
	var v2: Vector3
	var v3: Vector3
	
	match face:
		"top":
			# Counter-clockwise when viewed from above (looking down -Y)
			v0 = base_pos + Vector3(0, 1, 0)  # Front-left
			v1 = base_pos + Vector3(1, 1, 0)  # Front-right
			v2 = base_pos + Vector3(1, 1, 1)  # Back-right
			v3 = base_pos + Vector3(0, 1, 1)  # Back-left
		"bottom":
			# Counter-clockwise when viewed from below (looking up +Y)
			v0 = base_pos + Vector3(0, 0, 1)  # Back-left
			v1 = base_pos + Vector3(1, 0, 1)  # Back-right
			v2 = base_pos + Vector3(1, 0, 0)  # Front-right
			v3 = base_pos + Vector3(0, 0, 0)  # Front-left
		"north": # +Z face
			v0 = base_pos + Vector3(0, 0, 1)  # Bottom-left
			v1 = base_pos + Vector3(0, 1, 1)  # Top-left
			v2 = base_pos + Vector3(1, 1, 1)  # Top-right
			v3 = base_pos + Vector3(1, 0, 1)  # Bottom-right
		"south": # -Z face
			v0 = base_pos + Vector3(1, 0, 0)  # Bottom-left
			v1 = base_pos + Vector3(1, 1, 0)  # Top-left
			v2 = base_pos + Vector3(0, 1, 0)  # Top-right
			v3 = base_pos + Vector3(0, 0, 0)  # Bottom-right
		"east": # +X face
			v0 = base_pos + Vector3(1, 0, 1)  # Bottom-left
			v1 = base_pos + Vector3(1, 1, 1)  # Top-left
			v2 = base_pos + Vector3(1, 1, 0)  # Top-right
			v3 = base_pos + Vector3(1, 0, 0)  # Bottom-right
		"west": # -X face
			v0 = base_pos + Vector3(0, 0, 0)  # Bottom-left
			v1 = base_pos + Vector3(0, 1, 0)  # Top-left
			v2 = base_pos + Vector3(0, 1, 1)  # Top-right
			v3 = base_pos + Vector3(0, 0, 1)  # Bottom-right
	
	# Create triangles with correct winding order
	vertices.push_back(v0)  # First triangle
	vertices.push_back(v1)
	vertices.push_back(v2)
	
	vertices.push_back(v0)  # Second triangle
	vertices.push_back(v2)
	vertices.push_back(v3)
	
	return vertices

func _get_normal_for_face(face: String) -> Vector3:
	match face:
		"top": return NORMAL_TOP
		"bottom": return NORMAL_BOTTOM
		"north": return NORMAL_NORTH
		"south": return NORMAL_SOUTH
		"east": return NORMAL_EAST
		"west": return NORMAL_WEST
	return Vector3.ZERO

func _get_texture_for_block(world_pos: Vector3, face: String, voxel_type: int) -> String:
	var y := int(world_pos.y)
	
	match voxel_type:
		VoxelTypes.Type.GRASS:
			if face == "top":
				if y > SNOW_HEIGHT:
					return "snow"
				return "grass_top"
			elif face == "bottom":
				return "dirt"
			else:
				return "grass_side"
		VoxelTypes.Type.DIRT:
			if y < DEEP_UNDERGROUND:
				return "stone"
			return "dirt"
		VoxelTypes.Type.STONE:
			if y > SNOW_HEIGHT:
				return "snow" if face == "top" else "stone"
			return "stone"
		VoxelTypes.Type.SNOW:
			return "snow"
		VoxelTypes.Type.SAND:
			return "sand"
		VoxelTypes.Type.METAL:
			return "metal"
		_:
			# Default fallback based on height
			if y < DEEP_UNDERGROUND:
				return "stone"
			elif y > SNOW_HEIGHT:
				return "snow"
			return "dirt"

func _get_uvs_for_texture(texture_name: String, face: String = "") -> PackedVector2Array:
	var base_uv: Vector2 = _texture_coords[texture_name]  # Use instance variable
	var uv_size := TEXTURE_SIZE / ATLAS_SIZE
	
	var uvs := PackedVector2Array()
	uvs.resize(6)
	
	var u := base_uv.x * uv_size
	var v := base_uv.y * uv_size
	
	# Check if this is a grass side texture that needs rotation
	if texture_name == "grass_side" and (face == "north" or face == "south" or face == "east" or face == "west"):
		# Rotated UV mapping for side faces
		# First triangle
		uvs[4] = Vector2(u + uv_size, v)           # Bottom-right
		uvs[5] = Vector2(u + uv_size, v + uv_size) # Top-right
		uvs[3] = Vector2(u, v + uv_size)           # Top-left
		
		# Second triangle
		uvs[2] = Vector2(u + uv_size, v)           # Bottom-right
		uvs[0] = Vector2(u, v + uv_size)           # Top-left
		uvs[1] = Vector2(u, v)                     # Bottom-left
	else:
		# Standard UV mapping for other textures
		# First triangle
		uvs[0] = Vector2(u, v + uv_size)           # Bottom-left
		uvs[1] = Vector2(u + uv_size, v + uv_size) # Bottom-right
		uvs[2] = Vector2(u + uv_size, v)           # Top-right
		
		# Second triangle
		uvs[3] = Vector2(u, v + uv_size)           # Bottom-left
		uvs[4] = Vector2(u + uv_size, v)           # Top-right
		uvs[5] = Vector2(u, v)                     # Top-left
	
	return uvs


func build_mesh(chunk_data: ChunkData) -> MeshInstance3D:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var vertices_added := 0
	
	# Get default material
	var default_material = material_factory.get_material_for_type(VoxelTypes.Type.STONE)
	if not default_material:
		printerr("Failed to get default material")
		return null
	
	# Set default material properties
	var default_props = VoxelTypes.get_material_properties(VoxelTypes.Type.STONE)
	default_material.roughness = default_props.roughness
	default_material.metallic = default_props.metallic
	default_material.metallic_specular = 0.0
	default_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	
	# Use get_voxel_positions() instead of accessing voxels directly
	for pos in chunk_data.get_voxel_positions():
		var current_voxel_type = chunk_data.get_voxel(pos)
		if current_voxel_type == VoxelTypes.Type.AIR:
			continue
			
		var world_pos: Vector3 = pos * VOXEL_SIZE
		_add_voxel_faces(world_pos, pos, current_voxel_type, chunk_data, surface_tool)
		vertices_added += 1
	
	if vertices_added == 0:
		return null
	
	surface_tool.index()
	
	var array_mesh := surface_tool.commit()
	if not array_mesh:
		printerr("Failed to create array mesh")
		return null
	
	array_mesh.surface_set_material(0, default_material)
	
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = array_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	
	_add_collision(mesh_instance)
	return mesh_instance
	
func _add_collision(mesh_instance: MeshInstance3D) -> void:
	var body := StaticBody3D.new()
	var shape := ConcavePolygonShape3D.new()
	var collision_shape := CollisionShape3D.new()
	
	shape.set_faces(mesh_instance.mesh.get_faces())
	collision_shape.shape = shape
	body.add_child(collision_shape)
	mesh_instance.add_child(body)

func clear_neighbor_cache() -> void:
	_neighbor_cache.clear()
	
func _get_face_uvs(face_name: String, voxel_type: int) -> PackedVector2Array:
	var texture_coords: Vector2
	
	# Get the appropriate texture coordinates based on face and type
	match voxel_type:
		VoxelTypes.Type.GRASS:
			match face_name:
				"top": texture_coords = VoxelTypes.get_texture_coords(voxel_type, "top")
				"bottom": texture_coords = VoxelTypes.get_texture_coords(VoxelTypes.Type.DIRT)
				_: texture_coords = VoxelTypes.get_texture_coords(voxel_type, "side")
		_:
			texture_coords = VoxelTypes.get_texture_coords(voxel_type)
	
	var uv_size = TEXTURE_SIZE / ATLAS_SIZE
	var u = texture_coords.x * uv_size
	var v = texture_coords.y * uv_size
	
	var uvs = PackedVector2Array()
	uvs.resize(6)
	
	# Standard UV mapping for a quad
	uvs[0] = Vector2(u, v + uv_size)           # Bottom-left
	uvs[1] = Vector2(u + uv_size, v + uv_size) # Bottom-right
	uvs[2] = Vector2(u + uv_size, v)           # Top-right
	uvs[3] = Vector2(u, v + uv_size)           # Bottom-left
	uvs[4] = Vector2(u + uv_size, v)           # Top-right
	uvs[5] = Vector2(u, v)                     # Top-left
	
	return uvs
	
func _should_add_face(pos: Vector3, chunk_data: ChunkData) -> bool:
	if not chunk_data.is_position_valid(pos):
		# Convert the local position to world coordinates using chunk_data's position
		var world_pos = chunk_data.local_to_world(pos)
		var chunk_pos = chunk_manager.get_chunk_position(world_pos)
		
		if not chunk_pos in _neighbor_cache:
			_neighbor_cache[chunk_pos] = chunk_manager.get_chunk_at_position(world_pos)
			
		var neighbor_chunk = _neighbor_cache[chunk_pos]
		if neighbor_chunk:
			var local_pos = neighbor_chunk.world_to_local(world_pos)
			return neighbor_chunk.get_voxel(local_pos) == VoxelTypes.Type.AIR
		return true
	
	return chunk_data.get_voxel(pos) == VoxelTypes.Type.AIR
	
func _add_voxel_faces(world_pos: Vector3, chunk_pos: Vector3, current_voxel_type: int, chunk_data: ChunkData, surface_tool: SurfaceTool) -> void:
	for face_name in _face_data:
		var face = _face_data[face_name]
		var check_pos = chunk_pos + face.check_dir
		
		if _should_add_face(check_pos, chunk_data):
			# Get the appropriate texture based on height and face
			var texture_name := _get_texture_for_block(world_pos, face_name, current_voxel_type)
			# Pass the face name to get correct UV rotation
			var uvs := _get_uvs_for_texture(texture_name, face_name)
			
			# Add vertices for the face
			for i in range(face.vertices.size()):
				surface_tool.set_normal(face.normal)
				surface_tool.set_uv(uvs[i])
				surface_tool.add_vertex(face.vertices[i] + world_pos)
