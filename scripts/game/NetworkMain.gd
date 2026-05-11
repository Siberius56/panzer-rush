extends Node3D
class_name NetworkMainRespawnPatch

# Nouvelle version pour contourner le cache Godot de l’ancien script.

const MENU_SCENE_PATH := "res://scenes/menu/MainMenu.tscn"
const PLAYER_SCENE := preload("res://scenes/player/NetworkProceduralPlayer.tscn")

@export var debug_disable_enemy_spawn: bool = true
@export var initial_enemy_count: int = 4
@export var max_enemies: int = 8

@export_group("Mission Vehicles")
@export var default_vehicle_scene: PackedScene
@export var mission_vehicle_scenes: Array[PackedScene] = []
@export var force_players_alive_on_level_load: bool = true

@export_group("Respawn")
@export var trigger_root_path: NodePath = ^"Trigger"

@onready var enemies_root: Node3D = $Enemies
@onready var spawn_points_root: Node3D = $SpawnPoints
@onready var vehicle_spawns_root: Node3D = $VehicleSpawns
@onready var hud = $CanvasLayer/NetworkHUD

var players_root: Node3D = null
var vehicles_root: Node3D = null
var next_enemy_id: int = 1
var active_respawn_passage: Node3D = null
var active_respawn_passage_path: NodePath = NodePath("")


func _ready() -> void:
	if NetworkManager.multiplayer.multiplayer_peer == null:
		get_tree().change_scene_to_file(MENU_SCENE_PATH)
		return
	
	add_to_group("network_main")
	_ensure_players_root()
	_ensure_vehicles_root()
	
	if not NetworkManager.player_list_changed.is_connected(_sync_players):
		NetworkManager.player_list_changed.connect(_sync_players)
	if not NetworkManager.connection_closed.is_connected(_on_connection_closed):
		NetworkManager.connection_closed.connect(_on_connection_closed)
	if not hud.leave_requested.is_connected(_on_leave_requested):
		hud.leave_requested.connect(_on_leave_requested)
	
	hud.set_session_text(_build_session_text())
	
	randomize()
	_sync_players()
	_sync_vehicles()
	_apply_session_snapshot_to_scene()

func _ensure_players_root() -> void:
	players_root = get_node_or_null("Players") as Node3D
	if players_root != null:
		return
	
	players_root = Node3D.new()
	players_root.name = "Players"
	add_child(players_root)

func _ensure_vehicles_root() -> void:
	vehicles_root = get_node_or_null("Vehicles") as Node3D
	if vehicles_root != null:
		return

	vehicles_root = Node3D.new()
	vehicles_root.name = "Vehicles"
	add_child(vehicles_root)


func _build_session_text() -> String:
	var mode: String = "Hôte" if NetworkManager.multiplayer.is_server() else "Client"
	return "%s, %s joueur(s)" % [mode, NetworkManager.players.size()]


func _sync_players() -> void:
	hud.set_session_text(_build_session_text())

	var expected: Dictionary = {}
	var spawn_points: Array = spawn_points_root.get_children()
	var ids: Array = NetworkManager.get_player_ids()

	for peer_id_value in ids:
		var peer_id: int = int(peer_id_value)
		var node_name: String = "Player_%s" % peer_id
		expected[node_name] = true

		var player = players_root.get_node_or_null(node_name)
		if player == null:
			var new_player = PLAYER_SCENE.instantiate()
			new_player.name = node_name
			new_player.player_id = peer_id
			new_player.player_name = NetworkManager.get_player_display_name(peer_id)
			new_player.set_multiplayer_authority(peer_id)
			players_root.add_child(new_player)

			var spawn_index: int = 0
			if not spawn_points.is_empty():
				var peer_index: int = ids.find(peer_id)
				spawn_index = clampi(peer_index, 0, spawn_points.size() - 1)

				var spawn_point: Node3D = spawn_points[spawn_index] as Node3D
				if spawn_point != null:
					new_player.global_transform = spawn_point.global_transform

			if GameSessionState.has_player_state(peer_id):
				GameSessionState.apply_player_state_to_node(new_player, force_players_alive_on_level_load)
		else:
			player.player_name = NetworkManager.get_player_display_name(peer_id)
			player.update_name_label()

	for child in players_root.get_children():
		if not expected.has(child.name):
			child.queue_free()


