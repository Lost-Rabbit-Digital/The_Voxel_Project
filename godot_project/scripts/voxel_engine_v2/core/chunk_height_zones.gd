## ChunkHeightZones - Manages adaptive chunk heights based on Y-level
## Implements Sodium's strategy: smaller chunks where terrain is dense,
## larger chunks in sky/void for better performance
##
## Strategy:
## - Dense terrain (Y: -64 to 180): 16-block chunks (better culling granularity)
## - Sky zone (Y: 180 to 320): 64-block chunks (mostly empty)
## - Deep void (Y: below -64): 32-block chunks (bedrock/sparse)
class_name ChunkHeightZones
extends RefCounted

## Height zone definitions
enum Zone {
	DEEP_VOID,   # Y < -64: 32-block chunks (sparse bedrock)
	DENSE,       # Y: -64 to 180: 16-block chunks (dense terrain, better culling)
	SKY          # Y: 180+: 64-block chunks (mostly empty sky)
}

## Zone configurations (Y ranges and chunk heights)
const ZONE_CONFIG := {
	Zone.DEEP_VOID: {
		"y_min": -128,
		"y_max": -64,
		"chunk_height": 32,
		"name": "Deep Void"
	},
	Zone.DENSE: {
		"y_min": -64,
		"y_max": 180,
		"chunk_height": 16,
		"name": "Dense Terrain"
	},
	Zone.SKY: {
		"y_min": 180,
		"y_max": 320,
		"chunk_height": 64,
		"name": "Sky"
	}
}

## Horizontal chunk size (constant across all zones)
const CHUNK_SIZE_XZ := 16

## Get chunk height for a given world Y position
static func get_chunk_height_at_y(world_y: int) -> int:
	var zone := get_zone_at_y(world_y)
	return ZONE_CONFIG[zone].chunk_height

## Get zone for a given world Y position
static func get_zone_at_y(world_y: int) -> Zone:
	if world_y < ZONE_CONFIG[Zone.DENSE].y_min:
		return Zone.DEEP_VOID
	elif world_y >= ZONE_CONFIG[Zone.SKY].y_min:
		return Zone.SKY
	else:
		return Zone.DENSE

## Convert world Y position to chunk Y coordinate
## This is complex because chunks have different heights in different zones
static func world_y_to_chunk_y(world_y: int) -> int:
	var zone := get_zone_at_y(world_y)
	var zone_config = ZONE_CONFIG[zone]

	# Calculate Y position relative to zone start
	var y_in_zone: int = world_y - zone_config.y_min

	# Calculate chunk index within this zone
	var chunk_y_in_zone := floori(float(y_in_zone) / zone_config.chunk_height)

	# Calculate absolute chunk Y by adding chunks from previous zones
	var chunk_y := chunk_y_in_zone

	# Add chunks from zones below this one
	if zone == Zone.DENSE:
		# Add chunks from deep void
		var deep_void_height := ZONE_CONFIG[Zone.DEEP_VOID].y_max - ZONE_CONFIG[Zone.DEEP_VOID].y_min
		chunk_y += ceili(float(deep_void_height) / ZONE_CONFIG[Zone.DEEP_VOID].chunk_height)
	elif zone == Zone.SKY:
		# Add chunks from deep void
		var deep_void_height := ZONE_CONFIG[Zone.DEEP_VOID].y_max - ZONE_CONFIG[Zone.DEEP_VOID].y_min
		chunk_y += ceili(float(deep_void_height) / ZONE_CONFIG[Zone.DEEP_VOID].chunk_height)

		# Add chunks from dense zone
		var dense_height := ZONE_CONFIG[Zone.DENSE].y_max - ZONE_CONFIG[Zone.DENSE].y_min
		chunk_y += ceili(float(dense_height) / ZONE_CONFIG[Zone.DENSE].chunk_height)

	return chunk_y

## Convert chunk Y coordinate to world Y position (bottom of chunk)
static func chunk_y_to_world_y(chunk_y: int) -> int:
	var cumulative_y := ZONE_CONFIG[Zone.DEEP_VOID].y_min
	var remaining_chunks := chunk_y

	# Process each zone in order
	for zone_id in [Zone.DEEP_VOID, Zone.DENSE, Zone.SKY]:
		var zone_config = ZONE_CONFIG[zone_id]
		var zone_height: int = zone_config.y_max - zone_config.y_min
		var chunks_in_zone := ceili(float(zone_height) / zone_config.chunk_height)

		if remaining_chunks < chunks_in_zone:
			# Chunk is in this zone
			return cumulative_y + (remaining_chunks * zone_config.chunk_height)

		# Move to next zone
		remaining_chunks -= chunks_in_zone
		cumulative_y = zone_config.y_max

	# If we get here, chunk is above all zones - use sky chunk height
	return cumulative_y + (remaining_chunks * ZONE_CONFIG[Zone.SKY].chunk_height)

## Get chunk height for a chunk at given chunk coordinates
static func get_chunk_height_for_chunk(chunk_pos: Vector3i) -> int:
	var world_y := chunk_y_to_world_y(chunk_pos.y)
	return get_chunk_height_at_y(world_y)

