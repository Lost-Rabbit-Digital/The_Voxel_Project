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
var debug_materials: Dictionary = {}

func _init(mat_factory: MaterialFactory, chunk_mgr: ChunkManager) -> void:
	material_factory = mat_factory
	chunk_manager = chunk_mgr
	
func _create_debug_materials() -> void:
	# Check if debug_materials is empty to avoid recreating them
	if not debug_materials.is_empty():
		return
		
	# Create a material for each face direction
	debug_materials["pos_x"] = _create_colored_material(chunk_manager.debug_color_positive_x)
	debug_materials["neg_x"] = _create_colored_material(chunk_manager.debug_color_negative_x)
	debug_materials["pos_y"] = _create_colored_material(chunk_manager.debug_color_positive_y)
	debug_materials["neg_y"] = _create_colored_material(chunk_manager.debug_color_negative_y)
	debug_materials["pos_z"] = _create_colored_material(chunk_manager.debug_color_positive_z)
	debug_materials["neg_z"] = _create_colored_material(chunk_manager.debug_color_negative_z)

func _create_colored_material(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func build_mesh(chunk_data: ChunkData, debug_mode: bool = false) -> MeshInstance3D:
	if not chunk_data or chunk_data.voxels.is_empty():
		return null
	
	var mesh_instance := MeshInstance3D.new()
	
	if debug_mode:
		# Create debug materials if they don't already exist
		_create_debug_materials()
		
		# Create a separate mesh for each face direction
		var mesh = ArrayMesh.new()
		
		# Dictionary to track which directions have faces
		var has_vertices = {
			"pos_x": false,
			"neg_x": false,
			"pos_y": false,
			"neg_y": false,
			"pos_z": false,
			"neg_z": false
		}
		
		# Prepare surface tools for each direction
		var surface_tools = {
			"pos_x": SurfaceTool.new(),
			"neg_x": SurfaceTool.new(),
			"pos_y": SurfaceTool.new(),
			"neg_y": SurfaceTool.new(),
			"pos_z": SurfaceTool.new(),
			"neg_z": SurfaceTool.new()
		}
		
		for key in surface_tools:
			surface_tools[key].begin(Mesh.PRIMITIVE_TRIANGLES)
		
		# Add faces to the appropriate surface tools
		for pos in chunk_data.voxels:
			var voxel = chunk_data.get_voxel(pos)
			if voxel == VoxelTypes.Type.AIR:
				continue
				
			var world_pos = pos * VOXEL_SIZE
			
			# Top face (+Y)
			if should_add_face(pos + Vector3.UP, chunk_data):
				add_top_face(surface_tools["pos_y"], world_pos, voxel)
				has_vertices["pos_y"] = true
			
			# Bottom face (-Y)
			if should_add_face(pos + Vector3.DOWN, chunk_data):
				add_bottom_face(surface_tools["neg_y"], world_pos, voxel)
				has_vertices["neg_y"] = true
			
			# North face (+Z)
			if should_add_face(pos + Vector3.FORWARD, chunk_data):
				add_north_face(surface_tools["pos_z"], world_pos, voxel)
				has_vertices["pos_z"] = true
			
			# South face (-Z)
			if should_add_face(pos + Vector3.BACK, chunk_data):
				add_south_face(surface_tools["neg_z"], world_pos, voxel)
				has_vertices["neg_z"] = true
			
			# East face (+X)
			if should_add_face(pos + Vector3.RIGHT, chunk_data):
				add_east_face(surface_tools["pos_x"], world_pos, voxel)
				has_vertices["pos_x"] = true
			
			# West face (-X)
			if should_add_face(pos + Vector3.LEFT, chunk_data):
				add_west_face(surface_tools["neg_x"], world_pos, voxel)
				has_vertices["neg_x"] = true
		
		# Commit surface tools that have vertices to the mesh
		var material_idx = 0
		var used_directions = []
		
		for key in surface_tools:
			if has_vertices[key]:
				surface_tools[key].index()
				surface_tools[key].commit(mesh)
				used_directions.append(key)
				material_idx += 1
		
		mesh_instance.mesh = mesh
		
		if chunk_manager.debug_visual_normals:
			visualize_normals(mesh_instance)
			
		# Now that mesh is committed with surfaces, we can set the materials
		for i in range(used_directions.size()):
			mesh_instance.set_surface_override_material(i, debug_materials[used_directions[i]])
	else:
		# Non-debug mode - use a single surface tool
		var st = SurfaceTool.new()
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
		mesh_instance.mesh = st.commit()
		mesh_instance.material_override = material_factory.get_default_material()
		
		if chunk_manager.debug_visual_normals:
			visualize_normals(mesh_instance)
	
	# Create collision using simplified box for performance
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
	var neighbor_chunk_pos = chunk_manager.get_chunk_position(world_pos)
	
	# Check if the neighboring chunk exists and has a voxel at this position
	if chunk_manager.active_chunks.has(neighbor_chunk_pos):
		var neighbor = chunk_manager.active_chunks[neighbor_chunk_pos].data
		# Convert the world position back to local position in the neighbor chunk
		var local_pos = neighbor.world_to_local(world_pos)
		
		# Important fix: ensure local_pos is valid before checking voxel type
		if neighbor.is_position_valid(local_pos):
			return neighbor.get_voxel(local_pos) == VoxelTypes.Type.AIR
	
	# If neighboring chunk doesn't exist or position is invalid, assume it's air
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
		# First triangle - correct counter-clockwise winding when viewed from outside
		pos + Vector3(1, 0, 1), # Bottom right
		pos + Vector3(0, 0, 1), # Bottom left
		pos + Vector3(0, 1, 1), # Top left
		
		# Second triangle
		pos + Vector3(1, 0, 1), # Bottom right
		pos + Vector3(0, 1, 1), # Top left
		pos + Vector3(1, 1, 1)  # Top right
	])
	add_vertices(st, vertices, Vector3.FORWARD, get_uv(get_texture_pos(voxel_type, "side")))
	