func _sync_vehicles() -> void:
	_ensure_vehicles_root()
	if vehicles_root == null:
		return

	if vehicle_spawns_root == null:
		push_warning("[NetworkMain] VehicleSpawns introuvable.")
		return

	var spawn_points: Array = vehicle_spawns_root.get_children()
	if spawn_points.is_empty():
		return

	var vehicle_count: int = _get_required_vehicle_count(spawn_points.size())
	var expected: Dictionary = {}

	for vehicle_index in range(vehicle_count):
		if vehicle_index >= spawn_points.size():
			break

		var scene: PackedScene = _get_vehicle_scene_for_index(vehicle_index)
		if scene == null:
			continue

		var node_name: String = "Vehicle_%d" % vehicle_index
		expected[node_name] = true

		var vehicle = vehicles_root.get_node_or_null(node_name)
		if vehicle == null:
			vehicle = scene.instantiate()
			vehicle.name = node_name
			vehicle.set_multiplayer_authority(1)
			vehicles_root.add_child(vehicle)

			var spawn_point: Node3D = spawn_points[vehicle_index] as Node3D
			if spawn_point != null:
				vehicle.global_transform = spawn_point.global_transform

		if GameSessionState.has_vehicle_state(vehicle_index):
			GameSessionState.apply_vehicle_state_to_node(vehicle_index, vehicle)

	for child in vehicles_root.get_children():
		if not expected.has(child.name):
			child.queue_free()


func _get_required_vehicle_count(max_spawn_count: int) -> int:
	if GameSessionState.has_vehicle_snapshot():
		return min(GameSessionState.get_vehicle_count(), max_spawn_count)

	if not mission_vehicle_scenes.is_empty():
		return min(mission_vehicle_scenes.size(), max_spawn_count)

	if default_vehicle_scene != null:
		return 1

	return 0


func _get_vehicle_scene_for_index(vehicle_index: int) -> PackedScene:
	if GameSessionState.has_vehicle_state(vehicle_index):
		var state: Dictionary = GameSessionState.get_vehicle_state(vehicle_index)
		var scene_path: String = String(state.get("scene_path", ""))
		if not scene_path.is_empty():
			var loaded_scene: PackedScene = load(scene_path) as PackedScene
			if loaded_scene != null:
				return loaded_scene

		return _get_initial_mission_vehicle_scene(vehicle_index)

	return _get_initial_mission_vehicle_scene(vehicle_index)


func _get_initial_mission_vehicle_scene(vehicle_index: int) -> PackedScene:
	if vehicle_index >= 0 and vehicle_index < mission_vehicle_scenes.size():
		return mission_vehicle_scenes[vehicle_index]

	if vehicle_index == 0:
		return default_vehicle_scene

	return null


func _apply_session_snapshot_to_scene() -> void:
	if GameSessionState.player_snapshot_active:
		for player in players_root.get_children():
			GameSessionState.apply_player_state_to_node(player, force_players_alive_on_level_load)

	if GameSessionState.vehicle_snapshot_active and vehicles_root != null:
		var vehicle_index: int = 0
		for vehicle in vehicles_root.get_children():
			GameSessionState.apply_vehicle_state_to_node(vehicle_index, vehicle)
			vehicle_index += 1


func change_level_to_file(scene_path: String) -> void:
	if not multiplayer.is_server():
		return
	if scene_path.is_empty():
		return

	GameSessionState.capture_scene_state(players_root, vehicles_root)

	_change_level_to_file_remote.rpc(
		scene_path,
		GameSessionState.players.duplicate(true),
		GameSessionState.vehicles.duplicate(true)
	)


@rpc("authority", "call_local", "reliable")
func _change_level_to_file_remote(
	scene_path: String,
	players_snapshot: Dictionary,
	vehicles_snapshot: Dictionary
) -> void:
	GameSessionState.apply_snapshot(players_snapshot, vehicles_snapshot)
	get_tree().change_scene_to_file(scene_path)


func set_active_respawn_passage(passage_gate: Node) -> void:
	if passage_gate == null or not is_instance_valid(passage_gate):
		return
	if not passage_gate.is_inside_tree():
		return

	var passage_path: NodePath = _get_network_relative_passage_path(passage_gate)
	if String(passage_path).is_empty():
		return

	if multiplayer.multiplayer_peer == null:
		_set_active_respawn_passage_from_path(passage_path)
		return

	if multiplayer.is_server():
		_set_active_respawn_passage_remote.rpc(passage_path)
		return

	_request_active_respawn_passage.rpc_id(NetworkManager.SERVER_PEER_ID, passage_path)
	_set_active_respawn_passage_from_path(passage_path)


@rpc("any_peer", "reliable")
func _request_active_respawn_passage(passage_path: NodePath) -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return

	_set_active_respawn_passage_remote.rpc(passage_path)


@rpc("authority", "call_local", "reliable")
func _set_active_respawn_passage_remote(passage_path: NodePath) -> void:
	_set_active_respawn_passage_from_path(passage_path)


func _set_active_respawn_passage_from_path(passage_path: NodePath) -> void:
	var passage_node: Node = _resolve_respawn_passage_from_path(passage_path)
	if passage_node == null or not is_instance_valid(passage_node):
		push_warning("[NetworkMain] Point de passage introuvable : %s" % String(passage_path))
		return
	if not (passage_node is Node3D):
		return

	active_respawn_passage = passage_node as Node3D
	active_respawn_passage_path = _get_network_relative_passage_path(passage_node)
	print("[NetworkMain] Point de respawn actif : ", active_respawn_passage_path)


