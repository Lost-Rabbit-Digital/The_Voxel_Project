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
@export var enable_threading: bool = true  # Multi-threaded chunk generation

@export_group("Debug")
@export var print_stats_interval: float = 5.0

## Core systems
var chunk_manager: ChunkManager
var terrain_generator: TerrainGenerator
var mesh_builder: ChunkMeshBuilder

## Player tracking (will be replaced with actual player reference)
var tracked_position: Vector3 = Vector3.ZERO
@export var player_node_path: NodePath
var player_node: Node3D
var active_camera: Camera3D  # For frustum culling

## Debug states (F3 cycles through these)
enum DebugState {
	OFF,           # No debug info
	FPS_ONLY,      # FPS and draw calls only
	FPS_AND_GIZMO  # FPS, draw calls, and axis gizmo
}

var debug_state: DebugState = DebugState.FPS_ONLY
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
	if enable_threading:
		print("  - enable_threading: TRUE ✓ (4 worker threads)")
	else:
		print("  - enable_threading: FALSE ⚠️ (SLOW - WILL FREEZE!)")
	print("========================================")

	# Report loading progress if LoadingManager exists
	if LoadingManager:
		LoadingManager.start_loading(5)  # 5 initialization steps
		LoadingManager.update_progress("Initializing voxel systems...")

	_initialize_systems()

	if LoadingManager:
		LoadingManager.complete_task("Systems initialized")
		LoadingManager.update_progress("Setting up debug UI...")

	_setup_debug_ui()

	if LoadingManager:
		LoadingManager.complete_task("Debug UI created")
		LoadingManager.update_progress("Finding player...")

	# Find player if path is set
	if not player_node_path.is_empty():
		print("[VoxelWorld] Looking for player at path: %s" % player_node_path)
		player_node = get_node_or_null(player_node_path)
		if player_node:
			print("[VoxelWorld] Found player node: %s" % player_node.name)
			tracked_position = player_node.global_position
			print("[VoxelWorld] Initial player position: %s" % tracked_position)

			# Check if player node is a camera
			if player_node is Camera3D:
				active_camera = player_node
				print("[VoxelWorld] Player node is camera, using for frustum culling")
		else:
			print("[VoxelWorld] WARNING: Player node not found at path!")
	else:
		print("[VoxelWorld] No player node path set, using default position")

	# If no camera found yet, try to find one in the scene tree
	if not active_camera:
		active_camera = _find_camera()
		if active_camera:
			print("[VoxelWorld] Found camera: %s" % active_camera.name)

	if LoadingManager:
		LoadingManager.complete_task("Player located")
		LoadingManager.update_progress("Generating initial terrain...")

	# Start with initial chunk load
	if enable_auto_generation:
		print("[VoxelWorld] Starting initial chunk generation...")
		_update_chunks()

		# Wait for initial chunks to be ready (with timeout)
		print("[VoxelWorld] Waiting for initial chunks to render...")
		if chunk_manager:
			var timeout := 10.0  # 10 second timeout
			var timer := get_tree().create_timer(timeout)
			var timed_out := false

			# Connect to timeout signal
			timer.timeout.connect(func(): timed_out = true, CONNECT_ONE_SHOT)

			# Wait for either chunks ready or timeout
			while not chunk_manager._initial_chunks_ready and not timed_out:
				await get_tree().process_frame

			if timed_out:
				print("[VoxelWorld] WARNING: Initial chunk loading timed out after %.1f seconds" % timeout)
			else:
				print("[VoxelWorld] Initial chunks rendered successfully!")
	else:
		print("[VoxelWorld] Auto-generation disabled")

	if LoadingManager:
		LoadingManager.complete_task("Initial chunks generated")
		LoadingManager.update_progress("Finalizing...")

	# Wait a frame to ensure everything is set up
	await get_tree().process_frame

	if LoadingManager:
		LoadingManager.complete_task("World ready")
		LoadingManager.finish_loading()

