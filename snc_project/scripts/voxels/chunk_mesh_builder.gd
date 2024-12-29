# chunk_mesh_builder.gd

class_name ChunkMeshBuilder
extends Resource

const VOXEL_SIZE: float = 1.0
const FACE_DIRECTIONS = {
	"top": Vector3(0, 1, 0),
	"bottom": Vector3(0, -1, 0),
	"right": Vector3(1, 0, 0),
	"left": Vector3(-1, 0, 0),
	"front": Vector3(0, 0, 1),
	"back": Vector3(0, 0, -1)
}

var material_factory: MaterialFactory

func _init(mat_factory: MaterialFactory) -> void:
	material_factory = mat_factory

func build_mesh(chunk_data: ChunkData) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Set default material
	st.set_material(material_factory.get_material_for_type(VoxelTypes.Type.STONE))
	
	var faces_added := false
	for pos in chunk_data.voxels:
		if _add_visible_faces(pos, chunk_data, st):
			faces_added = true
	
	if not faces_added:
		return null
		
	st.generate_normals()
	st.generate_tangents()
	
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = st.commit()
	_add_collision(mesh_instance)
	
	return mesh_instance

func _add_visible_faces(pos: Vector3, chunk_data: ChunkData, st: SurfaceTool) -> bool:
	var added_any := false
	
	for face in FACE_DIRECTIONS:
		var neighbor_pos = pos + FACE_DIRECTIONS[face]
		
		# Check if face should be visible (neighbor is air or outside chunk)
		if _should_add_face(neighbor_pos, chunk_data):
			_add_face(pos, face, st, chunk_data.get_voxel(pos))
			added_any = true
	
	return added_any

func _should_add_face(pos: Vector3, chunk_data: ChunkData) -> bool:
	# Check if position is outside chunk bounds
	if pos.x < 0 or pos.y < 0 or pos.z < 0 or \
	   pos.x >= ChunkData.CHUNK_SIZE or pos.y >= ChunkData.CHUNK_SIZE or pos.z >= ChunkData.CHUNK_SIZE:
		return true
	
	# Face should be added if neighbor is air
	return chunk_data.get_voxel(pos) == VoxelTypes.Type.AIR

func _add_face(pos: Vector3, face: String, st: SurfaceTool, voxel_type: VoxelTypes.Type) -> void:
	var base_pos = pos * VOXEL_SIZE
	var vertices = _get_face_vertices(base_pos, face)
	var face_normal = FACE_DIRECTIONS[face]
	var uvs = _get_face_uvs()
	
	# Add vertices for face triangles
	for i in range(6):  # 2 triangles = 6 vertices
		st.set_normal(face_normal)
		st.set_uv(uvs[i])
		st.add_vertex(vertices[i])

func _get_face_vertices(pos: Vector3, face: String) -> Array:
	match face:
		"top":
			return [
				pos + Vector3(0, 1, 0), pos + Vector3(1, 1, 0), pos + Vector3(1, 1, 1),
				pos + Vector3(0, 1, 0), pos + Vector3(1, 1, 1), pos + Vector3(0, 1, 1)
			]
		"bottom":
			return [
				pos + Vector3(0, 0, 1), pos + Vector3(1, 0, 1), pos + Vector3(1, 0, 0),
				pos + Vector3(0, 0, 1), pos + Vector3(1, 0, 0), pos + Vector3(0, 0, 0)
			]
		"right":
			return [
				pos + Vector3(1, 0, 0), pos + Vector3(1, 1, 0), pos + Vector3(1, 1, 1),
				pos + Vector3(1, 0, 0), pos + Vector3(1, 1, 1), pos + Vector3(1, 0, 1)
			]
		"left":
			return [
				pos + Vector3(0, 0, 1), pos + Vector3(0, 1, 1), pos + Vector3(0, 1, 0),
				pos + Vector3(0, 0, 1), pos + Vector3(0, 1, 0), pos + Vector3(0, 0, 0)
			]
		"front":
			return [
				pos + Vector3(0, 0, 1), pos + Vector3(1, 0, 1), pos + Vector3(1, 1, 1),
				pos + Vector3(0, 0, 1), pos + Vector3(1, 1, 1), pos + Vector3(0, 1, 1)
			]
		"back":
			return [
				pos + Vector3(1, 0, 0), pos + Vector3(0, 0, 0), pos + Vector3(0, 1, 0),
				pos + Vector3(1, 0, 0), pos + Vector3(0, 1, 0), pos + Vector3(1, 1, 0)
			]
	return []

func _get_face_uvs() -> Array:
	return [
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1),
		Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)
	]

func _add_collision(mesh_instance: MeshInstance3D) -> void:
	var body := StaticBody3D.new()
	var collision_shape := CollisionShape3D.new()
	var mesh_faces := mesh_instance.mesh.get_faces()
	
	if mesh_faces.size() > 0:
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(mesh_faces)
		collision_shape.shape = shape
		body.add_child(collision_shape)
		mesh_instance.add_child(body)
