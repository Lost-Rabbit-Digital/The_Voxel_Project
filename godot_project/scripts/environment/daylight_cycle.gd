# simple_sun_orbit.gd
extends DirectionalLight3D

@export var orbit_speed: float = 1.0  # Full rotation time in minutes
@export var max_height: float = 75.0  # Maximum height of sun
@export var min_height: float = -15.0 # Minimum height of sun

var current_angle: float = 0.0
var angle_offset: float = 0.0

func _process(delta: float) -> void:
	# Update angle (convert minutes to seconds)
	current_angle += delta * (360.0 / (orbit_speed * 60.0))
	current_angle = fmod(current_angle, 360.0)
	# Offset the sun slightly while it rotates
	angle_offset += 0.01
	
	# Calculate height using sine wave
	var height = lerp(min_height, max_height, (sin(deg_to_rad(current_angle)) + 1.0) / 2.0)
	
	# Update sun rotation
	rotation_degrees = Vector3(-height, current_angle + angle_offset, 0.0)
