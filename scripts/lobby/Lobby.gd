extends Control

const MENU_SCENE_PATH := "res://scenes/menu/MainMenu.tscn"

@onready var info_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/InfoLabel
@onready var players_list: VBoxContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PlayersPanel/PlayersList
@onready var ready_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Buttons/ReadyButton
@onready var start_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Buttons/StartButton
@onready var back_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Buttons/BackButton
@onready var invite_friend_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Buttons/InviteFriendButton
@onready var status_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatusLabel

var steam_lobby_mode := false


func _exit_tree() -> void:
	_disconnect_network_signals()
	_disconnect_steam_lobby_signals()


func _ready() -> void:
	var steam_lobby_manager := _get_steam_lobby_manager()
	steam_lobby_mode = steam_lobby_manager != null and int(steam_lobby_manager.current_lobby_id) != 0

	_connect_network_signals()
	_connect_steam_lobby_signals()

	invite_friend_button.visible = steam_lobby_mode

	if NetworkManager.multiplayer.multiplayer_peer == null:
		if steam_lobby_mode:
			_setup_steam_lobby_only_mode()
			return

		_change_scene_safely(MENU_SCENE_PATH)
		return

	_refresh_ui()


func _get_steam_lobby_manager() -> Node:
	return get_node_or_null("/root/SteamLobbyManager")


func _connect_network_signals() -> void:
	if not NetworkManager.player_list_changed.is_connected(_refresh_ui):
		NetworkManager.player_list_changed.connect(_refresh_ui)

	if not NetworkManager.connection_closed.is_connected(_on_connection_closed):
		NetworkManager.connection_closed.connect(_on_connection_closed)


func _disconnect_network_signals() -> void:
	if not is_instance_valid(NetworkManager):
		return

	if NetworkManager.player_list_changed.is_connected(_refresh_ui):
		NetworkManager.player_list_changed.disconnect(_refresh_ui)

	if NetworkManager.connection_closed.is_connected(_on_connection_closed):
		NetworkManager.connection_closed.disconnect(_on_connection_closed)


func _connect_steam_lobby_signals() -> void:
	var steam_lobby_manager := _get_steam_lobby_manager()
	if steam_lobby_manager == null:
		return

	if steam_lobby_manager.has_signal("lobby_members_changed"):
		var callable := Callable(self, "_refresh_ui")
		if not steam_lobby_manager.is_connected("lobby_members_changed", callable):
			steam_lobby_manager.connect("lobby_members_changed", callable)

	if steam_lobby_manager.has_signal("lobby_failed"):
		var failed_callable := Callable(self, "_on_steam_lobby_failed")
		if not steam_lobby_manager.is_connected("lobby_failed", failed_callable):
			steam_lobby_manager.connect("lobby_failed", failed_callable)


func _disconnect_steam_lobby_signals() -> void:
	var steam_lobby_manager := _get_steam_lobby_manager()
	if steam_lobby_manager == null:
		return

	if steam_lobby_manager.has_signal("lobby_members_changed"):
		var callable := Callable(self, "_refresh_ui")
		if steam_lobby_manager.is_connected("lobby_members_changed", callable):
			steam_lobby_manager.disconnect("lobby_members_changed", callable)

	if steam_lobby_manager.has_signal("lobby_failed"):
		var failed_callable := Callable(self, "_on_steam_lobby_failed")
		if steam_lobby_manager.is_connected("lobby_failed", failed_callable):
			steam_lobby_manager.disconnect("lobby_failed", failed_callable)


func _setup_steam_lobby_only_mode() -> void:
	ready_button.visible = false
	start_button.visible = false
	invite_friend_button.visible = true
	_refresh_ui()


func _change_scene_safely(scene_path: String) -> void:
	if not is_inside_tree():
		return

	var tree := get_tree()
	if tree == null:
		return

	tree.call_deferred("change_scene_to_file", scene_path)


func _refresh_ui() -> void:
	if not is_inside_tree():
		return

	var has_network_peer := NetworkManager.multiplayer.multiplayer_peer != null
	var is_host := NetworkManager.is_host() if NetworkManager.has_method("is_host") else NetworkManager.multiplayer.is_server()

	if steam_lobby_mode:
		info_label.text = "Lobby Steam: %s" % SteamLobbyManager.current_lobby_id
	else:
		info_label.text = "Hôte: %s, port %s" % [NetworkManager.current_ip if not is_host else "local", NetworkManager.current_port]

	_clear_players_list()

	if has_network_peer:
		_draw_network_players()
		if steam_lobby_mode:
			_draw_unregistered_steam_members()
	else:
		_draw_steam_lobby_members_only()

	ready_button.visible = has_network_peer
	ready_button.disabled = not has_network_peer
	ready_button.text = "Annuler prêt" if NetworkManager.is_local_player_ready() else "Se déclarer prêt"

	# Correction importante : seul le vrai host de session peut voir le bouton Start.
	start_button.visible = has_network_peer and is_host
	start_button.disabled = not NetworkManager.can_start_game()

	invite_friend_button.visible = steam_lobby_mode

	if not has_network_peer and steam_lobby_mode:
		status_label.text = "Lobby Steam actif, mais la connexion SteamMultiplayerPeer n'est pas encore active."
	elif is_host:
		status_label.text = "Le lancement exige que tous les joueurs soient prêts."
	else:
		status_label.text = "Attendez que l'hôte lance la partie."