## Get the actual Y size of a chunk at chunk coordinates
## This returns the minimum of (zone chunk height, distance to zone boundary)
static func get_actual_chunk_y_size(chunk_pos: Vector3i) -> int:
	var world_y_bottom := chunk_y_to_world_y(chunk_pos.y)
	var zone := get_zone_at_y(world_y_bottom)
	var zone_config = ZONE_CONFIG[zone]
	var chunk_height: int = zone_config.chunk_height

	# Check if chunk extends beyond zone boundary
	var world_y_top: int = world_y_bottom + chunk_height
	if world_y_top > zone_config.y_max:
		# Chunk is cut off at zone boundary
		return zone_config.y_max - world_y_bottom

	return chunk_height

## Convert world position to chunk position (handles variable heights)
static func world_to_chunk_position(world_pos: Vector3) -> Vector3i:
	return Vector3i(
		floori(world_pos.x / CHUNK_SIZE_XZ),
		world_y_to_chunk_y(int(world_pos.y)),
		floori(world_pos.z / CHUNK_SIZE_XZ)
	)

## Get chunk bounds in world coordinates
static func get_chunk_world_bounds(chunk_pos: Vector3i) -> AABB:
	var world_x := chunk_pos.x * CHUNK_SIZE_XZ
	var world_y := chunk_y_to_world_y(chunk_pos.y)
	var world_z := chunk_pos.z * CHUNK_SIZE_XZ
	var chunk_y_size := get_actual_chunk_y_size(chunk_pos)

	return AABB(
		Vector3(world_x, world_y, world_z),
		Vector3(CHUNK_SIZE_XZ, chunk_y_size, CHUNK_SIZE_XZ)
	)

## Calculate total number of chunks from Y min to Y max
static func get_total_chunks_in_y_range(y_min: int, y_max: int) -> int:
	var chunk_y_min := world_y_to_chunk_y(y_min)
	var chunk_y_max := world_y_to_chunk_y(y_max)
	return chunk_y_max - chunk_y_min + 1

## Get zone statistics for debugging
static func get_zone_stats() -> Dictionary:
	var stats := {}

	for zone_id in Zone.values():
		var zone_config = ZONE_CONFIG[zone_id]
		var zone_height: int = zone_config.y_max - zone_config.y_min
		var chunks_in_zone := ceili(float(zone_height) / zone_config.chunk_height)

		stats[Zone.keys()[zone_id]] = {
			"name": zone_config.name,
			"y_range": [zone_config.y_min, zone_config.y_max],
			"chunk_height": zone_config.chunk_height,
			"chunks_in_zone": chunks_in_zone,
			"zone_height": zone_height
		}

	return stats

## Print zone configuration (for debugging)
static func print_zone_config() -> void:
	print("=== Adaptive Chunk Height Zones ===")
	print("Horizontal size: %d x %d" % [CHUNK_SIZE_XZ, CHUNK_SIZE_XZ])
	print("")

	for zone_id in [Zone.DEEP_VOID, Zone.DENSE, Zone.SKY]:
		var zone_config = ZONE_CONFIG[zone_id]
		var zone_height: int = zone_config.y_max - zone_config.y_min
		var chunks_in_zone := ceili(float(zone_height) / zone_config.chunk_height)

		print("%s (Y: %d to %d):" % [zone_config.name, zone_config.y_min, zone_config.y_max])
		print("  Chunk height: %d blocks" % zone_config.chunk_height)
		print("  Zone height: %d blocks" % zone_height)
		print("  Chunks in zone: %d" % chunks_in_zone)
		print("  Reason: %s" % _get_zone_reason(zone_id))
		print("")

	print("Total world height: %d to %d" % [
		ZONE_CONFIG[Zone.DEEP_VOID].y_min,
		ZONE_CONFIG[Zone.SKY].y_max
	])

## Get explanation for why a zone uses its chunk height
static func _get_zone_reason(zone: Zone) -> String:
	match zone:
		Zone.DEEP_VOID:
			return "Sparse bedrock area - medium chunks for efficiency"
		Zone.DENSE:
			return "Dense terrain - small chunks for better culling granularity"
		Zone.SKY:
			return "Mostly empty sky - large chunks for fewer objects"
		_:
			return "Unknown"

## Test adaptive sizing with sample positions
static func test_adaptive_sizing() -> void:
	print("=== Testing Adaptive Chunk Sizing ===")

	var test_positions := [
		-100,  # Deep void
		-64,   # Deep void boundary
		0,     # Surface (dense)
		64,    # Mid terrain (dense)
		180,   # Dense/sky boundary
		256,   # Sky
	]

	for world_y in test_positions:
		var zone := get_zone_at_y(world_y)
		var chunk_height := get_chunk_height_at_y(world_y)
		var chunk_y := world_y_to_chunk_y(world_y)
		var zone_name: String = ZONE_CONFIG[zone].name

		print("Y=%d -> Zone: %s, Chunk Height: %d, Chunk Y: %d" % [
			world_y, zone_name, chunk_height, chunk_y
		])
