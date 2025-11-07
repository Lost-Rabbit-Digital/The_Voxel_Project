## VoxelTypes - Block type definitions and registry
## Defines all voxel/block types in the game
class_name VoxelTypes
extends RefCounted

## Block type enumeration
## Each block type is represented by a single byte (0-255)
enum Type {
	AIR = 0,        # Empty space, no rendering
	STONE = 1,      # Basic stone
	DIRT = 2,       # Dirt block
	GRASS = 3,      # Grass block (dirt with grass on top)
	WOOD = 4,       # Wood/log block
	LEAVES = 5,     # Tree leaves (transparent)
	SAND = 6,       # Sand
	GRAVEL = 7,     # Gravel
	WATER = 8,      # Water (transparent, animated)
	LAVA = 9,       # Lava (transparent, animated, light source)
	COAL_ORE = 10,  # Coal ore
	IRON_ORE = 11,  # Iron ore
	GOLD_ORE = 12,  # Gold ore
	COBBLESTONE = 13, # Cobblestone
	PLANKS = 14,    # Wooden planks
	GLASS = 15,     # Glass (transparent)
	# Add more block types as needed
}

## Block properties structure
class BlockProperties:
	var id: int
	var name: String
	var is_solid: bool = true          # Does it have collision?
	var is_transparent: bool = false   # Can you see through it?
	var is_liquid: bool = false        # Is it a liquid?
	var hardness: float = 1.0          # How long to break (0 = instant, higher = longer)
	var light_level: int = 0           # Light emission (0-15)
	var tool_required: String = ""     # Which tool type is best ("pickaxe", "axe", "shovel", "")
	var drops_self: bool = true        # Does it drop itself when broken?
	var drop_item: int = -1            # If not drops_self, what does it drop? (-1 = nothing)

	func _init(p_id: int, p_name: String) -> void:
		id = p_id
		name = p_name

## Registry of all block properties
static var _block_registry: Dictionary = {}
static var _initialized: bool = false

## Initialize the block registry with all block definitions
static func initialize() -> void:
	if _initialized:
		return

	_initialized = true

	# AIR - special case, no properties needed
	var air := BlockProperties.new(Type.AIR, "Air")
	air.is_solid = false
	air.is_transparent = true
	air.hardness = 0.0
	_block_registry[Type.AIR] = air

	# STONE
	var stone := BlockProperties.new(Type.STONE, "Stone")
	stone.hardness = 3.0
	stone.tool_required = "pickaxe"
	stone.drops_self = false
	stone.drop_item = Type.COBBLESTONE
	_block_registry[Type.STONE] = stone

	# DIRT
	var dirt := BlockProperties.new(Type.DIRT, "Dirt")
	dirt.hardness = 1.0
	dirt.tool_required = "shovel"
	_block_registry[Type.DIRT] = dirt

	# GRASS
	var grass := BlockProperties.new(Type.GRASS, "Grass")
	grass.hardness = 1.0
	grass.tool_required = "shovel"
	grass.drops_self = false
	grass.drop_item = Type.DIRT
	_block_registry[Type.GRASS] = grass

	# WOOD
	var wood := BlockProperties.new(Type.WOOD, "Wood")
	wood.hardness = 2.0
	wood.tool_required = "axe"
	_block_registry[Type.WOOD] = wood

	# LEAVES
	var leaves := BlockProperties.new(Type.LEAVES, "Leaves")
	leaves.hardness = 0.2
	leaves.is_transparent = true
	leaves.tool_required = "shears"
	_block_registry[Type.LEAVES] = leaves

	# SAND
	var sand := BlockProperties.new(Type.SAND, "Sand")
	sand.hardness = 1.0
	sand.tool_required = "shovel"
	_block_registry[Type.SAND] = sand

	# GRAVEL
	var gravel := BlockProperties.new(Type.GRAVEL, "Gravel")
	gravel.hardness = 1.2
	gravel.tool_required = "shovel"
	_block_registry[Type.GRAVEL] = gravel

	# WATER
	var water := BlockProperties.new(Type.WATER, "Water")
	water.is_solid = false
	water.is_transparent = true
	water.is_liquid = true
	water.hardness = 0.0
	_block_registry[Type.WATER] = water

	# LAVA
	var lava := BlockProperties.new(Type.LAVA, "Lava")
	lava.is_solid = false
	lava.is_transparent = true
	lava.is_liquid = true
	lava.hardness = 0.0
	lava.light_level = 15
	_block_registry[Type.LAVA] = lava

	# COAL_ORE
	var coal_ore := BlockProperties.new(Type.COAL_ORE, "Coal Ore")
	coal_ore.hardness = 3.0
	coal_ore.tool_required = "pickaxe"
	_block_registry[Type.COAL_ORE] = coal_ore

	# IRON_ORE
	var iron_ore := BlockProperties.new(Type.IRON_ORE, "Iron Ore")
	iron_ore.hardness = 4.0
	iron_ore.tool_required = "pickaxe"
	_block_registry[Type.IRON_ORE] = iron_ore

	# GOLD_ORE
	var gold_ore := BlockProperties.new(Type.GOLD_ORE, "Gold Ore")
	gold_ore.hardness = 4.5
	gold_ore.tool_required = "pickaxe"
	_block_registry[Type.GOLD_ORE] = gold_ore

	# COBBLESTONE
	var cobblestone := BlockProperties.new(Type.COBBLESTONE, "Cobblestone")
	cobblestone.hardness = 3.0
	cobblestone.tool_required = "pickaxe"
	_block_registry[Type.COBBLESTONE] = cobblestone

	# PLANKS
	var planks := BlockProperties.new(Type.PLANKS, "Planks")
	planks.hardness = 2.0
	planks.tool_required = "axe"
	_block_registry[Type.PLANKS] = planks

	# GLASS
	var glass := BlockProperties.new(Type.GLASS, "Glass")
	glass.hardness = 0.3
	glass.is_transparent = true
	glass.drops_self = false
	glass.drop_item = -1  # Breaks into nothing
	_block_registry[Type.GLASS] = glass

## Get block properties by type ID
static func get_properties(block_type: int) -> BlockProperties:
	if not _initialized:
		initialize()

	if block_type in _block_registry:
		return _block_registry[block_type]

	# Return AIR properties as fallback
	return _block_registry[Type.AIR]

## Check if a block type is solid (has collision)
static func is_solid(block_type: int) -> bool:
	return get_properties(block_type).is_solid

## Check if a block type is transparent (can see through it)
static func is_transparent(block_type: int) -> bool:
	return get_properties(block_type).is_transparent

## Check if a block type is a liquid
static func is_liquid(block_type: int) -> bool:
	return get_properties(block_type).is_liquid

## Get the light level emitted by a block type (0-15)
static func get_light_level(block_type: int) -> int:
	return get_properties(block_type).light_level

## Get the hardness of a block (affects break time)
static func get_hardness(block_type: int) -> float:
	return get_properties(block_type).hardness

## Get the best tool type for a block
static func get_tool_required(block_type: int) -> String:
	return get_properties(block_type).tool_required

## Get what item a block drops when broken
static func get_drop_item(block_type: int) -> int:
	var props := get_properties(block_type)
	if props.drops_self:
		return block_type
	return props.drop_item
