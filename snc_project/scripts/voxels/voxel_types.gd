class_name VoxelTypes
extends Resource

enum Type {
	AIR,
	DIRT,
	STONE,
	GRASS,
	METAL,
	SNOW,
	SAND
}

# Properties for each voxel type including texture coordinates
const PROPERTIES = {
	Type.DIRT: {
		"color": Color(0.6, 0.4, 0.2),
		"roughness": 0.7,
		"metallic": 0.0,
		"texture_coords": {
			"all": Vector2(2, 0)  # Position in texture atlas (matches "dirt" in mesh builder)
		}
	},
	Type.STONE: {
		"color": Color(0.7, 0.7, 0.7),
		"roughness": 0.8,
		"metallic": 0.1,
		"texture_coords": {
			"all": Vector2(1, 0)  # Position in texture atlas (matches "stone" in mesh builder)
		}
	},
	Type.GRASS: {
		"color": Color(0.3, 0.7, 0.3),
		"roughness": 0.9,
		"metallic": 0.0,
		"texture_coords": {
			"top": Vector2(0, 0),    # grass_top
			"side": Vector2(3, 0),    # grass_side
			"bottom": Vector2(2, 0)   # dirt texture for bottom
		}
	},
	Type.METAL: {
		"color": Color(0.8, 0.8, 0.9),
		"roughness": 0.4,
		"metallic": 0.8,
		"texture_coords": {
			"all": Vector2(3, 0)  # Position in texture atlas
		}
	},
	Type.SNOW: {
		"color": Color(0.95, 0.95, 0.95),
		"roughness": 0.5,
		"metallic": 0.0,
		"texture_coords": {
			"all": Vector2(2, 4)  # Position in texture atlas (matches "snow" in mesh builder)
		}
	},
	Type.SAND: {
		"color": Color(0.85, 0.8, 0.6),
		"roughness": 0.8,
		"metallic": 0.0,
		"texture_coords": {
			"all": Vector2(2, 1)  # Position in texture atlas (matches "sand" in mesh builder)
		}
	}
}

# Helper function to get texture coordinates for a specific face
static func get_texture_coords(type: Type, face: String = "all") -> Vector2:
	if not PROPERTIES.has(type):
		return Vector2.ZERO
		
	var tex_coords = PROPERTIES[type]["texture_coords"]
	
	# Handle special cases like grass that have different textures per face
	if tex_coords.has(face):
		return tex_coords[face]
	elif tex_coords.has("all"):
		return tex_coords["all"]
	
	return Vector2.ZERO

# Helper function to get material properties
static func get_material_properties(type: Type) -> Dictionary:
	if not PROPERTIES.has(type):
		return {}
	
	return {
		"color": PROPERTIES[type]["color"],
		"roughness": PROPERTIES[type]["roughness"],
		"metallic": PROPERTIES[type]["metallic"]
	}
