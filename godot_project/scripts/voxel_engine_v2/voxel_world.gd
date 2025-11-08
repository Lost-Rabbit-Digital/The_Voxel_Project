## VoxelWorld - Main controller for the voxel engine
## Orchestrates ChunkManager, TerrainGenerator, and MeshBuilder
## Tracks player position and manages chunk loading
class_name VoxelWorld
extends Node3D

## Configuration exports
@export_group("World Settings")
@export var world_seed: int = 0
@export var enable_auto_generation: bool = true

@export_group("Rendering")
@export var render_distance: int = 8
@export var vertical_render_distance: int = 4

@export_group("Performance")
@export var enable_chunk_pooling: bool = true
@export var chunk_pool_size: int = 128
@export var enable_threading: bool = false  # Phase 3 feature

@export_group("Debug")
@export var show_debug_info: bool = true
@export var print_stats_interval: float = 5.0

## Core systems
var chunk_manager: ChunkManager
var terrain_generator: TerrainGenerator
var mesh_builder: ChunkMeshBuilder

## Player tracking (will be replaced with actual player reference)
var tracked_position: Vector3 = Vector3.ZERO
@export var player_node_path: NodePath
var player_node: Node3D

## Debug
var debug_label: Label
var axis_gizmo: AxisGizmo
var stats_timer: float = 0.0

func _ready() -> void:
	print("========================================")
	print("[VoxelWorld] _ready() called")
	print("[VoxelWorld] Configuration:")
	print("  - world_seed: %d" % world_seed)
	print("  - render_distance: %d" % render_distance)
	print("  - vertical_render_distance: %d" % vertical_render_distance)
	print("  - enable_auto_generation: %s" % enable_auto_generation)
	print("  - enable_chunk_pooling: %s" % enable_chunk_pooling)
	print("  - chunk_pool_size: %d" % chunk_pool_size)
	print("========================================")

	_initialize_systems()
	_setup_debug_ui()

	# Find player if path is set
	if not player_node_path.is_empty():
		print("[VoxelWorld] Looking for player at path: %s" % player_node_path)
		player_node = get_node_or_null(player_node_path)
		if player_node:
			print("[VoxelWorld] Found player node: %s" % player_node.name)
			tracked_position = player_node.global_position
			print("[VoxelWorld] Initial player position: %s" % tracked_position)
		else:
			print("[VoxelWorld] WARNING: Player node not found at path!")
	else:
		print("[VoxelWorld] No player node path set, using default position")

	# Start with initial chunk load
	if enable_auto_generation:
		print("[VoxelWorld] Starting initial chunk generation...")
		_update_chunks()
	else:
		print("[VoxelWorld] Auto-generation disabled")

func _process(delta: float) -> void:
	# Update tracked position
	if player_node:
		tracked_position = player_node.global_position

	# Update chunks based on player position
	if enable_auto_generation and chunk_manager:
		chunk_manager.update_chunks(tracked_position)

	# Update debug info
	if show_debug_info:
		_update_debug_info(delta)

## Initialize all voxel systems
func _initialize_systems() -> void:
	print("[VoxelWorld] Initializing voxel systems...")

	# Create terrain generator with seed
	if world_seed == 0:
		world_seed = randi()
		print("[VoxelWorld] Generated random seed: %d" % world_seed)
	else:
		print("[VoxelWorld] Using configured seed: %d" % world_seed)

	print("[VoxelWorld] Creating TerrainGenerator...")
	terrain_generator = TerrainGenerator.new(world_seed)
	print("[VoxelWorld] TerrainGenerator created successfully")

	# Create chunk manager
	print("[VoxelWorld] Creating ChunkManager...")
	chunk_manager = ChunkManager.new()
	chunk_manager.render_distance = render_distance
	chunk_manager.vertical_render_distance = vertical_render_distance
	chunk_manager.enable_pooling = enable_chunk_pooling
	chunk_manager.pool_size = chunk_pool_size
	print("[VoxelWorld] Adding ChunkManager as child...")
	add_child(chunk_manager)
	print("[VoxelWorld] ChunkManager added to scene tree")

	# Create mesh builder
	print("[VoxelWorld] Creating ChunkMeshBuilder...")
	mesh_builder = ChunkMeshBuilder.new(chunk_manager)
	print("[VoxelWorld] ChunkMeshBuilder created successfully")

	# Connect systems
	print("[VoxelWorld] Connecting systems...")
	chunk_manager.terrain_generator = terrain_generator
	chunk_manager.mesh_builder = mesh_builder
	print("[VoxelWorld] Systems connected")

	print("[VoxelWorld] ✓ All systems initialized successfully!")
	print("========================================")

