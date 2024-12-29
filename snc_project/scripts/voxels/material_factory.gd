# material_factory.gd
class_name MaterialFactory
extends Resource

const TEXTURE_PATH = "res://textures/main_texture_atlas.png"  # Adjust path to your texture atlas

var _cached_materials: Dictionary = {}

func get_material_for_type(_type: int) -> StandardMaterial3D:
	# Create a single shared material for all voxels
	if not _cached_materials.has("voxel"):
		var material = StandardMaterial3D.new()
		
		# Load texture atlas
		var texture = load(TEXTURE_PATH)
		if texture:
			material.albedo_texture = texture
		
		# Essential material settings for voxel rendering
		material.vertex_color_use_as_albedo = false
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # For crisp pixel art textures
		material.uv1_scale = Vector3(1, 1, 1)  # Important for correct UV mapping
		material.uv1_triplanar = false  # We're using custom UV mapping
		material.roughness = 1.0
		material.metallic_specular = 0.0
		
		_cached_materials["voxel"] = material
	
	return _cached_materials["voxel"]
