extends Node3D
class_name PassageGate

@export var player_group_name: String = "players"
@export var enemy_group_name: String = "enemies"
@export var vehicle_group_name: String = "vehicles"

@export var validation_duration: float = 3.0
@export var ignore_dead_players: bool = false
@export var lock_after_validation: bool = true

@export var passage_area_path: NodePath = ^"PassageArea"
@export var front_door_path: NodePath = ^"FrontDoor"
@export var rear_door_path: NodePath = ^"RearDoor"

@export var front_door_open_offset: Vector3 = Vector3(0.0, 4.0, 0.0)
@export var rear_door_open_offset: Vector3 = Vector3(0.0, 4.0, 0.0)
@export var door_animation_duration: float = 0.35

@onready var passage_area: Area3D = get_node_or_null(passage_area_path) as Area3D
@onready var front_door: Node3D = get_node_or_null(front_door_path) as Node3D
@onready var rear_door: Node3D = get_node_or_null(rear_door_path) as Node3D

var _players_inside: Dictionary = {}
var _enemies_inside: Dictionary = {}
var _validation_timer: float = 0.0
var _validated: bool = false

var _front_closed_position: Vector3 = Vector3.ZERO
var _rear_closed_position: Vector3 = Vector3.ZERO
var _front_is_open: bool = false
var _rear_is_open: bool = false
var _front_tween: Tween = null
var _rear_tween: Tween = null

func _ready() -> void:
	if passage_area != null:
		passage_area.monitoring = true
		passage_area.monitorable = true

	if front_door != null:
		_front_closed_position = front_door.global_position

	if rear_door != null:
		_rear_closed_position = rear_door.global_position

	_apply_passage_closed_state(true)


func _physics_process(delta: float) -> void:
	_rebuild_presence()
	_update_validation(delta)
	_refresh_hud_feedback()


func _rebuild_presence() -> void:
	_players_inside.clear()
	_enemies_inside.clear()

	if passage_area == null:
		return

	var detectors: Array = []
	detectors.append_array(passage_area.get_overlapping_bodies())
	detectors.append_array(passage_area.get_overlapping_areas())

	for detector in detectors:
		if detector == null or not is_instance_valid(detector):
			continue

		var detected_players: Array[Node] = _get_players_from_detector(detector)
		for player_node in detected_players:
			if player_node == null or not is_instance_valid(player_node):
				continue
			if not _is_required_player(player_node):
				continue
			_players_inside[player_node.get_instance_id()] = player_node

		var enemy_node: Node = _get_enemy_from_detector(detector)
		if enemy_node != null and is_instance_valid(enemy_node):
			_enemies_inside[enemy_node.get_instance_id()] = enemy_node


func _update_validation(delta: float) -> void:
	if _validated and lock_after_validation:
		return

	var required_players: Array[Node] = _get_required_players()
	var required_count: int = required_players.size()
	var inside_count: int = _count_required_players_inside(required_players)
	var all_players_inside: bool = required_count > 0 and inside_count >= required_count
	var has_enemy_inside: bool = _enemies_inside.size() > 0
	var can_validate: bool = all_players_inside and not has_enemy_inside

	if not can_validate:
		_validation_timer = 0.0
		if not _validated:
			_apply_passage_closed_state(false)
		return

	_validation_timer = min(_validation_timer + delta, validation_duration)

	if _validation_timer >= validation_duration:
		_validate_passage()


func _validate_passage() -> void:
	_validated = true
	_validation_timer = validation_duration
	_apply_passage_validated_state(false)


func reset_passage() -> void:
	_validated = false
	_validation_timer = 0.0
	_apply_passage_closed_state(false)
	_hide_feedback_for_all_players()


func _apply_passage_closed_state(immediate: bool) -> void:
	_set_front_door_open(false, immediate)
	_set_rear_door_open(true, immediate)


func _apply_passage_validated_state(immediate: bool) -> void:
	_set_front_door_open(true, immediate)
	_set_rear_door_open(false, immediate)


func _set_front_door_open(open: bool, immediate: bool) -> void:
	if front_door == null:
		return
	if _front_is_open == open:
		return
	_front_is_open = open
	_set_door_open(front_door, open, _front_closed_position, front_door_open_offset, immediate, true)


func _set_rear_door_open(open: bool, immediate: bool) -> void:
	if rear_door == null:
		return
	if _rear_is_open == open:
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


