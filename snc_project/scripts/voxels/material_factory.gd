class_name MaterialFactory
extends Resource

var _cached_materials: Dictionary = {}

func get_material_for_type(type: VoxelTypes.Type) -> StandardMaterial3D:
	if type in _cached_materials:
		return _cached_materials[type]
		
	var props = VoxelTypes.PROPERTIES[type]
	var material = StandardMaterial3D.new()
	material.albedo_color = props.color
	material.roughness = props.roughness
	material.metallic = props.metallic
	
	_cached_materials[type] = material
	return material
