# material_factory.gd
class_name MaterialFactory
extends Resource

const TEXTURE_PATH = "res://textures/main_texture_atlas.png"  # Adjust path to your texture atlas
var cached_materials: Dictionary = {}

func get_material_for_type(type: int = 0) -> StandardMaterial3D:
	# Use type as part of the cache key if you want different materials per type
	var cache_key = "voxel_%d" % type
	
	if not cached_materials.has(cache_key):
		var material = StandardMaterial3D.new()
		
		# Load texture atlas
		var texture = load(TEXTURE_PATH)
		if texture:
			material.albedo_texture = texture
		else:
			push_error("Failed to load texture atlas at: " + TEXTURE_PATH)
		
		# Essential material settings for voxel rendering
		material.vertex_color_use_as_albedo = false
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.uv1_scale = Vector3(1, 1, 1)
		material.uv1_triplanar = false
		material.roughness = 1.0
		material.metallic_specular = 0.0
		material.cull_mode = BaseMaterial3D.CULL_BACK  # Add this to ensure proper face culling
		
		cached_materials[cache_key] = material
	
	return cached_materials[cache_key]

# Add a convenience method for getting the default material
func get_default_material() -> StandardMaterial3D:
	return get_material_for_type(0)
