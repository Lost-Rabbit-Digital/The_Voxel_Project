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

const UV_LOOKUP = {
	VoxelTypes.Type.DIRT: Vector2(0, 0),
	VoxelTypes.Type.STONE: Vector2(1, 0),
	VoxelTypes.Type.GRASS: Vector2(2, 0),
	VoxelTypes.Type.METAL: Vector2(3, 0)
}

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


func build_mesh(chunk_data: ChunkData) -> MeshInstance3D:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Clear any previous data
	_arrays.clear()
	
	var vertices_added := 0
	
	for pos in chunk_data.voxels:
		var voxel_type = chunk_data.get_voxel(pos)
		if voxel_type == VoxelTypes.Type.AIR:
			continue
			
		var world_pos: Vector3 = pos * VOXEL_SIZE
		_add_voxel_faces(world_pos, pos, voxel_type, chunk_data, surface_tool)
		vertices_added += 1
	
	if vertices_added == 0:
		print("No vertices added to mesh")
		return null
	
	# IMPORTANT: Remove this line - we don't want to generate smooth normals
	# surface_tool.generate_normals()
	
	surface_tool.index()
	
	var array_mesh := surface_tool.commit()
	if not array_mesh:
		printerr("Failed to create array mesh")
		return null
		
	var material = material_factory.get_material_for_type(VoxelTypes.Type.STONE)
	if not material:
		printerr("Failed to get material")
		return null
	
	# Adjust material settings for sharper shading
	material.roughness = 1.0
	material.metallic = 0.0
	material.metallic_specular = 0.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	
	array_mesh.surface_set_material(0, material)
	
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
	
func _get_face_uvs(face_name: String, voxel_type: VoxelTypes.Type) -> PackedVector2Array:
	# Get UV coordinates from atlas based on voxel type
	var base_uv = UV_LOOKUP[voxel_type]
	var uv_size = 1.0/16.0  # Assuming 16x16 texture atlas
	
	var uvs = PackedVector2Array()
	uvs.resize(6)  # 6 vertices per face (2 triangles)
	
	var u = base_uv.x * uv_size
	var v = base_uv.y * uv_size
	
	# Standard UV mapping for a quad
	uvs[0] = Vector2(u, v + uv_size)          # Bottom-left
	uvs[1] = Vector2(u + uv_size, v + uv_size) # Bottom-right
	uvs[2] = Vector2(u + uv_size, v)          # Top-right
	
	uvs[3] = Vector2(u, v + uv_size)          # Bottom-left
	uvs[4] = Vector2(u + uv_size, v)          # Top-right
	uvs[5] = Vector2(u, v)                    # Top-left
	
	return uvs
	
func _should_add_face(pos: Vector3, chunk_data: ChunkData) -> bool:
	if not chunk_data.is_position_valid(pos):
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
	
func _add_voxel_faces(world_pos: Vector3, chunk_pos: Vector3, voxel_type: int, chunk_data: ChunkData, surface_tool: SurfaceTool) -> void:
	for face_name in _face_data:
		var face = _face_data[face_name]
		var check_pos = chunk_pos + face.check_dir
		
		if _should_add_face(check_pos, chunk_data):
			# Add vertices for the face
			for i in range(face.vertices.size()):
				# Important: DON'T interpolate normals - use exact face normal
				surface_tool.set_normal(face.normal)
				surface_tool.set_uv(_uv_arrays.default[i])
				surface_tool.add_vertex(face.vertices[i] + world_pos)
