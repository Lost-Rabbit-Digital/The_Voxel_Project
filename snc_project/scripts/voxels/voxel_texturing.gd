class_name VoxelTexturing
extends Resource

const TEXTURE_ATLAS_SIZE := 16.0  # Size of texture atlas (16x16 tiles)

# Height-based biome ranges
const DEEP_UNDERGROUND := -64
const UNDERGROUND := -32
const SURFACE_LEVEL := 0
const MOUNTAIN_START := 32
const MOUNTAIN_SNOW := 64

# UV coordinates in the texture atlas (adjust based on your texture layout)
const UV_COORDS := {
	"grass_top": Vector2(0, 0),
	"grass_side": Vector2(1, 0),
	"dirt": Vector2(2, 0),
	"stone": Vector2(3, 0),
	"snow": Vector2(4, 0),
	"sand": Vector2(5, 0),
	"gravel": Vector2(6, 0),
	"bedrock": Vector2(7, 0)
}

# Get texture coordinates based on voxel position and face
static func get_voxel_uvs(pos: Vector3, face: String, voxel_type: int) -> PackedVector2Array:
	var texture_key := _get_texture_key(pos, face, voxel_type)
	return _create_uvs(UV_COORDS[texture_key])

static func _get_texture_key(pos: Vector3, face: String, voxel_type: int) -> String:
	# Special case for grass blocks
	if voxel_type == VoxelTypes.Type.GRASS:
		if face == "top":
			return "grass_top"
		elif face == "bottom":
			return "dirt"
		else:
			return "grass_side"
	
	# Height-based texture selection
	var y := int(pos.y)
	
	if y < DEEP_UNDERGROUND:
		return "bedrock"
	elif y < UNDERGROUND:
		return "stone"
	elif y < SURFACE_LEVEL:
		return "gravel"
	elif y < MOUNTAIN_START:
		if voxel_type == VoxelTypes.Type.STONE:
			return "stone"
		else:
			return "dirt"
	elif y < MOUNTAIN_SNOW:
		return "stone"
	else:
		# Snow-covered mountains
		if face == "top":
			return "snow"
		else:
			return "stone"

static func _create_uvs(base_uv: Vector2) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	uvs.resize(6)  # 6 vertices per face (2 triangles)
	
	var uv_size := 1.0 / TEXTURE_ATLAS_SIZE
	var u := base_uv.x * uv_size
	var v := base_uv.y * uv_size
	
	# Standard UV mapping for a quad
	uvs[0] = Vector2(u, v + uv_size)           # Bottom-left
	uvs[1] = Vector2(u + uv_size, v + uv_size) # Bottom-right
	uvs[2] = Vector2(u + uv_size, v)           # Top-right
	
	uvs[3] = Vector2(u, v + uv_size)           # Bottom-left
	uvs[4] = Vector2(u + uv_size, v)           # Top-right
	uvs[5] = Vector2(u, v)                     # Top-left
	
	return uvs
