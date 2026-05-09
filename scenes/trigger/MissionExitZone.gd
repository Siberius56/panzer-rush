extends Node3D
class_name MissionExitZone

signal zone_completed(zone: MissionExitZone)
signal completion_failed(reason: String)

enum CompletionMode {
	SHOW_VICTORY_SCREEN,
	CHANGE_TO_NEXT_LEVEL,
	CALL_METHOD,
	EMIT_SIGNAL_ONLY,
}

@export_group("Groups")
@export var player_group_name: String = "players"
@export var enemy_group_names: PackedStringArray = ["enemy", "enemies"]
@export var vehicle_group_names: PackedStringArray = ["vehicle", "vehicles"]

@export_group("Vehicle Detection")
@export var use_multiplayer_authority_vehicle_fallback: bool = false
@export var debug_vehicle_detection: bool = false

@export_group("Rules")
@export var validation_duration: float = 3.0
@export var ignore_dead_players: bool = false
@export var lock_after_validation: bool = true

@export_group("Completion")
@export var completion_mode: CompletionMode = CompletionMode.SHOW_VICTORY_SCREEN
@export_file("*.tscn") var next_level_scene_path: String = ""
@export var victory_screen_scene: PackedScene
@export var victory_screen_parent_path: NodePath = ^""
@export var completion_target_path: NodePath = ^""
@export var completion_method_name: StringName = &"complete_mission"
@export var level_controller_path: NodePath = ^""

@export_group("HUD Texts")
@export var count_message_template: String = "Zone d'extraction : {count}."
@export var waiting_message_singular: String = "Un allié vous attend à la zone d'extraction."
@export var waiting_message_plural: String = "Des alliés vous attendent à la zone d'extraction."
@export var validation_message_template: String = "Groupe réuni. Extraction dans {time} s."
@export var enemy_blocking_message: String = "Extraction bloquée. Éliminez les ennemis dans la zone."

@export_group("Nodes")
@export var scan_area_path: NodePath = ^"ScanArea"

@onready var scan_area: Area3D = get_node_or_null(scan_area_path) as Area3D

var _players_inside: Dictionary = {}
var _enemies_inside: Dictionary = {}
var _validation_timer: float = 0.0
var _validated: bool = false
var _spawned_victory_screen: Node = null


func _ready() -> void:
	if scan_area != null:
		scan_area.monitoring = true
		scan_area.monitorable = true


func _physics_process(delta: float) -> void:
	_rebuild_presence()
	_update_validation(delta)
	_refresh_hud_feedback()


func reset_zone() -> void:
	_validated = false
	_validation_timer = 0.0
	_spawned_victory_screen = null
	_hide_feedback_for_all_players()


func force_complete() -> void:
	_complete_zone()


func get_validation_progress() -> float:
	if validation_duration <= 0.0:
		return 1.0
	return clamp(_validation_timer / validation_duration, 0.0, 1.0)


func is_completed() -> bool:
	return _validated


func _rebuild_presence() -> void:
	_players_inside.clear()
	_enemies_inside.clear()

	if scan_area == null:
		return

	var detectors: Array = []
	detectors.append_array(scan_area.get_overlapping_bodies())
	detectors.append_array(scan_area.get_overlapping_areas())

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
		return

	_validation_timer = min(_validation_timer + delta, validation_duration)

	if _validation_timer >= validation_duration:
		_complete_zone()


func _complete_zone() -> void:
	if _validated and lock_after_validation:
		return

	_validated = true
	_validation_timer = validation_duration
	_hide_feedback_for_all_players()
	zone_completed.emit(self)

	match completion_mode:
		CompletionMode.SHOW_VICTORY_SCREEN:
			call_deferred("_show_victory_screen")
		CompletionMode.CHANGE_TO_NEXT_LEVEL:
			call_deferred("_change_to_next_level")
		CompletionMode.CALL_METHOD:
			call_deferred("_call_completion_method")
		CompletionMode.EMIT_SIGNAL_ONLY:
			pass


