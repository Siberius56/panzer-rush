extends Control

const MENU_SCENE_PATH := "res://scenes/menu/MainMenu.tscn"

@onready var info_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/InfoLabel
@onready var players_list: VBoxContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PlayersPanel/PlayersList
@onready var ready_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Buttons/ReadyButton
@onready var start_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Buttons/StartButton
@onready var status_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatusLabel

var steam_lobby_mode := false
var invite_friend_button: Button = null


func _exit_tree() -> void:
	_disconnect_network_signals()
	_disconnect_steam_lobby_signals()


func _get_steam_lobby_manager() -> Node:
	return get_node_or_null("/root/SteamLobbyManager")


func _disconnect_network_signals() -> void:
	if not is_instance_valid(NetworkManager):
		return

	if NetworkManager.has_signal("player_list_changed"):
		var refresh_callable := Callable(self, "_refresh_ui")
		if NetworkManager.is_connected("player_list_changed", refresh_callable):
			NetworkManager.disconnect("player_list_changed", refresh_callable)

	if NetworkManager.has_signal("connection_closed"):
		var closed_callable := Callable(self, "_on_connection_closed")
		if NetworkManager.is_connected("connection_closed", closed_callable):
			NetworkManager.disconnect("connection_closed", closed_callable)


func _disconnect_steam_lobby_signals() -> void:
	var steam_lobby_manager := _get_steam_lobby_manager()
	if steam_lobby_manager == null:
		return

	if steam_lobby_manager.has_signal("lobby_members_changed"):
		var members_callable := Callable(self, "_refresh_steam_lobby_ui")
		if steam_lobby_manager.is_connected("lobby_members_changed", members_callable):
			steam_lobby_manager.disconnect("lobby_members_changed", members_callable)

	if steam_lobby_manager.has_signal("lobby_failed"):
		var failed_callable := Callable(self, "_on_steam_lobby_failed")
		if steam_lobby_manager.is_connected("lobby_failed", failed_callable):
			steam_lobby_manager.disconnect("lobby_failed", failed_callable)


func _change_scene_safely(scene_path: String) -> void:
	if not is_inside_tree():
		return

	var tree := get_tree()
	if tree == null:
		return

	tree.call_deferred("change_scene_to_file", scene_path)


func _ready() -> void:
	var steam_lobby_manager := _get_steam_lobby_manager()
	steam_lobby_mode = steam_lobby_manager != null and int(steam_lobby_manager.current_lobby_id) != 0

	if steam_lobby_mode:
		_setup_steam_lobby_mode()
		return

	_setup_lan_lobby_mode()


func _setup_lan_lobby_mode() -> void:
	var peer: MultiplayerPeer = NetworkManager.multiplayer.multiplayer_peer

	if peer == null:
		_change_scene_safely(MENU_SCENE_PATH)
		return

	# Si on est client et que le peer n'est pas réellement connecté, on revient au menu.
	# Cela évite d'afficher un faux lobby après un join raté.
	if not NetworkManager.multiplayer.is_server():
		if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			_change_scene_safely(MENU_SCENE_PATH)
			return

	if NetworkManager.has_signal("player_list_changed"):
		var refresh_callable := Callable(self, "_refresh_ui")
		if not NetworkManager.is_connected("player_list_changed", refresh_callable):
			NetworkManager.connect("player_list_changed", refresh_callable)

	if NetworkManager.has_signal("connection_closed"):
		var closed_callable := Callable(self, "_on_connection_closed")
		if not NetworkManager.is_connected("connection_closed", closed_callable):
			NetworkManager.connect("connection_closed", closed_callable)

	_refresh_ui()


func _setup_steam_lobby_mode() -> void:
	var steam_lobby_manager := _get_steam_lobby_manager()
	if steam_lobby_manager == null:
		_change_scene_safely(MENU_SCENE_PATH)
		return

	print("[LOBBY_STEAM] Steam lobby mode. Lobby ID: ", steam_lobby_manager.current_lobby_id)

	if steam_lobby_manager.has_signal("lobby_members_changed"):
		var members_callable := Callable(self, "_refresh_steam_lobby_ui")
		if not steam_lobby_manager.is_connected("lobby_members_changed", members_callable):
			steam_lobby_manager.connect("lobby_members_changed", members_callable)

	if steam_lobby_manager.has_signal("lobby_failed"):
		var failed_callable := Callable(self, "_on_steam_lobby_failed")
		if not steam_lobby_manager.is_connected("lobby_failed", failed_callable):
			steam_lobby_manager.connect("lobby_failed", failed_callable)

	_setup_invite_friend_button()

	# Tant que SteamMultiplayerPeer n'est pas branché, ces boutons ne doivent pas appeler NetworkManager.
	ready_button.visible = false
	start_button.visible = false

	if steam_lobby_manager.has_method("refresh_members"):
		steam_lobby_manager.refresh_members()
	else:
		_refresh_steam_lobby_ui()


