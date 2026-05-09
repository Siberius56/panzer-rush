extends Node3D

const MENU_SCENE_PATH := "res://scenes/menu/MainMenu.tscn"
const PLAYER_SCENE := preload("res://scenes/player/NetworkPlayer.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/NetworkEnemy.tscn")

@export var debug_disable_enemy_spawn: bool = true
@export var initial_enemy_count: int = 4
@export var max_enemies: int = 8

@export_group("Mission Vehicles")
@export var default_vehicle_scene: PackedScene
@export var mission_vehicle_scenes: Array[PackedScene] = []
@export var force_players_alive_on_level_load: bool = true

@onready var players_root: Node3D = $Players
@onready var enemies_root: Node3D = $Enemies
@onready var spawn_points_root: Node3D = $SpawnPoints
@onready var enemy_spawns_root: Node3D = $EnemySpawns
@onready var vehicle_spawns_root: Node3D = $VehicleSpawns
@onready var hud = $CanvasLayer/NetworkHUD

var vehicles_root: Node3D = null
var next_enemy_id: int = 1


func _ready() -> void:
	if NetworkManager.multiplayer.multiplayer_peer == null:
		get_tree().change_scene_to_file(MENU_SCENE_PATH)
		return

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

	#if multiplayer.is_server():
		#call_deferred("_start_enemy_system")


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


func get_respawn_transform_for_player(_peer_id: int) -> Transform3D:
	var spawn_points: Array = spawn_points_root.get_children()
	if spawn_points.is_empty():
		return Transform3D(Basis(), Vector3.ZERO)

	var spawn_index: int = randi() % spawn_points.size()
	var spawn_point = spawn_points[spawn_index]
	if spawn_point is Node3D:
		return (spawn_point as Node3D).global_transform

	return Transform3D(Basis(), Vector3.ZERO)


func get_respawn_position_for_player(peer_id: int) -> Vector3:
	return get_respawn_transform_for_player(peer_id).origin


#func _start_enemy_system() -> void:
	#if not debug_disable_enemy_spawn:
		#await get_tree().create_timer(0.2).timeout
		#for i in initial_enemy_count:
			#_spawn_enemy()
#
#
#func _spawn_enemy() -> void:
	#if not multiplayer.is_server():
		#return
#
	#var points := enemy_spawns_root.get_children()
	#if points.is_empty():
		#return
#
	#var spawn_point: Marker3D = points[randi() % points.size()]
	#var enemy_id := next_enemy_id
	#next_enemy_id += 1
#
	#_create_enemy_node(enemy_id, spawn_point.global_position)
	#_spawn_enemy_remote.rpc(enemy_id, spawn_point.global_position)
#
#
#func _create_enemy_node(enemy_id: int, spawn_position: Vector3) -> void:
	#var node_name := "Enemy_%s" % enemy_id
	#if enemies_root.has_node(node_name):
		#return
#
	#var enemy = ENEMY_SCENE.instantiate()
	#enemy.name = node_name
	#enemy.enemy_id = enemy_id
	#enemy.set_multiplayer_authority(1)
	#enemies_root.add_child(enemy)
	#enemy.global_position = spawn_position
	#enemy.died.connect(_on_enemy_died)


#func _on_enemy_died(enemy_id: int) -> void:
	#print("> on enemy died")
	#if not multiplayer.is_server():
		#return
	#_despawn_enemy_remote.rpc(enemy_id)


#func _on_spawn_timer_timeout() -> void:
	#if not multiplayer.is_server():
		#return
	#
	#if not debug_disable_enemy_spawn:
		#if enemies_root.get_child_count() < max_enemies:
			#_spawn_enemy()


func _on_leave_requested() -> void:
	NetworkManager.leave_game()
	get_tree().change_scene_to_file(MENU_SCENE_PATH)


func _on_connection_closed(_message: String) -> void:
	get_tree().change_scene_to_file(MENU_SCENE_PATH)


#@rpc("authority", "call_remote", "reliable")
#func _spawn_enemy_remote(enemy_id: int, spawn_position: Vector3) -> void:
	#_create_enemy_node(enemy_id, spawn_position)


#@rpc("authority", "call_remote", "reliable")
#func _despawn_enemy_remote(enemy_id: int) -> void:
	#print("> despawn enemy remote")
	#var node := enemies_root.get_node_or_null("Enemy_%s" % enemy_id)
	#if node != null:
		#node.queue_free()
