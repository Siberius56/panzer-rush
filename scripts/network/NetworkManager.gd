extends Node

signal connection_succeeded
signal connection_failed(message: String)
signal connection_closed(message: String)
signal player_list_changed

const GAME_SCENE_PATH := "res://scenes/game/NetworkMain.tscn"
const STEAM_VIRTUAL_PORT := 0
const SERVER_PEER_ID := 1

enum NetworkMode {
	NONE,
	LAN,
	STEAM
}

var players: Dictionary = {}
var local_player_name: String = "Player"
var current_ip: String = "127.0.0.1"
var current_port: int = 7000
var max_clients: int = 4
var last_message: String = ""
var network_mode: NetworkMode = NetworkMode.NONE
var steam_host_id: int = 0
var steam_peer: MultiplayerPeer = null

# Important : on ne se fie pas uniquement à multiplayer.is_server().
# Avec SteamMultiplayerPeer, certains états peuvent être ambigus pendant le prototype.
var is_host_session := false


func _ready() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)

	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)

	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)

	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_game(port: int, player_name: String, desired_max_clients: int = 4) -> int:
	leave_game(false)

	network_mode = NetworkMode.LAN
	is_host_session = true
	local_player_name = _sanitize_player_name(player_name)
	current_port = port
	max_clients = max(desired_max_clients, 1)
	last_message = ""

	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(current_port, max_clients)

	print("[NET_LAN] create_server port=", current_port, " max_clients=", max_clients, " result=", error)

	if error != OK:
		last_message = "Impossible d'héberger la partie. Code %s." % error
		network_mode = NetworkMode.NONE
		is_host_session = false
		return error

	multiplayer.multiplayer_peer = peer
	_add_or_update_local_host_player(0)
	_broadcast_player_list()
	connection_succeeded.emit()
	return OK


func join_game(ip: String, port: int, player_name: String) -> int:
	leave_game(false)

	network_mode = NetworkMode.LAN
	is_host_session = false
	local_player_name = _sanitize_player_name(player_name)
	current_ip = ip.strip_edges()
	current_port = port
	last_message = ""

	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(current_ip, current_port)

	print("[NET_LAN] create_client ip=", current_ip, " port=", current_port, " result=", error)

	if error != OK:
		last_message = "Connexion impossible. Code %s." % error
		network_mode = NetworkMode.NONE
		return error

	multiplayer.multiplayer_peer = peer
	return OK


func host_steam(player_name: String) -> int:
	leave_game(false)

	if not _is_steam_ready():
		last_message = "Steam n'est pas prêt. Vérifie que Steam est lancé et que steam_appid.txt existe."
		network_mode = NetworkMode.NONE
		return ERR_UNAVAILABLE

	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		last_message = "SteamMultiplayerPeer est introuvable. Vérifie GodotSteam."
		network_mode = NetworkMode.NONE
		return ERR_UNAVAILABLE

	network_mode = NetworkMode.STEAM
	is_host_session = true
	local_player_name = _sanitize_player_name(player_name)
	last_message = ""
	steam_host_id = _get_local_steam_id()

	var peer = SteamMultiplayerPeer.new()
	var error: int = peer.create_host(STEAM_VIRTUAL_PORT)

	print("[NET_STEAM] create_host virtual_port=", STEAM_VIRTUAL_PORT, " result=", error)

	if error != OK:
		last_message = "Impossible de créer le host Steam. Code %s." % error
		network_mode = NetworkMode.NONE
		is_host_session = false
		steam_peer = null
		return error

	steam_peer = peer
	multiplayer.multiplayer_peer = steam_peer

	_add_or_update_local_host_player(_get_local_steam_id())
	_broadcast_player_list()

	last_message = "Host Steam actif."
	print("[NET_STEAM] Host ready. unique_id=", multiplayer.get_unique_id(), " steam_id=", _get_local_steam_id(), " is_server=", multiplayer.is_server())

	connection_succeeded.emit()
	return OK


