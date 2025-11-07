## TestCameraController - Simple flying camera for voxel engine testing
## WASD to move, mouse to look, E/Q for up/down, Shift to sprint
extends Camera3D

## Movement settings
@export var move_speed: float = 20.0
@export var sprint_multiplier: float = 3.0
@export var mouse_sensitivity: float = 0.003

## Look rotation
var rotation_x: float = 0.0
var rotation_y: float = 0.0

## Mouse captured
var mouse_captured: bool = false

func _ready() -> void:
	# Start with mouse captured for immediate control
	capture_mouse()

func _input(event: InputEvent) -> void:
	# Toggle mouse capture with Escape
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed:
			if mouse_captured:
				release_mouse()
			else:
				capture_mouse()

	# Handle mouse look
	if event is InputEventMouseMotion and mouse_captured:
		rotation_y -= event.relative.x * mouse_sensitivity
		rotation_x -= event.relative.y * mouse_sensitivity

		# Clamp vertical rotation
		rotation_x = clamp(rotation_x, -PI / 2.0, PI / 2.0)

		# Apply rotation
		rotation.x = rotation_x
		rotation.y = rotation_y

func _process(delta: float) -> void:
	if not mouse_captured:
		return

	# Get input direction
	var input_dir := Vector3.ZERO

	if Input.is_key_pressed(KEY_W):
		input_dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		input_dir += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		input_dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		input_dir += transform.basis.x
	if Input.is_key_pressed(KEY_E):
		input_dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		input_dir -= Vector3.UP

	# Apply sprint
	var current_speed := move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		current_speed *= sprint_multiplier

	# Move camera
	if input_dir.length() > 0:
		input_dir = input_dir.normalized()
		global_position += input_dir * current_speed * delta

## Capture mouse for camera control
func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true

## Release mouse
func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_captured = false

## Debug: Press R to regenerate world
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				# Regenerate world
				var voxel_world := get_node_or_null("/root/VoxelTestScene/VoxelWorld")
				if voxel_world and voxel_world.has_method("regenerate_world"):
					voxel_world.regenerate_world()
					print("Regenerating world...")

			KEY_F:
				# Toggle debug info
				var voxel_world := get_node_or_null("/root/VoxelTestScene/VoxelWorld")
				if voxel_world and voxel_world.has_method("debug_toggle_info"):
					voxel_world.debug_toggle_info()

			KEY_MINUS:
				# Decrease render distance
				var voxel_world := get_node_or_null("/root/VoxelTestScene/VoxelWorld")
				if voxel_world and voxel_world.has_method("debug_set_render_distance"):
					voxel_world.debug_set_render_distance(voxel_world.render_distance - 2)

			KEY_EQUAL:  # + key
				# Increase render distance
				var voxel_world := get_node_or_null("/root/VoxelTestScene/VoxelWorld")
				if voxel_world and voxel_world.has_method("debug_set_render_distance"):
					voxel_world.debug_set_render_distance(voxel_world.render_distance + 2)
