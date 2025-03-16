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
		
		# Top face (+Y)
		if should_add_face(pos + Vector3.UP, chunk_data):
			add_top_face(st, world_pos, voxel)
			
		# Bottom face (-Y)
		if should_add_face(pos + Vector3.DOWN, chunk_data):
			add_bottom_face(st, world_pos, voxel)
			
		# North face (+Z)
		if should_add_face(pos + Vector3.FORWARD, chunk_data):
			add_north_face(st, world_pos, voxel)
			
		# South face (-Z)
		if should_add_face(pos + Vector3.BACK, chunk_data):
			add_south_face(st, world_pos, voxel)
			
		# East face (+X)
		if should_add_face(pos + Vector3.RIGHT, chunk_data):
			add_east_face(st, world_pos, voxel)
			
		# West face (-X)
		if should_add_face(pos + Vector3.LEFT, chunk_data):
			add_west_face(st, world_pos, voxel)
	
	st.index()
	var mesh = st.commit()
	
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material_factory.get_default_material()
	
	# Create collision using simplified box for performance
	# In production, you might want to generate a more accurate collision shape
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(16, 16, 16)
	collision.shape = shape
	var body = StaticBody3D.new()
	body.add_child(collision)
	mesh_instance.add_child(body)
	
	return mesh_instance

# Determines if we need to add a face by checking if the adjacent voxel is air
# or if it's outside the chunk boundaries
func should_add_face(pos: Vector3, chunk_data: ChunkData) -> bool:
	# First check if position is within current chunk
	if chunk_data.is_position_valid(pos):
		return chunk_data.get_voxel(pos) == VoxelTypes.Type.AIR
	
	# If not in current chunk, find the chunk it belongs to
	var world_pos = chunk_data.local_to_world(pos)
	var chunk_pos = Vector3(
		floori(world_pos.x / ChunkData.CHUNK_SIZE),
		floori(world_pos.y / ChunkData.CHUNK_SIZE),
		floori(world_pos.z / ChunkData.CHUNK_SIZE)
	)
	
	# Check if the neighboring chunk exists and has a voxel at this position
	if chunk_manager.active_chunks.has(chunk_pos):
		var neighbor = chunk_manager.active_chunks[chunk_pos].data
		# Calculate the local position within the neighboring chunk
		# Using int() to ensure we're dealing with integer positions
		var local_pos = Vector3(
			int(world_pos.x) % ChunkData.CHUNK_SIZE,
			int(world_pos.y) % ChunkData.CHUNK_SIZE,
			int(world_pos.z) % ChunkData.CHUNK_SIZE
		)
		
		# Handle negative coordinates properly
		if local_pos.x < 0: local_pos.x += ChunkData.CHUNK_SIZE
		if local_pos.y < 0: local_pos.y += ChunkData.CHUNK_SIZE
		if local_pos.z < 0: local_pos.z += ChunkData.CHUNK_SIZE
		
		return neighbor.get_voxel(local_pos) == VoxelTypes.Type.AIR
	
	# If neighboring chunk doesn't exist, assume it's air
	return true

# Gets UV coordinates for a specific texture position in the atlas
func get_uv(atlas_pos: Vector2) -> PackedVector2Array:
	var uv_size := TEXTURE_SIZE / ATLAS_SIZE
	var u := atlas_pos.x * uv_size
	var v := atlas_pos.y * uv_size
	
	var uvs := PackedVector2Array()
	uvs.resize(6)
	
	# UV coordinates follow the same order as vertices
	# First triangle
	uvs[0] = Vector2(u, v + uv_size)           # Bottom left
	uvs[1] = Vector2(u + uv_size, v + uv_size) # Bottom right
	uvs[2] = Vector2(u + uv_size, v)           # Top right
	
	# Second triangle
	uvs[3] = Vector2(u, v + uv_size)           # Bottom left
	uvs[4] = Vector2(u + uv_size, v)           # Top right
	uvs[5] = Vector2(u, v)                     # Top left
	
	return uvs

# Gets the texture position for a voxel type and face
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

# Adds vertices with their normals and UVs to the surface tool
func add_vertices(st: SurfaceTool, vertices: PackedVector3Array, normal: Vector3, uvs: PackedVector2Array) -> void:
	for i in range(6):
		st.set_normal(normal)
		st.set_uv(uvs[i])
		st.add_vertex(vertices[i])

