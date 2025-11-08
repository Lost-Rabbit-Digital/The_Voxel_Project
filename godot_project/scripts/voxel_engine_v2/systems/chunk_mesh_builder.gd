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

## Build mesh for a chunk using greedy meshing
func build_mesh(chunk: Chunk) -> MeshInstance3D:
	if not chunk or not chunk.voxel_data:
		print("[MeshBuilder] ERROR: Invalid chunk or voxel data")
		return null

	# Skip empty chunks
	if chunk.is_empty():
		print("[MeshBuilder] Chunk %s is empty, skipping mesh" % chunk.position)
		return null

	# Reduce console spam - only print occasionally
	# print("[MeshBuilder] Building greedy mesh for chunk %s..." % chunk.position)

	# Create surface tool for mesh building
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var vertices_added := 0
	var quads_added := 0

	# Process each axis direction for greedy meshing
	# Each direction processes slices perpendicular to that axis
	var directions := [
		{"axis": Vector3i.UP, "name": "up"},
		{"axis": Vector3i.DOWN, "name": "down"},
		{"axis": Vector3i.FORWARD, "name": "forward"},
		{"axis": Vector3i.BACK, "name": "back"},
		{"axis": Vector3i.RIGHT, "name": "right"},
		{"axis": Vector3i.LEFT, "name": "left"}
	]

	for dir_info in directions:
		var result := _greedy_mesh_direction(st, chunk, dir_info.axis)
		vertices_added += result.vertices
		quads_added += result.quads

	# Reduce console spam
	# print("[MeshBuilder]   Added %d vertices in %d merged quads" % [vertices_added, quads_added])

	# Check if we have any geometry
	if vertices_added == 0:
		print("[MeshBuilder] No vertices to mesh, returning null")
		return null

	# Index the mesh for optimization
	st.index()

	# Create mesh instance
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = default_material

	# Enable shadow casting
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	# Reduce console spam
	# print("[MeshBuilder] ✓ Greedy mesh created successfully")
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
		# FORWARD is -Z direction, so render the -Z face (south)
		_add_south_face(st, world_pos, voxel_type)
		vertices_added += 6

	if _should_add_face(chunk, local_pos, Vector3i.BACK):
		# BACK is +Z direction, so render the +Z face (north)
		_add_north_face(st, world_pos, voxel_type)
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

## Greedy mesh a single direction
## Returns dictionary with vertex and quad counts
func _greedy_mesh_direction(st: SurfaceTool, chunk: Chunk, direction: Vector3i) -> Dictionary:
	var vertices_added := 0
	var quads_added := 0

	# Determine the axis we're looking along and the two perpendicular axes
	var axis_index := _get_primary_axis_index(direction)
	var axes := _get_axis_permutation(axis_index)

	# u and v are the two axes perpendicular to the direction we're looking
	var u_axis: int = axes[0]
	var v_axis: int = axes[1]
	var d_axis: int = axes[2]  # The direction axis

	# Iterate through each slice perpendicular to the direction
	for d in range(VoxelData.CHUNK_SIZE):
		# Create a 2D mask for this slice
		var mask := []
		mask.resize(VoxelData.CHUNK_SIZE)
		for i in range(VoxelData.CHUNK_SIZE):
			mask[i] = []
			mask[i].resize(VoxelData.CHUNK_SIZE)
			for j in range(VoxelData.CHUNK_SIZE):
				mask[i][j] = null

		# Fill the mask
		for u in range(VoxelData.CHUNK_SIZE):
			for v in range(VoxelData.CHUNK_SIZE):
				# Build position in 3D space
				var pos := Vector3i.ZERO
				pos[u_axis] = u
				pos[v_axis] = v
				pos[d_axis] = d

				# Check if this voxel needs a face in this direction
				var voxel_type := chunk.get_voxel(pos)
				if voxel_type != VoxelTypes.Type.AIR and not VoxelTypes.is_transparent(voxel_type):
					if _should_add_face(chunk, pos, direction):
						mask[u][v] = voxel_type

		# Greedily merge quads in this slice
		var result := _merge_quads_in_mask(st, chunk, mask, direction, u_axis, v_axis, d_axis, d)
		vertices_added += result.vertices
		quads_added += result.quads

	return {"vertices": vertices_added, "quads": quads_added}

