extends Node3D
class_name TransportHelicopterEnemySpawner


enum FlightState {
	FLY_TO_DESTINATION,
	ARRIVAL_PAUSE,
	DESCENDING,
	UNLOADING,
	TAKEOFF_TURN,
	RETURNING
}


@export_group("Mission")
@export var unit_set_id: String = "rifle_8"
@export var spawn_position: Vector3 = Vector3.ZERO
@export var destination_position: Vector3 = Vector3.ZERO

@export_group("Flight")
@export var forward_speed: float = 18.0
@export var return_speed: float = 22.0
@export var climb_speed: float = 7.0
@export var landing_descent_speed: float = 5.0
@export var ground_clearance: float = 16.0
@export var landed_ground_offset: float = 1.2
@export var arrival_radius: float = 2.0
@export var arrival_pause_duration: float = 0.5
@export var unload_duration: float = 1.0
@export var turn_speed_degrees: float = 110.0
@export var takeoff_alignment_angle_degrees: float = 6.0
@export var max_forward_pitch_degrees: float = 14.0
@export var visual_pitch_smoothing: float = 6.0
@export var raycast_length: float = 180.0
@export var transform_sync_interval: float = 0.05

@export_group("Unit Spawn")
@export var base_unit_scene_path: String = "res://scenes/enemies/NetworkProceduralEnemy.tscn"
@export var tank_unit_scene_path: String = "res://scenes/enemies/EnemyTankVehicle.tscn"
@export var rocket_unit_scene_path: String = "res://scenes/enemies/NetworkRocketEnemy.tscn"
@export var spawn_grid_columns: int = 4
@export var spawn_grid_spacing: float = 2.5

@export_group("Node Paths")
@export var body_root_path: NodePath = ^"Body"
@export var ground_ray_cast_path: NodePath = ^"GroundRayCast3D"
@export var unit_spawn_markers_root_path: NodePath = ^"UnitSpawnMarkers"


var _state: int = FlightState.FLY_TO_DESTINATION
var _state_time: float = 0.0
var _sync_accumulator: float = 0.0
var _units_spawned: bool = false
var _setup_done: bool = false
var _current_horizontal_speed: float = 0.0
var _unit_sequence: int = 1
var _despawn_requested: bool = false

@onready var body_root: Node3D = get_node_or_null(body_root_path) as Node3D
@onready var ground_ray_cast: RayCast3D = get_node_or_null(ground_ray_cast_path) as RayCast3D
@onready var unit_spawn_markers_root: Node3D = get_node_or_null(unit_spawn_markers_root_path) as Node3D


func _ready() -> void:
	add_to_group("transport_helicopters")

	if ground_ray_cast != null:
		ground_ray_cast.enabled = true
		ground_ray_cast.target_position = Vector3.DOWN * raycast_length

	if not _setup_done:
		spawn_position = global_position
		if destination_position == Vector3.ZERO:
			destination_position = global_position + (-global_transform.basis.z * 20.0)

	_face_horizontal_target(destination_position)


func setup_transport_helicopter(
	spawn_transform: Transform3D,
	assigned_destination_position: Vector3,
	assigned_unit_set_id: String
) -> void:
	global_transform = spawn_transform
	spawn_position = spawn_transform.origin
	destination_position = assigned_destination_position
	unit_set_id = assigned_unit_set_id
	_setup_done = true
	_state = FlightState.FLY_TO_DESTINATION
	_state_time = 0.0
	_units_spawned = false

	_face_horizontal_target(destination_position)


func _process(delta: float) -> void:
	_apply_visual_pitch(delta)


func _physics_process(delta: float) -> void:
	if not _is_server_authority():
		return

	_state_time += delta

	match _state:
		FlightState.FLY_TO_DESTINATION:
			_process_fly_to_destination(delta)
		FlightState.ARRIVAL_PAUSE:
			_process_arrival_pause(delta)
		FlightState.DESCENDING:
			_process_descending(delta)
		FlightState.UNLOADING:
			_process_unloading(delta)
		FlightState.TAKEOFF_TURN:
			_process_takeoff_turn(delta)
		FlightState.RETURNING:
			_process_returning(delta)

	_sync_state_if_needed(delta)


