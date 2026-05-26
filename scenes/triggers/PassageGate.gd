extends Node3D

# PassageGate bidirectionnel pour transition entre deux LevelBlock.
# Principe :
# - les deux portes sont fermées par défaut ;
# - un bouton extérieur ouvre le côté d'entrée et prépare le sens de transition ;
# - quand tous les joueurs sont dans le sas, le gate active le block de sortie ;
# - la porte de sortie s'ouvre ;
# - quand tout le monde a quitté le sas, le gate reste prêt dans le sens inverse.

const GATE_IDLE: int = 0
const GATE_READY_FRONT_TO_REAR: int = 1
const GATE_READY_REAR_TO_FRONT: int = 2
const GATE_WAITING_EXIT: int = 3

@export_group("Players")
@export var player_group_name: String = "players"
@export var enemy_group_name: String = "enemies"
@export var enemy_secondary_group_name: String = "enemy"
@export var vehicle_group_name: String = "vehicles"
@export var ignore_dead_players: bool = false
@export var count_vehicle_inside_as_all_players_inside: bool = true
@export var show_prompt_when_vehicle_inside: bool = true

@export_group("Validation")
@export var validation_duration: float = 3.0
@export var require_no_enemy_inside: bool = true
@export var auto_prepare_inverse_after_exit: bool = true

@export_group("Interaction")
@export var interact_action_name: StringName = &"interact"
@export var allow_input_polling_on_button_areas: bool = true
@export var debug_open_when_player_enters_button_area: bool = false

@export_group("Node Paths")
@export var passage_area_path: NodePath = ^"PassageArea"
@export var front_button_area_path: NodePath = ^"FrontButtonArea"
@export var rear_button_area_path: NodePath = ^"RearButtonArea"
@export var front_door_path: NodePath = ^"FrontDoor"
@export var rear_door_path: NodePath = ^"RearDoor"
@export var tank_tp_path: NodePath = ^"%Tank_TP"
@export var respawn_spawn_points_path: NodePath = ^"SpawnPoints"
@export var capture_node_path: NodePath = ^"NodeCapture"

@export_group("Doors")
@export var force_closed_on_ready: bool = true
@export var front_door_open_offset: Vector3 = Vector3(0.0, 4.0, 0.0)
@export var rear_door_open_offset: Vector3 = Vector3(0.0, 4.0, 0.0)
@export var door_animation_duration: float = 0.35

@export_group("Debug")
@export var debug_print_events: bool = false

@onready var passage_area: Area3D = get_node_or_null(passage_area_path) as Area3D
@onready var front_button_area: Area3D = get_node_or_null(front_button_area_path) as Area3D
@onready var rear_button_area: Area3D = get_node_or_null(rear_button_area_path) as Area3D
@onready var front_door: Node3D = get_node_or_null(front_door_path) as Node3D
@onready var rear_door: Node3D = get_node_or_null(rear_door_path) as Node3D
@onready var tank_tp_marker: Node3D = get_node_or_null(tank_tp_path) as Node3D
@onready var respawn_spawn_points_root: Node3D = get_node_or_null(respawn_spawn_points_path) as Node3D
@onready var node_capture: Node3D = get_node_or_null(capture_node_path) as Node3D

var front_block: Node3D = null
var rear_block: Node3D = null
var level_runtime_manager: Node = null
var front_block_label: String = "front"
var rear_block_label: String = "rear"

var _players_inside: Dictionary = {}
var _enemies_inside: Dictionary = {}
var _vehicles_inside: Dictionary = {}
var _front_button_players: Dictionary = {}
var _rear_button_players: Dictionary = {}

var _gate_state: int = GATE_IDLE
var _validation_timer: float = 0.0
var _last_travel_front_to_rear: bool = true
var _waiting_exit_elapsed: float = 0.0

var _front_closed_position: Vector3 = Vector3.ZERO
var _rear_closed_position: Vector3 = Vector3.ZERO
var _front_is_open: bool = false
var _rear_is_open: bool = false
var _front_tween: Tween = null
var _rear_tween: Tween = null