func _get_network_relative_passage_path(passage_gate: Node) -> NodePath:
	if passage_gate == null or not is_instance_valid(passage_gate):
		return NodePath("")
	if not passage_gate.is_inside_tree():
		return NodePath("")

	if is_ancestor_of(passage_gate):
		return get_path_to(passage_gate)

	return passage_gate.get_path()


func _resolve_respawn_passage_from_path(passage_path: NodePath) -> Node:
	if String(passage_path).is_empty():
		return null

	var passage_node: Node = get_node_or_null(passage_path)
	if passage_node != null and is_instance_valid(passage_node):
		return passage_node

	var current_scene: Node = get_tree().current_scene
	if current_scene != null and current_scene != self:
		passage_node = current_scene.get_node_or_null(passage_path)
		if passage_node != null and is_instance_valid(passage_node):
			return passage_node

	var trigger_root: Node = get_node_or_null(trigger_root_path)
	if trigger_root != null and is_instance_valid(trigger_root):
		passage_node = _find_respawn_passage_by_name(trigger_root, String(passage_path.get_name(passage_path.get_name_count() - 1)))
		if passage_node != null and is_instance_valid(passage_node):
			return passage_node

	for candidate in get_tree().get_nodes_in_group("passage_gates"):
		if candidate == null or not is_instance_valid(candidate):
			continue
		if String(candidate.name) == String(passage_path.get_name(passage_path.get_name_count() - 1)):
			return candidate

	return null


func _find_respawn_passage_by_name(root: Node, passage_name: String) -> Node:
	if root == null or not is_instance_valid(root):
		return null
	if passage_name.is_empty():
		return null

	if String(root.name) == passage_name and root.has_method("get_respawn_spawn_points"):
		return root

	for child in root.get_children():
		if child == null or not is_instance_valid(child):
			continue

		if String(child.name) == passage_name and child.has_method("get_respawn_spawn_points"):
			return child

		var found: Node = _find_respawn_passage_by_name(child, passage_name)
		if found != null and is_instance_valid(found):
			return found

	return null


func get_respawn_transform_for_player(_peer_id: int) -> Transform3D:
	var spawn_points: Array[Node3D] = _get_respawn_spawn_points()
	if spawn_points.is_empty():
		return Transform3D(Basis(), Vector3.ZERO)

	var spawn_index: int = randi() % spawn_points.size()
	var spawn_point: Node3D = spawn_points[spawn_index]
	if spawn_point != null and is_instance_valid(spawn_point):
		return spawn_point.global_transform

	return Transform3D(Basis(), Vector3.ZERO)


func get_respawn_position_for_player(peer_id: int) -> Vector3:
	return get_respawn_transform_for_player(peer_id).origin


func _get_respawn_spawn_points() -> Array[Node3D]:
	var active_spawn_points: Array[Node3D] = _get_active_respawn_spawn_points()
	if not active_spawn_points.is_empty():
		return active_spawn_points

	return _collect_spawn_points_from_root(spawn_points_root)


func _get_active_respawn_spawn_points() -> Array[Node3D]:
	if active_respawn_passage != null and not is_instance_valid(active_respawn_passage):
		active_respawn_passage = null

	if active_respawn_passage == null and not String(active_respawn_passage_path).is_empty():
		var passage_node: Node = _resolve_respawn_passage_from_path(active_respawn_passage_path)
		if passage_node is Node3D:
			active_respawn_passage = passage_node as Node3D

	if active_respawn_passage == null or not is_instance_valid(active_respawn_passage):
		var empty_spawn_points: Array[Node3D] = []
		return empty_spawn_points

	if active_respawn_passage.has_method("get_respawn_spawn_points"):
		var custom_spawn_points: Variant = active_respawn_passage.call("get_respawn_spawn_points")
		return _collect_spawn_points_from_value(custom_spawn_points)

	var active_spawn_root: Node3D = active_respawn_passage.get_node_or_null("SpawnPoints") as Node3D
	return _collect_spawn_points_from_root(active_spawn_root)


func _collect_spawn_points_from_root(root: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = []
	if root == null or not is_instance_valid(root):
		return result

	for child in root.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if child is Node3D:
			result.append(child as Node3D)

	return result


func _collect_spawn_points_from_value(value: Variant) -> Array[Node3D]:
	var result: Array[Node3D] = []
	if value == null:
		return result

	if value is Node3D:
		result.append(value as Node3D)
		return result

	if value is Array:
		for item in value:
			if not (item is Node3D):
				continue
			var spawn_point: Node3D = item as Node3D
			if spawn_point == null or not is_instance_valid(spawn_point):
				continue
			result.append(spawn_point)

	return result


func _on_leave_requested() -> void:
	NetworkManager.leave_game()
	get_tree().change_scene_to_file(MENU_SCENE_PATH)


func _on_connection_closed(_message: String) -> void:
	get_tree().change_scene_to_file(MENU_SCENE_PATH)