## Frame timing tracking
var _frame_times: Array[float] = []
var _last_perf_log: float = 0.0
const PERF_LOG_INTERVAL: float = 2.0  # Log every 2 seconds

## Handle input for debug toggles
func _input(event: InputEvent) -> void:
	# Cycle debug UI states with F3
	if event is InputEventKey:
		if event.keycode == KEY_F3 and event.pressed and not event.echo:
			_cycle_debug_state()

func _process(delta: float) -> void:
	var frame_start := Time.get_ticks_usec()

	# Update tracked position
	var pos_start := Time.get_ticks_usec()
	if player_node:
		tracked_position = player_node.global_position
	var pos_time := (Time.get_ticks_usec() - pos_start) / 1000.0

	# Update chunks based on player position
	var chunk_update_start := Time.get_ticks_usec()
	if enable_auto_generation and chunk_manager:
		# Pass camera for prioritization if available
		var camera_forward := Vector3.FORWARD
		if active_camera:
			camera_forward = -active_camera.global_transform.basis.z
		chunk_manager.update_chunks(tracked_position, camera_forward)
	var chunk_update_time := (Time.get_ticks_usec() - chunk_update_start) / 1000.0

	# Update frustum culling
	var culling_start := Time.get_ticks_usec()
	if active_camera and chunk_manager:
		chunk_manager.update_frustum_culling(active_camera)
	var culling_time := (Time.get_ticks_usec() - culling_start) / 1000.0

	# Update debug info
	var debug_start := Time.get_ticks_usec()
	if debug_state != DebugState.OFF:
		_update_debug_info(delta)
	var debug_time := (Time.get_ticks_usec() - debug_start) / 1000.0

	var frame_total := (Time.get_ticks_usec() - frame_start) / 1000.0

	# Track frame times
	_frame_times.append(frame_total)
	if _frame_times.size() > 60:
		_frame_times.pop_front()

	# Log performance periodically
	var current_time := Time.get_ticks_msec() / 1000.0
	if current_time - _last_perf_log >= PERF_LOG_INTERVAL:
		_last_perf_log = current_time
		_log_performance_breakdown(delta, pos_time, chunk_update_time, culling_time, debug_time, frame_total)

## Log detailed performance breakdown
func _log_performance_breakdown(delta: float, pos_time: float, chunk_time: float, culling_time: float, debug_time: float, frame_time: float) -> void:
	var fps: float = 1.0 / delta
	var avg_frame: float = 0.0
	var max_frame: float = 0.0
	var min_frame: float = 999.0

	for t in _frame_times:
		avg_frame += t
		max_frame = max(max_frame, t)
		min_frame = min(min_frame, t)

	if _frame_times.size() > 0:
		avg_frame /= float(_frame_times.size())

	var engine_time := (delta * 1000.0) - frame_time  # Time spent outside our code

	print("========================================")
	print("[Performance] FPS: %.1f (delta: %.2fms)" % [fps, delta * 1000.0])
	print("[Performance] Frame times - Avg: %.2fms, Min: %.2fms, Max: %.2fms" % [avg_frame, min_frame, max_frame])
	print("[Performance] Breakdown:")
	print("  Position update: %.2fms (%.1f%%)" % [pos_time, (pos_time / (delta * 1000.0)) * 100.0])
	print("  Chunk update: %.2fms (%.1f%%)" % [chunk_time, (chunk_time / (delta * 1000.0)) * 100.0])
	print("  Frustum culling: %.2fms (%.1f%%)" % [culling_time, (culling_time / (delta * 1000.0)) * 100.0])
	print("  Debug UI: %.2fms (%.1f%%)" % [debug_time, (debug_time / (delta * 1000.0)) * 100.0])
	print("  Our code total: %.2fms (%.1f%%)" % [frame_time, (frame_time / (delta * 1000.0)) * 100.0])
	print("  Engine/GPU: %.2fms (%.1f%%)" % [engine_time, (engine_time / (delta * 1000.0)) * 100.0])
	print("========================================")

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
	chunk_manager.enable_threading = enable_threading  # Pass threading setting
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

	# Set chunk cache seed
	if chunk_manager.chunk_cache:
		print("[VoxelWorld] Setting chunk cache seed to %d..." % world_seed)
		chunk_manager.chunk_cache.set_world_seed(world_seed)

	print("[VoxelWorld] Systems connected")

	print("[VoxelWorld] ✓ All systems initialized successfully!")
	print("========================================")