func _ready() -> void:
	add_to_group("passage_gates")

	_configure_area(passage_area)
	_configure_area(front_button_area)
	_configure_area(rear_button_area)

	if front_door != null:
		_front_closed_position = front_door.global_position
	if rear_door != null:
		_rear_closed_position = rear_door.global_position

	if node_capture != null and is_instance_valid(node_capture):
		node_capture.hide()

	if force_closed_on_ready:
		_force_door_scene_start_closed(front_door)
		_force_door_scene_start_closed(rear_door)
		_close_both_doors(true, true)
	else:
		_close_both_doors(true, true)

	_debug("Prêt. Les deux portes sont fermées.")


func _physics_process(delta: float) -> void:
	_rebuild_presence()
	_update_button_interaction()
	_update_validation(delta)
	_update_exit_reset(delta)
	_refresh_hud_feedback()


func configure_passage_blocks(new_front_block: Node3D, new_rear_block: Node3D, new_front_label: String = "front", new_rear_label: String = "rear", new_manager: Node = null) -> void:
	front_block = new_front_block
	rear_block = new_rear_block
	front_block_label = new_front_label
	rear_block_label = new_rear_label
	level_runtime_manager = new_manager


func press_front_button(_player: Node = null) -> void:
	_request_prepare_direction(true)


func press_rear_button(_player: Node = null) -> void:
	_request_prepare_direction(false)


func interact_from_world_position(world_position: Vector3, player: Node = null) -> void:
	var local_position: Vector3 = to_local(world_position)
	if local_position.z <= 0.0:
		press_front_button(player)
	else:
		press_rear_button(player)


func reset_passage() -> void:
	_gate_state = GATE_IDLE
	_validation_timer = 0.0
	_waiting_exit_elapsed = 0.0
	_close_both_doors(false)
	_hide_feedback_for_all_players()
	if node_capture != null and is_instance_valid(node_capture):
		node_capture.hide()


func get_respawn_spawn_points() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var root: Node3D = _get_respawn_spawn_points_root()
	if root == null or not is_instance_valid(root):
		return result

	for child: Node in root.get_children():
		if child is Node3D:
			result.append(child as Node3D)

	return result


func is_ready_for_front_to_rear() -> bool:
	return _gate_state == GATE_READY_FRONT_TO_REAR


func is_ready_for_rear_to_front() -> bool:
	return _gate_state == GATE_READY_REAR_TO_FRONT


func _configure_area(area: Area3D) -> void:
	if area == null:
		return
	area.monitoring = true
	area.monitorable = true


func _request_prepare_direction(front_to_rear: bool) -> void:
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			rpc("rpc_prepare_direction", front_to_rear)
		else:
			rpc_id(1, "rpc_request_prepare_direction", front_to_rear)
		return

	rpc_prepare_direction(front_to_rear)


@rpc("any_peer", "reliable")
func rpc_request_prepare_direction(front_to_rear: bool) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	rpc("rpc_prepare_direction", front_to_rear)


@rpc("authority", "call_local", "reliable")
func rpc_prepare_direction(front_to_rear: bool) -> void:
	_prepare_direction(front_to_rear)


func _prepare_direction(front_to_rear: bool) -> void:
	_last_travel_front_to_rear = front_to_rear
	_validation_timer = 0.0
	_waiting_exit_elapsed = 0.0

	if front_to_rear:
		_gate_state = GATE_READY_FRONT_TO_REAR
		_set_front_door_open(true, false)
		_set_rear_door_open(false, false)
		_debug("Ouverture côté front. Préparation %s -> %s." % [front_block_label, rear_block_label])
	else:
		_gate_state = GATE_READY_REAR_TO_FRONT
		_set_front_door_open(false, false)
		_set_rear_door_open(true, false)
		_debug("Ouverture côté rear. Préparation %s -> %s." % [rear_block_label, front_block_label])

	if node_capture != null and is_instance_valid(node_capture):
		node_capture.hide()


func _update_button_interaction() -> void:
	if debug_open_when_player_enters_button_area:
		if not _front_button_players.is_empty():
			press_front_button()
			return
		if not _rear_button_players.is_empty():
			press_rear_button()
			return

	if not allow_input_polling_on_button_areas:
		return
	if String(interact_action_name).is_empty():
		return
	if not Input.is_action_just_pressed(interact_action_name):
		return

	if not _front_button_players.is_empty():
		press_front_button()
		return
	if not _rear_button_players.is_empty():
		press_rear_button()


