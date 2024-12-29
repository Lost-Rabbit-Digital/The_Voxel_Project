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
var chunk_manager: ChunkManager

func _init(mat_factory: MaterialFactory, chunk_mgr: ChunkManager) -> void:
	material_factory = mat_factory
	chunk_manager = chunk_mgr
	
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
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	
	for pos in chunk_data.voxels:
		var voxel_type = chunk_data.get_voxel(pos)
		if voxel_type == VoxelTypes.Type.AIR:
			continue
		
		_add_voxel_faces(pos, chunk_data, vertices, normals, uvs)
	
	if vertices.size() == 0:
		return null
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	var material = material_factory.get_material_for_type(VoxelTypes.Type.STONE)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, material)
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	
	_add_collision(mesh_instance)
	return mesh_instance

func _should_add_face(pos: Vector3, chunk_data: ChunkData) -> bool:
	# Check if the position is outside the current chunk bounds
	if pos.x < 0 or pos.x >= ChunkData.CHUNK_SIZE or \
	   pos.y < 0 or pos.y >= ChunkData.CHUNK_SIZE or \
	   pos.z < 0 or pos.z >= ChunkData.CHUNK_SIZE:
		
		# Convert to world position to check neighboring chunks
		var world_pos = chunk_data.local_to_world(pos)
		var neighbor_chunk = chunk_manager.get_chunk_at_position(world_pos)
		
		if neighbor_chunk:
			# Convert world position to local position in the neighboring chunk
			var local_pos = neighbor_chunk.world_to_local(world_pos)
			# Only add face if neighbor block is air
			return neighbor_chunk.get_voxel(local_pos) == VoxelTypes.Type.AIR
		
		# Add face if no neighboring chunk exists (for now)
		return true
	
	# Inside current chunk, add face only if neighbor is air
	return chunk_data.get_voxel(pos) == VoxelTypes.Type.AIR

func _add_voxel_faces(pos: Vector3, chunk_data: ChunkData, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array) -> void:
	var world_pos = pos * VOXEL_SIZE
	
	for face in ["top", "bottom", "north", "south", "east", "west"]:
		var check_pos = pos + _get_normal_for_face(face)
		if _should_add_face(check_pos, chunk_data):
			var face_vertices = _get_vertices_for_face(face, world_pos)
			var normal = _get_normal_for_face(face)
			
			for vertex in face_vertices:
				vertices.push_back(vertex)
				normals.push_back(normal)
			
			# Add UVs for this face
			uvs.append_array([
				Vector2(0, 0),  # First triangle
				Vector2(1, 0),
				Vector2(1, 1),
				Vector2(0, 0),  # Second triangle
				Vector2(1, 1),
				Vector2(0, 1)
			])

func _add_collision(mesh_instance: MeshInstance3D) -> void:
	var body = StaticBody3D.new()
	var shape = ConcavePolygonShape3D.new()
	var collision_shape = CollisionShape3D.new()
	
	shape.set_faces(mesh_instance.mesh.get_faces())
	collision_shape.shape = shape
	body.add_child(collision_shape)
	mesh_instance.add_child(body)