## Setup debug UI
func _setup_debug_ui() -> void:
	# Always create debug elements, visibility controlled by debug_state
	debug_label = Label.new()
	debug_label.position = Vector2(10, 10)
	debug_label.add_theme_font_size_override("font_size", 14)
	add_child(debug_label)

	# Add axis gizmo (3D orientation indicator)
	axis_gizmo = AxisGizmo.new()
	add_child(axis_gizmo)

	# Set initial visibility based on debug_state
	_update_debug_visibility()

## Update debug information display (lightweight version)
func _update_debug_info(delta: float) -> void:
	if not debug_label:
		return

	# Console stats timer
	stats_timer += delta
	if stats_timer >= print_stats_interval:
		stats_timer = 0.0
		if chunk_manager:
			chunk_manager.print_stats()

	# LIGHTWEIGHT: Only show FPS and objects in frame
	var fps := Engine.get_frames_per_second()
	var objects := Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)

	var debug_text := ""
	debug_text += "FPS: %d\n" % fps
	debug_text += "Objects: %d\n" % objects
	debug_text += "Draw Calls: %d" % draw_calls

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

	# Update chunk cache seed
	if chunk_manager and chunk_manager.chunk_cache:
		chunk_manager.chunk_cache.set_world_seed(world_seed)

	# Reload chunks
	_update_chunks()

## Cleanup all systems
func cleanup() -> void:
	print("[VoxelWorld] Cleaning up...")

	if chunk_manager:
		print("[VoxelWorld] Cleaning up chunk manager...")
		chunk_manager.cleanup_all()

	if terrain_generator:
		print("[VoxelWorld] Cleaning up terrain generator...")
		terrain_generator = null

	if mesh_builder:
		print("[VoxelWorld] Cleaning up mesh builder...")
		mesh_builder = null

	print("[VoxelWorld] Cleanup complete")

## Cleanup on exit
func _exit_tree() -> void:
	print("[VoxelWorld] _exit_tree called")
	cleanup()

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

## Cycle through debug states: OFF -> FPS_ONLY -> FPS_AND_GIZMO -> OFF
func _cycle_debug_state() -> void:
	match debug_state:
		DebugState.OFF:
			debug_state = DebugState.FPS_ONLY
			print("[VoxelWorld] Debug: FPS + Draw Calls")
		DebugState.FPS_ONLY:
			debug_state = DebugState.FPS_AND_GIZMO
			print("[VoxelWorld] Debug: FPS + Draw Calls + Gizmo")
		DebugState.FPS_AND_GIZMO:
			debug_state = DebugState.OFF
			print("[VoxelWorld] Debug: OFF")

	# Update visibility
	_update_debug_visibility()

## Update debug element visibility based on current state
func _update_debug_visibility() -> void:
	if debug_label:
		debug_label.visible = (debug_state == DebugState.FPS_ONLY or debug_state == DebugState.FPS_AND_GIZMO)
	if axis_gizmo:
		axis_gizmo.visible = (debug_state == DebugState.FPS_AND_GIZMO)

## Legacy function for compatibility
func debug_toggle_info() -> void:
	_cycle_debug_state()

## Find active camera in scene tree
func _find_camera() -> Camera3D:
	var viewport := get_viewport()
	if viewport:
		return viewport.get_camera_3d()
	return null
