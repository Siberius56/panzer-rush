extends Node3D
class_name ProceduralNetworkMain

# Nouvelle version pour contourner le cache Godot de l’ancien script.

const MENU_SCENE_PATH: String = "res://scenes/menu/MainMenu.tscn"
const PLAYER_SCENE: PackedScene = preload("uid://bnp6yotc2a1np") #preload("uid://2mul2xilh3fg") # preload("res://scenes/player/NetworkProceduralPlayer.tscn")
const TRANSPORT_HELICOPTER_FALLBACK_SCENE_PATH: String = "res://scenes/enemies/TransportHelicopterEnemySpawner.tscn"

@export var debug_disable_enemy_spawn: bool = true
@export var initial_enemy_count: int = 4
@export var max_enemies: int = 8

@export_group("Mission Vehicles")
@export var default_vehicle_scene: PackedScene
@export var mission_vehicle_scenes: Array[PackedScene] = []
@export var force_players_alive_on_level_load: bool = true


@export_group("Procedural Level Generation")
@export var use_procedural_generation: bool = true
@export var procedural_generator_path: NodePath = ^"ProceduralLevelGenerator"
@export var debug_reposition_players_on_regeneration: bool = true

@export_group("Respawn")
@export var trigger_root_path: NodePath = ^"Trigger"

@export_group("Initial Network Zones")
@export var apply_initial_network_zone_state_on_ready: bool = true
@export var initial_network_zones_to_activate: Array[NodePath] = []
@export var initial_network_zones_to_deactivate: Array[NodePath] = []
@export var debug_initial_network_zone_state: bool = false
@export var initial_network_zone_enemy_group_name: String = "enemies"
@export var initial_network_zone_enemy_secondary_group_name: String = "enemy"

@export_group("Transport Helicopter Attacks")
@export var transport_helicopter_scene: PackedScene
@export var max_active_transport_helicopters: int = 4
@export var allow_client_transport_helicopter_requests: bool = false

@onready var enemies_root: Node3D = get_node_or_null("Enemies") as Node3D
@onready var spawn_points_root: Node3D = get_node_or_null("SpawnPoints") as Node3D
@onready var vehicle_spawns_root: Node3D = get_node_or_null("VehicleSpawns") as Node3D
@onready var hud: Node = get_node_or_null("CanvasLayer/NetworkHUD")
@onready var world_environment: WorldEnvironment = get_node_or_null("%WorldEnvironment") as WorldEnvironment

const ENV_DAY = preload("uid://ji8qy5d56h0t")

var players_root: Node3D = null
var vehicles_root: Node3D = null
var next_enemy_id: int = 1
var next_transport_helicopter_id: int = 1
var active_respawn_passage: Node3D = null
var active_respawn_passage_path: NodePath = NodePath("")

var procedural_generator: Node = null
var procedural_level_ready: bool = false
var procedural_generation_snapshot: Dictionary = {}
var procedural_sync_after_receive_started: bool = false


func _ready() -> void:
	if NetworkManager.multiplayer.multiplayer_peer == null:
		get_tree().change_scene_to_file(MENU_SCENE_PATH)
		return
	
	add_to_group("network_main")
	_ensure_players_root()
	_ensure_vehicles_root()
	_apply_initial_network_zone_states()
	
	
	if world_environment:
		world_environment.environment = ENV_DAY
	
	
	if not NetworkManager.player_list_changed.is_connected(_sync_players):
		NetworkManager.player_list_changed.connect(_sync_players)
	if not NetworkManager.connection_closed.is_connected(_on_connection_closed):
		NetworkManager.connection_closed.connect(_on_connection_closed)
	if hud != null and hud.has_signal("leave_requested") and not hud.is_connected("leave_requested", Callable(self, "_on_leave_requested")):
		hud.connect("leave_requested", Callable(self, "_on_leave_requested"))
	
	_set_hud_session_text(_build_session_text())
	
	randomize()
	_prepare_procedural_level()
	if use_procedural_generation and not procedural_level_ready:
		return
	_sync_players()
	_prepare_vehicle_snapshot_flow()


func _set_hud_session_text(text: String) -> void:
	if hud == null or not is_instance_valid(hud):
		return
	if hud.has_method("set_session_text"):
		hud.call("set_session_text", text)