func _refresh_hud_feedback() -> void:
	var required_players: Array[Node] = _get_required_players()
	var required_count: int = required_players.size()
	var inside_count: int = _count_required_players_inside(required_players)
	var has_enemy_inside: bool = _enemies_inside.size() > 0
	var somebody_waiting: bool = inside_count > 0

	if _validated:
		_hide_feedback_for_all_players()
		return

	for player_node in required_players:
		if player_node == null or not is_instance_valid(player_node):
			continue

		var player_is_inside: bool = _players_inside.has(player_node.get_instance_id())

		if has_enemy_inside and (player_is_inside or somebody_waiting):
			_show_feedback_for_player(player_node, "Point de passage bloqué. Éliminez les ennemis dans la zone.", -1.0)
			continue

		if player_is_inside:
			if inside_count >= required_count:
				var remaining: float = max(validation_duration - _validation_timer, 0.0)
				var progress: float = 0.0
				if validation_duration > 0.0:
					progress = clamp(_validation_timer / validation_duration, 0.0, 1.0)
				_show_feedback_for_player(player_node, "Groupe réuni. Validation dans %.1f s." % remaining, progress)
			else:
				_show_feedback_for_player(player_node, "Point de passage : %s." % _format_player_count(inside_count, required_count), -1.0)
			continue

		if somebody_waiting:
			var waiting_text: String = "Des alliés vous attendent au point de passage."
			if inside_count == 1:
				waiting_text = "Un allié vous attend au point de passage."
			_show_feedback_for_player(player_node, "%s %s." % [waiting_text, _format_player_count(inside_count, required_count)], -1.0)
		else:
			_hide_feedback_for_player(player_node)


func _hide_feedback_for_all_players() -> void:
	var required_players: Array[Node] = _get_required_players()
	for player_node in required_players:
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
	for method_info in target.get_method_list():
		if StringName(method_info.get("name", "")) != method_name:
			continue
		var args: Array = method_info.get("args", [])
		return args.size()
	return 0

func _find_hud_for_player(player_node: Node) -> Node:
	for hud_candidate in get_tree().get_nodes_in_group("player_huds"):
		if hud_candidate == null or not is_instance_valid(hud_candidate):
			continue
		if hud_candidate.has_method("get_player") and hud_candidate.call("get_player") == player_node:
			return hud_candidate
		var linked_player = hud_candidate.get("player")
		if linked_player == player_node:
			return hud_candidate

	return null


func _get_required_players() -> Array[Node]:
	var result: Array[Node] = []
	for candidate in get_tree().get_nodes_in_group(player_group_name):
		if candidate == null or not is_instance_valid(candidate):
			continue
		if candidate is Node and _is_required_player(candidate as Node):
			result.append(candidate as Node)
	return result


func _is_required_player(player_node: Node) -> bool:
	if player_node == null or not is_instance_valid(player_node):
		return false

	if not ignore_dead_players:
		return true

	if player_node.has_method("is_dead") and bool(player_node.call("is_dead")):
		return false

	var dead_value = player_node.get("is_dead")
	if dead_value != null and bool(dead_value):
		return false

	return true


func _count_required_players_inside(required_players: Array[Node]) -> int:
	var count: int = 0
	for player_node in required_players:
		if player_node != null and is_instance_valid(player_node) and _players_inside.has(player_node.get_instance_id()):
			count += 1
	return count


func _get_enemy_from_detector(detector: Variant) -> Node:
	if not (detector is Node):
		return null

	var current: Node = detector as Node
	while current != null:
		if current.is_in_group(enemy_group_name):
			return current
		current = current.get_parent()

	return null


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

	for method_name in method_names:
		if node.has_method(method_name):
			var method_value = node.call(method_name)
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

	for property_name in property_names:
		var property_value = node.get(property_name)
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
		for item in value:
			_append_players_from_value(result, item)
		return

	if value is Dictionary:
		for dictionary_value in value.values():
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

	for player_node in players:
		if player_node == null or not is_instance_valid(player_node):
			continue
		var key: int = player_node.get_instance_id()
		if seen.has(key):
			continue
		seen[key] = true
		result.append(player_node)

	return result


func _format_player_count(current: int, total: int) -> String:
	var player_word: String = "joueur"
	var presence_word: String = "présent"
	if current > 1:
		player_word = "joueurs"
		presence_word = "présents"
	return "%d/%d %s %s" % [current, total, player_word, presence_word]
