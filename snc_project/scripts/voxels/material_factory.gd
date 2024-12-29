class_name MaterialFactory
extends Resource

var _cached_materials: Dictionary = {}
var _texture: Texture2D

func _init() -> void:
	# Load the texture
	_texture = preload("res://textures/uv_coordinate_map.png")

func get_material_for_type(type: VoxelTypes.Type) -> StandardMaterial3D:
	if type in _cached_materials:
		return _cached_materials[type]
	
	var material = StandardMaterial3D.new()
	
	# Set base material properties
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	material.vertex_color_use_as_albedo = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST # Pixelated look
	
	# Apply the texture
	material.albedo_texture = _texture
	
	# Store in cache
	_cached_materials[type] = material
	return material
