extends Node3D
class_name CameraShakeController

# Visual-only camera shake controller.
# Important:
# - Does NOT move the SpringArm3D.
# - Does NOT move the CameraRig.
# - Does NOT change Camera3D.position.
# - Does NOT change SpringArm3D.spring_length.
#
# It only applies temporary Camera3D projection offsets and a small roll.
# This avoids breaking the camera distance when entering or leaving a vehicle.

@export var enabled: bool = true
@export var only_when_camera_is_current: bool = true

@export_group("Camera")
# Recommended when the controller is a child of CameraRig:
# ../SpringArm3D/Camera3D
@export var camera_path: NodePath = NodePath("")
@export var use_active_camera_fallback: bool = true

# Kept only to avoid stale .tscn export warnings from older versions.
# This script no longer shakes a target node.
@export var target_path: NodePath = NodePath("")

@export_group("Shake Shape")
@export var trauma_decay_per_second: float = 1.55
@export var max_trauma: float = 1.0
@export var frequency: float = 25.0
@export_range(0.5, 2.0, 0.05) var trauma_power: float = 0.70
@export var minimum_added_trauma: float = 0.14

# Camera3D.h_offset / v_offset are visual offsets. They do not change the
# SpringArm distance, so they are safe for the vehicle camera zoom.
@export var max_h_offset: float = 0.46
@export var max_v_offset: float = 0.34

# Rotation is temporary and removed every frame before the next shake sample.
# Roll is the safest visible rotation. Pitch and yaw are kept modest because they can disturb aiming.
@export var max_pitch_degrees: float = 0.35
@export var max_yaw_degrees: float = 0.28
@export var max_roll_degrees: float = 3.25
@export var allow_pitch_yaw_rotation: bool = true

@export_group("Debug")
@export var debug_logs: bool = false
@export var debug_print_interval: float = 0.25
@export var debug_force_big_test_offset: bool = false

var trauma: float = 0.0

var _camera: Camera3D = null
var _last_camera: Camera3D = null
var _last_h_offset: float = 0.0
var _last_v_offset: float = 0.0
var _last_pitch: float = 0.0
var _last_yaw: float = 0.0
var _last_roll: float = 0.0

var _shake_time: float = 0.0
var _seed_x: float = 0.0
var _seed_y: float = 0.0
var _seed_z: float = 0.0
var _seed_pitch: float = 0.0
var _seed_yaw: float = 0.0
var _frequency_multiplier: float = 1.0
var _debug_timer: float = 0.0


static func emit_local_shake(tree: SceneTree, intensity: float, frequency_multiplier: float = 1.0) -> void:
	if tree == null:
		return

	for receiver in tree.get_nodes_in_group(&"camera_shake_receiver"):
		if receiver != null and receiver.has_method(&"add_shake"):
			receiver.add_shake(intensity, frequency_multiplier)


static func emit_global_shake(
	tree: SceneTree,
	source_position: Vector3,
	intensity: float,
	radius: float = 18.0,
	falloff: float = 1.35,
	frequency_multiplier: float = 1.0
) -> void:
	if tree == null:
		return

	for receiver in tree.get_nodes_in_group(&"camera_shake_receiver"):
		if receiver != null and receiver.has_method(&"add_world_shake"):
			receiver.add_world_shake(source_position, intensity, radius, falloff, frequency_multiplier)


func _ready() -> void:
	add_to_group(&"camera_shake_receiver")
	set_process(true)

	_seed_x = randf_range(0.0, 1000.0)
	_seed_y = randf_range(0.0, 1000.0)
	_seed_z = randf_range(0.0, 1000.0)
	_seed_pitch = randf_range(0.0, 1000.0)
	_seed_yaw = randf_range(0.0, 1000.0)

	_camera = _resolve_camera()

	if debug_logs:
		print("CameraShakeController ready. self=", get_path(), " camera=", _debug_node_path(_camera), " active=", _debug_node_path(_get_active_camera()))


func _exit_tree() -> void:
	_clear_previous_offset()


func add_shake(intensity: float, frequency_multiplier: float = 1.0) -> void:
	if not enabled:
		return

	if intensity <= 0.0:
		return

	var added_trauma: float = maxf(intensity, minimum_added_trauma)
	trauma = clampf(trauma + added_trauma, 0.0, max_trauma)
	_frequency_multiplier = maxf(_frequency_multiplier, maxf(frequency_multiplier, 0.1))

	if debug_logs:
		print("Camera shake add. intensity=", intensity, " added=", added_trauma, " trauma=", trauma, " camera=", _debug_node_path(_resolve_camera()))


func add_world_shake(
	source_position: Vector3,
	intensity: float,
	radius: float = 18.0,
	falloff: float = 1.35,
	frequency_multiplier: float = 1.0
) -> void:
	if not enabled:
		return

	if intensity <= 0.0 or radius <= 0.0:
		return

	var reference_camera: Camera3D = _resolve_camera()
	if reference_camera == null:
		return

	var distance: float = reference_camera.global_position.distance_to(source_position)
	if distance > radius:
		return

	var normalized_distance: float = clampf(distance / radius, 0.0, 1.0)
	var attenuation: float = pow(1.0 - normalized_distance, maxf(falloff, 0.01))
	add_shake(intensity * attenuation, frequency_multiplier)


