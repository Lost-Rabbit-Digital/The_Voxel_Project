## AxisGizmo - 3D orientation indicator for UI
## Shows X/Y/Z axes that rotate with camera view
## Similar to 3D modeling software like Blender
class_name AxisGizmo
extends Control

## Settings
@export var gizmo_size: float = 60.0  ## Radius of the gizmo
@export var line_thickness: float = 3.0  ## Thickness of axis lines
@export var label_distance: float = 75.0  ## Distance of labels from center

## Colors for each axis (standard 3D convention)
const COLOR_X := Color(1.0, 0.3, 0.3)  # Red
const COLOR_Y := Color(0.3, 1.0, 0.3)  # Green
const COLOR_Z := Color(0.3, 0.5, 1.0)  # Blue
const COLOR_NEGATIVE := Color(0.5, 0.5, 0.5, 0.6)  # Gray for negative axes

## Camera to track
var camera: Camera3D

## Center point of gizmo (set in _ready)
var center: Vector2

func _ready() -> void:
	# Set size to bottom-right corner
	custom_minimum_size = Vector2(140, 140)
	size = custom_minimum_size

	# Position in bottom-right corner with some padding
	position = Vector2(
		get_viewport().get_visible_rect().size.x - size.x - 10,
		get_viewport().get_visible_rect().size.y - size.y - 10
	)

	# Center of the gizmo widget
	center = size / 2.0

	# Try to find camera
	_find_camera()

	# Redraw every frame
	set_process(true)

func _process(_delta: float) -> void:
	if not camera:
		_find_camera()

	queue_redraw()

func _find_camera() -> void:
	# Try to find the camera in the scene
	if not camera:
		var viewport := get_viewport()
		if viewport:
			camera = viewport.get_camera_3d()

func _draw() -> void:
	if not camera:
		# Draw a placeholder if no camera found
		draw_circle(center, 5.0, Color.RED)
		draw_string(ThemeDB.fallback_font, center + Vector2(-30, -10), "No Camera", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.RED)
		return

	# Get camera basis (orientation)
	var basis := camera.global_transform.basis

	# Project 3D axis directions to 2D screen space
	# We'll use the camera's basis to determine how axes appear
	var axis_x := Vector3.RIGHT
	var axis_y := Vector3.UP
	var axis_z := Vector3.FORWARD

	# Transform axes by camera basis (inverse to get camera-relative)
	var cam_x := basis.inverse() * axis_x
	var cam_y := basis.inverse() * axis_y
	var cam_z := basis.inverse() * axis_z

	# Convert to 2D screen coordinates
	# We flip Y because screen Y goes down, and flip Z for correct depth
	var screen_x := Vector2(cam_x.x, -cam_x.y) * gizmo_size
	var screen_y := Vector2(cam_y.x, -cam_y.y) * gizmo_size
	var screen_z := Vector2(cam_z.x, -cam_z.y) * gizmo_size

	# Depth values for sorting (what's in front)
	var depth_x := cam_x.z
	var depth_y := cam_y.z
	var depth_z := cam_z.z

	# Create array of axes with depth for sorting
	var axes := [
		{"pos": screen_x, "neg": -screen_x, "depth": depth_x, "color": COLOR_X, "label": "X", "depth_neg": -depth_x},
		{"pos": screen_y, "neg": -screen_y, "depth": depth_y, "color": COLOR_Y, "label": "Y", "depth_neg": -depth_y},
		{"pos": screen_z, "neg": -screen_z, "depth": depth_z, "color": COLOR_Z, "label": "Z", "depth_neg": -depth_z}
	]

	# Draw background circle
	draw_circle(center, gizmo_size + 5.0, Color(0.1, 0.1, 0.1, 0.5))
	draw_arc(center, gizmo_size + 5.0, 0, TAU, 32, Color(0.3, 0.3, 0.3, 0.8), 1.5)

	# Sort axes by depth (back to front)
	# We need to draw furthest axes first
	var all_axis_ends := []
	for axis in axes:
		all_axis_ends.append({"vec": axis.pos, "depth": axis.depth, "color": axis.color, "label": axis.label})
		all_axis_ends.append({"vec": axis.neg, "depth": axis.depth_neg, "color": COLOR_NEGATIVE, "label": "-" + axis.label})

	# Sort by depth (furthest first)
	all_axis_ends.sort_custom(func(a, b): return a.depth < b.depth)

	# Draw each axis line and label
	for axis_end in all_axis_ends:
		var end_pos: Vector2 = center + axis_end.vec
		var color: Color = axis_end.color

		# Make lines facing away dimmer
		if axis_end.depth < 0:
			color.a = 0.4

		# Draw line from center to end
		draw_line(center, end_pos, color, line_thickness, true)

		# Draw small circle at end
		draw_circle(end_pos, 4.0, color)

		# Draw label
		var label_pos: Vector2 = center + axis_end.vec.normalized() * label_distance
		var label_color: Color = color
		label_color.a = 1.0 if axis_end.depth > 0 else 0.5

		# Offset label slightly for better readability
		var label_offset := Vector2(-8, 5)
		draw_string(
			ThemeDB.fallback_font,
			label_pos + label_offset,
			axis_end.label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			label_color
		)

func _notification(what: int) -> void:
	# Reposition when viewport is resized
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_ENTER_TREE:
		call_deferred("_update_position")

func _update_position() -> void:
	if is_inside_tree():
		var viewport_size := get_viewport().get_visible_rect().size
		position = Vector2(
			viewport_size.x - size.x - 10,
			viewport_size.y - size.y - 10
		)