func _process_fly_to_destination(delta: float) -> void:
	var horizontal_distance: float = _move_horizontal_towards(destination_position, forward_speed, delta)
	_follow_ground_clearance(delta)

	if horizontal_distance <= arrival_radius:
		_current_horizontal_speed = 0.0
		_set_state(FlightState.ARRIVAL_PAUSE)


func _process_arrival_pause(delta: float) -> void:
	_current_horizontal_speed = 0.0
	_follow_ground_clearance(delta)

	if _state_time >= arrival_pause_duration:
		_set_state(FlightState.DESCENDING)


func _process_descending(delta: float) -> void:
	_current_horizontal_speed = 0.0

	if _descend_to_ground(delta):
		_set_state(FlightState.UNLOADING)
		_spawn_units_once()


func _process_unloading(_delta: float) -> void:
	_current_horizontal_speed = 0.0

	if not _units_spawned:
		_spawn_units_once()

	if _state_time >= unload_duration:
		_set_state(FlightState.TAKEOFF_TURN)


func _process_takeoff_turn(delta: float) -> void:
	_current_horizontal_speed = 0.0
	_follow_ground_clearance(delta)

	var direction: Vector3 = _get_horizontal_direction_to(spawn_position)
	if direction.length() > 0.001:
		_rotate_towards_direction(direction, delta)

	if _is_aligned_with_position(spawn_position) and _is_at_cruise_height():
		_set_state(FlightState.RETURNING)


func _process_returning(delta: float) -> void:
	var horizontal_distance: float = _move_horizontal_towards(spawn_position, return_speed, delta)
	_follow_ground_clearance(delta)

	if horizontal_distance <= arrival_radius:
		_request_despawn()


func _move_horizontal_towards(target_position: Vector3, speed: float, delta: float) -> float:
	var direction: Vector3 = _get_horizontal_direction_to(target_position)
	var horizontal_distance: float = _get_horizontal_distance_to(target_position)

	if horizontal_distance <= 0.001:
		_current_horizontal_speed = 0.0
		return horizontal_distance

	var step: float = min(speed * delta, horizontal_distance)
	var new_position: Vector3 = global_position + (direction * step)
	global_position = new_position

	if delta > 0.0:
		_current_horizontal_speed = step / delta
	else:
		_current_horizontal_speed = 0.0

	_rotate_towards_direction(direction, delta)
	return horizontal_distance


func _follow_ground_clearance(delta: float) -> void:
	var ground_y: float = _get_ground_y()
	var target_y: float = ground_y + ground_clearance
	var new_position: Vector3 = global_position
	new_position.y = move_toward(global_position.y, target_y, climb_speed * delta)
	global_position = new_position


func _descend_to_ground(delta: float) -> bool:
	var ground_y: float = _get_ground_y()
	var target_y: float = ground_y + landed_ground_offset
	var new_position: Vector3 = global_position
	new_position.y = move_toward(global_position.y, target_y, landing_descent_speed * delta)
	global_position = new_position

	return absf(global_position.y - target_y) <= 0.08


func _get_ground_y() -> float:
	if ground_ray_cast == null:
		return global_position.y - ground_clearance

	ground_ray_cast.target_position = Vector3.DOWN * raycast_length
	ground_ray_cast.force_raycast_update()

	if ground_ray_cast.is_colliding():
		return ground_ray_cast.get_collision_point().y

	return global_position.y - ground_clearance


func _is_at_cruise_height() -> bool:
	var ground_y: float = _get_ground_y()
	var target_y: float = ground_y + ground_clearance
	return absf(global_position.y - target_y) <= 0.25


func _get_horizontal_direction_to(target_position: Vector3) -> Vector3:
	var direction: Vector3 = Vector3(
		target_position.x - global_position.x,
		0.0,
		target_position.z - global_position.z
	)

	if direction.length() <= 0.001:
		return Vector3.ZERO

	return direction.normalized()


func _get_horizontal_distance_to(target_position: Vector3) -> float:
	var offset: Vector3 = Vector3(
		target_position.x - global_position.x,
		0.0,
		target_position.z - global_position.z
	)

	return offset.length()


