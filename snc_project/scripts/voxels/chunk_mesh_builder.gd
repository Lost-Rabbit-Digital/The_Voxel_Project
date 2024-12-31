# chunk_mesh_builder.gd
class_name ChunkMeshBuilder
extends Resource

const VOXEL_SIZE: float = 1.0
var _neighbor_cache: Dictionary = {}

var _vertex_cache := {}
var _mesh_pool := []

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

# Update the texture coordinates to match your actual texture atlas
const TEXTURE_SIZE := 16.0  # Size of each texture in the atlas
const ATLAS_SIZE := 256.0   # Total atlas size in pixels

# Texture coordinates in atlas
const TEXTURE_COORDS := {
	"grass_top": Vector2(0, 0),
	"grass_side": Vector2(3, 0),
	"dirt": Vector2(2, 0),
	"stone": Vector2(1, 0),
	"snow": Vector2(2, 4),
	"sand": Vector2(2, 1),
}

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
	
	# Counter-clockwise winding order for all faces
	match face:
		"top":
			vertices.push_back(base_pos + Vector3(0, 1, 0))  # Bottom-left
			vertices.push_back(base_pos + Vector3(1, 1, 0))  # Bottom-right
			vertices.push_back(base_pos + Vector3(1, 1, 1))  # Top-right
			
			vertices.push_back(base_pos + Vector3(0, 1, 0))  # Bottom-left
			vertices.push_back(base_pos + Vector3(1, 1, 1))  # Top-right
			vertices.push_back(base_pos + Vector3(0, 1, 1))  # Top-left
			
		"bottom":
			vertices.push_back(base_pos + Vector3(0, 0, 0))  # Bottom-left
			vertices.push_back(base_pos + Vector3(1, 0, 1))  # Top-right
			vertices.push_back(base_pos + Vector3(1, 0, 0))  # Bottom-right
			
			vertices.push_back(base_pos + Vector3(0, 0, 0))  # Bottom-left
			vertices.push_back(base_pos + Vector3(0, 0, 1))  # Top-left
			vertices.push_back(base_pos + Vector3(1, 0, 1))  # Top-right
			
		"north":
			vertices.push_back(base_pos + Vector3(0, 0, 1))  # Bottom-left
			vertices.push_back(base_pos + Vector3(1, 0, 1))  # Bottom-right
			vertices.push_back(base_pos + Vector3(1, 1, 1))  # Top-right
			
			vertices.push_back(base_pos + Vector3(0, 0, 1))  # Bottom-left
			vertices.push_back(base_pos + Vector3(1, 1, 1))  # Top-right
			vertices.push_back(base_pos + Vector3(0, 1, 1))  # Top-left
			
		"south":
			vertices.push_back(base_pos + Vector3(0, 0, 0))  # Bottom-left
			vertices.push_back(base_pos + Vector3(1, 1, 0))  # Top-right
			vertices.push_back(base_pos + Vector3(1, 0, 0))  # Bottom-right
			
			vertices.push_back(base_pos + Vector3(0, 0, 0))  # Bottom-left
			vertices.push_back(base_pos + Vector3(0, 1, 0))  # Top-left
			vertices.push_back(base_pos + Vector3(1, 1, 0))  # Top-right
			
		"east":
			vertices.push_back(base_pos + Vector3(1, 0, 0))  # Bottom-left
			vertices.push_back(base_pos + Vector3(1, 0, 1))  # Bottom-right
			vertices.push_back(base_pos + Vector3(1, 1, 1))  # Top-right
			
			vertices.push_back(base_pos + Vector3(1, 0, 0))  # Bottom-left
			vertices.push_back(base_pos + Vector3(1, 1, 1))  # Top-right
			vertices.push_back(base_pos + Vector3(1, 1, 0))  # Top-left
			
		"west":
			vertices.push_back(base_pos + Vector3(0, 0, 0))  # Bottom-left
			vertices.push_back(base_pos + Vector3(0, 1, 1))  # Top-right
			vertices.push_back(base_pos + Vector3(0, 1, 0))  # Top-left
			
			vertices.push_back(base_pos + Vector3(0, 0, 0))  # Bottom-left
			vertices.push_back(base_pos + Vector3(0, 0, 1))  # Bottom-right
			vertices.push_back(base_pos + Vector3(0, 1, 1))  # Top-right
	
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
	
	# Enhanced texture selection based on block type and position
	match voxel_type:
		VoxelTypes.Type.GRASS:
			if face == "top":
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
		_:
			# Default fallback
			if y < DEEP_UNDERGROUND:
				return "stone"
			elif y > SNOW_HEIGHT:
				return "snow"
			return "dirt"

func _get_uvs_for_texture(texture_name: String, face: String = "") -> PackedVector2Array:
	var base_uv: Vector2 = TEXTURE_COORDS[texture_name]
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

func _add_face(world_pos: Vector3, chunk_pos: Vector3, voxel_type: int, chunk_data: ChunkData, surface_tool: SurfaceTool, face_name: String) -> void:
	var face = _face_data[face_name]
	var check_pos = chunk_pos + face.check_dir
	
	if _should_add_face(check_pos, chunk_data):
		var texture_name := _get_texture_for_block(world_pos, face_name, voxel_type)
		var uvs := _get_uvs_for_texture(texture_name, face_name)
		
		for i in range(face.vertices.size()):
			surface_tool.set_normal(face.normal)
			surface_tool.set_uv(uvs[i])
			surface_tool.add_vertex(face.vertices[i] + world_pos)