# TOP FACE (+Y)
func add_top_face(st: SurfaceTool, pos: Vector3, voxel_type: int) -> void:
	var vertices = PackedVector3Array([
		# First triangle - bottom left, bottom right, top right
		pos + Vector3(0, 1, 0), # Bottom left
		pos + Vector3(1, 1, 0), # Bottom right
		pos + Vector3(1, 1, 1), # Top right
		
		# Second triangle - bottom left, top right, top left
		pos + Vector3(0, 1, 0), # Bottom left
		pos + Vector3(1, 1, 1), # Top right
		pos + Vector3(0, 1, 1)  # Top left
	])
	add_vertices(st, vertices, Vector3.UP, get_uv(get_texture_pos(voxel_type, "top")))

# BOTTOM FACE (-Y)
func add_bottom_face(st: SurfaceTool, pos: Vector3, voxel_type: int) -> void:
	var vertices = PackedVector3Array([
		# First triangle - matches a counter-clockwise winding when viewed from below
		pos + Vector3(0, 0, 1), # Top left
		pos + Vector3(1, 0, 1), # Top right 
		pos + Vector3(1, 0, 0), # Bottom right
		
		# Second triangle
		pos + Vector3(0, 0, 1), # Top left
		pos + Vector3(1, 0, 0), # Bottom right
		pos + Vector3(0, 0, 0)  # Bottom left
	])
	add_vertices(st, vertices, Vector3.DOWN, get_uv(get_texture_pos(voxel_type, "bottom")))

# NORTH FACE (+Z)
func add_north_face(st: SurfaceTool, pos: Vector3, voxel_type: int) -> void:
	var vertices = PackedVector3Array([
		# First triangle
		pos + Vector3(0, 0, 1), # Bottom left
		pos + Vector3(1, 0, 1), # Bottom right
		pos + Vector3(1, 1, 1), # Top right
		
		# Second triangle
		pos + Vector3(0, 0, 1), # Bottom left
		pos + Vector3(1, 1, 1), # Top right
		pos + Vector3(0, 1, 1)  # Top left
	])
	add_vertices(st, vertices, Vector3.FORWARD, get_uv(get_texture_pos(voxel_type, "side")))

# SOUTH FACE (-Z)
func add_south_face(st: SurfaceTool, pos: Vector3, voxel_type: int) -> void:
	var vertices = PackedVector3Array([
		# First triangle - correct counter-clockwise winding when viewed from outside
		pos + Vector3(1, 0, 0), # Bottom right
		pos + Vector3(0, 0, 0), # Bottom left
		pos + Vector3(0, 1, 0), # Top left
		
		# Second triangle
		pos + Vector3(1, 0, 0), # Bottom right
		pos + Vector3(0, 1, 0), # Top left
		pos + Vector3(1, 1, 0)  # Top right
	])
	add_vertices(st, vertices, Vector3.BACK, get_uv(get_texture_pos(voxel_type, "side")))

# EAST FACE (+X)
func add_east_face(st: SurfaceTool, pos: Vector3, voxel_type: int) -> void:
	var vertices = PackedVector3Array([
		# First triangle
		pos + Vector3(1, 0, 1), # Bottom back
		pos + Vector3(1, 0, 0), # Bottom front
		pos + Vector3(1, 1, 0), # Top front
		
		# Second triangle
		pos + Vector3(1, 0, 1), # Bottom back
		pos + Vector3(1, 1, 0), # Top front
		pos + Vector3(1, 1, 1)  # Top back
	])
	add_vertices(st, vertices, Vector3.RIGHT, get_uv(get_texture_pos(voxel_type, "side")))

# WEST FACE (-X)
func add_west_face(st: SurfaceTool, pos: Vector3, voxel_type: int) -> void:
	var vertices = PackedVector3Array([
		# First triangle
		pos + Vector3(0, 0, 0), # Bottom front
		pos + Vector3(0, 0, 1), # Bottom back
		pos + Vector3(0, 1, 1), # Top back
		
		# Second triangle
		pos + Vector3(0, 0, 0), # Bottom front
		pos + Vector3(0, 1, 1), # Top back
		pos + Vector3(0, 1, 0)  # Top front
	])
	add_vertices(st, vertices, Vector3.LEFT, get_uv(get_texture_pos(voxel_type, "side")))
