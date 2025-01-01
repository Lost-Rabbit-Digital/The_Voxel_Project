class_name ChunkMeshBuilder
extends Resource

const VOXEL_SIZE := 1.0
const TEXTURE_SIZE := 16.0
const ATLAS_SIZE := 256.0

# Texture atlas positions
const UV_GRASS_TOP := Vector2(0, 0)
const UV_STONE := Vector2(1, 0)
const UV_DIRT := Vector2(2, 0)
const UV_GRASS_SIDE := Vector2(3, 0)

var material_factory: MaterialFactory
var chunk_manager: ChunkManager

func _init(mat_factory: MaterialFactory, chunk_mgr: ChunkManager) -> void:
	material_factory = mat_factory
	chunk_manager = chunk_mgr

func build_mesh(chunk_data: ChunkData) -> MeshInstance3D:
	if not chunk_data or chunk_data.voxels.is_empty():
		return null
		
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for pos in chunk_data.voxels:
		var voxel = chunk_data.get_voxel(pos)
		if voxel == VoxelTypes.Type.AIR:
			continue
			
		var world_pos = pos * VOXEL_SIZE
		
		# Top face
		if should_add_face(pos + Vector3.UP, chunk_data):
			add_top_face(st, world_pos, voxel)
			
		# Bottom face
		if should_add_face(pos + Vector3.DOWN, chunk_data):
			add_bottom_face(st, world_pos, voxel)
			
		# North face (Z+)
		if should_add_face(pos + Vector3.FORWARD, chunk_data):
			add_north_face(st, world_pos, voxel)
			
		# South face (Z-)
		if should_add_face(pos + Vector3.BACK, chunk_data):
			add_south_face(st, world_pos, voxel)
			
		# East face (X+)
		if should_add_face(pos + Vector3.RIGHT, chunk_data):
			add_east_face(st, world_pos, voxel)
			
		# West face (X-)
		if should_add_face(pos + Vector3.LEFT, chunk_data):
			add_west_face(st, world_pos, voxel)
	
	st.index()
	var mesh = st.commit()
	
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material_factory.get_default_material()
	
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(16, 16, 16)
	collision.shape = shape
	var body = StaticBody3D.new()
	body.add_child(collision)
	mesh_instance.add_child(body)
	
	return mesh_instance

func should_add_face(pos: Vector3, chunk_data: ChunkData) -> bool:
	if chunk_data.is_position_valid(pos):
		return chunk_data.get_voxel(pos) == VoxelTypes.Type.AIR
	
	var world_pos = chunk_data.local_to_world(pos)
	var chunk_pos = Vector3(
		floori(world_pos.x / ChunkData.CHUNK_SIZE),
		floori(world_pos.y / ChunkData.CHUNK_SIZE),
		floori(world_pos.z / ChunkData.CHUNK_SIZE)
	)
	
	if chunk_manager.active_chunks.has(chunk_pos):
		var neighbor = chunk_manager.active_chunks[chunk_pos].data
		var local_pos = Vector3(
			posmod(world_pos.x, ChunkData.CHUNK_SIZE),
			posmod(world_pos.y, ChunkData.CHUNK_SIZE),
			posmod(world_pos.z, ChunkData.CHUNK_SIZE)
		)
		return neighbor.get_voxel(local_pos) == VoxelTypes.Type.AIR
	
	return true

func get_uv(atlas_pos: Vector2) -> PackedVector2Array:
	var uv_size := TEXTURE_SIZE / ATLAS_SIZE
	var u := atlas_pos.x * uv_size
	var v := atlas_pos.y * uv_size
	
	var uvs := PackedVector2Array()
	uvs.resize(6)
	uvs[0] = Vector2(u, v + uv_size)
	uvs[1] = Vector2(u + uv_size, v + uv_size)
	uvs[2] = Vector2(u + uv_size, v)
	uvs[3] = Vector2(u, v + uv_size)
	uvs[4] = Vector2(u + uv_size, v)
	uvs[5] = Vector2(u, v)
	return uvs