func _show_victory_screen() -> void:
	if _spawned_victory_screen != null and is_instance_valid(_spawned_victory_screen):
		if _spawned_victory_screen.has_method("show_victory"):
			_spawned_victory_screen.call("show_victory")
		else:
			_spawned_victory_screen.visible = true
		return

	if victory_screen_scene == null:
		completion_failed.emit("Aucune VictoryScreen n'est assignée.")
		push_warning("MissionExitZone: victory_screen_scene n'est pas assignée.")
		return

	var victory_screen: Node = victory_screen_scene.instantiate()
	if victory_screen == null:
		completion_failed.emit("Impossible d'instancier l'écran de victoire.")
		return

	var parent_node: Node = _get_victory_screen_parent()
	if parent_node == null:
		parent_node = get_tree().root

	parent_node.add_child(victory_screen)
	_spawned_victory_screen = victory_screen

	if victory_screen.has_method("show_victory"):
		victory_screen.call("show_victory")


func _get_victory_screen_parent() -> Node:
	if victory_screen_parent_path == NodePath(""):
		return null
	return get_node_or_null(victory_screen_parent_path)


func _change_to_next_level() -> void:
	if next_level_scene_path.is_empty():
		completion_failed.emit("Aucun prochain niveau n'est assigné.")
		push_warning("MissionExitZone: next_level_scene_path est vide.")
		return

	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return

	var level_controller: Node = _get_level_controller()
	if level_controller == null:
		completion_failed.emit("Aucun contrôleur de niveau avec change_level_to_file n'a été trouvé.")
		push_warning("MissionExitZone: impossible de trouver un node qui possède change_level_to_file.")
		return

	level_controller.call("change_level_to_file", next_level_scene_path)


func _get_level_controller() -> Node:
	if level_controller_path != NodePath(""):
		var explicit_controller: Node = get_node_or_null(level_controller_path)
		if explicit_controller != null and explicit_controller.has_method("change_level_to_file"):
			return explicit_controller

	var current_scene: Node = get_tree().current_scene
	if current_scene != null and current_scene.has_method("change_level_to_file"):
		return current_scene

	var current: Node = self
	while current != null:
		if current.has_method("change_level_to_file"):
			return current
		current = current.get_parent()

	return null


func _call_completion_method() -> void:
	var target: Node = get_node_or_null(completion_target_path)
	if target == null:
		completion_failed.emit("Aucun node cible n'est assigné pour compléter la mission.")
		push_warning("MissionExitZone: completion_target_path est vide ou invalide.")
		return

	if not target.has_method(completion_method_name):
		completion_failed.emit("La cible ne possède pas la méthode %s." % String(completion_method_name))
		push_warning("MissionExitZone: la cible '%s' ne possède pas la méthode '%s'." % [target.name, String(completion_method_name)])
		return

	target.call(completion_method_name)


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
			_show_feedback_for_player(player_node, enemy_blocking_message, -1.0)
			continue

		if player_is_inside:
			if required_count > 0 and inside_count >= required_count:
				var remaining: float = max(validation_duration - _validation_timer, 0.0)
				var message: String = validation_message_template.replace("{time}", "%.1f" % remaining)
				_show_feedback_for_player(player_node, message, get_validation_progress())
			else:
				var count_message: String = count_message_template.replace("{count}", _format_player_count(inside_count, required_count))
				_show_feedback_for_player(player_node, count_message, -1.0)
			continue

		if somebody_waiting:
			var waiting_text: String = waiting_message_plural
			if inside_count == 1:
				waiting_text = waiting_message_singular
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
		for group_name in enemy_group_names:
			if String(group_name).is_empty():
				continue
			if current.is_in_group(String(group_name)):
				return current
		current = current.get_parent()

	return null


