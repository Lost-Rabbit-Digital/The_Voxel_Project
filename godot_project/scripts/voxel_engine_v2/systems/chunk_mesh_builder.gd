## ChunkMeshBuilder - Generates optimized meshes for chunks
## Uses naive face culling (greedy meshing will be Phase 2)
## Properly handles cross-chunk face culling using neighbor references
class_name ChunkMeshBuilder
extends RefCounted

## Voxel size in world units (1.0 = 1 meter cube)
const VOXEL_SIZE: float = 1.0

## Face direction vectors
const FACE_NORMALS := {
	"top": Vector3.UP,
	"bottom": Vector3.DOWN,
	"north": Vector3.FORWARD,
	"south": Vector3.BACK,
	"east": Vector3.RIGHT,
	"west": Vector3.LEFT
}

## Default material (will be replaced with textured material in Phase 2)
var default_material: StandardMaterial3D

## Reference to chunk manager (for neighbor queries)
var chunk_manager: ChunkManager

func _init(manager: ChunkManager = null) -> void:
	print("[MeshBuilder] Initializing...")
	chunk_manager = manager
	_create_default_material()
	print("[MeshBuilder] Ready")

## Create a simple default material for testing
func _create_default_material() -> void:
	default_material = StandardMaterial3D.new()
	default_material.albedo_color = Color(0.7, 0.7, 0.7)
	default_material.roughness = 1.0
	default_material.cull_mode = BaseMaterial3D.CULL_BACK

## Build mesh for a chunk
func build_mesh(chunk: Chunk) -> MeshInstance3D:
	if not chunk or not chunk.voxel_data:
		print("[MeshBuilder] ERROR: Invalid chunk or voxel data")
		return null

	# Skip empty chunks
	if chunk.is_empty():
		print("[MeshBuilder] Chunk %s is empty, skipping mesh" % chunk.position)
		return null

	print("[MeshBuilder] Building mesh for chunk %s..." % chunk.position)

	# Create surface tool for mesh building
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var solid_voxels := 0
	var vertices_added := 0

	# Iterate through all voxels in the chunk
	for x in range(VoxelData.CHUNK_SIZE):
		for y in range(VoxelData.CHUNK_SIZE):
			for z in range(VoxelData.CHUNK_SIZE):
				var local_pos := Vector3i(x, y, z)
				var voxel_type := chunk.get_voxel(local_pos)

				# Skip air voxels
				if voxel_type == VoxelTypes.Type.AIR:
					continue

				solid_voxels += 1

				# Skip transparent voxels for now (Phase 2 feature)
				if VoxelTypes.is_transparent(voxel_type):
					continue

				# Add visible faces (returns number of vertices added)
				var verts := _add_voxel_faces(st, chunk, local_pos, voxel_type)
				vertices_added += verts

	print("[MeshBuilder]   Processed %d solid voxels" % solid_voxels)
	print("[MeshBuilder]   Added %d vertices (%d triangles)" % [vertices_added, vertices_added / 3])

	# Check if we have any geometry
	if vertices_added == 0:
		print("[MeshBuilder] No vertices to mesh, returning null")
		return null

	# Index the mesh for optimization (manual normals already set, no auto-generation needed)
	st.index()

	# Create mesh instance
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = default_material

	# Enable shadow casting
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	print("[MeshBuilder] ✓ Mesh created successfully")
	return mesh_instance

## Add visible faces for a single voxel
## Returns the number of vertices added (6 per face)
func _add_voxel_faces(st: SurfaceTool, chunk: Chunk, local_pos: Vector3i, voxel_type: int) -> int:
	var world_pos := local_pos * VOXEL_SIZE
	var vertices_added := 0

	# Check each face direction (each face adds 6 vertices)
	if _should_add_face(chunk, local_pos, Vector3i.UP):
		_add_top_face(st, world_pos, voxel_type)
		vertices_added += 6

	if _should_add_face(chunk, local_pos, Vector3i.DOWN):
		_add_bottom_face(st, world_pos, voxel_type)
		vertices_added += 6

	if _should_add_face(chunk, local_pos, Vector3i.FORWARD):
		_add_north_face(st, world_pos, voxel_type)
		vertices_added += 6

	if _should_add_face(chunk, local_pos, Vector3i.BACK):
		_add_south_face(st, world_pos, voxel_type)
		vertices_added += 6

	if _should_add_face(chunk, local_pos, Vector3i.RIGHT):
		_add_east_face(st, world_pos, voxel_type)
		vertices_added += 6

	if _should_add_face(chunk, local_pos, Vector3i.LEFT):
		_add_west_face(st, world_pos, voxel_type)
		vertices_added += 6

	return vertices_added

