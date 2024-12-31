class_name VoxelTypes
extends Resource

enum Type {
	AIR,
	DIRT,
	STONE,
	METAL,
	GRASS
}

# Properties for each voxel type
const PROPERTIES = {
	Type.DIRT: {
		"color": Color(0.6, 0.4, 0.2),
		"roughness": 0.7,
		"metallic": 0.0
	},
	Type.STONE: {
		"color": Color(0.7, 0.7, 0.7),
		"roughness": 0.8,
		"metallic": 0.1
	},
	Type.METAL: {
		"color": Color(0.8, 0.8, 0.9),
		"roughness": 0.4,
		"metallic": 0.8
	},
	Type.GRASS: {
		"color": Color(0.3, 0.7, 0.3),
		"roughness": 0.9,
		"metallic": 0.0
	}
}