func _setup_invite_friend_button() -> void:
	if invite_friend_button != null and is_instance_valid(invite_friend_button):
		return

	invite_friend_button = Button.new()
	invite_friend_button.name = "InviteFriendButton"
	invite_friend_button.text = "Inviter un ami Steam"

	var buttons_parent := ready_button.get_parent()
	buttons_parent.add_child(invite_friend_button)

	if not invite_friend_button.pressed.is_connected(_on_invite_friend_pressed):
		invite_friend_button.pressed.connect(_on_invite_friend_pressed)


func _refresh_ui() -> void:
	if not is_inside_tree():
		return

	var is_host := NetworkManager.multiplayer.is_server()
	info_label.text = "Hôte: %s, port %s" % [NetworkManager.current_ip if not is_host else "local", NetworkManager.current_port]

	for child in players_list.get_children():
		child.queue_free()

	var local_id := NetworkManager.multiplayer.get_unique_id()

	for peer_id in NetworkManager.get_player_ids():
		var player_data: Dictionary = NetworkManager.players[peer_id]
		var line := Label.new()
		var role := "Hôte" if peer_id == 1 else "Client"
		var ready_text := "Prêt" if bool(player_data.get("ready", false)) else "En attente"
		var local_text := " (vous)" if peer_id == local_id else ""
		line.text = "%s%s, %s, %s" % [str(player_data.get("name", "Player")), local_text, role, ready_text]
		players_list.add_child(line)

	ready_button.text = "Annuler prêt" if NetworkManager.is_local_player_ready() else "Se déclarer prêt"
	start_button.visible = is_host
	start_button.disabled = not NetworkManager.can_start_game()

	if is_host:
		status_label.text = "Le lancement exige que tous les joueurs soient prêts."
	else:
		status_label.text = "Attendez que l'hôte lance la partie."


func _refresh_steam_lobby_ui() -> void:
	if not is_inside_tree():
		return

	var steam_lobby_manager := _get_steam_lobby_manager()
	if steam_lobby_manager == null or int(steam_lobby_manager.current_lobby_id) == 0:
		_change_scene_safely(MENU_SCENE_PATH)
		return

	info_label.text = "Lobby Steam: %s" % steam_lobby_manager.current_lobby_id

	for child in players_list.get_children():
		child.queue_free()

	for steam_id in steam_lobby_manager.lobby_members:
		var line := Label.new()
		var member_name := str(steam_lobby_manager.get_member_name(steam_id))
		var role := "Hôte" if int(steam_id) == int(steam_lobby_manager.lobby_owner_id) else "Client"
		var local_text := " (vous)" if int(steam_id) == int(SteamManager.steam_id) else ""

		line.text = "%s%s, %s" % [member_name, local_text, role]
		players_list.add_child(line)

	status_label.text = "Lobby Steam actif. Invite un ami, puis on branchera la connexion SteamMultiplayerPeer."


func _on_invite_friend_pressed() -> void:
	var steam_lobby_manager := _get_steam_lobby_manager()
	if steam_lobby_manager == null or int(steam_lobby_manager.current_lobby_id) == 0:
		status_label.text = "Aucun lobby Steam actif."
		return

	print("[LOBBY_STEAM] Invite friend pressed. Lobby ID: ", steam_lobby_manager.current_lobby_id)

	if steam_lobby_manager.has_method("invite_friends"):
		steam_lobby_manager.invite_friends()
	else:
		status_label.text = "SteamLobbyManager.invite_friends() est introuvable."


func _on_steam_lobby_failed(message: String) -> void:
	if not is_inside_tree():
		return

	status_label.text = message
	print("[LOBBY_STEAM] Failed: ", message)


func _on_ready_button_pressed() -> void:
	if not is_inside_tree():
		return

	if steam_lobby_mode:
		status_label.text = "Le ready Steam sera branché après SteamMultiplayerPeer."
		return

	NetworkManager.set_local_ready(not NetworkManager.is_local_player_ready())


func _on_start_button_pressed() -> void:
	if not is_inside_tree():
		return

	if steam_lobby_mode:
		status_label.text = "Le lancement Steam sera branché après SteamMultiplayerPeer."
		return

	if not NetworkManager.can_start_game():
		status_label.text = "Tous les joueurs doivent être prêts."
		return

	NetworkManager.start_game()


func _on_back_button_pressed() -> void:
	if not is_inside_tree():
		return

	if steam_lobby_mode:
		var steam_lobby_manager := _get_steam_lobby_manager()
		if steam_lobby_manager != null and steam_lobby_manager.has_method("leave_lobby"):
			steam_lobby_manager.leave_lobby()
	else:
		NetworkManager.leave_game()

	_change_scene_safely(MENU_SCENE_PATH)


func _on_connection_closed(_message: String = "Connexion fermée.") -> void:
	if not is_inside_tree():
		return

	_change_scene_safely(MENU_SCENE_PATH)
