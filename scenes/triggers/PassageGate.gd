extends Node3D
class_name PassageGateRespawnPatch

# Nouvelle version pour contourner le cache Godot de l’ancien script.

@export var player_group_name: String = "players"
@export var enemy_group_name: String = "enemies"
@export var enemy_secondary_group_name: String = "enemy"
@export var vehicle_group_name: String = "vehicles"

@export var validation_duration: float = 3.0
@export var ignore_dead_players: bool = false
@export var lock_after_validation: bool = true

@export var passage_area_path: NodePath = ^"PassageArea"
@export var front_door_path: NodePath = ^"FrontDoor"
@export var rear_door_path: NodePath = ^"RearDoor"
@export var tank_tp_path: NodePath = ^"%Tank_TP"
@export var respawn_spawn_points_path: NodePath = ^"SpawnPoints"
@export var capture_node_path: NodePath = ^"NodeCapture"

@export_group("Zone Network Sync")
@export var apply_zone_switch_on_validation: bool = true
@export var zone_to_activate_path: NodePath = NodePath("")
@export var zone_to_deactivate_path: NodePath = NodePath("")
@export var debug_zone_switch: bool = false

@export var front_door_open_offset: Vector3 = Vector3(0.0, 4.0, 0.0)
@export var rear_door_open_offset: Vector3 = Vector3(0.0, 4.0, 0.0)
@export var door_animation_duration: float = 0.35

@onready var passage_area: Area3D = get_node_or_null(passage_area_path) as Area3D
@onready var front_door: Node3D = get_node_or_null(front_door_path) as Node3D
@onready var rear_door: Node3D = get_node_or_null(rear_door_path) as Node3D
@onready var tank_tp_marker: Node3D = get_node_or_null(tank_tp_path) as Node3D
@onready var respawn_spawn_points_root: Node3D = get_node_or_null(respawn_spawn_points_path) as Node3D
@onready var node_capture : Node3D = get_node_or_null(capture_node_path) as Node3D

var _players_inside: Dictionary = {}
var _enemies_inside: Dictionary = {}
var _zone_enemy_cache: Dictionary = {}
var _validation_timer: float = 0.0
var _validated: bool = false

var _front_closed_position: Vector3 = Vector3.ZERO
var _rear_closed_position: Vector3 = Vector3.ZERO
var _front_is_open: bool = false
var _rear_is_open: bool = false
var _front_tween: Tween = null
var _rear_tween: Tween = null

func _ready() -> void:
	add_to_group("passage_gates")

	if passage_area != null:
		passage_area.monitoring = true
		passage_area.monitorable = true

	if front_door != null:
		_front_closed_position = front_door.global_position

	if rear_door != null:
		_rear_closed_position = rear_door.global_position
	
	if is_instance_valid(node_capture):
		node_capture.hide()
	
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
	_register_as_active_respawn_passage()
	_teleport_first_vehicle_to_tank_marker_if_missing()
	_apply_passage_validated_state(false)
	_request_zone_switch_after_validation()


func _request_zone_switch_after_validation() -> void:
	if not apply_zone_switch_on_validation:
		return
	if zone_to_activate_path.is_empty() and zone_to_deactivate_path.is_empty():
		return

	if multiplayer.has_multiplayer_peer():
		if not multiplayer.is_server():
			return
		rpc("rpc_apply_passage_zone_switch")
		return

	rpc_apply_passage_zone_switch()


@rpc("authority", "call_local", "reliable")
func rpc_apply_passage_zone_switch() -> void:
	_apply_passage_zone_switch_local()


func _apply_passage_zone_switch_local() -> void:
	var zone_to_deactivate: Node3D = _get_zone_from_path(zone_to_deactivate_path, "désactiver")
	var zone_to_activate: Node3D = _get_zone_from_path(zone_to_activate_path, "activer")

	if zone_to_deactivate != null and is_instance_valid(zone_to_deactivate):
		_set_network_zone_active(zone_to_deactivate, false)

	if zone_to_activate != null and is_instance_valid(zone_to_activate):
		_set_network_zone_active(zone_to_activate, true)


