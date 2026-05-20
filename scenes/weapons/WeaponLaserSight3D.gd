extends Node3D
class_name WeaponLaserSight3D

@export var laser_radius: float = 0.018
@export var max_length: float = 80.0

@onready var beam: MeshInstance3D = $Beam

func _ready() -> void:
	set_laser_visible(false)

func set_laser_visible(active: bool) -> void:
	visible = active
	if beam != null:
		beam.visible = active

func set_laser_segment(start_position: Vector3, end_position: Vector3) -> void:
	if beam == null:
		return

	var segment: Vector3 = end_position - start_position
	var segment_length: float = min(segment.length(), max_length)
	if segment_length <= 0.01:
		set_laser_visible(false)
		return

	var y_axis: Vector3 = segment.normalized()
	var x_axis: Vector3 = y_axis.cross(Vector3.FORWARD)
	if x_axis.length_squared() <= 0.001:
		x_axis = y_axis.cross(Vector3.RIGHT)
	x_axis = x_axis.normalized()

	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	var midpoint: Vector3 = start_position + y_axis * segment_length * 0.5
	global_transform = Transform3D(Basis(x_axis, y_axis, z_axis).orthonormalized(), midpoint)
	beam.scale = Vector3(laser_radius, segment_length, laser_radius)
	set_laser_visible(true)