func _prepare_procedural_level() -> void:
	if not use_procedural_generation:
		procedural_level_ready = true
		return

	procedural_generator = _get_procedural_generator()
	if procedural_generator == null:
		push_warning("[ProceduralNetworkMain] ProceduralLevelGenerator introuvable. La scène continue sans génération procédurale.")
		procedural_level_ready = true
		return

	if procedural_generator.has_signal("generation_finished") and not procedural_generator.is_connected("generation_finished", Callable(self, "_on_procedural_generation_finished")):
		procedural_generator.connect("generation_finished", Callable(self, "_on_procedural_generation_finished"))

	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		procedural_level_ready = false
		_request_procedural_level_snapshot.rpc_id(NetworkManager.SERVER_PEER_ID)
		return

	_generate_procedural_level_as_authority(0, false)


func _get_procedural_generator() -> Node:
	if procedural_generator != null and is_instance_valid(procedural_generator):
		return procedural_generator

	if not procedural_generator_path.is_empty():
		procedural_generator = get_node_or_null(procedural_generator_path)
		if procedural_generator != null:
			return procedural_generator

	var generators: Array[Node] = get_tree().get_nodes_in_group("procedural_level_generator")
	if not generators.is_empty():
		procedural_generator = generators[0]
		return procedural_generator

	return null


func _generate_procedural_level_as_authority(requested_seed: int, broadcast_to_clients: bool) -> void:
	var generator: Node = _get_procedural_generator()
	if generator == null:
		procedural_level_ready = true
		return

	var generated_generation_data: Variant = generator.call("generate_random", requested_seed)

	procedural_generation_snapshot = _read_generation_dictionary_from_generator(generator)
	procedural_level_ready = true
	_refresh_spawn_roots_from_procedural_generator()

	if broadcast_to_clients and multiplayer.multiplayer_peer != null and multiplayer.is_server():
		_receive_procedural_level_snapshot.rpc(procedural_generation_snapshot.duplicate(true))

	if debug_reposition_players_on_regeneration and broadcast_to_clients:
		_reposition_existing_players_and_vehicles_to_current_spawns()


func _read_generation_dictionary_from_generator(generator: Node) -> Dictionary:
	if generator == null:
		return {}

	if generator.has_method("get_generation_dictionary"):
		var generation_value: Variant = generator.call("get_generation_dictionary")
		if generation_value is Dictionary:
			return (generation_value as Dictionary).duplicate(true)

	return {}


func _refresh_spawn_roots_from_procedural_generator() -> void:
	var generator: Node = _get_procedural_generator()
	if generator != null and generator.has_method("get_spawn_points_root"):
		var spawn_value: Variant = generator.call("get_spawn_points_root")
		if spawn_value is Node3D:
			spawn_points_root = spawn_value as Node3D
	if generator != null and generator.has_method("get_vehicle_spawns_root"):
		var vehicle_spawn_value: Variant = generator.call("get_vehicle_spawns_root")
		if vehicle_spawn_value is Node3D:
			vehicle_spawns_root = vehicle_spawn_value as Node3D

	if spawn_points_root == null:
		spawn_points_root = get_node_or_null("SpawnPoints") as Node3D
	if vehicle_spawns_root == null:
		vehicle_spawns_root = get_node_or_null("VehicleSpawns") as Node3D


func _on_procedural_generation_finished(generation_dictionary: Dictionary) -> void:
	procedural_generation_snapshot = generation_dictionary.duplicate(true)
	_refresh_spawn_roots_from_procedural_generator()


@rpc("any_peer", "reliable")
func _request_procedural_level_snapshot() -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return

	if procedural_generation_snapshot.is_empty():
		_generate_procedural_level_as_authority(0, false)

	var requester_peer_id: int = multiplayer.get_remote_sender_id()
	if requester_peer_id <= 0:
		return

	_receive_procedural_level_snapshot.rpc_id(requester_peer_id, procedural_generation_snapshot.duplicate(true))


@rpc("authority", "call_local", "reliable")
func _receive_procedural_level_snapshot(generation_dictionary: Dictionary) -> void:
	var generator: Node = _get_procedural_generator()
	if generator == null:
		procedural_level_ready = true
		return

	if generator.has_method("generate_from_dictionary"):
		generator.call("generate_from_dictionary", generation_dictionary.duplicate(true))

	procedural_generation_snapshot = generation_dictionary.duplicate(true)
	procedural_level_ready = true
	_refresh_spawn_roots_from_procedural_generator()

	if not procedural_sync_after_receive_started:
		procedural_sync_after_receive_started = true
		_sync_players()
		_prepare_vehicle_snapshot_flow()