## Determine if a face should be added (face culling logic)
## Checks both within chunk and across chunk boundaries
func _should_add_face(chunk: Chunk, local_pos: Vector3i, direction: Vector3i) -> bool:
	var neighbor_pos := local_pos + direction

	# Check if neighbor is within current chunk
	if chunk.voxel_data.is_position_valid(neighbor_pos):
		var neighbor_voxel := chunk.get_voxel(neighbor_pos)
		# Add face if neighbor is air or transparent
		return neighbor_voxel == VoxelTypes.Type.AIR or VoxelTypes.is_transparent(neighbor_voxel)

	# Neighbor is outside chunk, need to check neighboring chunk
	var neighbor_chunk := _get_neighbor_chunk(chunk, direction)

	if neighbor_chunk:
		# Convert position to neighbor chunk's local space
		var world_pos := chunk.local_to_world(neighbor_pos)
		var neighbor_local := neighbor_chunk.world_to_local(world_pos)

		if neighbor_chunk.voxel_data.is_position_valid(neighbor_local):
			var neighbor_voxel := neighbor_chunk.get_voxel(neighbor_local)
			# Add face if neighbor is air or transparent
			return neighbor_voxel == VoxelTypes.Type.AIR or VoxelTypes.is_transparent(neighbor_voxel)

	# If neighbor chunk doesn't exist, assume it's air (render the face)
	return true

## Get neighboring chunk based on direction
func _get_neighbor_chunk(chunk: Chunk, direction: Vector3i) -> Chunk:
	if direction == Vector3i.UP:
		return chunk.get_neighbor("up")
	elif direction == Vector3i.DOWN:
		return chunk.get_neighbor("down")
	elif direction == Vector3i.FORWARD:
		# FORWARD is (0,0,-1) which is negative Z, maps to "south"
		return chunk.get_neighbor("south")
	elif direction == Vector3i.BACK:
		# BACK is (0,0,1) which is positive Z, maps to "north"
		return chunk.get_neighbor("north")
	elif direction == Vector3i.RIGHT:
		return chunk.get_neighbor("east")
	elif direction == Vector3i.LEFT:
		return chunk.get_neighbor("west")
	return null

## Get a pastel color based on y-level (height-based coloring)
func _get_color_for_y_level(y_pos: float) -> Color:
	# Normalize y position to 0-1 range (assuming terrain between y=0 and y=128)
	var normalized_y: float = clamp(y_pos / 128.0, 0.0, 1.0)

	# Create pastel gradient from bottom to top
	# Low elevations: pastel blue-green (water/low areas)
	# Mid elevations: pastel green-yellow (plains/hills)
	# High elevations: pastel pink-purple (mountains/peaks)

	if normalized_y < 0.33:
		# Bottom third: pastel aqua to mint green
		var t: float = normalized_y / 0.33
		return Color(0.7, 0.9, 0.85).lerp(Color(0.75, 0.95, 0.75), t)
	elif normalized_y < 0.66:
		# Middle third: mint green to pastel yellow
		var t: float = (normalized_y - 0.33) / 0.33
		return Color(0.75, 0.95, 0.75).lerp(Color(0.95, 0.95, 0.7), t)
	else:
		# Top third: pastel yellow to pastel pink-purple
		var t: float = (normalized_y - 0.66) / 0.34
		return Color(0.95, 0.95, 0.7).lerp(Color(0.95, 0.75, 0.9), t)

## Add a quad (two triangles) with color
## Vertices should be in counter-clockwise order when viewed from outside
func _add_quad(st: SurfaceTool, vertices: PackedVector3Array, normal: Vector3, color: Color) -> void:
	# First triangle (0, 1, 2) - counter-clockwise
	st.set_color(color)
	st.set_normal(normal)
	st.add_vertex(vertices[0])
	st.set_normal(normal)
	st.add_vertex(vertices[1])
	st.set_normal(normal)
	st.add_vertex(vertices[2])

	# Second triangle (0, 2, 3) - counter-clockwise
	st.set_color(color)
	st.set_normal(normal)
	st.add_vertex(vertices[0])
	st.set_normal(normal)
	st.add_vertex(vertices[2])
	st.set_normal(normal)
	st.add_vertex(vertices[3])