func join_steam(host_steam_id: int, player_name: String) -> int:
	leave_game(false)

	if not _is_steam_ready():
		last_message = "Steam n'est pas prêt. Vérifie que Steam est lancé et que steam_appid.txt existe."
		network_mode = NetworkMode.NONE
		return ERR_UNAVAILABLE

	if host_steam_id <= 0:
		last_message = "Steam ID du host invalide."
		network_mode = NetworkMode.NONE
		return ERR_INVALID_PARAMETER

	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		last_message = "SteamMultiplayerPeer est introuvable. Vérifie GodotSteam."
		network_mode = NetworkMode.NONE
		return ERR_UNAVAILABLE

	network_mode = NetworkMode.STEAM
	is_host_session = false
	local_player_name = _sanitize_player_name(player_name)
	steam_host_id = host_steam_id
	last_message = ""

	var peer = SteamMultiplayerPeer.new()
	var error: int = peer.create_client(host_steam_id, STEAM_VIRTUAL_PORT)

	print("[NET_STEAM] create_client host_steam_id=", host_steam_id, " virtual_port=", STEAM_VIRTUAL_PORT, " result=", error)

	if error != OK:
		last_message = "Impossible de créer le client Steam. Code %s." % error
		network_mode = NetworkMode.NONE
		steam_peer = null
		return error

	steam_peer = peer
	multiplayer.multiplayer_peer = steam_peer
	last_message = "Connexion Steam en cours..."
	print("[NET_STEAM] Client peer created. local unique_id=", multiplayer.get_unique_id(), " is_server=", multiplayer.is_server())
	return OK


func leave_game(emit_update: bool = true) -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()

	multiplayer.multiplayer_peer = null
	steam_peer = null
	steam_host_id = 0
	network_mode = NetworkMode.NONE
	is_host_session = false
	players.clear()

	if emit_update:
		player_list_changed.emit()


func set_local_ready(to_ready: bool) -> void:
	if multiplayer.multiplayer_peer == null:
		print("[NET] set_local_ready ignored. No multiplayer peer.")
		return

	print("[NET] set_local_ready to=", to_ready, " is_host_session=", is_host_session, " unique_id=", multiplayer.get_unique_id(), " is_server=", multiplayer.is_server())

	if is_host_session:
		if players.has(SERVER_PEER_ID):
			players[SERVER_PEER_ID]["ready"] = to_ready
			_broadcast_player_list()
		else:
			print("[NET] Host ready failed. Host player missing from players.")
		return

	_set_ready_state.rpc_id(SERVER_PEER_ID, to_ready)


func is_local_player_ready() -> bool:
	var local_id := SERVER_PEER_ID if is_host_session else multiplayer.get_unique_id()
	if players.has(local_id):
		return bool(players[local_id].get("ready", false))
	return false


func can_start_game() -> bool:
	if not is_host_session:
		return false
	if players.is_empty():
		return false

	for player_data in players.values():
		if not bool(player_data.get("ready", false)):
			return false
	return true


func start_game() -> void:
	if not is_host_session:
		print("[NET] start_game ignored. Not host session.")
		return
	if not can_start_game():
		print("[NET] start_game ignored. Not everyone ready.")
		return
	_load_game_scene.rpc()


func get_player_display_name(peer_id: int) -> String:
	if players.has(peer_id):
		return str(players[peer_id].get("name", "Player"))
	return "Player"


func get_player_steam_id(peer_id: int) -> int:
	if players.has(peer_id):
		return int(players[peer_id].get("steam_id", 0))
	return 0


func get_player_ids() -> Array:
	var ids: Array = players.keys()
	ids.sort()
	return ids


func is_steam_mode() -> bool:
	return network_mode == NetworkMode.STEAM


func is_lan_mode() -> bool:
	return network_mode == NetworkMode.LAN


func is_host() -> bool:
	return is_host_session


