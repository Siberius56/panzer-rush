extends Node3D

const MENU_SCENE_PATH := "res://scenes/menu/MainMenu.tscn"
const PLAYER_SCENE := preload("res://scenes/player/NetworkPlayer.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/NetworkEnemy.tscn")

@export var debug_disable_enemy_spawn: bool = true
@export var initial_enemy_count: int = 4
@export var max_enemies: int = 8

@onready var players_root: Node3D = $Players
@onready var enemies_root: Node3D = $Enemies
@onready var spawn_points_root: Node3D = $SpawnPoints
@onready var enemy_spawns_root: Node3D = $EnemySpawns
@onready var spawn_timer: Timer = $SpawnTimer
@onready var hud = $CanvasLayer/NetworkHUD

var next_enemy_id: int = 1


func _ready() -> void:
	if NetworkManager.multiplayer.multiplayer_peer == null:
		get_tree().change_scene_to_file(MENU_SCENE_PATH)
		return

	NetworkManager.player_list_changed.connect(_sync_players)
	NetworkManager.connection_closed.connect(_on_connection_closed)
	hud.leave_requested.connect(_on_leave_requested)
	hud.set_session_text(_build_session_text())

	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	randomize()
	_sync_players()

	if multiplayer.is_server():
		call_deferred("_start_enemy_system")


func _build_session_text() -> String:
	var mode := "Hôte" if NetworkManager.multiplayer.is_server() else "Client"
	return "%s, %s joueur(s)" % [mode, NetworkManager.players.size()]


func _sync_players() -> void:
	hud.set_session_text(_build_session_text())

	var expected := {}
	var spawn_points := spawn_points_root.get_children()
	var ids = NetworkManager.get_player_ids()

	for peer_id in ids:
		expected["Player_%s" % peer_id] = true
		var node_name := "Player_%s" % peer_id
		var player = players_root.get_node_or_null(node_name)
		if player == null:
			var new_player = PLAYER_SCENE.instantiate()
			new_player.name = node_name
			new_player.player_id = peer_id
			new_player.player_name = NetworkManager.get_player_display_name(peer_id)
			new_player.set_multiplayer_authority(peer_id)
			players_root.add_child(new_player)

			var spawn_index := 0
			if not spawn_points.is_empty():
				spawn_index = abs(peer_id) % spawn_points.size()
				new_player.global_position = spawn_points[spawn_index].global_position
		else:
			player.player_name = NetworkManager.get_player_display_name(peer_id)
			player.update_name_label()

	for child in players_root.get_children():
		if not expected.has(child.name):
			child.queue_free()


func get_respawn_transform_for_player(_peer_id: int) -> Transform3D:
	var spawn_points := spawn_points_root.get_children()
	if spawn_points.is_empty():
		return Transform3D(Basis(), Vector3.ZERO)

	var spawn_index := randi() % spawn_points.size()
	var spawn_point := spawn_points[spawn_index]
	if spawn_point is Node3D:
		return (spawn_point as Node3D).global_transform

	return Transform3D(Basis(), Vector3.ZERO)

func get_respawn_position_for_player(peer_id: int) -> Vector3:
	return get_respawn_transform_for_player(peer_id).origin

func _start_enemy_system() -> void:
	if not debug_disable_enemy_spawn:
		await get_tree().create_timer(0.2).timeout
		for i in initial_enemy_count:
			_spawn_enemy()


func _spawn_enemy() -> void:
	if not multiplayer.is_server():
		return

	var points := enemy_spawns_root.get_children()
	if points.is_empty():
		return

	var spawn_point: Marker3D = points[randi() % points.size()]
	var enemy_id := next_enemy_id
	next_enemy_id += 1

	_create_enemy_node(enemy_id, spawn_point.global_position)
	_spawn_enemy_remote.rpc(enemy_id, spawn_point.global_position)


func _create_enemy_node(enemy_id: int, spawn_position: Vector3) -> void:
	var node_name := "Enemy_%s" % enemy_id
	if enemies_root.has_node(node_name):
		return

	var enemy = ENEMY_SCENE.instantiate()
	enemy.name = node_name
	enemy.enemy_id = enemy_id
	enemy.set_multiplayer_authority(1)
	enemies_root.add_child(enemy)
	enemy.global_position = spawn_position
	enemy.died.connect(_on_enemy_died)


func _on_enemy_died(enemy_id: int) -> void:
	if not multiplayer.is_server():
		return
	_despawn_enemy_remote.rpc(enemy_id)


func _on_spawn_timer_timeout() -> void:
	if not multiplayer.is_server():
		return
	
	if not debug_disable_enemy_spawn:
		if enemies_root.get_child_count() < max_enemies:
			_spawn_enemy()


func _on_leave_requested() -> void:
	NetworkManager.leave_game()
	get_tree().change_scene_to_file(MENU_SCENE_PATH)


func _on_connection_closed(_message: String) -> void:
	get_tree().change_scene_to_file(MENU_SCENE_PATH)


@rpc("authority", "call_remote", "reliable")
func _spawn_enemy_remote(enemy_id: int, spawn_position: Vector3) -> void:
	_create_enemy_node(enemy_id, spawn_position)


@rpc("authority", "call_remote", "reliable")
func _despawn_enemy_remote(enemy_id: int) -> void:
	var node := enemies_root.get_node_or_null("Enemy_%s" % enemy_id)
	if node != null:
		node.queue_free()
