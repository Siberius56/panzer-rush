extends Control

const MENU_SCENE_PATH := "res://scenes/menu/MainMenu.tscn"

@onready var info_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/InfoLabel
@onready var players_list: VBoxContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PlayersPanel/PlayersList
@onready var ready_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Buttons/ReadyButton
@onready var start_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Buttons/StartButton
@onready var status_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatusLabel


func _exit_tree() -> void:
	_disconnect_network_signals()


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


func _change_scene_safely(scene_path: String) -> void:
	if not is_inside_tree():
		return

	var tree := get_tree()
	if tree == null:
		return

	tree.call_deferred("change_scene_to_file", scene_path)


func _ready() -> void:
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


func _on_ready_button_pressed() -> void:
	if not is_inside_tree():
		return

	NetworkManager.set_local_ready(not NetworkManager.is_local_player_ready())


func _on_start_button_pressed() -> void:
	if not is_inside_tree():
		return

	if not NetworkManager.can_start_game():
		status_label.text = "Tous les joueurs doivent être prêts."
		return

	NetworkManager.start_game()


func _on_back_button_pressed() -> void:
	if not is_inside_tree():
		return

	NetworkManager.leave_game()
	_change_scene_safely(MENU_SCENE_PATH)


func _on_connection_closed(_message: String = "Connexion fermée.") -> void:
	if not is_inside_tree():
		return

	_change_scene_safely(MENU_SCENE_PATH)