func _update_validation(delta: float) -> void:
	if _gate_state != GATE_READY_FRONT_TO_REAR and _gate_state != GATE_READY_REAR_TO_FRONT:
		return

	var required_players: Array[Node] = _get_required_players()
	var required_count: int = required_players.size()
	var inside_count: int = _count_required_players_inside(required_players)
	var vehicle_inside: bool = _vehicles_inside.size() > 0
	var all_players_inside: bool = required_count > 0 and inside_count >= required_count

	# Cas tank : si les joueurs sont transportés dans un véhicule et que leurs bodies
	# ne sont pas détectés séparément par l'Area3D, le tank compte comme présence valide.
	if count_vehicle_inside_as_all_players_inside and vehicle_inside:
		all_players_inside = true

	var has_enemy_inside: bool = _enemies_inside.size() > 0
	var can_validate: bool = all_players_inside

	if require_no_enemy_inside and has_enemy_inside:
		can_validate = false

	if not can_validate:
		_validation_timer = 0.0
		return

	_validation_timer = min(_validation_timer + delta, validation_duration)
	if _validation_timer >= validation_duration:
		_validate_passage()


func _validate_passage() -> void:
	_gate_state = GATE_WAITING_EXIT
	_validation_timer = validation_duration
	_waiting_exit_elapsed = 0.0

	_register_as_active_respawn_passage()
	_teleport_first_vehicle_to_tank_marker_if_missing()

	if node_capture != null and is_instance_valid(node_capture):
		node_capture.show()

	if _last_travel_front_to_rear:
		_set_front_door_open(false, false)
		_set_rear_door_open(true, false)
		_request_level_block_transition(front_block, rear_block)
	else:
		_set_front_door_open(true, false)
		_set_rear_door_open(false, false)
		_request_level_block_transition(rear_block, front_block)

	_debug("Passage validé.")


func _request_level_block_transition(from_block: Node3D, to_block: Node3D) -> void:
	var manager: Node = _get_level_runtime_manager()
	if manager == null:
		push_warning("[PassageGate] Aucun LevelGenerator/runtime manager trouvé pour basculer les blocks.")
		return

	if manager.has_method("request_level_block_transition"):
		manager.call("request_level_block_transition", from_block, to_block, self)
		return

	if manager.has_method("set_active_level_block"):
		manager.call("set_active_level_block", to_block)


func _get_level_runtime_manager() -> Node:
	if level_runtime_manager != null and is_instance_valid(level_runtime_manager):
		return level_runtime_manager

	var current: Node = self
	while current != null:
		if current.has_method("request_level_block_transition"):
			level_runtime_manager = current
			return level_runtime_manager
		current = current.get_parent()

	for candidate: Node in get_tree().get_nodes_in_group("procedural_level_generator"):
		if candidate != null and is_instance_valid(candidate) and candidate.has_method("request_level_block_transition"):
			level_runtime_manager = candidate
			return level_runtime_manager

	return null


func _update_exit_reset(delta: float) -> void:
	if _gate_state != GATE_WAITING_EXIT:
		return

	_waiting_exit_elapsed += delta
	if _waiting_exit_elapsed < 0.25:
		return

	var required_players: Array[Node] = _get_required_players()
	var inside_count: int = _count_required_players_inside(required_players)
	if inside_count > 0 or _vehicles_inside.size() > 0:
		return

	_validation_timer = 0.0
	_waiting_exit_elapsed = 0.0

	if auto_prepare_inverse_after_exit:
		_prepare_direction(not _last_travel_front_to_rear)
	else:
		reset_passage()


func _rebuild_presence() -> void:
	_players_inside.clear()
	_enemies_inside.clear()
	_vehicles_inside.clear()
	_front_button_players.clear()
	_rear_button_players.clear()

	_collect_players_and_enemies_from_area(passage_area, _players_inside, _enemies_inside)
	_collect_vehicles_from_area(passage_area, _vehicles_inside)
	_collect_players_from_area(front_button_area, _front_button_players)
	_collect_players_from_area(rear_button_area, _rear_button_players)