func _sanitize_player_name(value: String) -> String:
	var trimmed := value.strip_edges()
	if trimmed.is_empty():
		return "Player"
	return trimmed.substr(0, 20)


func _add_or_update_local_host_player(steam_id: int) -> void:
	players[SERVER_PEER_ID] = {
		"name": local_player_name,
		"ready": false,
		"steam_id": steam_id
	}


func _broadcast_player_list() -> void:
	if not is_host_session:
		return

	print("[NET] broadcast_player_list players=", players)
	_receive_player_list.rpc(players)


func _on_peer_connected(id: int) -> void:
	print("[NET] peer_connected id=", id, " mode=", NetworkMode.keys()[network_mode], " is_host_session=", is_host_session, " is_server=", multiplayer.is_server())


func _on_peer_disconnected(id: int) -> void:
	print("[NET] peer_disconnected id=", id, " mode=", NetworkMode.keys()[network_mode])

	if not is_host_session:
		return

	if players.has(id):
		players.erase(id)
		_broadcast_player_list()


func _on_connected_to_server() -> void:
	print("[NET] connected_to_server mode=", NetworkMode.keys()[network_mode], " unique_id=", multiplayer.get_unique_id(), " is_server=", multiplayer.is_server())

	_register_player.rpc_id(SERVER_PEER_ID, {
		"name": local_player_name,
		"ready": false,
		"steam_id": _get_local_steam_id() if network_mode == NetworkMode.STEAM else 0
	})

	connection_succeeded.emit()


func _on_connection_failed() -> void:
	last_message = "Connexion au serveur impossible."
	print("[NET] connection_failed mode=", NetworkMode.keys()[network_mode])
	leave_game()
	connection_failed.emit(last_message)


func _on_server_disconnected() -> void:
	last_message = "La session a été fermée par l'hôte."
	print("[NET] server_disconnected mode=", NetworkMode.keys()[network_mode])
	leave_game()
	connection_closed.emit(last_message)


func _is_steam_ready() -> bool:
	var manager := get_node_or_null("/root/SteamManager")
	if manager == null:
		return false
	return bool(manager.get("is_ready"))


func _get_local_steam_id() -> int:
	var manager := get_node_or_null("/root/SteamManager")
	if manager == null:
		return 0
	return int(manager.get("steam_id"))


func _get_local_steam_name() -> String:
	var manager := get_node_or_null("/root/SteamManager")
	if manager == null:
		return "Player"
	return str(manager.get("steam_name"))


@rpc("any_peer", "reliable")
func _register_player(player_data: Dictionary) -> void:
	if not is_host_session:
		print("[NET] register_player ignored. Not host session.")
		return

	var sender_id := multiplayer.get_remote_sender_id()

	players[sender_id] = {
		"name": _sanitize_player_name(str(player_data.get("name", "Player"))),
		"ready": false,
		"steam_id": int(player_data.get("steam_id", 0))
	}

	print("[NET] register_player peer_id=", sender_id, " data=", players[sender_id])
	_broadcast_player_list()


@rpc("any_peer", "reliable")
func _set_ready_state(to_ready: bool) -> void:
	if not is_host_session:
		print("[NET] _set_ready_state ignored. Not host session.")
		return

	var sender_id := multiplayer.get_remote_sender_id()
	print("[NET] _set_ready_state sender=", sender_id, " ready=", to_ready)

	if players.has(sender_id):
		players[sender_id]["ready"] = to_ready
		_broadcast_player_list()
	else:
		print("[NET] _set_ready_state ignored. Sender not registered: ", sender_id)


@rpc("authority", "call_local", "reliable")
func _load_game_scene() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


@rpc("authority", "call_local", "reliable")
func _receive_player_list(new_players: Dictionary) -> void:
	players = new_players.duplicate(true)
	print("[NET] receive_player_list unique_id=", multiplayer.get_unique_id(), " players=", players)
	player_list_changed.emit()