func _get_players_from_detector(detector: Variant) -> Array[Node]:
	var result: Array[Node] = []

	if not (detector is Node):
		return result

	var detector_node: Node = detector as Node
	var vehicle_node: Node = null
	var current: Node = detector_node

	while current != null:
		_append_players_from_node(result, current)
		if vehicle_node == null and _is_vehicle_node(current):
			vehicle_node = current
		current = current.get_parent()

	if vehicle_node != null:
		_append_players_from_vehicle(result, vehicle_node)
		if debug_vehicle_detection:
			print("MissionExitZone: véhicule détecté = ", vehicle_node.name, " | joueurs trouvés = ", result.size())

	return _deduplicate_players(result)


func _append_players_from_vehicle(result: Array[Node], vehicle_node: Node) -> void:
	if vehicle_node == null or not is_instance_valid(vehicle_node):
		return

	_append_players_from_node(result, vehicle_node)
	_append_players_related_to_vehicle(result, vehicle_node)


func _is_vehicle_node(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false

	for group_name in vehicle_group_names:
		if String(group_name).is_empty():
			continue
		if node.is_in_group(String(group_name)):
			return true

	return false


func _append_players_related_to_vehicle(result: Array[Node], vehicle_node: Node) -> void:
	var required_players: Array[Node] = _get_required_players()

	for player_node in required_players:
		if player_node == null or not is_instance_valid(player_node):
			continue
		if _is_player_related_to_vehicle(player_node, vehicle_node):
			result.append(player_node)


func _is_player_related_to_vehicle(player_node: Node, vehicle_node: Node) -> bool:
	if player_node == null or vehicle_node == null:
		return false
	if not is_instance_valid(player_node) or not is_instance_valid(vehicle_node):
		return false

	if _is_descendant_of(player_node, vehicle_node):
		return true

	if player_node.get_parent() == vehicle_node:
		return true

	var method_names: Array[String] = [
		"get_vehicle",
		"get_current_vehicle",
		"get_controlled_vehicle",
		"get_occupied_vehicle",
		"get_mounted_vehicle",
		"get_inside_vehicle",
		"get_vehicle_node",
	]

	for method_name in method_names:
		if player_node.has_method(method_name):
			var method_value = player_node.call(method_name)
			if _value_contains_node(method_value, vehicle_node):
				return true

	var property_names: Array[String] = [
		"vehicle",
		"current_vehicle",
		"controlled_vehicle",
		"occupied_vehicle",
		"mounted_vehicle",
		"inside_vehicle",
		"vehicle_node",
	]

	for property_name in property_names:
		var property_value = player_node.get(property_name)
		if _value_contains_node(property_value, vehicle_node):
			return true

	if use_multiplayer_authority_vehicle_fallback:
		if player_node.get_multiplayer_authority() == vehicle_node.get_multiplayer_authority():
			return true

	return false


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
		"get_controller_player",
		"get_driver",
		"get_driver_player",
		"get_current_driver",
		"get_pilot",
		"get_pilot_player",
		"get_occupant",
		"get_occupant_player",
		"get_occupants",
		"get_players_inside",
		"get_passenger_players",
		"get_passengers",
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
		"controller_player",
		"driver",
		"driver_player",
		"current_driver",
		"pilot",
		"pilot_player",
		"occupant",
		"occupant_player",
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

	if value is WeakRef:
		var weak_ref: WeakRef = value as WeakRef
		_append_players_from_value(result, weak_ref.get_ref())
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


func _value_contains_node(value: Variant, searched_node: Node) -> bool:
	if value == null or searched_node == null:
		return false

	if value is WeakRef:
		var weak_ref: WeakRef = value as WeakRef
		return _value_contains_node(weak_ref.get_ref(), searched_node)

	if value is Node:
		var node_value: Node = value as Node
		return node_value == searched_node or _is_descendant_of(node_value, searched_node) or _is_descendant_of(searched_node, node_value)

	if value is Array:
		for item in value:
			if _value_contains_node(item, searched_node):
				return true
		return false

	if value is Dictionary:
		for dictionary_value in value.values():
			if _value_contains_node(dictionary_value, searched_node):
				return true
		return false

	return false


func _is_descendant_of(node: Node, possible_parent: Node) -> bool:
	var current: Node = node
	while current != null:
		if current == possible_parent:
			return true
		current = current.get_parent()
	return false


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