func _collect_players_and_enemies_from_area(area: Area3D, players_result: Dictionary, enemies_result: Dictionary) -> void:
	if area == null:
		return

	var detectors: Array = []
	detectors.append_array(area.get_overlapping_bodies())
	detectors.append_array(area.get_overlapping_areas())

	for detector: Variant in detectors:
		if detector == null or not is_instance_valid(detector):
			continue

		var detected_players: Array[Node] = _get_players_from_detector(detector)
		for player_node: Node in detected_players:
			if player_node == null or not is_instance_valid(player_node):
				continue
			if not _is_required_player(player_node):
				continue
			players_result[player_node.get_instance_id()] = player_node

		var enemy_node: Node = _get_enemy_from_detector(detector)
		if enemy_node != null and is_instance_valid(enemy_node):
			enemies_result[enemy_node.get_instance_id()] = enemy_node


func _collect_players_from_area(area: Area3D, players_result: Dictionary) -> void:
	if area == null:
		return

	var detectors: Array = []
	detectors.append_array(area.get_overlapping_bodies())
	detectors.append_array(area.get_overlapping_areas())

	for detector: Variant in detectors:
		var detected_players: Array[Node] = _get_players_from_detector(detector)
		for player_node: Node in detected_players:
			if player_node == null or not is_instance_valid(player_node):
				continue
			if not _is_required_player(player_node):
				continue
			players_result[player_node.get_instance_id()] = player_node


func _collect_vehicles_from_area(area: Area3D, vehicles_result: Dictionary) -> void:
	if area == null:
		return

	var detectors: Array = []
	detectors.append_array(area.get_overlapping_bodies())
	detectors.append_array(area.get_overlapping_areas())

	for detector: Variant in detectors:
		var vehicle_node: Node3D = _get_vehicle_from_detector(detector)
		if vehicle_node == null or not is_instance_valid(vehicle_node):
			continue
		vehicles_result[vehicle_node.get_instance_id()] = vehicle_node


func _refresh_hud_feedback() -> void:
	var required_players: Array[Node] = _get_required_players()
	var required_count: int = required_players.size()
	var inside_count: int = _count_required_players_inside(required_players)
	var vehicle_inside: bool = _vehicles_inside.size() > 0
	var has_enemy_inside: bool = _enemies_inside.size() > 0
	var somebody_waiting: bool = inside_count > 0 or (show_prompt_when_vehicle_inside and vehicle_inside)

	if _gate_state == GATE_IDLE:
		_hide_feedback_for_all_players()
		return

	if _gate_state == GATE_WAITING_EXIT:
		for player_node: Node in required_players:
			if _players_inside.has(player_node.get_instance_id()):
				_show_feedback_for_player(player_node, "Sortez du sas.", -1.0)
			else:
				_hide_feedback_for_player(player_node)
		return

	for player_node: Node in required_players:
		if player_node == null or not is_instance_valid(player_node):
			continue

		var player_is_inside: bool = _players_inside.has(player_node.get_instance_id())

		if require_no_enemy_inside and has_enemy_inside and (player_is_inside or somebody_waiting):
			_show_feedback_for_player(player_node, "Éliminez les ennemis dans le sas.", -1.0)
			continue

		if player_is_inside:
			if inside_count >= required_count:
				var remaining: float = max(validation_duration - _validation_timer, 0.0)
				var progress: float = 0.0
				if validation_duration > 0.0:
					progress = clampf(_validation_timer / validation_duration, 0.0, 1.0)
				_show_feedback_for_player(player_node, "Validation dans %.1f s." % remaining, progress)
			else:
				_show_feedback_for_player(player_node, "Point de passage : %s." % _format_player_count(inside_count, required_count), -1.0)
			continue

		if somebody_waiting:
			_show_feedback_for_player(player_node, "Des alliés vous attendent au point de passage. %s" % _format_player_count(inside_count, required_count), -1.0)
		else:
			_hide_feedback_for_player(player_node)


func _hide_feedback_for_all_players() -> void:
	var required_players: Array[Node] = _get_required_players()
	for player_node: Node in required_players:
		_hide_feedback_for_player(player_node)


func _show_feedback_for_player(player_node: Node, message: String, progress: float) -> void:
	if player_node == null or not is_instance_valid(player_node):
		return

	if player_node.has_method("show_passage_prompt"):
		_call_hud_method(player_node, &"show_passage_prompt", [message, progress, self], [message, progress])
		return

	var hud: Node = _find_hud_for_player(player_node)
	if hud != null and hud.has_method("show_passage_prompt"):
		_call_hud_method(hud, &"show_passage_prompt", [message, progress, self], [message, progress])