func _rotate_towards_direction(direction: Vector3, delta: float) -> void:
	if direction.length() <= 0.001:
		return

	var desired_yaw: float = _get_yaw_for_direction(direction)
	var turn_speed: float = deg_to_rad(turn_speed_degrees)
	rotation.y = rotate_toward(rotation.y, desired_yaw, turn_speed * delta)


func _face_horizontal_target(target_position: Vector3) -> void:
	var direction: Vector3 = _get_horizontal_direction_to(target_position)
	if direction.length() <= 0.001:
		return

	rotation.y = _get_yaw_for_direction(direction)


func _get_yaw_for_direction(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


func _is_aligned_with_position(target_position: Vector3) -> bool:
	var direction: Vector3 = _get_horizontal_direction_to(target_position)
	if direction.length() <= 0.001:
		return true

	var desired_yaw: float = _get_yaw_for_direction(direction)
	var angle_difference: float = absf(wrapf(desired_yaw - rotation.y, -PI, PI))
	return angle_difference <= deg_to_rad(takeoff_alignment_angle_degrees)


func _set_state(new_state: int) -> void:
	_state = new_state
	_state_time = 0.0


func _spawn_units_once() -> void:
	if _units_spawned:
		return

	_units_spawned = true

	var entries: Array[Dictionary] = _get_unit_entries_for_set(unit_set_id)
	var total_count: int = _get_total_unit_count(entries)
	var spawn_index: int = 0

	for entry: Dictionary in entries:
		var scene_path: String = String(entry.get("scene_path", base_unit_scene_path))
		var count: int = int(entry.get("count", 1))

		for local_index in range(count):
			var unit_name: String = "%s_Unit_%02d" % [name, spawn_index]
			var unit_transform: Transform3D = _get_unit_spawn_transform(spawn_index, total_count)
			var unit_id: int = _unit_sequence
			_unit_sequence += 1

			if multiplayer.multiplayer_peer != null:
				_spawn_unit_remote.rpc(unit_name, scene_path, unit_transform, unit_id)
			else:
				_spawn_unit_remote(unit_name, scene_path, unit_transform, unit_id)

			spawn_index += 1


func _get_unit_entries_for_set(requested_set_id: String) -> Array[Dictionary]:
	var sets: Dictionary = {
		"rifle_8": [
			{"scene_path": base_unit_scene_path, "count": 8}
		],
		"rifle_12": [
			{"scene_path": base_unit_scene_path, "count": 12}
		],
		"rifle_4_rocket_4": [
			{"scene_path": base_unit_scene_path, "count": 4},
			{"scene_path": rocket_unit_scene_path, "count": 4}
		],
		"tank_1": [
			{"scene_path": tank_unit_scene_path, "count": 1}
		],
		"tank_1_rifle_4": [
			{"scene_path": tank_unit_scene_path, "count": 1},
			{"scene_path": base_unit_scene_path, "count": 4}
		]
	}

	var source_entries: Array = []
	if sets.has(requested_set_id):
		source_entries = sets[requested_set_id]
	else:
		push_warning("[TransportHelicopter] Set d'unité introuvable : %s. Fallback sur rifle_8." % requested_set_id)
		source_entries = sets["rifle_8"]

	var result: Array[Dictionary] = []
	for entry in source_entries:
		if entry is Dictionary:
			result.append((entry as Dictionary).duplicate(true))

	return result


func _get_total_unit_count(entries: Array[Dictionary]) -> int:
	var total_count: int = 0

	for entry: Dictionary in entries:
		total_count += max(0, int(entry.get("count", 0)))

	return total_count


func _get_unit_spawn_transform(spawn_index: int, total_count: int) -> Transform3D:
	var markers: Array[Node3D] = _get_unit_spawn_markers()
	if spawn_index >= 0 and spawn_index < markers.size():
		var marker: Node3D = markers[spawn_index]
		if marker != null and is_instance_valid(marker):
			return marker.global_transform

	var local_offset: Vector3 = _get_grid_offset(spawn_index, total_count)
	var spawn_position_on_ground: Vector3 = global_position
	spawn_position_on_ground += global_transform.basis.x * local_offset.x
	spawn_position_on_ground += global_transform.basis.z * local_offset.z
	spawn_position_on_ground.y = _get_ground_y() + 0.08

	return Transform3D(global_transform.basis, spawn_position_on_ground)


func _get_unit_spawn_markers() -> Array[Node3D]:
	var result: Array[Node3D] = []
	if unit_spawn_markers_root == null:
		return result

	for child in unit_spawn_markers_root.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if child is Node3D:
			result.append(child as Node3D)

	return result


func _get_grid_offset(spawn_index: int, total_count: int) -> Vector3:
	var safe_total: int = max(1, total_count)
	var columns: int = min(max(1, spawn_grid_columns), safe_total)
	var rows: int = ceili(float(safe_total) / float(columns))
	var row: int = floori(float(spawn_index) / float(columns))
	var column: int = spawn_index % columns

	var x: float = (float(column) - ((float(columns) - 1.0) * 0.5)) * spawn_grid_spacing
	var z: float = (float(row) - ((float(rows) - 1.0) * 0.5)) * spawn_grid_spacing

	return Vector3(x, 0.0, z)


@rpc("authority", "call_local", "reliable")
func _spawn_unit_remote(
	unit_name: String,
	requested_scene_path: String,
	unit_transform: Transform3D,
	unit_id: int
) -> void:
	if get_parent() == null:
		return

	if get_parent().get_node_or_null(unit_name) != null:
		return

	var scene_path: String = _resolve_unit_scene_path(requested_scene_path)
	if scene_path.is_empty():
		push_warning("[TransportHelicopter] Impossible de trouver une scène d'unité, même le fallback est absent.")
		return

	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		push_warning("[TransportHelicopter] Impossible de charger l'unité : %s" % scene_path)
		return

	var unit: Node = scene.instantiate()
	unit.name = unit_name
	unit.set_multiplayer_authority(NetworkManager.SERVER_PEER_ID)

	_set_property_if_exists(unit, "enemy_id", unit_id)
	_set_property_if_exists(unit, "unit_set_id", unit_set_id)

	add_sibling(unit)

	if unit is Node3D:
		(unit as Node3D).global_transform = unit_transform


func _resolve_unit_scene_path(requested_scene_path: String) -> String:
	if not requested_scene_path.is_empty() and ResourceLoader.exists(requested_scene_path):
		return requested_scene_path

	if ResourceLoader.exists(base_unit_scene_path):
		return base_unit_scene_path

	return ""


func _sync_state_if_needed(delta: float) -> void:
	if multiplayer.multiplayer_peer == null:
		return

	_sync_accumulator += delta
	if _sync_accumulator < transform_sync_interval:
		return

	_sync_accumulator = 0.0
	_receive_helicopter_state_remote.rpc(global_transform, _current_horizontal_speed, _state)


@rpc("authority", "unreliable")
func _receive_helicopter_state_remote(
	new_transform: Transform3D,
	new_horizontal_speed: float,
	new_state: int
) -> void:
	if _is_server_authority():
		return

	global_transform = new_transform
	_current_horizontal_speed = new_horizontal_speed
	_state = new_state


func _request_despawn() -> void:
	if _despawn_requested:
		return

	_despawn_requested = true

	if multiplayer.multiplayer_peer != null:
		_despawn_remote.rpc()
		return

	_despawn_remote()


@rpc("authority", "call_local", "reliable")
func _despawn_remote() -> void:
	queue_free()



func _apply_visual_pitch(delta: float) -> void:
	if body_root == null:
		return

	var speed_reference: float = max(0.01, max(forward_speed, return_speed))
	var speed_factor: float = clampf(_current_horizontal_speed / speed_reference, 0.0, 1.0)
	var target_pitch: float = -deg_to_rad(max_forward_pitch_degrees) * speed_factor
	var interpolation_weight: float = clampf(delta * visual_pitch_smoothing, 0.0, 1.0)

	body_root.rotation.x = lerp_angle(body_root.rotation.x, target_pitch, interpolation_weight)


func _set_property_if_exists(target: Object, property_name: String, value: Variant) -> void:
	if target == null:
		return

	for property_info in target.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			target.set(property_name, value)
			return


func _is_server_authority() -> bool:
	if multiplayer.multiplayer_peer == null:
		return true

	return multiplayer.is_server()