## Top face (+Y) - looking down from above, vertices are counter-clockwise
func _add_top_face(st: SurfaceTool, pos: Vector3, voxel_type: int) -> void:
	var vertices := PackedVector3Array([
		pos + Vector3(0, VOXEL_SIZE, 0),              # back-left
		pos + Vector3(VOXEL_SIZE, VOXEL_SIZE, 0),      # back-right
		pos + Vector3(VOXEL_SIZE, VOXEL_SIZE, VOXEL_SIZE), # front-right
		pos + Vector3(0, VOXEL_SIZE, VOXEL_SIZE)       # front-left
	])
	var color := _get_color_for_y_level(pos.y)
	_add_quad(st, vertices, Vector3.UP, color * 1.0)  # Brightest (facing sky)

## Bottom face (-Y) - looking up from below, vertices are counter-clockwise
func _add_bottom_face(st: SurfaceTool, pos: Vector3, voxel_type: int) -> void:
	var vertices := PackedVector3Array([
		pos + Vector3(0, 0, 0),              # back-left
		pos + Vector3(0, 0, VOXEL_SIZE),      # front-left
		pos + Vector3(VOXEL_SIZE, 0, VOXEL_SIZE), # front-right
		pos + Vector3(VOXEL_SIZE, 0, 0)       # back-right
	])
	var color := _get_color_for_y_level(pos.y)
	_add_quad(st, vertices, Vector3.DOWN, color * 0.6)  # Darker (shadow)

## North face (+Z) - looking from front, vertices are counter-clockwise
func _add_north_face(st: SurfaceTool, pos: Vector3, voxel_type: int) -> void:
	var vertices := PackedVector3Array([
		pos + Vector3(0, 0, VOXEL_SIZE),              # bottom-left
		pos + Vector3(0, VOXEL_SIZE, VOXEL_SIZE),      # top-left
		pos + Vector3(VOXEL_SIZE, VOXEL_SIZE, VOXEL_SIZE), # top-right
		pos + Vector3(VOXEL_SIZE, 0, VOXEL_SIZE)       # bottom-right
	])
	var color := _get_color_for_y_level(pos.y)
	_add_quad(st, vertices, Vector3.FORWARD, color * 0.85)  # Slightly shaded

## South face (-Z) - looking from back, vertices are counter-clockwise
func _add_south_face(st: SurfaceTool, pos: Vector3, voxel_type: int) -> void:
	var vertices := PackedVector3Array([
		pos + Vector3(VOXEL_SIZE, 0, 0),      # bottom-right (when viewing from back)
		pos + Vector3(VOXEL_SIZE, VOXEL_SIZE, 0), # top-right
		pos + Vector3(0, VOXEL_SIZE, 0),      # top-left
		pos + Vector3(0, 0, 0)                # bottom-left
	])
	var color := _get_color_for_y_level(pos.y)
	_add_quad(st, vertices, Vector3.BACK, color * 0.85)  # Slightly shaded

## East face (+X) - looking from right side, vertices are counter-clockwise
func _add_east_face(st: SurfaceTool, pos: Vector3, voxel_type: int) -> void:
	var vertices := PackedVector3Array([
		pos + Vector3(VOXEL_SIZE, 0, VOXEL_SIZE),  # bottom-front
		pos + Vector3(VOXEL_SIZE, VOXEL_SIZE, VOXEL_SIZE), # top-front
		pos + Vector3(VOXEL_SIZE, VOXEL_SIZE, 0),  # top-back
		pos + Vector3(VOXEL_SIZE, 0, 0)            # bottom-back
	])
	var color := _get_color_for_y_level(pos.y)
	_add_quad(st, vertices, Vector3.RIGHT, color * 0.75)  # Medium shade

## West face (-X) - looking from left side, vertices are counter-clockwise
func _add_west_face(st: SurfaceTool, pos: Vector3, voxel_type: int) -> void:
	var vertices := PackedVector3Array([
		pos + Vector3(0, 0, 0),           # bottom-back
		pos + Vector3(0, VOXEL_SIZE, 0),   # top-back
		pos + Vector3(0, VOXEL_SIZE, VOXEL_SIZE), # top-front
		pos + Vector3(0, 0, VOXEL_SIZE)    # bottom-front
	])
	var color := _get_color_for_y_level(pos.y)
	_add_quad(st, vertices, Vector3.LEFT, color * 0.75)  # Medium shade