func _hide_feedback_for_player(player_node: Node) -> void:
	if player_node == null or not is_instance_valid(player_node):
		return

	if player_node.has_method("hide_passage_prompt"):
		_call_hud_method(player_node, &"hide_passage_prompt", [self], [])
		return

	var hud: Node = _find_hud_for_player(player_node)
	if hud != null and hud.has_method("hide_passage_prompt"):
		_call_hud_method(hud, &"hide_passage_prompt", [self], [])


func _call_hud_method(target: Node, method_name: StringName, args_with_owner: Array, args_without_owner: Array) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method(method_name):
		return

	var argument_count: int = _get_method_argument_count(target, method_name)
	if argument_count >= args_with_owner.size():
		target.callv(method_name, args_with_owner)
	else:
		target.callv(method_name, args_without_owner)


func _get_method_argument_count(target: Object, method_name: StringName) -> int:
	for method_info: Dictionary in target.get_method_list():
		if StringName(method_info.get("name", "")) != method_name:
			continue
		var args: Array = method_info.get("args", [])
		return args.size()
	return 0


func _find_hud_for_player(player_node: Node) -> Node:
	for hud_candidate: Node in get_tree().get_nodes_in_group("player_huds"):
		if hud_candidate == null or not is_instance_valid(hud_candidate):
			continue
		if hud_candidate.has_method("get_player") and hud_candidate.call("get_player") == player_node:
			return hud_candidate
		var linked_player: Variant = hud_candidate.get("player")
		if linked_player == player_node:
			return hud_candidate

	return null


func _get_required_players() -> Array[Node]:
	var result: Array[Node] = []
	if player_group_name.is_empty():
		return result

	for candidate: Node in get_tree().get_nodes_in_group(player_group_name):
		if candidate == null or not is_instance_valid(candidate):
			continue
		if _is_required_player(candidate):
			result.append(candidate)
	return result


func _is_required_player(player_node: Node) -> bool:
	if player_node == null or not is_instance_valid(player_node):
		return false

	if not ignore_dead_players:
		return true

	if player_node.has_method("is_dead") and bool(player_node.call("is_dead")):
		return false

	var dead_value: Variant = player_node.get("is_dead")
	if dead_value != null and bool(dead_value):
		return false

	return true


func _count_required_players_inside(required_players: Array[Node]) -> int:
	var count: int = 0
	for player_node: Node in required_players:
		if player_node != null and is_instance_valid(player_node) and _players_inside.has(player_node.get_instance_id()):
			count += 1
	return count


func _get_enemy_from_detector(detector: Variant) -> Node:
	if not (detector is Node):
		return null

	var current: Node = detector as Node
	while current != null:
		if _is_enemy_node(current):
			return current
		current = current.get_parent()

	return null


