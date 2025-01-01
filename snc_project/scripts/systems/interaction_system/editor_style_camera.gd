## A camera controller that mimics Unreal Editor's viewport camera controls
extends Camera3D

@onready var game_world: Node3D = $".."

# Camera movement settings
@export_group("Movement Settings")
## Base movement speed
@export var base_speed: float = 5.0 
## Speed multiplier when holding shift          
@export var speed_multiplier: float = 2.0  
## Mouse look sensitivity   
@export var mouse_sensitivity: float = 0.003  
## Zoom speed with right+left mouse
@export var zoom_speed: float = 1.0     
## Movement acceleration      
@export var acceleration: float = 3.0     
## Movement deceleration    
@export var deceleration: float = 5.0         

# Camera behavior settings
@export_group("Behavior Settings")
## Invert vertical mouse movement
@export var invert_y: bool = true      
## Invert zoom direction       
@export var invert_zoom: bool = false         
## Enable movement smoothing
@export var smooth_movement: bool = true      

# Internal variables for camera state
var _current_velocity: Vector3 = Vector3.ZERO
var _target_velocity: Vector3 = Vector3.ZERO
var _mouse_captured: bool = false
var _last_mouse_position: Vector2 = Vector2.ZERO
var _initial_rotation: Vector3
var _total_pitch: float = 0.0

func _ready() -> void:
	# Store initial rotation to use as reference
	_initial_rotation = rotation_degrees
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_captured = true

func _input(event: InputEvent) -> void:
	# Handle mouse button events
	if event is InputEventMouseButton:
			if Input.is_action_pressed("zoom"):
				_last_mouse_position = event.position
	
	# Handle mouse motion for camera rotation and zoom
	elif event is InputEventMouseMotion:
		if _mouse_captured:
			# Handle camera rotation
			var rotation_delta = event.relative * mouse_sensitivity
			
			if Input.is_action_pressed("zoom"):
				# Handle zoom with right + left/middle mouse drag
				var zoom_factor = zoom_speed * (-event.relative.y * 0.01)
				if invert_zoom:
					zoom_factor = -zoom_factor
				
				# Move camera forward/backward based on zoom
				translate_object_local(Vector3(0, 0, zoom_factor))
			else:
				# Regular camera rotation
				_total_pitch = clamp(
					_total_pitch + (-rotation_delta.y if invert_y else rotation_delta.y),
					-PI/2,  # Limit looking up
					PI/2    # Limit looking down
				)
				
				# Apply rotations
				rotation.x = _total_pitch
				rotate_y(-rotation_delta.x)

func _process(delta: float) -> void:
	if _mouse_captured:
		# Check if trying to escape from the game
		if Input.is_action_pressed("escape"):
			get_tree().quit()
			
		# Calculate movement direction based on input
		var input_dir = Vector3.ZERO
		
		if Input.is_action_pressed("forward"):
			input_dir.z -= 1
		if Input.is_action_pressed("backward"):
			input_dir.z += 1
		if Input.is_action_pressed("left"):
			input_dir.x -= 1
		if Input.is_action_pressed("right"):
			input_dir.x += 1
		if Input.is_action_pressed("up"):
			input_dir.y += 1
		if Input.is_action_pressed("down"):
			input_dir.y -= 1
			
		# Normalize input direction
		input_dir = input_dir.normalized()
		
		# Apply speed modifier if shift is held
		var current_speed = base_speed
		if Input.is_action_pressed("sprint"):
			current_speed *= speed_multiplier
		
		# Calculate target velocity
		_target_velocity = input_dir * current_speed
		
		# Smooth movement
		if smooth_movement:
			_current_velocity = _current_velocity.lerp(
				_target_velocity,
				1.0 - exp(-acceleration * delta)
			)
		else:
			_current_velocity = _target_velocity
		
		# Apply deceleration when no input
		if input_dir == Vector3.ZERO:
			_current_velocity = _current_velocity.lerp(
				Vector3.ZERO,
				1.0 - exp(-deceleration * delta)
			)
		
		# Move the camera based on its current rotation
		translate_object_local(_current_velocity * delta)

# Reset camera to initial position and rotation
func reset_camera() -> void:
	transform.origin = Vector3.ZERO
	rotation_degrees = _initial_rotation
	_total_pitch = 0.0
	_current_velocity = Vector3.ZERO
	_target_velocity = Vector3.ZERO
