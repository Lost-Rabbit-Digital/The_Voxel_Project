## This class is responsible for managing and caching the materials used in the voxel-based game.
class_name MaterialFactory
extends Resource

## The path to the main texture atlas used for the voxel textures.
const TEXTURE_PATH = "res://assets/textures/main_texture_atlas.png"

## A dictionary that stores the cached materials, using a unique key based on the voxel type.
var cached_materials: Dictionary = {}

## Property Description:
## 'cached_materials' is a dictionary that stores the cached materials, using a unique key based on the voxel type.
## This allows the MaterialFactory to efficiently retrieve and reuse materials, reducing the overhead of creating new materials.

## Retrieves a material for the specified voxel type.
##
## Parameters:
##   type: int = 0 - The voxel type to get the material for.
##
## Returns:
##   A StandardMaterial3D instance configured for the given voxel type.
func get_material_for_type(type: int = 0) -> StandardMaterial3D:
	# Create a unique cache key based on the voxel type.
	var cache_key = "voxel_%d" % type
	
	# Check if the material for the given cache key is already cached.
	if not cached_materials.has(cache_key):
		# If not, create a new StandardMaterial3D instance.
		var material = StandardMaterial3D.new()
		
		# Load the texture atlas.
		var texture = load(TEXTURE_PATH)
		if texture:
			# Set the texture on the material.
			material.albedo_texture = texture
		else:
			# If the texture fails to load, log an error.
			push_error("Failed to load texture atlas at: " + TEXTURE_PATH)
		
		# Configure the material for voxel rendering.
		material.vertex_color_use_as_albedo = false
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.uv1_scale = Vector3(1, 1, 1)
		material.uv1_triplanar = false
		material.roughness = 1.0
		material.metallic_specular = 0.0
		material.cull_mode = BaseMaterial3D.CULL_BACK
		
		# Cache the material using the cache key.
		cached_materials[cache_key] = material
	
	# Return the cached material.
	return cached_materials[cache_key]

## A convenience method to get the default material used for voxel rendering.
func get_default_material() -> StandardMaterial3D:
	return get_material_for_type(0)
