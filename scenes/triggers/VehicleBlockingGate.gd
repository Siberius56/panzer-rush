extends Node3D
class_name VehicleBlockingGate

signal completed
signal gate_opened
signal gate_closed

@export_group("Groups")
@export var vehicle_group_name: String = "vehicle"
@export var vehicle_group_fallback_name: String = "vehicles"
@export var player_group_name: String = "player"
@export var player_group_fallback_name: String = "players"

@export_group("Nodes")
@export var door_path: NodePath = ^"Door"
@export var vehicle_open_area_path: NodePath = ^"VehicleOpenArea"
@export var unlock_button_path: NodePath = ^"UnlockButton"

@export_group("State")
@export var start_completed: bool = false
@export var start_open: bool = false
@export var debug_gate: bool = false

@export_group("Door behavior")
@export var close_when_no_vehicle: bool = true
@export var immediate_open_on_start: bool = true
@export var snap_close_when_vehicle_leaves: bool = false

@onready var door: Node = get_node_or_null(door_path)
@onready var vehicle_open_area: Area3D = get_node_or_null(vehicle_open_area_path) as Area3D
@onready var unlock_button: Node = get_node_or_null(unlock_button_path)

var _vehicles_inside: Dictionary = {}
var _completed: bool = false
var _is_open: bool = false
var _last_presence_has_vehicle: bool = false


func _ready() -> void:
	add_to_group("vehicle_blocking_gates")

	_completed = start_completed
	_is_open = start_open or _completed

	if vehicle_open_area != null:
		vehicle_open_area.monitoring = true
		vehicle_open_area.monitorable = true
		if not vehicle_open_area.body_entered.is_connected(_on_vehicle_detector_changed):
			vehicle_open_area.body_entered.connect(_on_vehicle_detector_changed)
		if not vehicle_open_area.body_exited.is_connected(_on_vehicle_detector_changed):
			vehicle_open_area.body_exited.connect(_on_vehicle_detector_changed)
		if not vehicle_open_area.area_entered.is_connected(_on_vehicle_detector_changed):
			vehicle_open_area.area_entered.connect(_on_vehicle_detector_changed)
		if not vehicle_open_area.area_exited.is_connected(_on_vehicle_detector_changed):
			vehicle_open_area.area_exited.connect(_on_vehicle_detector_changed)

	_apply_open_state_local(_is_open, immediate_open_on_start)
	_apply_button_completed_state_local(_completed)


func _physics_process(_delta: float) -> void:
	if not _can_drive_authoritative_state():
		return

	_update_from_vehicle_presence(false)


func interact(player_node: Node = null) -> bool:
	return request_complete_from_player(player_node)


func activate(player_node: Node = null) -> bool:
	return request_complete_from_player(player_node)


func use(player_node: Node = null) -> bool:
	return request_complete_from_player(player_node)


func request_complete_from_player(player_node: Node = null) -> bool:
	if _completed:
		return true

	if player_node != null and not _is_player_detector(player_node):
		return false

	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		var player_path: NodePath = NodePath("")
		if player_node != null and player_node.is_inside_tree():
			player_path = get_path_to(player_node)
		rpc_id(1, "rpc_request_complete_from_player", player_path)
		return true

	return _complete_gate(player_node)


@rpc("any_peer", "reliable")
func rpc_request_complete_from_player(player_path: NodePath = NodePath("")) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	var player_node: Node = null
	if not player_path.is_empty():
		player_node = get_node_or_null(player_path)

	_complete_gate(player_node)


@rpc("authority", "call_local", "reliable")
func rpc_apply_gate_state(completed_value: bool, open_value: bool, immediate: bool) -> void:
	_completed = completed_value
	_apply_open_state_local(open_value, immediate)
	_apply_button_completed_state_local(completed_value)


func is_completed() -> bool:
	return _completed


func is_open() -> bool:
	return _is_open


func reset_gate() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	_completed = false
	_rebuild_vehicle_presence()
	var should_open: bool = _vehicles_inside.size() > 0
	_request_gate_state(false, should_open, true, true)


func force_complete() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	_complete_gate(null, true)


