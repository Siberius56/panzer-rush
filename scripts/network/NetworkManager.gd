extends Node

signal connection_succeeded
signal connection_failed(message: String)
signal connection_closed(message: String)
signal player_list_changed

const GAME_SCENE_PATH := "res://scenes/game/NetworkMain.tscn"

var players: Dictionary = {}
var local_player_name: String = "Player"
var current_ip: String = "127.0.0.1"
var current_port: int = 7000
var max_clients: int = 4
var last_message: String = ""


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_game(port: int, player_name: String, desired_max_clients: int = 4) -> int:
	leave_game(false)
	local_player_name = _sanitize_player_name(player_name)
	current_port = port
	max_clients = max(desired_max_clients, 1)
	last_message = ""

	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(current_port, max_clients)
	if error != OK:
		last_message = "Impossible d'héberger la partie. Code %s." % error
		return error

	multiplayer.multiplayer_peer = peer
	players = {
		1: {
			"name": local_player_name,
			"ready": false
		}
	}
	_broadcast_player_list()
	connection_succeeded.emit()
	return OK


func join_game(ip: String, port: int, player_name: String) -> int:
	leave_game(false)
	local_player_name = _sanitize_player_name(player_name)
	current_ip = ip.strip_edges()
	current_port = port
	last_message = ""

	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(current_ip, current_port)
	if error != OK:
		last_message = "Connexion impossible. Code %s." % error
		return error

	multiplayer.multiplayer_peer = peer
	return OK


func leave_game(emit_update: bool = true) -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	players.clear()
	if emit_update:
		player_list_changed.emit()


func set_local_ready(to_ready: bool) -> void:
	if multiplayer.multiplayer_peer == null:
		return

	if multiplayer.is_server():
		var local_id := multiplayer.get_unique_id()
		if players.has(local_id):
			players[local_id]["ready"] = to_ready
			_broadcast_player_list()
		return

	_set_ready_state.rpc_id(1, to_ready)


func is_local_player_ready() -> bool:
	var local_id := multiplayer.get_unique_id()
	if players.has(local_id):
		return bool(players[local_id].get("ready", false))
	return false


func can_start_game() -> bool:
	if not multiplayer.is_server():
		return false
	if players.is_empty():
		return false

	for player_data in players.values():
		if not bool(player_data.get("ready", false)):
			return false
	return true


func start_game() -> void:
	if not multiplayer.is_server():
		return
	if not can_start_game():
		return
	_load_game_scene.rpc()


func get_player_display_name(peer_id: int) -> String:
	if players.has(peer_id):
		return str(players[peer_id].get("name", "Player"))
	return "Player"


func get_player_ids() -> Array:
	var ids: Array = players.keys()
	ids.sort()
	return ids


func _sanitize_player_name(value: String) -> String:
	var trimmed := value.strip_edges()
	if trimmed.is_empty():
		return "Player"
	return trimmed.substr(0, 20)


func _broadcast_player_list() -> void:
	if not multiplayer.is_server():
		return
	_receive_player_list.rpc(players)


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	if players.has(id):
		players.erase(id)
		_broadcast_player_list()


func _on_connected_to_server() -> void:
	_register_player.rpc_id(1, {
		"name": local_player_name,
		"ready": false
	})
	connection_succeeded.emit()


func _on_connection_failed() -> void:
	last_message = "Connexion au serveur impossible."
	leave_game()
	connection_failed.emit(last_message)


func _on_server_disconnected() -> void:
	last_message = "La session a été fermée par l'hôte."
	leave_game()
	connection_closed.emit(last_message)


@rpc("any_peer", "reliable")
func _register_player(player_data: Dictionary) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	players[sender_id] = {
		"name": _sanitize_player_name(str(player_data.get("name", "Player"))),
		"ready": false
	}
	_broadcast_player_list()


@rpc("any_peer", "reliable")
func _set_ready_state(to_ready: bool) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if players.has(sender_id):
		players[sender_id]["ready"] = to_ready
		_broadcast_player_list()


@rpc("authority", "call_local", "reliable")
func _load_game_scene() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


@rpc("authority", "call_local", "reliable")
func _receive_player_list(new_players: Dictionary) -> void:
	players = new_players.duplicate(true)
	player_list_changed.emit()
