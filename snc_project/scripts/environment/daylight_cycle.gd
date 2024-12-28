# daylight_cycle.gd
# Attach this script to your DirectionalLight3D node to create a realistic day/night cycle

extends DirectionalLight3D

# Cycle settings
@export_group("Time Settings")
@export var day_duration: float = 720.0  # Duration of a full day in seconds (12 minutes default)
@export var starting_hour: float = 8.0   # Starting time in 24-hour format (8 AM default)

@export_group("Sun Movement")
@export var max_sun_height: float = 75.0 # Maximum height of sun in degrees
@export var min_sun_height: float = -15.0 # Minimum height of sun in degrees (slightly below horizon)

@export_group("Light Settings")
@export var max_light_energy: float = 1.5  # Maximum light intensity at noon
@export var min_light_energy: float = 0.0  # Minimum light intensity at night
@export var dawn_light_energy: float = 0.3 # Light intensity during dawn/dusk

# Color settings for different times of day
var sun_colors: Dictionary = {
	"dawn": Color(0.855, 0.686, 0.549),  # Warm orange sunrise
	"day": Color(1.0, 0.985, 0.937),     # Bright daylight
	"dusk": Color(0.855, 0.686, 0.549),  # Warm orange sunset
	"night": Color(0.188, 0.203, 0.309)  # Dark blue night
}

# Internal variables
var _current_time: float
var _environment: Environment

func _ready() -> void:
	# Convert starting hour to normalized time (0-1)
	_current_time = starting_hour / 24.0
	
	# Get the environment resource (you'll need to set this up)
	_environment = get_world_3d().environment
	if not _environment:
		push_warning("DaylightCycle: No Environment resource found. Create a WorldEnvironment node!")
	
	# Initialize sun position
	_update_sun_position(_current_time)
	_update_lighting(_current_time)

func _process(delta: float) -> void:
	# Update time (complete day cycle in day_duration seconds)
	_current_time += delta / day_duration
	_current_time = fmod(_current_time, 1.0)  # Keep between 0 and 1
	
	# Update sun position and lighting
	_update_sun_position(_current_time)
	_update_lighting(_current_time)

func _update_sun_position(time: float) -> void:
	# Calculate sun angle based on time
	var sun_angle = (time * 360.0) - 90.0  # -90 to start at sunrise
	
	# Calculate height of sun using sine wave
	var height = lerp(min_sun_height, max_sun_height, (sin(deg_to_rad(sun_angle)) + 1.0) / 2.0)
	
	# Update light rotation
	rotation_degrees = Vector3(height, sun_angle, 0.0)

func _update_lighting(time: float) -> void:
	# Convert time to 24-hour format
	var hour = time * 24.0
	
	# Determine light intensity and color based on time
	var light_energy: float
	var light_color: Color
	
	if hour < 6.0:  # Night to dawn
		light_energy = lerp(min_light_energy, dawn_light_energy, smoothstep(4.0, 6.0, hour))
		light_color = sun_colors.night.lerp(sun_colors.dawn, smoothstep(4.0, 6.0, hour))
	elif hour < 8.0:  # Dawn to day
		light_energy = lerp(dawn_light_energy, max_light_energy, smoothstep(6.0, 8.0, hour))
		light_color = sun_colors.dawn.lerp(sun_colors.day, smoothstep(6.0, 8.0, hour))
	elif hour < 16.0:  # Day
		light_energy = max_light_energy
		light_color = sun_colors.day
	elif hour < 18.0:  # Day to dusk
		light_energy = lerp(max_light_energy, dawn_light_energy, smoothstep(16.0, 18.0, hour))
		light_color = sun_colors.day.lerp(sun_colors.dusk, smoothstep(16.0, 18.0, hour))
	elif hour < 20.0:  # Dusk to night
		light_energy = lerp(dawn_light_energy, min_light_energy, smoothstep(18.0, 20.0, hour))
		light_color = sun_colors.dusk.lerp(sun_colors.night, smoothstep(18.0, 20.0, hour))
	else:  # Night
		light_energy = min_light_energy
		light_color = sun_colors.night
	
	# Update light properties
	light_energy = light_energy
	light_color = light_color
	
	# Update environment if available
	if _environment:
		_environment.ambient_light_color = light_color
		_environment.ambient_light_energy = light_energy * 0.2

# Get current hour in 24-hour format
func get_current_hour() -> float:
	return _current_time * 24.0

# Get current time as string (e.g., "14:30")
func get_time_string() -> String:
	var hour = int(get_current_hour())
	var minute = int((get_current_hour() - hour) * 60)
	return "%02d:%02d" % [hour, minute]