func debug_regenerate_procedural_level(requested_seed: int = 0) -> void:
	if not use_procedural_generation:
		return

	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		_request_debug_regenerate_procedural_level.rpc_id(NetworkManager.SERVER_PEER_ID, requested_seed)
		return

	_generate_procedural_level_as_authority(requested_seed, true)
	_sync_players()
	_sync_vehicles()


@rpc("any_peer", "reliable")
func _request_debug_regenerate_procedural_level(requested_seed: int) -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return
	debug_regenerate_procedural_level(requested_seed)


func get_procedural_generation_snapshot() -> Dictionary:
	return procedural_generation_snapshot.duplicate(true)


func _reposition_existing_players_and_vehicles_to_current_spawns() -> void:
	_refresh_spawn_roots_from_procedural_generator()

	var player_spawns: Array[Node3D] = _collect_spawn_points_from_root(spawn_points_root)
	if players_root != null and not player_spawns.is_empty():
		var player_index: int = 0
		for player_node: Node in players_root.get_children():
			if player_node is Node3D:
				var spawn_index: int = player_index % player_spawns.size()
				(player_node as Node3D).global_transform = player_spawns[spawn_index].global_transform
				player_index += 1

	var vehicle_spawns: Array[Node3D] = _collect_spawn_points_from_root(vehicle_spawns_root)
	if vehicles_root != null and not vehicle_spawns.is_empty():
		var vehicle_index: int = 0
		for vehicle_node: Node in vehicles_root.get_children():
			if vehicle_node is Node3D:
				var vehicle_spawn_index: int = vehicle_index % vehicle_spawns.size()
				(vehicle_node as Node3D).global_transform = vehicle_spawns[vehicle_spawn_index].global_transform
				_prime_client_vehicle_transform(vehicle_node, vehicle_spawns[vehicle_spawn_index].global_transform)
				vehicle_index += 1


func _apply_initial_network_zone_states() -> void:
	if not apply_initial_network_zone_state_on_ready:
		return

	# On désactive d'abord, puis on active.
	# Si une zone est dans les deux listes, l'activation gagne.
	for zone_path: NodePath in initial_network_zones_to_deactivate:
		_apply_initial_network_zone_state_from_path(zone_path, false)

	for zone_path: NodePath in initial_network_zones_to_activate:
		_apply_initial_network_zone_state_from_path(zone_path, true)


func _apply_initial_network_zone_state_from_path(zone_path: NodePath, active: bool) -> void:
	if zone_path.is_empty():
		return

	var zone_node: Node = _get_initial_network_zone_from_path(zone_path)
	if zone_node == null or not is_instance_valid(zone_node):
		var action_text: String = "activer" if active else "désactiver"
		push_warning("[NetworkMain] Impossible de %s la zone initiale : %s" % [action_text, str(zone_path)])
		return

	_set_initial_network_zone_active(zone_node, active)


func _get_initial_network_zone_from_path(zone_path: NodePath) -> Node:
	if zone_path.is_empty():
		return null

	var node: Node = get_node_or_null(zone_path)
	if node == null:
		var current_scene: Node = get_tree().current_scene
		if current_scene != null and current_scene != self:
			node = current_scene.get_node_or_null(zone_path)

	return node


func _set_initial_network_zone_active(zone_node: Node, active: bool) -> void:
	if zone_node == null or not is_instance_valid(zone_node):
		return

	if debug_initial_network_zone_state:
		var state_text: String = "activée" if active else "désactivée"
		print("[NetworkMain] Zone initiale %s : %s" % [state_text, zone_node.get_path()])

	if zone_node.has_method("set_network_zone_active"):
		zone_node.call("set_network_zone_active", active)
	else:
		push_warning("[NetworkMain] La zone ne possède pas set_network_zone_active(active). Les props ne seront pas gérées par NetworkZone.gd : %s" % str(zone_node.get_path()))

	_set_initial_network_zone_enemies_active(zone_node, active)