## Setup debug UI
func _setup_debug_ui() -> void:
	if not show_debug_info:
		return

	debug_label = Label.new()
	debug_label.position = Vector2(10, 10)
	debug_label.add_theme_font_size_override("font_size", 14)
	add_child(debug_label)

	# Add axis gizmo (3D orientation indicator)
	axis_gizmo = AxisGizmo.new()
	add_child(axis_gizmo)

## Update debug information display
func _update_debug_info(delta: float) -> void:
	if not debug_label:
		return

	stats_timer += delta
	if stats_timer >= print_stats_interval:
		stats_timer = 0.0
		if chunk_manager:
			chunk_manager.print_stats()

	var fps := Engine.get_frames_per_second()
	var stats := chunk_manager.get_stats() if chunk_manager else {}

	var debug_text := ""
	debug_text += "FPS: %d\n" % fps
	debug_text += "Position: (%.1f, %.1f, %.1f)\n" % [
		tracked_position.x,
		tracked_position.y,
		tracked_position.z
	]
	debug_text += "Chunk: (%d, %d, %d)\n" % [
		floori(tracked_position.x / VoxelData.CHUNK_SIZE),
		floori(tracked_position.y / VoxelData.CHUNK_SIZE),
		floori(tracked_position.z / VoxelData.CHUNK_SIZE)
	]
	debug_text += "\n"
	debug_text += "Active Chunks: %d\n" % stats.get("active_chunks", 0)
	debug_text += "Pooled Chunks: %d\n" % stats.get("pooled_chunks", 0)
	debug_text += "Generated: %d\n" % stats.get("chunks_generated", 0)
	debug_text += "Meshed: %d\n" % stats.get("chunks_meshed", 0)
	debug_text += "\n"
	debug_text += "Seed: %d\n" % world_seed

	debug_label.text = debug_text

## Force chunk update at current position
func _update_chunks() -> void:
	if chunk_manager:
		chunk_manager.update_chunks(tracked_position)

## Set player tracking position manually (for testing)
func set_tracked_position(pos: Vector3) -> void:
	tracked_position = pos

## Get voxel at world position
func get_voxel(world_pos: Vector3i) -> int:
	if chunk_manager:
		return chunk_manager.get_voxel_at_world(world_pos)
	return VoxelTypes.Type.AIR

## Set voxel at world position
func set_voxel(world_pos: Vector3i, voxel_type: int) -> void:
	if chunk_manager:
		chunk_manager.set_voxel_at_world(world_pos, voxel_type)

## Regenerate terrain with new seed
func regenerate_world(new_seed: int = 0) -> void:
	if new_seed == 0:
		new_seed = randi()

	print("VoxelWorld: Regenerating with seed %d" % new_seed)

	# Clear existing chunks
	if chunk_manager:
		chunk_manager.cleanup_all()

	# Update terrain generator seed
	world_seed = new_seed
	if terrain_generator:
		terrain_generator.set_world_seed(world_seed)

	# Reload chunks
	_update_chunks()

## Cleanup on exit
func _exit_tree() -> void:
	if chunk_manager:
		chunk_manager.cleanup_all()

## Debug commands (can be called from console/debug menu)
func debug_print_stats() -> void:
	if chunk_manager:
		chunk_manager.print_stats()

func debug_set_render_distance(distance: int) -> void:
	render_distance = clampi(distance, 1, 32)
	if chunk_manager:
		chunk_manager.render_distance = render_distance
		_update_chunks()
	print("VoxelWorld: Render distance set to %d" % render_distance)

func debug_toggle_info() -> void:
	show_debug_info = not show_debug_info
	if debug_label:
		debug_label.visible = show_debug_info
	if axis_gizmo:
		axis_gizmo.visible = show_debug_info