func _get_zone_from_path(zone_path: NodePath, action_name: String) -> Node3D:
	if zone_path.is_empty():
		return null

	var node: Node = get_node_or_null(zone_path)
	if node == null:
		push_warning("[PassageGateRespawnPatch] Zone à %s introuvable : %s" % [action_name, str(zone_path)])
		return null

	if not (node is Node3D):
		push_warning("[PassageGateRespawnPatch] Le NodePath à %s ne pointe pas vers un Node3D : %s" % [action_name, str(zone_path)])
		return null

	return node as Node3D


func _set_network_zone_active(zone_node: Node3D, active: bool) -> void:
	if zone_node == null or not is_instance_valid(zone_node):
		return

	if debug_zone_switch:
		var state_text: String = "activée" if active else "désactivée"
		print("[PassageGateRespawnPatch] Zone %s : %s" % [state_text, zone_node.get_path()])

	if zone_node.has_method("set_network_zone_active"):
		zone_node.call("set_network_zone_active", active)
	else:
		push_warning("[PassageGateRespawnPatch] La zone %s ne possède pas set_network_zone_active(active). Les props ne seront pas gérées par NetworkZone.gd." % str(zone_node.get_path()))

	_set_cached_zone_enemies_active(zone_node, active)


func _set_cached_zone_enemies_active(zone_node: Node, active: bool) -> void:
	var zone_enemies: Array[Node] = _get_cached_zone_enemies(zone_node)
	var valid_enemies: Array[Node] = []

	for enemy_node in zone_enemies:
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		valid_enemies.append(enemy_node)
		_set_zone_enemy_active(enemy_node, active)

	if zone_node != null and is_instance_valid(zone_node):
		_zone_enemy_cache[zone_node.get_instance_id()] = valid_enemies

	if debug_zone_switch and valid_enemies.size() > 0:
		var state_text: String = "activés" if active else "désactivés"
		print("[PassageGateRespawnPatch] Ennemis de zone %s : %d" % [state_text, valid_enemies.size()])


func _get_cached_zone_enemies(zone_node: Node) -> Array[Node]:
	var result: Array[Node] = []
	if zone_node == null or not is_instance_valid(zone_node):
		return result

	var zone_id: int = zone_node.get_instance_id()
	if _zone_enemy_cache.has(zone_id):
		for cached_enemy in _zone_enemy_cache[zone_id]:
			if cached_enemy != null and is_instance_valid(cached_enemy):
				result.append(cached_enemy as Node)
		return result

	var seen: Dictionary = {}
	_collect_zone_enemies(zone_node, result, seen)
	_zone_enemy_cache[zone_id] = result
	return result


func _collect_zone_enemies(root: Node, result: Array[Node], seen: Dictionary) -> void:
	if root == null or not is_instance_valid(root):
		return

	if _is_zone_enemy_node(root):
		var enemy_id: int = root.get_instance_id()
		if not seen.has(enemy_id):
			seen[enemy_id] = true
			result.append(root)
		return

	for child in root.get_children():
		if child == null or not is_instance_valid(child):
			continue
		_collect_zone_enemies(child, result, seen)