func _set_initial_network_zone_enemies_active(zone_node: Node, active: bool) -> void:
	if zone_node == null or not is_instance_valid(zone_node):
		return

	var zone_enemies: Array[Node] = []
	var seen: Dictionary = {}
	_collect_initial_network_zone_enemies(zone_node, zone_enemies, seen)

	for enemy_node in zone_enemies:
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		_set_initial_network_zone_enemy_active(enemy_node, active)

	if debug_initial_network_zone_state and zone_enemies.size() > 0:
		var state_text: String = "activés" if active else "désactivés"
		print("[NetworkMain] Ennemis de zone initiale %s : %d" % [state_text, zone_enemies.size()])


func _collect_initial_network_zone_enemies(root: Node, result: Array[Node], seen: Dictionary) -> void:
	if root == null or not is_instance_valid(root):
		return

	if _is_initial_network_zone_enemy_node(root):
		var enemy_id: int = root.get_instance_id()
		if not seen.has(enemy_id):
			seen[enemy_id] = true
			result.append(root)
		return

	for child in root.get_children():
		if child == null or not is_instance_valid(child):
			continue
		_collect_initial_network_zone_enemies(child, result, seen)


func _is_initial_network_zone_enemy_node(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false

	if not initial_network_zone_enemy_group_name.is_empty() and node.is_in_group(initial_network_zone_enemy_group_name):
		return true

	if not initial_network_zone_enemy_secondary_group_name.is_empty() and node.is_in_group(initial_network_zone_enemy_secondary_group_name):
		return true

	return false


func _set_initial_network_zone_enemy_active(enemy_node: Node, active: bool) -> void:
	if enemy_node == null or not is_instance_valid(enemy_node):
		return

	if enemy_node.has_method("set_network_zone_active"):
		enemy_node.call("set_network_zone_active", active)
		return

	_apply_generic_initial_network_zone_enemy_state(enemy_node, active)


func _apply_generic_initial_network_zone_enemy_state(enemy_node: Node, active: bool) -> void:
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
	_apply_generic_initial_network_zone_enemy_tree_state(enemy_node, active)


func _apply_generic_initial_network_zone_enemy_tree_state(root: Node, active: bool) -> void:
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
		_apply_generic_initial_network_zone_enemy_tree_state(child, active)


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


func _ensure_enemies_root() -> void:
	enemies_root = get_node_or_null("Enemies") as Node3D
	if enemies_root != null:
		return

	enemies_root = Node3D.new()
	enemies_root.name = "Enemies"
	add_child(enemies_root)


func request_transport_helicopter(
	spawn_transform: Transform3D,
	destination_position: Vector3,
	unit_set_id: String
) -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		if allow_client_transport_helicopter_requests:
			_request_transport_helicopter_from_client.rpc_id(
				NetworkManager.SERVER_PEER_ID,
				spawn_transform,
				destination_position,
				unit_set_id
			)
		return

	_server_request_transport_helicopter(spawn_transform, destination_position, unit_set_id)


@rpc("any_peer", "reliable")
func _request_transport_helicopter_from_client(
	spawn_transform: Transform3D,
	destination_position: Vector3,
	unit_set_id: String
) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if not multiplayer.is_server():
		return
	if not allow_client_transport_helicopter_requests:
		return

	_server_request_transport_helicopter(spawn_transform, destination_position, unit_set_id)


func _server_request_transport_helicopter(
	spawn_transform: Transform3D,
	destination_position: Vector3,
	unit_set_id: String
) -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return

	_ensure_enemies_root()

	if enemies_root == null:
		push_warning("[NetworkMain] Enemies root introuvable. Impossible de créer l'hélicoptère.")
		return

	if _get_active_transport_helicopter_count() >= max_active_transport_helicopters:
		push_warning("[NetworkMain] Limite d'hélicoptères actifs atteinte.")
		return

	var helicopter_name: String = "TransportHelicopter_%d" % next_transport_helicopter_id
	next_transport_helicopter_id += 1

	if multiplayer.multiplayer_peer != null:
		_spawn_transport_helicopter_remote.rpc(
			helicopter_name,
			spawn_transform,
			destination_position,
			unit_set_id
		)
		return

	_spawn_transport_helicopter_remote(
		helicopter_name,
		spawn_transform,
		destination_position,
		unit_set_id
	)


@rpc("authority", "call_local", "reliable")
func _spawn_transport_helicopter_remote(
	helicopter_name: String,
	spawn_transform: Transform3D,
	destination_position: Vector3,
	unit_set_id: String
) -> void:
	_ensure_enemies_root()

	if enemies_root == null:
		return

	if enemies_root.get_node_or_null(helicopter_name) != null:
		return

	var scene: PackedScene = _get_transport_helicopter_scene()
	if scene == null:
		push_warning("[NetworkMain] Scène d'hélicoptère introuvable : %s" % TRANSPORT_HELICOPTER_FALLBACK_SCENE_PATH)
		return

	var helicopter: Node = scene.instantiate()
	helicopter.name = helicopter_name
	helicopter.set_multiplayer_authority(NetworkManager.SERVER_PEER_ID)
	enemies_root.add_child(helicopter)

	if helicopter is Node3D:
		(helicopter as Node3D).global_transform = spawn_transform

	if helicopter.has_method("setup_transport_helicopter"):
		helicopter.call("setup_transport_helicopter", spawn_transform, destination_position, unit_set_id)
		return
	
	_set_property_if_exists(helicopter, "destination_position", destination_position)
	_set_property_if_exists(helicopter, "spawn_position", spawn_transform.origin)
	_set_property_if_exists(helicopter, "unit_set_id", unit_set_id)


func _get_transport_helicopter_scene() -> PackedScene:
	if transport_helicopter_scene != null:
		return transport_helicopter_scene

	if ResourceLoader.exists(TRANSPORT_HELICOPTER_FALLBACK_SCENE_PATH):
		return load(TRANSPORT_HELICOPTER_FALLBACK_SCENE_PATH) as PackedScene

	return null


func _get_active_transport_helicopter_count() -> int:
	_ensure_enemies_root()

	if enemies_root == null:
		return 0

	var count: int = 0
	for child in enemies_root.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if child.is_in_group("transport_helicopters"):
			count += 1
			continue
		if String(child.name).begins_with("TransportHelicopter_"):
			count += 1

	return count


func _set_property_if_exists(target: Object, property_name: String, value: Variant) -> void:
	if target == null:
		return

	for property_info in target.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			target.set(property_name, value)
			return


func _build_session_text() -> String:
	var mode: String = "Hôte" if NetworkManager.multiplayer.is_server() else "Client"
	return "%s, %s joueur(s)" % [mode, NetworkManager.players.size()]


func _sync_players() -> void:
	_refresh_spawn_roots_from_procedural_generator()
	_set_hud_session_text(_build_session_text())

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
					new_player.rotation = Vector3.ZERO
			
			if GameSessionState.has_player_state(peer_id):
				GameSessionState.apply_player_state_to_node(new_player, force_players_alive_on_level_load)
		else:
			player.player_name = NetworkManager.get_player_display_name(peer_id)
			if player.has_method("update_name_label"):
				player.call("update_name_label")

	for child in players_root.get_children():
		if not expected.has(child.name):
			child.queue_free()

	_sync_team_respawn_lives_to_players()


func _sync_team_respawn_lives_to_players() -> void:
	if not multiplayer.is_server():
		return
	if players_root == null:
		return

	for child in players_root.get_children():
		if child != null and is_instance_valid(child) and child.has_method("_server_sync_team_respawn_lives_state"):
			child.call("_server_sync_team_respawn_lives_state")


func _prepare_vehicle_snapshot_flow() -> void:
	_normalize_game_session_vehicle_keys()

	if multiplayer.is_server():
		_sync_vehicles()
		_apply_session_snapshot_to_scene()
		_broadcast_vehicle_snapshot_to_clients()
		return

	if GameSessionState.has_vehicle_snapshot() and GameSessionState.get_vehicle_count() > 0:
		_sync_vehicles()
		_apply_session_snapshot_to_scene()
		return

	_request_vehicle_snapshot_from_server.rpc_id(NetworkManager.SERVER_PEER_ID)


@rpc("any_peer", "reliable")
func _request_vehicle_snapshot_from_server() -> void:
	if not multiplayer.is_server():
		return

	var requester_peer_id: int = multiplayer.get_remote_sender_id()
	if requester_peer_id <= 0:
		return

	_normalize_game_session_vehicle_keys()
	_receive_vehicle_snapshot_from_server.rpc_id(
		requester_peer_id,
		GameSessionState.vehicle_snapshot_active,
		GameSessionState.vehicles.duplicate(true)
	)


func _broadcast_vehicle_snapshot_to_clients() -> void:
	if not multiplayer.is_server():
		return

	_normalize_game_session_vehicle_keys()
	_receive_vehicle_snapshot_from_server.rpc(
		GameSessionState.vehicle_snapshot_active,
		GameSessionState.vehicles.duplicate(true)
	)


@rpc("authority", "call_local", "reliable")
func _receive_vehicle_snapshot_from_server(snapshot_active: bool, vehicles_snapshot: Dictionary) -> void:
	GameSessionState.vehicle_snapshot_active = snapshot_active
	GameSessionState.vehicles = vehicles_snapshot.duplicate(true)
	_normalize_game_session_vehicle_keys()

	_sync_vehicles()
	_apply_session_snapshot_to_scene()


func _sync_vehicles() -> void:
	_ensure_vehicles_root()
	_refresh_spawn_roots_from_procedural_generator()
	_normalize_game_session_vehicle_keys()

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

		var spawn_point: Node3D = spawn_points[vehicle_index] as Node3D
		var vehicle: Node = vehicles_root.get_node_or_null(node_name)

		if vehicle != null and not _vehicle_node_matches_expected_scene(vehicle, scene, vehicle_index):
			vehicles_root.remove_child(vehicle)
			vehicle.queue_free()
			vehicle = null

		if vehicle == null:
			vehicle = scene.instantiate()
			vehicle.name = node_name
			vehicle.set_multiplayer_authority(NetworkManager.SERVER_PEER_ID)
			vehicles_root.add_child(vehicle)

			if spawn_point != null and vehicle is Node3D:
				(vehicle as Node3D).global_transform = spawn_point.global_transform
				_prime_client_vehicle_transform(vehicle, spawn_point.global_transform)
		elif spawn_point != null and vehicle is Node3D and not _has_vehicle_state_resilient(vehicle_index):
			(vehicle as Node3D).global_transform = spawn_point.global_transform
			_prime_client_vehicle_transform(vehicle, spawn_point.global_transform)

		_apply_vehicle_state_to_spawned_vehicle(vehicle_index, vehicle)

		if spawn_point != null and vehicle is Node3D:
			_prime_client_vehicle_transform(vehicle, (vehicle as Node3D).global_transform)

	for child in vehicles_root.get_children():
		if not expected.has(child.name):
			child.queue_free()


func _get_required_vehicle_count(max_spawn_count: int) -> int:
	_normalize_game_session_vehicle_keys()

	if GameSessionState.has_vehicle_snapshot() and GameSessionState.get_vehicle_count() > 0:
		return min(GameSessionState.get_vehicle_count(), max_spawn_count)

	if not mission_vehicle_scenes.is_empty():
		return min(mission_vehicle_scenes.size(), max_spawn_count)

	if default_vehicle_scene != null:
		return 1

	return 0


func _get_vehicle_scene_for_index(vehicle_index: int) -> PackedScene:
	var state: Dictionary = _get_vehicle_state_resilient(vehicle_index)
	if not state.is_empty():
		var scene_path: String = String(state.get("scene_path", ""))
		if not scene_path.is_empty():
			var loaded_scene: PackedScene = load(scene_path) as PackedScene
			if loaded_scene != null:
				return loaded_scene
			push_warning("[NetworkMain] Impossible de charger le châssis sauvegardé : %s" % scene_path)

		return _get_initial_mission_vehicle_scene(vehicle_index)

	return _get_initial_mission_vehicle_scene(vehicle_index)


func _get_initial_mission_vehicle_scene(vehicle_index: int) -> PackedScene:
	if vehicle_index >= 0 and vehicle_index < mission_vehicle_scenes.size():
		return mission_vehicle_scenes[vehicle_index]

	if vehicle_index == 0:
		return default_vehicle_scene

	return null


func _has_vehicle_state_resilient(vehicle_index: int) -> bool:
	if GameSessionState.has_vehicle_state(vehicle_index):
		return true

	var string_key: String = str(vehicle_index)
	return GameSessionState.vehicle_snapshot_active and GameSessionState.vehicles.has(string_key)


func _get_vehicle_state_resilient(vehicle_index: int) -> Dictionary:
	if GameSessionState.has_vehicle_state(vehicle_index):
		return GameSessionState.get_vehicle_state(vehicle_index)

	var string_key: String = str(vehicle_index)
	if GameSessionState.vehicle_snapshot_active and GameSessionState.vehicles.has(string_key):
		var state_value: Variant = GameSessionState.vehicles[string_key]
		if state_value is Dictionary:
			return (state_value as Dictionary).duplicate(true)

	return {}


func _normalize_game_session_vehicle_keys() -> void:
	if not GameSessionState.vehicle_snapshot_active:
		return
	if GameSessionState.vehicles.is_empty():
		return

	var normalized: Dictionary = {}
	var changed: bool = false

	for key in GameSessionState.vehicles.keys():
		var vehicle_index: int = int(key)
		var state_value: Variant = GameSessionState.vehicles[key]
		if state_value is Dictionary:
			var state: Dictionary = (state_value as Dictionary).duplicate(true)
			state["vehicle_index"] = vehicle_index
			normalized[vehicle_index] = state
		else:
			normalized[vehicle_index] = state_value

		if key != vehicle_index:
			changed = true

	if changed:
		GameSessionState.vehicles = normalized


func _apply_vehicle_state_to_spawned_vehicle(vehicle_index: int, vehicle: Node) -> void:
	if vehicle == null or not is_instance_valid(vehicle):
		return

	var state: Dictionary = _get_vehicle_state_resilient(vehicle_index)
	if state.is_empty():
		return

	if vehicle.has_method("apply_session_state"):
		vehicle.call("apply_session_state", state)
		return

	GameSessionState.apply_vehicle_state_to_node(vehicle_index, vehicle)


func _prime_client_vehicle_transform(vehicle: Node, spawn_transform: Transform3D) -> void:
	if multiplayer.is_server():
		return
	if vehicle == null or not is_instance_valid(vehicle):
		return
	if not (vehicle is Node3D):
		return

	# Le client n'est pas autoritaire sur la physique du tank.
	# On le plaque immédiatement au transform connu pour éviter qu'il reste en l'air
	# en attendant les premiers paquets _sync_vehicle_state du serveur.
	(vehicle as Node3D).global_transform = spawn_transform

	if vehicle.has_method("prime_client_transform"):
		vehicle.call("prime_client_transform", spawn_transform)
		return

	if "client_target_transform" in vehicle:
		vehicle.set("client_target_transform", spawn_transform)
	if "client_has_target_transform" in vehicle:
		vehicle.set("client_has_target_transform", true)
	if "linear_velocity" in vehicle:
		vehicle.set("linear_velocity", Vector3.ZERO)
	if "angular_velocity" in vehicle:
		vehicle.set("angular_velocity", Vector3.ZERO)


func _vehicle_node_matches_expected_scene(vehicle: Node, expected_scene: PackedScene, vehicle_index: int) -> bool:
	if vehicle == null or expected_scene == null:
		return false

	var expected_scene_path: String = _get_expected_vehicle_scene_path(expected_scene, vehicle_index)
	if expected_scene_path.is_empty():
		return true

	var current_scene_path: String = ""
	if "scene_file_path" in vehicle:
		current_scene_path = String(vehicle.get("scene_file_path"))

	return current_scene_path == expected_scene_path


func _get_expected_vehicle_scene_path(expected_scene: PackedScene, vehicle_index: int) -> String:
	var state: Dictionary = _get_vehicle_state_resilient(vehicle_index)
	var saved_scene_path: String = String(state.get("scene_path", ""))
	if not saved_scene_path.is_empty():
		return saved_scene_path

	if expected_scene != null and not expected_scene.resource_path.is_empty():
		return expected_scene.resource_path

	return ""


func _apply_session_snapshot_to_scene() -> void:
	_normalize_game_session_vehicle_keys()

	if GameSessionState.player_snapshot_active:
		for player in players_root.get_children():
			GameSessionState.apply_player_state_to_node(player, force_players_alive_on_level_load)

	if GameSessionState.vehicle_snapshot_active and vehicles_root != null:
		for key in GameSessionState.vehicles.keys():
			var vehicle_index: int = int(key)
			var vehicle: Node = vehicles_root.get_node_or_null("Vehicle_%d" % vehicle_index)
			if vehicle == null:
				continue
			_apply_vehicle_state_to_spawned_vehicle(vehicle_index, vehicle)


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