func _clear_players_list() -> void:
	for child in players_list.get_children():
		child.queue_free()


func _draw_network_players() -> void:
	var local_id := NetworkManager.multiplayer.get_unique_id()

	for peer_id in NetworkManager.get_player_ids():
		var player_data: Dictionary = NetworkManager.players[peer_id]
		var line := Label.new()

		var steam_id := int(player_data.get("steam_id", 0))
		var to_name := str(player_data.get("name", "Player"))
		if steam_lobby_mode and steam_id != 0:
			var steam_name := SteamLobbyManager.get_member_name(steam_id)
			if not str(steam_name).is_empty():
				to_name = steam_name

		var role := _get_role_text(peer_id, steam_id)
		var ready_text := "Prêt" if bool(player_data.get("ready", false)) else "En attente"
		var local_text := " (vous)" if peer_id == local_id else ""

		line.text = "%s%s, %s, %s" % [to_name, local_text, role, ready_text]
		players_list.add_child(line)


func _draw_unregistered_steam_members() -> void:
	if not steam_lobby_mode:
		return

	var registered_steam_ids := {}
	for player_data in NetworkManager.players.values():
		var steam_id := int(player_data.get("steam_id", 0))
		if steam_id != 0:
			registered_steam_ids[steam_id] = true

	for steam_id in SteamLobbyManager.lobby_members:
		var member_id := int(steam_id)
		if registered_steam_ids.has(member_id):
			continue

		var line := Label.new()
		var member_name := str(SteamLobbyManager.get_member_name(member_id))
		var role := "Hôte" if member_id == int(SteamLobbyManager.lobby_owner_id) else "Client"
		var local_text := " (vous)" if member_id == int(SteamManager.steam_id) else ""
		line.text = "%s%s, %s, Steam lobby uniquement" % [member_name, local_text, role]
		players_list.add_child(line)


func _draw_steam_lobby_members_only() -> void:
	if not steam_lobby_mode:
		return

	for steam_id in SteamLobbyManager.lobby_members:
		var member_id := int(steam_id)
		var line := Label.new()
		var member_name := str(SteamLobbyManager.get_member_name(member_id))
		var role := "Hôte" if member_id == int(SteamLobbyManager.lobby_owner_id) else "Client"
		var local_text := " (vous)" if member_id == int(SteamManager.steam_id) else ""
		line.text = "%s%s, %s" % [member_name, local_text, role]
		players_list.add_child(line)


func _get_role_text(peer_id: int, steam_id: int) -> String:
	if peer_id == 1:
		return "Hôte"

	if steam_lobby_mode and steam_id != 0 and steam_id == int(SteamLobbyManager.lobby_owner_id):
		return "Hôte"

	return "Client"


func _on_invite_friend_pressed() -> void:
	if not steam_lobby_mode:
		status_label.text = "Aucun lobby Steam actif."
		return

	print("[LOBBY_STEAM] Invite friend pressed. Lobby ID: ", SteamLobbyManager.current_lobby_id)
	SteamLobbyManager.invite_friends()


func _on_ready_button_pressed() -> void:
	if not is_inside_tree():
		return

	if NetworkManager.multiplayer.multiplayer_peer == null:
		status_label.text = "Connexion réseau inactive."
		return

	NetworkManager.set_local_ready(not NetworkManager.is_local_player_ready())


func _on_start_button_pressed() -> void:
	if not is_inside_tree():
		return

	var is_host := NetworkManager.is_host() if NetworkManager.has_method("is_host") else NetworkManager.multiplayer.is_server()
	if not is_host:
		status_label.text = "Seul l'hôte peut lancer la partie."
		start_button.visible = false
		return

	if not NetworkManager.can_start_game():
		status_label.text = "Tous les joueurs doivent être prêts."
		return

	NetworkManager.start_game()


func _on_back_button_pressed() -> void:
	if not is_inside_tree():
		return

	if steam_lobby_mode:
		SteamLobbyManager.leave_lobby()

	NetworkManager.leave_game()
	_change_scene_safely(MENU_SCENE_PATH)


func _on_steam_lobby_failed(message: String) -> void:
	if not is_inside_tree():
		return

	status_label.text = message
	print("[LOBBY_STEAM] Failed: ", message)


func _on_connection_closed(_message: String = "Connexion fermée.") -> void:
	if not is_inside_tree():
		return

	_change_scene_safely(MENU_SCENE_PATH)