func reset_shake() -> void:
	trauma = 0.0
	_frequency_multiplier = 1.0
	_clear_previous_offset()


func debug_force_visible_shake() -> void:
	add_shake(1.0, 1.0)


func _process(delta: float) -> void:
	_clear_previous_offset()

	if not enabled:
		return

	_camera = _resolve_camera()
	if _camera == null or not is_instance_valid(_camera):
		return

	if only_when_camera_is_current and not _is_camera_current(_camera):
		return

	if trauma <= 0.0005:
		trauma = 0.0
		_frequency_multiplier = 1.0
		return

	_shake_time += delta * frequency * _frequency_multiplier

	var power: float = pow(clampf(trauma, 0.0, max_trauma), trauma_power)
	var h_offset: float = _smooth_signal(_seed_x, 1.00) * max_h_offset * power
	var v_offset: float = _smooth_signal(_seed_y, 1.41) * max_v_offset * power
	var pitch_degrees: float = 0.0
	var yaw_degrees: float = 0.0
	var roll_degrees: float = _smooth_signal(_seed_z, 1.23) * max_roll_degrees * power

	if allow_pitch_yaw_rotation:
		pitch_degrees = _smooth_signal(_seed_pitch, 1.09) * max_pitch_degrees * power
		yaw_degrees = _smooth_signal(_seed_yaw, 1.17) * max_yaw_degrees * power

	if debug_force_big_test_offset:
		v_offset += 1.25
		roll_degrees += 8.0

	var pitch: float = deg_to_rad(pitch_degrees)
	var yaw: float = deg_to_rad(yaw_degrees)
	var roll: float = deg_to_rad(roll_degrees)

	_camera.h_offset += h_offset
	_camera.v_offset += v_offset
	_camera.rotation.x += pitch
	_camera.rotation.y += yaw
	_camera.rotation.z += roll

	_last_camera = _camera
	_last_h_offset = h_offset
	_last_v_offset = v_offset
	_last_pitch = pitch
	_last_yaw = yaw
	_last_roll = roll

	if debug_logs:
		_debug_timer -= delta
		if _debug_timer <= 0.0:
			_debug_timer = maxf(debug_print_interval, 0.05)
			print("Camera shake process. trauma=", trauma, " power=", power, " h=", h_offset, " v=", v_offset, " pitch_deg=", pitch_degrees, " yaw_deg=", yaw_degrees, " roll_deg=", roll_degrees, " camera=", _debug_node_path(_camera))

	trauma = maxf(trauma - trauma_decay_per_second * delta, 0.0)
	_frequency_multiplier = move_toward(_frequency_multiplier, 1.0, delta * 3.0)


func _clear_previous_offset() -> void:
	if _last_camera != null and is_instance_valid(_last_camera):
		_last_camera.h_offset -= _last_h_offset
		_last_camera.v_offset -= _last_v_offset
		_last_camera.rotation.x -= _last_pitch
		_last_camera.rotation.y -= _last_yaw
		_last_camera.rotation.z -= _last_roll

	_last_camera = null
	_last_h_offset = 0.0
	_last_v_offset = 0.0
	_last_pitch = 0.0
	_last_yaw = 0.0
	_last_roll = 0.0


func _smooth_signal(seed: float, speed_multiplier: float) -> float:
	var time_value: float = (_shake_time * speed_multiplier) + seed
	return (sin(time_value) * 0.62) + (sin(time_value * 2.11 + seed * 0.37) * 0.38)


func _resolve_camera() -> Camera3D:
	if camera_path != NodePath(""):
		var explicit_camera: Camera3D = get_node_or_null(camera_path) as Camera3D
		if explicit_camera != null:
			return explicit_camera

	if use_active_camera_fallback:
		var active_camera: Camera3D = _get_active_camera()
		if active_camera != null:
			return active_camera

	var parent_node: Node = get_parent()
	if parent_node != null:
		var nearby_camera: Camera3D = _find_first_camera(parent_node)
		if nearby_camera != null:
			return nearby_camera

	return null


func _get_active_camera() -> Camera3D:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return null

	var active_camera: Camera3D = viewport.get_camera_3d()
	if active_camera != null and is_instance_valid(active_camera):
		return active_camera

	return null


func _is_camera_current(camera_to_check: Camera3D) -> bool:
	if camera_to_check == null or not is_instance_valid(camera_to_check):
		return false

	if camera_to_check.current:
		return true

	var active_camera: Camera3D = _get_active_camera()
	return active_camera == camera_to_check


func _find_first_camera(root: Node) -> Camera3D:
	if root == null:
		return null

	if root is Camera3D:
		return root as Camera3D

	for child in root.get_children():
		var found: Camera3D = _find_first_camera(child)
		if found != null:
			return found

	return null


func _debug_node_path(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return "null"

	return str(node.get_path())