func _process_voxel_batch(chunk_data: ChunkData, batch_start: int, batch_end: int, surface_tool: SurfaceTool) -> void:
	var voxels = chunk_data.voxels.keys()
	
	for i in range(batch_start, min(batch_end, voxels.size())):
		var pos = voxels[i]
		var voxel_type = chunk_data.get_voxel(pos)
		if voxel_type == VoxelTypes.Type.AIR:
			continue
			
		var world_pos = pos * VOXEL_SIZE
		# Only check faces that might be visible
		if pos.y < ChunkData.CHUNK_SIZE - 1:
			_add_face(world_pos, pos, voxel_type, chunk_data, surface_tool, "top")
		if pos.y > 0:
			_add_face(world_pos, pos, voxel_type, chunk_data, surface_tool, "bottom")
		_add_face(world_pos, pos, voxel_type, chunk_data, surface_tool, "north")
		_add_face(world_pos, pos, voxel_type, chunk_data, surface_tool, "south")
		_add_face(world_pos, pos, voxel_type, chunk_data, surface_tool, "east")
		_add_face(world_pos, pos, voxel_type, chunk_data, surface_tool, "west")

func build_mesh_threaded(chunk_data: ChunkData, callback: Callable) -> void:
	# Validate chunk data
	if not chunk_data:
		push_error("Null chunk data passed to build_mesh_threaded")
		callback.call(null, Vector3.ZERO)
		return
		
	if not is_instance_valid(chunk_data):
		push_error("Invalid chunk data instance in build_mesh_threaded")
		callback.call(null, chunk_data.position if chunk_data else Vector3.ZERO)
		return
		
	if not chunk_data.voxels or chunk_data.voxels.is_empty():
		push_warning("Empty chunk data in build_mesh_threaded for position: " + str(chunk_data.position))
		callback.call(null, chunk_data.position)
		return
		
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var vertices_added := 0
	
	# Process in batches
	for batch_start in range(0, chunk_data.voxels.size(), 64):
		var batch_end = min(batch_start + 64, chunk_data.voxels.size())
		_process_voxel_batch(chunk_data, batch_start, batch_end, surface_tool)
		vertices_added += batch_end - batch_start
		
		# Allow frame to process after each batch
		await Engine.get_main_loop().process_frame
	
	if vertices_added == 0:
		push_warning("No vertices added for chunk at position: " + str(chunk_data.position))
		callback.call(null, chunk_data.position)
		return
	
	# Important: Index and commit the surface
	surface_tool.index()
	var array_mesh = surface_tool.commit()
	
	if not array_mesh or array_mesh.get_surface_count() == 0:
		push_warning("Failed to generate valid mesh for position: " + str(chunk_data.position))
		callback.call(null, chunk_data.position)
		return
		
	callback.call(array_mesh, chunk_data.position)

func build_mesh(chunk_data: ChunkData) -> MeshInstance3D:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Process in batches of 64 voxels
	var voxels = chunk_data.voxels.keys()
	var vertices_added := 0
	
	for batch_start in range(0, voxels.size(), 64):
		var batch_end = min(batch_start + 64, voxels.size())
		_process_voxel_batch(chunk_data, batch_start, batch_end, surface_tool)
		vertices_added += batch_end - batch_start
		
		# Allow frame to process after each batch
		await Engine.get_main_loop().process_frame
	
	if vertices_added == 0:
		return null
	
	surface_tool.index()
	var array_mesh = _get_mesh_from_pool()
	array_mesh = surface_tool.commit()
	
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = array_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	
	# Fix the material assignment
	var material = material_factory.get_default_material()  # Use the new convenience method
	mesh_instance.material_override = material
	
	# Simplified collision
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(16, 16, 16)
	collision.shape = shape
	var body = StaticBody3D.new()
	body.add_child(collision)
	mesh_instance.add_child(body)
	
	return mesh_instance
	
func _get_mesh_from_pool() -> ArrayMesh:
	return _mesh_pool.pop_back() if not _mesh_pool.is_empty() else ArrayMesh.new()

	
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
	
func _get_cached_chunk(chunk_pos: Vector3) -> ChunkData:
	if not chunk_pos in _neighbor_cache:
		_neighbor_cache[chunk_pos] = chunk_manager.get_chunk_at_position(chunk_pos)
	return _neighbor_cache[chunk_pos]
	
func _should_add_face(pos: Vector3, chunk_data: ChunkData) -> bool:
	if chunk_data.is_position_valid(pos):
		return chunk_data.get_voxel(pos) == VoxelTypes.Type.AIR
		
	var world_pos = chunk_data.local_to_world(pos)
	var chunk_pos = chunk_manager.get_chunk_position(world_pos)
	var neighbor_chunk = _get_cached_chunk(chunk_pos)
	
	if not neighbor_chunk:
		return true
	
	var local_pos = neighbor_chunk.world_to_local(world_pos)
	return neighbor_chunk.get_voxel(local_pos) == VoxelTypes.Type.AIR
	
func _add_voxel_faces(world_pos: Vector3, chunk_pos: Vector3, voxel_type: int, chunk_data: ChunkData, surface_tool: SurfaceTool) -> void:
	for face_name in _face_data:
		var face = _face_data[face_name]
		var check_pos = chunk_pos + face.check_dir
		
		if _should_add_face(check_pos, chunk_data):
			# Get the appropriate texture based on height and face
			var texture_name := _get_texture_for_block(world_pos, face_name, voxel_type)
			# Pass the face name to get correct UV rotation
			var uvs := _get_uvs_for_texture(texture_name, face_name)
			
			# Add vertices for the face
			for i in range(face.vertices.size()):
				surface_tool.set_normal(face.normal)
				surface_tool.set_uv(uvs[i])
				surface_tool.add_vertex(face.vertices[i] + world_pos)