# SOUTH FACE (-Z)
func add_south_face(st: SurfaceTool, pos: Vector3, voxel_type: int) -> void:
	var vertices = PackedVector3Array([
		# First triangle - correct counter-clockwise winding when viewed from outside
		pos + Vector3(0, 0, 0),  # Bottom left
		pos + Vector3(1, 0, 0),  # Bottom right
		pos + Vector3(1, 1, 0),  # Top right
		
		# Second triangle
		pos + Vector3(0, 0, 0),  # Bottom left
		pos + Vector3(1, 1, 0),  # Top right
		pos + Vector3(0, 1, 0)   # Top left
	])
	add_vertices(st, vertices, Vector3.BACK, get_uv(get_texture_pos(voxel_type, "side")))


# EAST FACE (+X)
func add_east_face(st: SurfaceTool, pos: Vector3, voxel_type: int) -> void:
	var vertices = PackedVector3Array([
		# First triangle - correct counter-clockwise winding when viewed from outside
		pos + Vector3(1, 0, 0),  # Bottom front
		pos + Vector3(1, 0, 1),  # Bottom back
		pos + Vector3(1, 1, 1),  # Top back
		
		# Second triangle
		pos + Vector3(1, 0, 0),  # Bottom front
		pos + Vector3(1, 1, 1),  # Top back
		pos + Vector3(1, 1, 0)   # Top front
	])
	add_vertices(st, vertices, Vector3.RIGHT, get_uv(get_texture_pos(voxel_type, "side")))


# WEST FACE (-X)
func add_west_face(st: SurfaceTool, pos: Vector3, voxel_type: int) -> void:
	var vertices = PackedVector3Array([
		# First triangle - correct counter-clockwise winding when viewed from outside
		pos + Vector3(0, 0, 1),  # Bottom back
		pos + Vector3(0, 0, 0),  # Bottom front
		pos + Vector3(0, 1, 0),  # Top front
		
		# Second triangle
		pos + Vector3(0, 0, 1),  # Bottom back
		pos + Vector3(0, 1, 0),  # Top front
		pos + Vector3(0, 1, 1)   # Top back
	])
	add_vertices(st, vertices, Vector3.LEFT, get_uv(get_texture_pos(voxel_type, "side")))

# Add this to your mesh building function to visualize the normals
func visualize_normals(mesh_instance: MeshInstance3D) -> void:
	var mesh = mesh_instance.mesh
	var imm = ImmediateMesh.new()
	var normal_vis = MeshInstance3D.new()
	normal_vis.mesh = imm
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 0) # Yellow
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	normal_vis.material_override = mat
	
	for s in range(mesh.get_surface_count()):
		var array = mesh.surface_get_arrays(s)
		var vertices = array[Mesh.ARRAY_VERTEX]
		var normals = array[Mesh.ARRAY_NORMAL]
		
		imm.clear_surfaces()
		imm.surface_begin(Mesh.PRIMITIVE_LINES)
		
		for i in range(vertices.size()):
			if i % 3 == 0: # Only show one normal per triangle
				var pos = vertices[i]
				var normal = normals[i]
				imm.surface_add_vertex(pos)
				imm.surface_add_vertex(pos + normal) # Scale normal for visibility
		
		imm.surface_end()
	
	mesh_instance.add_child(normal_vis)
