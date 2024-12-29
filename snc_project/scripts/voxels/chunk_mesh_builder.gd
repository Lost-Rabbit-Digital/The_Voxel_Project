# chunk_mesh_builder.gd
class_name ChunkMeshBuilder
extends Resource

const VOXEL_SIZE: float = 1.0

# Face normals as simple Vector3 constants
const NORMAL_TOP := Vector3(0, 1, 0)
const NORMAL_BOTTOM := Vector3(0, -1, 0)
const NORMAL_NORTH := Vector3(0, 0, 1)
const NORMAL_SOUTH := Vector3(0, 0, -1)
const NORMAL_EAST := Vector3(1, 0, 0)
const NORMAL_WEST := Vector3(-1, 0, 0)

var material_factory: MaterialFactory

func _init(mat_factory: MaterialFactory) -> void:
	material_factory = mat_factory

func _get_vertices_for_face(face: String, base_pos: Vector3) -> PackedVector3Array:
	var vertices = PackedVector3Array()
	match face:
		"top":
			vertices.push_back(base_pos + Vector3(0, 1, 0))
			vertices.push_back(base_pos + Vector3(1, 1, 0))
			vertices.push_back(base_pos + Vector3(1, 1, 1))
			vertices.push_back(base_pos + Vector3(0, 1, 0))
			vertices.push_back(base_pos + Vector3(1, 1, 1))
			vertices.push_back(base_pos + Vector3(0, 1, 1))
		"bottom":
			vertices.push_back(base_pos + Vector3(0, 0, 1))
			vertices.push_back(base_pos + Vector3(1, 0, 1))
			vertices.push_back(base_pos + Vector3(1, 0, 0))
			vertices.push_back(base_pos + Vector3(0, 0, 1))
			vertices.push_back(base_pos + Vector3(1, 0, 0))
			vertices.push_back(base_pos + Vector3(0, 0, 0))
		"north":
			vertices.push_back(base_pos + Vector3(0, 0, 1))
			vertices.push_back(base_pos + Vector3(1, 0, 1))
			vertices.push_back(base_pos + Vector3(1, 1, 1))
			vertices.push_back(base_pos + Vector3(0, 0, 1))
			vertices.push_back(base_pos + Vector3(1, 1, 1))
			vertices.push_back(base_pos + Vector3(0, 1, 1))
		"south":
			vertices.push_back(base_pos + Vector3(0, 0, 0))
			vertices.push_back(base_pos + Vector3(0, 1, 0))
			vertices.push_back(base_pos + Vector3(1, 1, 0))
			vertices.push_back(base_pos + Vector3(0, 0, 0))
			vertices.push_back(base_pos + Vector3(1, 1, 0))
			vertices.push_back(base_pos + Vector3(1, 0, 0))
		"east":
			vertices.push_back(base_pos + Vector3(1, 0, 0))
			vertices.push_back(base_pos + Vector3(1, 1, 0))
			vertices.push_back(base_pos + Vector3(1, 1, 1))
			vertices.push_back(base_pos + Vector3(1, 0, 0))
			vertices.push_back(base_pos + Vector3(1, 1, 1))
			vertices.push_back(base_pos + Vector3(1, 0, 1))
		"west":
			vertices.push_back(base_pos + Vector3(0, 0, 0))
			vertices.push_back(base_pos + Vector3(0, 0, 1))
			vertices.push_back(base_pos + Vector3(0, 1, 1))
			vertices.push_back(base_pos + Vector3(0, 0, 0))
			vertices.push_back(base_pos + Vector3(0, 1, 1))
			vertices.push_back(base_pos + Vector3(0, 1, 0))
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
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	
	# Process each voxel
	for pos in chunk_data.voxels:
		var voxel_type = chunk_data.get_voxel(pos)
		if voxel_type == VoxelTypes.Type.AIR:
			continue
			
		_add_voxel_faces(pos, chunk_data, vertices, normals, uvs)
	
	# If no vertices were generated, return null
	if vertices.size() == 0:
		return null
	
	# Create arrays
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	
	# Create mesh
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	# Setup material
	var material = material_factory.get_material_for_type(VoxelTypes.Type.STONE)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	material.cull_mode = BaseMaterial3D.CULL_BACK
	mesh.surface_set_material(0, material)
	
	# Create mesh instance
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	
	_add_collision(mesh_instance)
	return mesh_instance

func _add_voxel_faces(pos: Vector3, chunk_data: ChunkData, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array) -> void:
	var world_pos = pos * VOXEL_SIZE
	
	for face in ["top", "bottom", "north", "south", "east", "west"]:
		var check_pos = pos + _get_normal_for_face(face)
		if _should_add_face(check_pos, chunk_data):
			var face_vertices = _get_vertices_for_face(face, world_pos)
			# Add vertices
			for vertex in face_vertices:
				vertices.push_back(vertex)
				normals.push_back(_get_normal_for_face(face))
			
			# Add UVs
			for _i in range(6):
				uvs.push_back(Vector2(float(_i > 2), float(_i % 3 == 0)))

func _should_add_face(pos: Vector3, chunk_data: ChunkData) -> bool:
	if pos.x < 0 or pos.y < 0 or pos.z < 0 or \
	   pos.x >= ChunkData.CHUNK_SIZE or pos.y >= ChunkData.CHUNK_SIZE or pos.z >= ChunkData.CHUNK_SIZE:
		return true
	return chunk_data.get_voxel(pos) == VoxelTypes.Type.AIR

func _add_collision(mesh_instance: MeshInstance3D) -> void:
	var body = StaticBody3D.new()
	var shape = ConcavePolygonShape3D.new()
	var collision_shape = CollisionShape3D.new()
	
	shape.set_faces(mesh_instance.mesh.get_faces())
	collision_shape.shape = shape
	body.add_child(collision_shape)
	mesh_instance.add_child(body)