func get_texture_pos(voxel_type: int, face: String) -> Vector2:
	match voxel_type:
		VoxelTypes.Type.GRASS:
			match face:
				"top": return UV_GRASS_TOP
				"bottom": return UV_DIRT
				_: return UV_GRASS_SIDE
		VoxelTypes.Type.DIRT:
			return UV_DIRT
		VoxelTypes.Type.STONE:
			return UV_STONE
		_:
			return UV_STONE

func add_vertices(st: SurfaceTool, vertices: PackedVector3Array, normal: Vector3, uvs: PackedVector2Array) -> void:
	for i in range(6):
		st.set_normal(normal)
		st.set_uv(uvs[i])
		st.add_vertex(vertices[i])

func add_top_face(st: SurfaceTool, pos: Vector3, voxel_type: int) -> void:
	var vertices = PackedVector3Array([
		pos + Vector3(1, 1, 0), # Front right - v1
		pos + Vector3(1, 1, 1), # Back right - v5
		pos + Vector3(0, 1, 1), # Back left - v4
		pos + Vector3(1, 1, 0), # Front right - v1
		pos + Vector3(0, 1, 1), # Back left - v4
		pos + Vector3(0, 1, 0)  # Front left - v0
	])
	add_vertices(st, vertices, Vector3.UP, get_uv(get_texture_pos(voxel_type, "top")))

func add_bottom_face(st: SurfaceTool, pos: Vector3, voxel_type: int) -> void:
	var vertices = PackedVector3Array([
		pos + Vector3(0, 0, 0), # Front left
		pos + Vector3(1, 0, 0), # Front right
		pos + Vector3(1, 0, 1), # Back right
		pos + Vector3(0, 0, 0), # Front left
		pos + Vector3(1, 0, 1), # Back right
		pos + Vector3(0, 0, 1)  # Back left
	])
	add_vertices(st, vertices, Vector3.DOWN, get_uv(get_texture_pos(voxel_type, "bottom")))

func add_north_face(st: SurfaceTool, pos: Vector3, voxel_type: int) -> void:
	var vertices = PackedVector3Array([
		pos + Vector3(0, 0, 1), # Bottom left
		pos + Vector3(1, 0, 1), # Bottom right
		pos + Vector3(1, 1, 1), # Top right
		pos + Vector3(0, 0, 1), # Bottom left
		pos + Vector3(1, 1, 1), # Top right
		pos + Vector3(0, 1, 1)  # Top left
	])
	add_vertices(st, vertices, Vector3.FORWARD, get_uv(get_texture_pos(voxel_type, "side")))

func add_south_face(st: SurfaceTool, pos: Vector3, voxel_type: int) -> void:
	var vertices = PackedVector3Array([
		pos + Vector3(0, 0, 0), # Bottom left
		pos + Vector3(1, 1, 0), # Top right
		pos + Vector3(0, 1, 0), # Top left
		pos + Vector3(1, 0, 0), # Bottom right
		pos + Vector3(1, 1, 0), # Top right
		pos + Vector3(0, 0, 0)  # Bottom left
	])
	add_vertices(st, vertices, Vector3.BACK, get_uv(get_texture_pos(voxel_type, "side")))

func add_east_face(st: SurfaceTool, pos: Vector3, voxel_type: int) -> void:
	var vertices = PackedVector3Array([
		pos + Vector3(1, 0, 0), # Bottom front
		pos + Vector3(1, 0, 1),  # Bottom back
		pos + Vector3(1, 1, 1), # Top back
		pos + Vector3(1, 0, 0), # Bottom front
		pos + Vector3(1, 1, 1), # Top back
		pos + Vector3(1, 1, 0), # Top front
	])
	add_vertices(st, vertices, Vector3.RIGHT, get_uv(get_texture_pos(voxel_type, "side")))

func add_west_face(st: SurfaceTool, pos: Vector3, voxel_type: int) -> void:
	var vertices = PackedVector3Array([
		pos + Vector3(0, 0, 1), # Bottom back
		pos + Vector3(0, 1, 1), # Top back
		pos + Vector3(0, 1, 0), # Top front
		pos + Vector3(0, 0, 1), # Bottom back
		pos + Vector3(0, 1, 0), # Top front
		pos + Vector3(0, 0, 0)  # Bottom front
	])
	add_vertices(st, vertices, Vector3.LEFT, get_uv(get_texture_pos(voxel_type, "side")))