## Get the primary axis index from a direction vector
func _get_primary_axis_index(direction: Vector3i) -> int:
	if direction.x != 0:
		return 0  # X axis
	elif direction.y != 0:
		return 1  # Y axis
	else:
		return 2  # Z axis

## Get axis permutation for greedy meshing
## Returns [u_axis, v_axis, d_axis] where u and v are perpendicular to d
func _get_axis_permutation(primary_axis: int) -> Array:
	match primary_axis:
		0:  # X is primary (east/west faces)
			return [1, 2, 0]  # u=Y, v=Z, d=X
		1:  # Y is primary (up/down faces)
			return [0, 2, 1]  # u=X, v=Z, d=Y
		2:  # Z is primary (north/south faces)
			return [0, 1, 2]  # u=X, v=Y, d=Z
		_:
			return [0, 1, 2]

## Greedily merge quads in a 2D mask
func _merge_quads_in_mask(st: SurfaceTool, chunk: Chunk, mask: Array, direction: Vector3i,
						  u_axis: int, v_axis: int, d_axis: int, d: int) -> Dictionary:
	var vertices_added := 0
	var quads_added := 0

	# Greedy meshing algorithm
	for u in range(VoxelData.CHUNK_SIZE):
		for v in range(VoxelData.CHUNK_SIZE):
			if mask[u][v] == null:
				continue

			var voxel_type: int = mask[u][v]

			# Measure width (in v direction)
			var width := 1
			while v + width < VoxelData.CHUNK_SIZE and mask[u][v + width] == voxel_type:
				width += 1

			# Measure height (in u direction)
			var height := 1
			var done := false
			while u + height < VoxelData.CHUNK_SIZE and not done:
				# Check if we can extend the rectangle
				for k in range(width):
					if mask[u + height][v + k] != voxel_type:
						done = true
						break
				if not done:
					height += 1

			# Create the merged quad
			var pos := Vector3i.ZERO
			pos[u_axis] = u
			pos[v_axis] = v
			pos[d_axis] = d

			_add_greedy_quad(st, pos, direction, width, height, u_axis, v_axis, voxel_type)
			vertices_added += 6
			quads_added += 1

			# Clear the mask for merged area
			for du in range(height):
				for dv in range(width):
					mask[u + du][v + dv] = null

	return {"vertices": vertices_added, "quads": quads_added}

## Add a quad with custom width and height for greedy meshing
func _add_greedy_quad(st: SurfaceTool, pos: Vector3i, direction: Vector3i, width: int, height: int,
					  u_axis: int, v_axis: int, voxel_type: int) -> void:
	var world_pos := Vector3(pos) * VOXEL_SIZE

	# Determine which face to add based on direction
	if direction == Vector3i.UP:
		_add_top_face_sized(st, world_pos, width, height, u_axis, v_axis, voxel_type)
	elif direction == Vector3i.DOWN:
		_add_bottom_face_sized(st, world_pos, width, height, u_axis, v_axis, voxel_type)
	elif direction == Vector3i.FORWARD:
		_add_south_face_sized(st, world_pos, width, height, u_axis, v_axis, voxel_type)
	elif direction == Vector3i.BACK:
		_add_north_face_sized(st, world_pos, width, height, u_axis, v_axis, voxel_type)
	elif direction == Vector3i.RIGHT:
		_add_east_face_sized(st, world_pos, width, height, u_axis, v_axis, voxel_type)
	elif direction == Vector3i.LEFT:
		_add_west_face_sized(st, world_pos, width, height, u_axis, v_axis, voxel_type)

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

## Greedy meshing sized face functions
## These create quads with custom width and height for merged faces