func _is_zone_enemy_node(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false

	if not enemy_group_name.is_empty() and node.is_in_group(enemy_group_name):
		return true

	if not enemy_secondary_group_name.is_empty() and node.is_in_group(enemy_secondary_group_name):
		return true

	return false


func _set_zone_enemy_active(enemy_node: Node, active: bool) -> void:
	if enemy_node == null or not is_instance_valid(enemy_node):
		return

	if enemy_node.has_method("set_network_zone_active"):
		enemy_node.call("set_network_zone_active", active)
		return

	_apply_generic_enemy_zone_state(enemy_node, active)


func _apply_generic_enemy_zone_state(enemy_node: Node, active: bool) -> void:
	if enemy_node == null or not is_instance_valid(enemy_node):
		return

	if enemy_node is Node3D:
		(enemy_node as Node3D).visible = active

	if enemy_node is CharacterBody3D:
		(enemy_node as CharacterBody3D).velocity = Vector3.ZERO
	elif enemy_node is RigidBody3D:
		var rigid_body: RigidBody3D = enemy_node as RigidBody3D
		rigid_body.linear_velocity = Vector3.ZERO
		rigid_body.angular_velocity = Vector3.ZERO
		rigid_body.sleeping = not active

	enemy_node.set_process(active)
	enemy_node.set_physics_process(active)
	enemy_node.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	_apply_generic_enemy_zone_tree_state(enemy_node, active)


func _apply_generic_enemy_zone_tree_state(root: Node, active: bool) -> void:
	if root == null or not is_instance_valid(root):
		return

	if root is CollisionObject3D:
		var collision_object: CollisionObject3D = root as CollisionObject3D
		if not active:
			collision_object.collision_layer = 0
			collision_object.collision_mask = 0

	if root is CollisionShape3D:
		(root as CollisionShape3D).disabled = not active

	if root is Area3D:
		var area: Area3D = root as Area3D
		area.monitoring = active
		area.monitorable = active

	if root is RayCast3D:
		(root as RayCast3D).enabled = active

	for child in root.get_children():
		if child == null or not is_instance_valid(child):
			continue
		_apply_generic_enemy_zone_tree_state(child, active)


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
	
	if is_instance_valid(node_capture):
		node_capture.show()

func get_respawn_spawn_points() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var root: Node3D = _get_respawn_spawn_points_root()
	if root == null or not is_instance_valid(root):
		return result

	for child in root.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if child is Node3D:
			result.append(child as Node3D)

	return result


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


func _register_as_active_respawn_passage() -> void:
	var network_main: Node = _find_network_main()
	if network_main == null or not is_instance_valid(network_main):
		push_warning("[PassageGateRespawnPatch] NetworkMain introuvable. Le respawn avancé ne sera pas activé.")
		return

	if network_main.has_method("set_active_respawn_passage"):
		network_main.call("set_active_respawn_passage", self)
		return

	push_warning("[PassageGateRespawnPatch] NetworkMain ne possède pas set_active_respawn_passage().")


func _find_network_main() -> Node:
	var current: Node = self
	while current != null:
		if current.has_method("set_active_respawn_passage"):
			return current
		current = current.get_parent()

	var current_scene: Node = get_tree().current_scene
	if current_scene != null and current_scene.has_method("set_active_respawn_passage"):
		return current_scene

	for candidate in get_tree().get_nodes_in_group("network_main"):
		if candidate == null or not is_instance_valid(candidate):
			continue
		if candidate.has_method("set_active_respawn_passage"):
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


func _has_vehicle_inside_passage_area() -> bool:
	if passage_area == null or not is_instance_valid(passage_area):
		return false
	if vehicle_group_name.is_empty():
		return false

	var detectors: Array = []
	detectors.append_array(passage_area.get_overlapping_bodies())
	detectors.append_array(passage_area.get_overlapping_areas())

	for detector in detectors:
		if detector == null or not is_instance_valid(detector):
			continue

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

	for candidate in get_tree().get_nodes_in_group(vehicle_group_name):
		if candidate == null or not is_instance_valid(candidate):
			continue
		if candidate is Node3D:
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
			_show_feedback_for_player(player_node, "Éliminez les ennemis dans la zone.", -1.0)
			continue

		if player_is_inside:
			if inside_count >= required_count:
				var remaining: float = max(validation_duration - _validation_timer, 0.0)
				var progress: float = 0.0
				if validation_duration > 0.0:
					progress = clamp(_validation_timer / validation_duration, 0.0, 1.0)
				_show_feedback_for_player(player_node, "Validation dans %.1f s." % remaining, progress)
			else:
				_show_feedback_for_player(player_node, "Point de passage : %s." % _format_player_count(inside_count, required_count), -1.0)
			continue

		if somebody_waiting:
			var waiting_text: String = "Des alliés vous attendent au point de passage."
			if inside_count == 1:
				waiting_text = "Un allié vous attend au point de passage."
			_show_feedback_for_player(player_node, "%s %s" % [waiting_text, _format_player_count(inside_count, required_count)], -1.0)
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
		if _is_zone_enemy_node(current):
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
	#var player_word: String = "joueur"
	#var presence_word: String = "présent"
	#if current > 1:
		#player_word = "joueurs"
		#presence_word = "présents"
	return "%d/%d" % [current, total] #, player_word] #, presence_word]
