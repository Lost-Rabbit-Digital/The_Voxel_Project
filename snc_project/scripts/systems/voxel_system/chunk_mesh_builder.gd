class_name ChunkMeshBuilder
extends Resource

const VOXEL_SIZE: float = 1.0
const TEXTURE_SIZE := 16.0  # Size of each texture in pixels
const ATLAS_SIZE := 256.0   # Total atlas size in pixels

# Texture coordinates in atlas
const TEXTURE_COORDS := {
	"grass_top": Vector2(0, 0),
	"grass_side": Vector2(3, 0),
	"dirt": Vector2(2, 0),
	"stone": Vector2(1, 0)
}

var material_factory: MaterialFactory

# Main function to build mesh
func build_mesh(chunk_data: ChunkData) -> MeshInstance3D:
	if not chunk_data or chunk_data.voxels.is_empty():
		return null
		
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Pre-calculate face checks for better performance
	var face_checks := {}
	for pos in chunk_data.voxels:
		face_checks[pos] = {
			"top": should_add_face(pos + Vector3.UP, chunk_data),
			"bottom": should_add_face(pos + Vector3.DOWN, chunk_data),
			"north": should_add_face(pos + Vector3.FORWARD, chunk_data),
			"south": should_add_face(pos + Vector3.BACK, chunk_data),
			"east": should_add_face(pos + Vector3.RIGHT, chunk_data),
			"west": should_add_face(pos + Vector3.LEFT, chunk_data)
		}
	
	# Build mesh using pre-calculated checks
	for pos in chunk_data.voxels:
		var voxel_type = chunk_data.get_voxel(pos)
		if voxel_type == VoxelTypes.Type.AIR:
			continue
			
		var world_pos = pos * VOXEL_SIZE
		var checks = face_checks[pos]
		
		for face in checks:
			if checks[face]:
				add_face(face, world_pos, voxel_type, surface_tool)
	
	surface_tool.index()
	var array_mesh = surface_tool.commit()
	
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = array_mesh
	mesh_instance.material_override = material_factory.get_default_material()
	
	# Simplified collision
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(16, 16, 16)
	collision.shape = shape
	var body = StaticBody3D.new()
	body.add_child(collision)
	mesh_instance.add_child(body)
	
	return mesh_instance

func add_voxel_faces(world_pos: Vector3, local_pos: Vector3, voxel_type: int, chunk_data: ChunkData, surface_tool: SurfaceTool) -> void:
	# Check each face
	if should_add_face(local_pos + Vector3.UP, chunk_data):
		add_face("top", world_pos, voxel_type, surface_tool)
	if should_add_face(local_pos + Vector3.DOWN, chunk_data):
		add_face("bottom", world_pos, voxel_type, surface_tool)
	if should_add_face(local_pos + Vector3.FORWARD, chunk_data):
		add_face("north", world_pos, voxel_type, surface_tool)
	if should_add_face(local_pos + Vector3.BACK, chunk_data):
		add_face("south", world_pos, voxel_type, surface_tool)
	if should_add_face(local_pos + Vector3.RIGHT, chunk_data):
		add_face("east", world_pos, voxel_type, surface_tool)
	if should_add_face(local_pos + Vector3.LEFT, chunk_data):
		add_face("west", world_pos, voxel_type, surface_tool)

func should_add_face(pos: Vector3, chunk_data: ChunkData) -> bool:
	# If position is within current chunk
	if chunk_data.is_position_valid(pos):
		var voxel = chunk_data.get_voxel(pos)
		# Only add face if neighboring block is air
		return voxel == VoxelTypes.Type.AIR
	
	# If we're at a chunk boundary, check if the adjacent chunk has a block there
	var world_pos = chunk_data.local_to_world(pos)
	var neighbor_chunk = get_chunk_at_position(world_pos)
	
	if neighbor_chunk:
		var local_pos = neighbor_chunk.world_to_local(world_pos)
		if neighbor_chunk.is_position_valid(local_pos):
			return neighbor_chunk.get_voxel(local_pos) == VoxelTypes.Type.AIR
	
	# At world boundaries or unloaded chunks, only show faces
	return true

func get_chunk_at_position(world_pos: Vector3) -> ChunkData:
	var chunk_pos = Vector3(
		floori(world_pos.x / (ChunkData.CHUNK_SIZE)),
		floori(world_pos.y / (ChunkData.CHUNK_SIZE)),
		floori(world_pos.z / (ChunkData.CHUNK_SIZE))
	)
	
	# Try to get the neighboring chunk data
	if chunk_manager and chunk_manager.active_chunks.has(chunk_pos):
		return chunk_manager.active_chunks[chunk_pos].data
	return null