func _is_enemy_node(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not enemy_group_name.is_empty() and node.is_in_group(enemy_group_name):
		return true
	if not enemy_secondary_group_name.is_empty() and node.is_in_group(enemy_secondary_group_name):
		return true
	return false


func _get_players_from_detector(detector: Variant) -> Array[Node]:
	var result: Array[Node] = []

	if not (detector is Node):
		return result

	var current: Node = detector as Node
	while current != null:
		_append_players_from_node(result, current)
		current = current.get_parent()

	return _deduplicate_players(result)


func _append_players_from_node(result: Array[Node], node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return

	if node.is_in_group(player_group_name):
		result.append(node)

	var method_names: Array[String] = [
		"get_player",
		"get_owner_player",
		"get_current_player",
		"get_controlling_player",
		"get_driver",
		"get_occupant",
		"get_occupants",
		"get_players_inside",
		"get_passenger_players",
		"get_seat_occupants",
	]

	for method_name: String in method_names:
		if node.has_method(method_name):
			var method_value: Variant = node.call(method_name)
			_append_players_from_value(result, method_value)

	var property_names: Array[String] = [
		"player",
		"owner_player",
		"current_player",
		"controlling_player",
		"driver",
		"occupant",
		"occupants",
		"passengers",
		"players_inside",
		"seat_occupants",
		"seats",
	]

	for property_name: String in property_names:
		var property_value: Variant = node.get(property_name)
		_append_players_from_value(result, property_value)


func _append_players_from_value(result: Array[Node], value: Variant) -> void:
	if value == null:
		return

	if value is Node:
		var node_value: Node = value as Node
		if node_value.is_in_group(player_group_name):
			result.append(node_value)
		else:
			var parent_player: Node = _find_parent_in_group(node_value, player_group_name)
			if parent_player != null:
				result.append(parent_player)
		return

	if value is Array:
		for item: Variant in value:
			_append_players_from_value(result, item)
		return

	if value is Dictionary:
		for dictionary_value: Variant in value.values():
			_append_players_from_value(result, dictionary_value)
		return


func _find_parent_in_group(node: Node, group_name: String) -> Node:
	var current: Node = node
	while current != null:
		if current.is_in_group(group_name):
			return current
		current = current.get_parent()
	return null


func _deduplicate_players(players: Array[Node]) -> Array[Node]:
	var result: Array[Node] = []
	var seen: Dictionary = {}

	for player_node: Node in players:
		if player_node == null or not is_instance_valid(player_node):
			continue
		var key: int = player_node.get_instance_id()
		if seen.has(key):
			continue
		seen[key] = true
		result.append(player_node)

	return result


func _register_as_active_respawn_passage() -> void:
	var network_main: Node = _find_network_main()
	if network_main == null or not is_instance_valid(network_main):
		return

	if network_main.has_method("set_active_respawn_passage"):
		network_main.call("set_active_respawn_passage", self)


func _find_network_main() -> Node:
	var current: Node = self
	while current != null:
		if current.has_method("set_active_respawn_passage"):
			return current
		current = current.get_parent()

	var current_scene: Node = get_tree().current_scene
	if current_scene != null and current_scene.has_method("set_active_respawn_passage"):
		return current_scene

	for candidate: Node in get_tree().get_nodes_in_group("network_main"):
		if candidate != null and is_instance_valid(candidate) and candidate.has_method("set_active_respawn_passage"):
			return candidate

	return null


func _teleport_first_vehicle_to_tank_marker_if_missing() -> void:
	var marker: Node3D = _get_tank_tp_marker()
	if marker == null or not is_instance_valid(marker):
		return

	if _has_vehicle_inside_passage_area():
		return

	var vehicle_node: Node3D = _get_first_vehicle()
	if vehicle_node == null or not is_instance_valid(vehicle_node):
		return

	_place_vehicle_on_tank_marker(vehicle_node, marker)


func _get_tank_tp_marker() -> Node3D:
	if tank_tp_marker != null and is_instance_valid(tank_tp_marker):
		return tank_tp_marker

	var marker: Node3D = get_node_or_null(tank_tp_path) as Node3D
	if marker != null and is_instance_valid(marker):
		tank_tp_marker = marker
		return tank_tp_marker

	marker = find_child("Tank_TP", true, false) as Node3D
	if marker != null and is_instance_valid(marker):
		tank_tp_marker = marker

	return tank_tp_marker


func _get_respawn_spawn_points_root() -> Node3D:
	if respawn_spawn_points_root != null and is_instance_valid(respawn_spawn_points_root):
		return respawn_spawn_points_root

	var root: Node3D = get_node_or_null(respawn_spawn_points_path) as Node3D
	if root != null and is_instance_valid(root):
		respawn_spawn_points_root = root
		return respawn_spawn_points_root

	root = find_child("SpawnPoints", true, false) as Node3D
	if root != null and is_instance_valid(root):
		respawn_spawn_points_root = root

	return respawn_spawn_points_root


func _has_vehicle_inside_passage_area() -> bool:
	if passage_area == null or not is_instance_valid(passage_area):
		return false
	if vehicle_group_name.is_empty():
		return false

	var detectors: Array = []
	detectors.append_array(passage_area.get_overlapping_bodies())
	detectors.append_array(passage_area.get_overlapping_areas())

	for detector: Variant in detectors:
		var vehicle_node: Node3D = _get_vehicle_from_detector(detector)
		if vehicle_node != null and is_instance_valid(vehicle_node):
			return true

	return false


func _get_vehicle_from_detector(detector: Variant) -> Node3D:
	if vehicle_group_name.is_empty():
		return null
	if not (detector is Node):
		return null

	var current: Node = detector as Node
	while current != null:
		if current.is_in_group(vehicle_group_name) and current is Node3D:
			return current as Node3D
		current = current.get_parent()

	return null


func _get_first_vehicle() -> Node3D:
	if vehicle_group_name.is_empty():
		return null

	for candidate: Node in get_tree().get_nodes_in_group(vehicle_group_name):
		if candidate != null and is_instance_valid(candidate) and candidate is Node3D:
			return candidate as Node3D

	return null


func _place_vehicle_on_tank_marker(vehicle_node: Node3D, marker: Node3D) -> void:
	if vehicle_node == null or not is_instance_valid(vehicle_node):
		return
	if marker == null or not is_instance_valid(marker):
		return

	if vehicle_node is RigidBody3D:
		var rigid_body: RigidBody3D = vehicle_node as RigidBody3D
		rigid_body.linear_velocity = Vector3.ZERO
		rigid_body.angular_velocity = Vector3.ZERO
		rigid_body.sleeping = false
	elif vehicle_node is CharacterBody3D:
		var character_body: CharacterBody3D = vehicle_node as CharacterBody3D
		character_body.velocity = Vector3.ZERO

	var current_scale: Vector3 = vehicle_node.global_transform.basis.get_scale()
	var target_basis: Basis = Basis.IDENTITY.scaled(current_scale)
	vehicle_node.global_transform = Transform3D(target_basis, marker.global_position)
	vehicle_node.rotation = Vector3.ZERO

	if vehicle_node.has_method("reset_physics_interpolation"):
		vehicle_node.call("reset_physics_interpolation")


func _force_door_scene_start_closed(door: Node3D) -> void:
	if door == null or not is_instance_valid(door):
		return

	if _object_has_property(door, "start_open"):
		door.set("start_open", false)

	if door.has_method("set_open"):
		door.call("set_open", false)
		return

	if door.has_method("close"):
		door.call("close")


func _object_has_property(object: Object, property_name: String) -> bool:
	if object == null:
		return false

	for property_info: Dictionary in object.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return true

	return false


func _close_both_doors(immediate: bool, force: bool = false) -> void:
	_set_front_door_open(false, immediate, force)
	_set_rear_door_open(false, immediate, force)


func _set_front_door_open(open: bool, immediate: bool, force: bool = false) -> void:
	if front_door == null:
		return
	if not force and _front_is_open == open:
		return
	_front_is_open = open
	_set_door_open(front_door, open, _front_closed_position, front_door_open_offset, immediate, true)


func _set_rear_door_open(open: bool, immediate: bool, force: bool = false) -> void:
	if rear_door == null:
		return
	if not force and _rear_is_open == open:
		return
	_rear_is_open = open
	_set_door_open(rear_door, open, _rear_closed_position, rear_door_open_offset, immediate, false)


func _set_door_open(door: Node3D, open: bool, closed_position: Vector3, open_offset: Vector3, immediate: bool, is_front_door: bool) -> void:
	if open:
		if door.has_method("set_open"):
			door.call("set_open", true)
			return
		if door.has_method("open"):
			door.call("open")
			return
	else:
		if door.has_method("set_open"):
			door.call("set_open", false)
			return
		if door.has_method("close"):
			door.call("close")
			return

	var target_position: Vector3 = closed_position
	if open:
		target_position = closed_position + open_offset

	_move_door_to(door, target_position, immediate, is_front_door)


func _move_door_to(door: Node3D, target_position: Vector3, immediate: bool, is_front_door: bool) -> void:
	if is_front_door:
		if _front_tween != null and _front_tween.is_valid():
			_front_tween.kill()
	else:
		if _rear_tween != null and _rear_tween.is_valid():
			_rear_tween.kill()

	if immediate or door_animation_duration <= 0.0:
		door.global_position = target_position
		return

	var tween: Tween = create_tween()
	tween.tween_property(door, "global_position", target_position, door_animation_duration)

	if is_front_door:
		_front_tween = tween
	else:
		_rear_tween = tween


func _format_player_count(current: int, total: int) -> String:
	return "%d/%d" % [current, total]


func _debug(text: String) -> void:
	if debug_print_events:
		print("[PassageGate] %s" % text)