## Top face (+Y) - sized version for greedy meshing
func _add_top_face_sized(st: SurfaceTool, pos: Vector3, width: int, height: int,
						 u_axis: int, v_axis: int, voxel_type: int) -> void:
	var w := float(width) * VOXEL_SIZE
	var h := float(height) * VOXEL_SIZE
	var vertices := PackedVector3Array([
		pos + Vector3(0, VOXEL_SIZE, 0),
		pos + Vector3(h, VOXEL_SIZE, 0),
		pos + Vector3(h, VOXEL_SIZE, w),
		pos + Vector3(0, VOXEL_SIZE, w)
	])
	var color := _get_color_for_y_level(pos.y)
	_add_quad(st, vertices, Vector3.UP, color * 1.0)

## Bottom face (-Y) - sized version for greedy meshing
func _add_bottom_face_sized(st: SurfaceTool, pos: Vector3, width: int, height: int,
							u_axis: int, v_axis: int, voxel_type: int) -> void:
	var w := float(width) * VOXEL_SIZE
	var h := float(height) * VOXEL_SIZE
	var vertices := PackedVector3Array([
		pos + Vector3(0, 0, 0),
		pos + Vector3(0, 0, w),
		pos + Vector3(h, 0, w),
		pos + Vector3(h, 0, 0)
	])
	var color := _get_color_for_y_level(pos.y)
	_add_quad(st, vertices, Vector3.DOWN, color * 0.6)

## North face (+Z) - sized version for greedy meshing
func _add_north_face_sized(st: SurfaceTool, pos: Vector3, width: int, height: int,
						   u_axis: int, v_axis: int, voxel_type: int) -> void:
	var w := float(width) * VOXEL_SIZE
	var h := float(height) * VOXEL_SIZE
	var vertices := PackedVector3Array([
		pos + Vector3(0, 0, VOXEL_SIZE),
		pos + Vector3(0, w, VOXEL_SIZE),
		pos + Vector3(h, w, VOXEL_SIZE),
		pos + Vector3(h, 0, VOXEL_SIZE)
	])
	var color := _get_color_for_y_level(pos.y)
	_add_quad(st, vertices, Vector3.FORWARD, color * 0.85)

## South face (-Z) - sized version for greedy meshing
func _add_south_face_sized(st: SurfaceTool, pos: Vector3, width: int, height: int,
						   u_axis: int, v_axis: int, voxel_type: int) -> void:
	var w := float(width) * VOXEL_SIZE
	var h := float(height) * VOXEL_SIZE
	var vertices := PackedVector3Array([
		pos + Vector3(h, 0, 0),
		pos + Vector3(h, w, 0),
		pos + Vector3(0, w, 0),
		pos + Vector3(0, 0, 0)
	])
	var color := _get_color_for_y_level(pos.y)
	_add_quad(st, vertices, Vector3.BACK, color * 0.85)

## East face (+X) - sized version for greedy meshing
func _add_east_face_sized(st: SurfaceTool, pos: Vector3, width: int, height: int,
						  u_axis: int, v_axis: int, voxel_type: int) -> void:
	var w := float(width) * VOXEL_SIZE
	var h := float(height) * VOXEL_SIZE
	var vertices := PackedVector3Array([
		pos + Vector3(VOXEL_SIZE, 0, w),
		pos + Vector3(VOXEL_SIZE, h, w),
		pos + Vector3(VOXEL_SIZE, h, 0),
		pos + Vector3(VOXEL_SIZE, 0, 0)
	])
	var color := _get_color_for_y_level(pos.y)
	_add_quad(st, vertices, Vector3.RIGHT, color * 0.75)

## West face (-X) - sized version for greedy meshing
func _add_west_face_sized(st: SurfaceTool, pos: Vector3, width: int, height: int,
						  u_axis: int, v_axis: int, voxel_type: int) -> void:
	var w := float(width) * VOXEL_SIZE
	var h := float(height) * VOXEL_SIZE
	var vertices := PackedVector3Array([
		pos + Vector3(0, 0, 0),
		pos + Vector3(0, h, 0),
		pos + Vector3(0, h, w),
		pos + Vector3(0, 0, w)
	])
	var color := _get_color_for_y_level(pos.y)
	_add_quad(st, vertices, Vector3.LEFT, color * 0.75)