var chunk_manager: ChunkManager  # Add this at the top of the class

func _init(mat_factory: MaterialFactory, chunk_mgr: ChunkManager) -> void:
	material_factory = mat_factory
	chunk_manager = chunk_mgr

func add_face(face: String, pos: Vector3, voxel_type: int, surface_tool: SurfaceTool) -> void:
	var vertices = _get_face_vertices(face, pos)
	var normal = _get_face_normal(face)
	
	# Get the appropriate UVs based on the face
	var uvs = _get_face_uvs(voxel_type, face)
	
	for i in range(6):  # 6 vertices per face (2 triangles)
		surface_tool.set_normal(normal)
		surface_tool.set_uv(uvs[i])
		surface_tool.add_vertex(vertices[i])

func _get_face_vertices(face: String, pos: Vector3) -> PackedVector3Array:
	var vertices = PackedVector3Array()
	match face:
		"top":
			vertices.append_array([
				pos + Vector3(0, 1, 0), pos + Vector3(1, 1, 0), pos + Vector3(1, 1, 1),
				pos + Vector3(0, 1, 0), pos + Vector3(1, 1, 1), pos + Vector3(0, 1, 1)
			])
		"bottom":
			vertices.append_array([
				pos + Vector3(0, 0, 1), pos + Vector3(1, 0, 1), pos + Vector3(1, 0, 0),
				pos + Vector3(0, 0, 1), pos + Vector3(1, 0, 0), pos + Vector3(0, 0, 0)
			])
		"north":
			vertices.append_array([
				pos + Vector3(0, 0, 1), pos + Vector3(0, 1, 1), pos + Vector3(1, 1, 1),
				pos + Vector3(0, 0, 1), pos + Vector3(1, 1, 1), pos + Vector3(1, 0, 1)
			])
		"south":
			vertices.append_array([
				pos + Vector3(1, 0, 0), pos + Vector3(1, 1, 0), pos + Vector3(0, 1, 0),
				pos + Vector3(1, 0, 0), pos + Vector3(0, 1, 0), pos + Vector3(0, 0, 0)
			])
		"east":
			vertices.append_array([
				pos + Vector3(1, 0, 1), pos + Vector3(1, 1, 1), pos + Vector3(1, 1, 0),
				pos + Vector3(1, 0, 1), pos + Vector3(1, 1, 0), pos + Vector3(1, 0, 0)
			])
		"west":
			vertices.append_array([
				pos + Vector3(0, 0, 0), pos + Vector3(0, 1, 0), pos + Vector3(0, 1, 1),
				pos + Vector3(0, 0, 0), pos + Vector3(0, 1, 1), pos + Vector3(0, 0, 1)
			])
	return vertices

func _get_face_normal(face: String) -> Vector3:
	match face:
		"top": return Vector3(0, 1, 0)
		"bottom": return Vector3(0, -1, 0)
		"north": return Vector3(0, 0, 1)
		"south": return Vector3(0, 0, -1)
		"east": return Vector3(1, 0, 0)
		"west": return Vector3(-1, 0, 0)
	return Vector3.ZERO

func _get_face_uvs(voxel_type: int, face: String = "side") -> PackedVector2Array:
	# Get the appropriate texture coordinates based on voxel type and face
	var texture_key := _get_texture_key(voxel_type, face)
	var base_uv: Vector2 = TEXTURE_COORDS[texture_key]
	
	# Calculate UV coordinates based on texture atlas
	var uv_size := TEXTURE_SIZE / ATLAS_SIZE
	var u := base_uv.x * uv_size
	var v := base_uv.y * uv_size
	
	var uvs := PackedVector2Array()
	uvs.resize(6)
	
	# Triangle 1
	uvs[0] = Vector2(u, v + uv_size)           # Bottom-left
	uvs[1] = Vector2(u + uv_size, v + uv_size) # Bottom-right
	uvs[2] = Vector2(u + uv_size, v)           # Top-right
	
	# Triangle 2
	uvs[3] = Vector2(u, v + uv_size)           # Bottom-left
	uvs[4] = Vector2(u + uv_size, v)           # Top-right
	uvs[5] = Vector2(u, v)                     # Top-left
	
	return uvs

func _get_texture_key(voxel_type: int, face: String) -> String:
	match voxel_type:
		VoxelTypes.Type.GRASS:
			match face:
				"top": return "grass_top"
				"bottom": return "dirt"
				_: return "grass_side"
		VoxelTypes.Type.DIRT:
			return "dirt"
		VoxelTypes.Type.STONE:
			return "stone"
		_:
			return "stone" # Default fallback