func _on_vehicle_detector_changed(_detector: Node) -> void:
	if not _can_drive_authoritative_state():
		return

	call_deferred("_update_from_vehicle_presence", false)


func _update_from_vehicle_presence(immediate: bool) -> void:
	_rebuild_vehicle_presence()

	var has_vehicle: bool = _vehicles_inside.size() > 0
	var should_open: bool = _completed or has_vehicle

	if not close_when_no_vehicle and _last_presence_has_vehicle:
		should_open = true

	var should_snap: bool = immediate
	if not should_open and not _completed and snap_close_when_vehicle_leaves:
		should_snap = true

	_last_presence_has_vehicle = has_vehicle
	_request_gate_state(_completed, should_open, should_snap)


func _complete_gate(player_node: Node = null, bypass_player_check: bool = false) -> bool:
	if _completed:
		return true

	if not bypass_player_check:
		if player_node == null or not _is_player_detector(player_node):
			return false

	_completed = true
	_vehicles_inside.clear()
	_request_gate_state(true, true, false, true)
	completed.emit()

	if debug_gate:
		print("[VehicleBlockingGate] Porte complétée : ", get_path())

	return true


func _request_gate_state(completed_value: bool, open_value: bool, immediate: bool, force: bool = false) -> void:
	if not force and completed_value == _completed and open_value == _is_open and not immediate:
		return

	if multiplayer.has_multiplayer_peer():
		if not multiplayer.is_server():
			return
		rpc("rpc_apply_gate_state", completed_value, open_value, immediate)
		return

	rpc_apply_gate_state(completed_value, open_value, immediate)


func _apply_open_state_local(open_value: bool, immediate: bool) -> void:
	if _is_open == open_value and not immediate:
		return

	_is_open = open_value

	if door == null:
		door = get_node_or_null(door_path)

	if door == null:
		return

	if door.has_method("set_open"):
		door.call("set_open", open_value, immediate)
	elif open_value and door.has_method("open"):
		door.call("open", immediate)
	elif not open_value and door.has_method("close"):
		door.call("close", immediate)

	if open_value:
		gate_opened.emit()
	else:
		gate_closed.emit()


func _apply_button_completed_state_local(completed_value: bool) -> void:
	if unlock_button == null:
		unlock_button = get_node_or_null(unlock_button_path)

	if unlock_button == null:
		return

	if unlock_button.has_method("set_used"):
		unlock_button.call("set_used", completed_value)

func _rebuild_vehicle_presence() -> void:
	_vehicles_inside.clear()

	if vehicle_open_area == null:
		vehicle_open_area = get_node_or_null(vehicle_open_area_path) as Area3D
	if vehicle_open_area == null:
		return

	var detectors: Array = []
	detectors.append_array(vehicle_open_area.get_overlapping_bodies())
	detectors.append_array(vehicle_open_area.get_overlapping_areas())

	for detector in detectors:
		if detector == null or not is_instance_valid(detector):
			continue

		var vehicle_node: Node = _get_parent_in_vehicle_group(detector as Node)
		if vehicle_node == null or not is_instance_valid(vehicle_node):
			continue

		_vehicles_inside[vehicle_node.get_instance_id()] = vehicle_node


func _get_parent_in_vehicle_group(node: Node) -> Node:
	var current: Node = node
	while current != null:
		if _is_vehicle_node(current):
			return current
		current = current.get_parent()
	return null


func _is_vehicle_node(node: Node) -> bool:
	if node == null:
		return false
	if not vehicle_group_name.is_empty() and node.is_in_group(vehicle_group_name):
		return true
	if not vehicle_group_fallback_name.is_empty() and node.is_in_group(vehicle_group_fallback_name):
		return true
	return false


func _is_player_detector(node: Node) -> bool:
	if node == null:
		return false

	var current: Node = node
	while current != null:
		if _is_player_node(current):
			return true
		current = current.get_parent()

	return false


func _is_player_node(node: Node) -> bool:
	if node == null:
		return false
	if not player_group_name.is_empty() and node.is_in_group(player_group_name):
		return true
	if not player_group_fallback_name.is_empty() and node.is_in_group(player_group_fallback_name):
		return true
	return false


func _can_drive_authoritative_state() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
