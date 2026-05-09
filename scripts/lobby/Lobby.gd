extends Control

const MENU_SCENE_PATH: String = "res://scenes/menu/MainMenu.tscn"
const SELECT_MISSION_ANIMATION: String = "select_mission"
const COUNTDOWN_SECONDS: int = 3

const MISSIONS: Array[Dictionary] = [
	{
		"id": "first_mission",
		"name": "Defend the Coast",
		"description": "Mission prototype. Les joueurs entrent dans le hangar et doivent survivre aux premières vagues ennemies.",
		"difficulty": 1,
		"scene_path": "res://scenes/game/NetworkMain.tscn",
		"position": Vector2(780.0, 270.0)
	},
	{
		"id": "second_mission",
		"name": "Force Landing",
		"description": "Mission prototype 2. Les joueurs entrent dans le hangar et doivent survivre aux premières vagues ennemies.",
		"difficulty": 3,
		"scene_path": "res://scenes/game/NetworkMain.tscn",
		"position": Vector2(650.0, 400.0)
	}
]

@export_category("Mission Pins")
var mission_pin_button_scene: PackedScene = preload("uid://vwyc3iay7o37")

@export_category("Mission Map")
@export var map_default_zoom: float = 1.0
@export var map_min_zoom: float = 0.65
@export var map_max_zoom: float = 1.75
@export var map_zoom_step: float = 0.12
@export var map_max_pan_offset: Vector2 = Vector2(700.0, 420.0)
@export var map_pan_mouse_button: int = MOUSE_BUTTON_LEFT

@onready var lobby_layer = %LobbyLayer
@onready var info_label: Label = %InfoLabel
@onready var lobby_id_row: HBoxContainer = %LobbyIdRow
@onready var lobby_id_line_edit: LineEdit = %LobbyIdLineEdit
@onready var copy_lobby_id_button: Button = %CopyLobbyIdButton
@onready var players_list: VBoxContainer = %PlayersList
@onready var ready_button: Button = %ReadyButton
@onready var start_button: Button = %StartButton
@onready var invite_friend_button: Button = %InviteFriendButton
@onready var back_button: Button = %BackButton
@onready var status_label: Label = %StatusLabel

@onready var background_animation_player: AnimationPlayer = %AnimationPlayer_Hangar

@onready var mission_layer: Control = %MissionLayer
@onready var mission_mask: Control = %MissionMask
@onready var map_control: Control = %MapControl
@onready var mission_map_area: Control = %MissionMapArea
@onready var mission_name_label: Label = %MissionNameLabel
@onready var mission_description_label: Label = %MissionDescriptionLabel
@onready var mission_difficulty_label: Label = %MissionDifficultyLabel
@onready var mission_selected_status_label: Label = %MissionSelectedStatusLabel
@onready var mission_launch_button: Button = %LaunchMissionButton
@onready var mission_back_button: Button = %BackToLobbyButton

@onready var countdown_layer: Control = %CountdownLayer
@onready var countdown_label: Label = %CountdownLabel

var steam_lobby_mode: bool = false
var mission_selection_open: bool = false
var countdown_in_progress: bool = false
var selected_mission_index: int = -1
var mission_buttons: Array[TextureButton] = []

var map_center_position: Vector2 = Vector2.ZERO
var map_pan_offset: Vector2 = Vector2.ZERO
var map_current_zoom: float = 1.0
var map_is_dragging: bool = false
var map_last_mouse_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	var steam_lobby_manager: Node = _get_steam_lobby_manager()
	steam_lobby_mode = steam_lobby_manager != null and int(steam_lobby_manager.get("current_lobby_id")) != 0

	_connect_network_signals()
	_connect_steam_lobby_signals()
	_connect_ui_signals()
	_setup_mission_map()
	_build_mission_buttons()
	_set_selected_mission(-1)

	lobby_id_row.visible = false
	mission_layer.visible = false
	countdown_layer.visible = false
	start_button.text = "Choisir une mission"
	invite_friend_button.visible = steam_lobby_mode

	if NetworkManager.multiplayer.multiplayer_peer == null:
		if steam_lobby_mode:
			_setup_steam_lobby_only_mode()
			return

		_change_scene_safely(MENU_SCENE_PATH)
		return

	_refresh_ui()


func _exit_tree() -> void:
	_disconnect_network_signals()
	_disconnect_steam_lobby_signals()


func _input(event: InputEvent) -> void:
	if not mission_selection_open:
		return

	if countdown_in_progress:
		return

	if event is InputEventMouseButton:
		_handle_map_mouse_button(event as InputEventMouseButton)
		return

	if event is InputEventMouseMotion:
		_handle_map_mouse_motion(event as InputEventMouseMotion)
		return


func _connect_ui_signals() -> void:
	if not ready_button.pressed.is_connected(_on_ready_button_pressed):
		ready_button.pressed.connect(_on_ready_button_pressed)

	if not start_button.pressed.is_connected(_on_start_button_pressed):
		start_button.pressed.connect(_on_start_button_pressed)

	if not invite_friend_button.pressed.is_connected(_on_invite_friend_pressed):
		invite_friend_button.pressed.connect(_on_invite_friend_pressed)

	if not back_button.pressed.is_connected(_on_back_button_pressed):
		back_button.pressed.connect(_on_back_button_pressed)

	if not copy_lobby_id_button.pressed.is_connected(_on_copy_lobby_id_button_pressed):
		copy_lobby_id_button.pressed.connect(_on_copy_lobby_id_button_pressed)

	if not mission_launch_button.pressed.is_connected(_on_mission_launch_button_pressed):
		mission_launch_button.pressed.connect(_on_mission_launch_button_pressed)

	if not mission_back_button.pressed.is_connected(_on_mission_back_button_pressed):
		mission_back_button.pressed.connect(_on_mission_back_button_pressed)


func _setup_mission_map() -> void:
	map_current_zoom = clampf(map_default_zoom, map_min_zoom, map_max_zoom)
	map_pan_offset = Vector2.ZERO
	map_control.pivot_offset = Vector2.ZERO

	if not mission_mask.resized.is_connected(_on_mission_mask_resized):
		mission_mask.resized.connect(_on_mission_mask_resized)

	call_deferred("_reset_map_view")


func _reset_map_view() -> void:
	if not is_inside_tree():
		return
	
	
	map_center_position = mission_mask.size * 0.5
	map_current_zoom = clampf(map_default_zoom, map_min_zoom, map_max_zoom)
	map_pan_offset = Vector2.ZERO
	_apply_map_transform()


func _on_mission_mask_resized() -> void:
	map_center_position = mission_mask.size * 0.5
	_apply_map_transform()


func _handle_map_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		if _is_mouse_inside_mission_mask():
			_zoom_map(map_zoom_step)
			get_viewport().set_input_as_handled()
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		if _is_mouse_inside_mission_mask():
			_zoom_map(-map_zoom_step)
			get_viewport().set_input_as_handled()
		return

	if event.button_index != map_pan_mouse_button:
		return

	if event.pressed:
		if not _is_mouse_inside_mission_mask():
			return

		if _is_mouse_over_mission_button():
			return

		map_is_dragging = true
		map_last_mouse_position = get_global_mouse_position()
		get_viewport().set_input_as_handled()
		return

	map_is_dragging = false


func _handle_map_mouse_motion(_event: InputEventMouseMotion) -> void:
	if not map_is_dragging:
		return

	var current_mouse_position: Vector2 = get_global_mouse_position()
	var drag_delta: Vector2 = current_mouse_position - map_last_mouse_position
	map_last_mouse_position = current_mouse_position

	map_pan_offset += drag_delta
	_apply_map_transform()
	get_viewport().set_input_as_handled()


func _zoom_map(zoom_delta: float) -> void:
	var previous_zoom: float = map_current_zoom
	var next_zoom: float = clampf(map_current_zoom + zoom_delta, map_min_zoom, map_max_zoom)

	if is_equal_approx(previous_zoom, next_zoom):
		return

	var mouse_position_in_mask: Vector2 = mission_mask.get_local_mouse_position()
	var map_origin_before_zoom: Vector2 = map_center_position + map_pan_offset
	var map_point_under_mouse: Vector2 = (mouse_position_in_mask - map_origin_before_zoom) / previous_zoom

	map_current_zoom = next_zoom
	map_pan_offset = mouse_position_in_mask - map_center_position - map_point_under_mouse * map_current_zoom
	_apply_map_transform()


func _apply_map_transform() -> void:
	map_pan_offset.x = clampf(map_pan_offset.x, -map_max_pan_offset.x, map_max_pan_offset.x)
	map_pan_offset.y = clampf(map_pan_offset.y, -map_max_pan_offset.y, map_max_pan_offset.y)

	map_control.position = map_center_position + map_pan_offset - (map_control.size * .5)
	map_control.scale = Vector2(map_current_zoom, map_current_zoom)


func _is_mouse_inside_mission_mask() -> bool:
	return mission_mask.get_global_rect().has_point(get_global_mouse_position())


func _is_mouse_over_mission_button() -> bool:
	for mission_button: TextureButton in mission_buttons:
		if mission_button.visible and mission_button.get_global_rect().has_point(get_global_mouse_position()):
			return true

	return false


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
	var steam_lobby_manager: Node = _get_steam_lobby_manager()
	if steam_lobby_manager == null:
		return

	if steam_lobby_manager.has_signal("lobby_members_changed"):
		var callable: Callable = Callable(self, "_refresh_ui")
		if not steam_lobby_manager.is_connected("lobby_members_changed", callable):
			steam_lobby_manager.connect("lobby_members_changed", callable)

	if steam_lobby_manager.has_signal("lobby_failed"):
		var failed_callable: Callable = Callable(self, "_on_steam_lobby_failed")
		if not steam_lobby_manager.is_connected("lobby_failed", failed_callable):
			steam_lobby_manager.connect("lobby_failed", failed_callable)


func _disconnect_steam_lobby_signals() -> void:
	var steam_lobby_manager: Node = _get_steam_lobby_manager()
	if steam_lobby_manager == null:
		return

	if steam_lobby_manager.has_signal("lobby_members_changed"):
		var callable: Callable = Callable(self, "_refresh_ui")
		if steam_lobby_manager.is_connected("lobby_members_changed", callable):
			steam_lobby_manager.disconnect("lobby_members_changed", callable)

	if steam_lobby_manager.has_signal("lobby_failed"):
		var failed_callable: Callable = Callable(self, "_on_steam_lobby_failed")
		if steam_lobby_manager.is_connected("lobby_failed", failed_callable):
			steam_lobby_manager.disconnect("lobby_failed", failed_callable)


func _setup_steam_lobby_only_mode() -> void:
	mission_selection_open = false
	ready_button.visible = false
	start_button.visible = false
	invite_friend_button.visible = true
	_refresh_ui()


func _change_scene_safely(scene_path: String) -> void:
	if not is_inside_tree():
		return

	var tree: SceneTree = get_tree()
	if tree == null:
		return

	tree.call_deferred("change_scene_to_file", scene_path)


func _refresh_ui() -> void:
	if not is_inside_tree():
		return

	var has_network_peer: bool = NetworkManager.multiplayer.multiplayer_peer != null
	var is_host: bool = _is_local_host()

	lobby_layer.visible = not mission_selection_open
	mission_layer.visible = mission_selection_open

	_update_lobby_id_display(is_host)
	_clear_players_list()

	if has_network_peer:
		_draw_network_players()
		if steam_lobby_mode:
			_draw_unregistered_steam_members()
	else:
		_draw_steam_lobby_members_only()

	ready_button.visible = has_network_peer and not mission_selection_open
	ready_button.disabled = not has_network_peer or countdown_in_progress
	if has_network_peer:
		ready_button.text = "Annuler prêt" if NetworkManager.is_local_player_ready() else "Se déclarer prêt"
	else:
		ready_button.text = "Se déclarer prêt"

	start_button.visible = has_network_peer and is_host and not mission_selection_open
	start_button.disabled = not has_network_peer or not NetworkManager.can_start_game() or countdown_in_progress
	start_button.text = "Choisir une mission"

	invite_friend_button.visible = steam_lobby_mode and not mission_selection_open
	back_button.visible = not mission_selection_open

	_update_mission_controls()
	_update_status_label(has_network_peer, is_host)


func _update_lobby_id_display(is_host: bool) -> void:
	if steam_lobby_mode:
		info_label.text = "Lobby Steam"
		lobby_id_row.visible = not mission_selection_open
		lobby_id_line_edit.text = str(SteamLobbyManager.current_lobby_id)
		return

	lobby_id_row.visible = false
	var host_text: String = "local" if is_host else str(NetworkManager.current_ip)
	info_label.text = "Hôte: %s, port %s" % [host_text, NetworkManager.current_port]


func _update_status_label(has_network_peer: bool, is_host: bool) -> void:
	if countdown_in_progress:
		status_label.text = "Lancement en cours."
		return

	if mission_selection_open:
		if is_host:
			status_label.text = "Choisissez une mission, puis lancez la partie."
		else:
			status_label.text = "L'hôte choisit la mission."
		return

	if not has_network_peer and steam_lobby_mode:
		status_label.text = "Lobby Steam actif, mais la connexion SteamMultiplayerPeer n'est pas encore active."
	elif is_host:
		status_label.text = "Le lancement exige que tous les joueurs soient prêts."
	else:
		status_label.text = "Attendez que l'hôte choisisse une mission."


func _clear_players_list() -> void:
	for child: Node in players_list.get_children():
		child.queue_free()


func _draw_network_players() -> void:
	var local_id: int = NetworkManager.multiplayer.get_unique_id()

	for peer_id: int in NetworkManager.get_player_ids():
		var player_data: Dictionary = NetworkManager.players[peer_id]
		var line: Label = Label.new()

		var steam_id: int = int(player_data.get("steam_id", 0))
		var player_name: String = str(player_data.get("name", "Player"))
		if steam_lobby_mode and steam_id != 0:
			var steam_name: String = str(SteamLobbyManager.get_member_name(steam_id))
			if not steam_name.is_empty():
				player_name = steam_name

		var role: String = _get_role_text(peer_id, steam_id)
		var ready_text: String = "Prêt" if bool(player_data.get("ready", false)) else "En attente"
		var local_text: String = " (vous)" if peer_id == local_id else ""

		line.text = "%s%s, %s, %s" % [player_name, local_text, role, ready_text]
		players_list.add_child(line)


func _draw_unregistered_steam_members() -> void:
	if not steam_lobby_mode:
		return

	var registered_steam_ids: Dictionary = {}
	for player_data: Dictionary in NetworkManager.players.values():
		var steam_id: int = int(player_data.get("steam_id", 0))
		if steam_id != 0:
			registered_steam_ids[steam_id] = true

	for steam_id_variant: Variant in SteamLobbyManager.lobby_members:
		var member_id: int = int(steam_id_variant)
		if registered_steam_ids.has(member_id):
			continue

		var line: Label = Label.new()
		var member_name: String = str(SteamLobbyManager.get_member_name(member_id))
		var role: String = "Hôte" if member_id == int(SteamLobbyManager.lobby_owner_id) else "Client"
		var local_text: String = " (vous)" if member_id == int(SteamManager.steam_id) else ""
		line.text = "%s%s, %s, Steam lobby uniquement" % [member_name, local_text, role]
		players_list.add_child(line)


func _draw_steam_lobby_members_only() -> void:
	if not steam_lobby_mode:
		return

	for steam_id_variant: Variant in SteamLobbyManager.lobby_members:
		var member_id: int = int(steam_id_variant)
		var line: Label = Label.new()
		var member_name: String = str(SteamLobbyManager.get_member_name(member_id))
		var role: String = "Hôte" if member_id == int(SteamLobbyManager.lobby_owner_id) else "Client"
		var local_text: String = " (vous)" if member_id == int(SteamManager.steam_id) else ""
		line.text = "%s%s, %s" % [member_name, local_text, role]
		players_list.add_child(line)


func _get_role_text(peer_id: int, steam_id: int) -> String:
	if peer_id == 1:
		return "Hôte"

	if steam_lobby_mode and steam_id != 0 and steam_id == int(SteamLobbyManager.lobby_owner_id):
		return "Hôte"

	return "Client"


func _build_mission_buttons() -> void:
	for child: Node in mission_map_area.get_children():
		child.queue_free()

	mission_buttons.clear()

	if mission_pin_button_scene == null:
		push_error("mission_pin_button_scene n'est pas assignée.")
		return

	for mission_index: int in range(MISSIONS.size()):
		var mission: Dictionary = MISSIONS[mission_index]
		var mission_button_node: Node = mission_pin_button_scene.instantiate()
		var mission_button: TextureButton = mission_button_node as TextureButton

		if mission_button == null:
			push_error("MissionPinButton.tscn doit avoir un Button comme node racine.")
			mission_button_node.queue_free()
			continue

		mission_map_area.add_child(mission_button)
		mission_buttons.append(mission_button)

		mission_button.name = "MissionPin_%s" % str(mission.get("id", mission_index))
		mission_button.position = _get_mission_position(mission)
		print("mission_button.position: ", mission_button.position, " from : ", _get_mission_position(mission))
		mission_button.toggle_mode = true
		mission_button.focus_mode = Control.FOCUS_ALL
		mission_button.set_meta("mission_index", mission_index)

		if mission_button.has_method("setup"):
			mission_button.call("setup", mission_index, mission)
		else:
			mission_button.text = _get_mission_button_text(mission_index)

		if mission_button.has_signal("mission_pressed"):
			var mission_signal_callback: Callable = Callable(self, "_on_mission_button_pressed")
			if not mission_button.is_connected("mission_pressed", mission_signal_callback):
				mission_button.connect("mission_pressed", mission_signal_callback)
		else:
			var pressed_callback: Callable = Callable(self, "_on_mission_button_pressed").bind(mission_index)
			if not mission_button.pressed.is_connected(pressed_callback):
				mission_button.pressed.connect(pressed_callback)

	_refresh_mission_button_states()


func _get_mission_position(mission: Dictionary) -> Vector2:
	var position_value: Variant = mission.get("position", Vector2.ZERO)

	if position_value is Vector2:
		return position_value

	if position_value is Vector2i:
		var vector_2i: Vector2i = position_value
		return Vector2(float(vector_2i.x), float(vector_2i.y))

	if position_value is Dictionary:
		var position_dictionary: Dictionary = position_value
		return Vector2(float(position_dictionary.get("x", 0.0)), float(position_dictionary.get("y", 0.0)))

	return Vector2.ZERO


func _get_mission_button_text(mission_index: int) -> String:
	var mission: Dictionary = MISSIONS[mission_index]
	return "%s\n%s" % [str(mission.get("name", "Mission")), str(mission.get("difficulty", "Non définie"))]


func _on_mission_button_pressed(mission_index: int) -> void:
	if countdown_in_progress:
		_refresh_mission_button_states()
		return

	if not _is_local_host():
		_refresh_mission_button_states()
		return

	if mission_index < 0 or mission_index >= MISSIONS.size():
		return

	_rpc_set_selected_mission.rpc(mission_index)


@rpc("authority", "call_local", "reliable")
func _rpc_set_selected_mission(mission_index: int) -> void:
	_set_selected_mission(mission_index)
	_refresh_ui()


func _set_selected_mission(mission_index: int) -> void:
	if mission_index < 0 or mission_index >= MISSIONS.size():
		selected_mission_index = -1
		mission_name_label.text = "Aucune mission sélectionnée"
		mission_description_label.text = "Sélectionnez une mission sur la carte. Les autres joueurs verront le même choix."
		mission_difficulty_label.text = ""
		mission_selected_status_label.text = "Sélectionnez une mission pour déverrouiller le lancement."
		_refresh_mission_button_states()
		return

	selected_mission_index = mission_index
	var mission: Dictionary = MISSIONS[mission_index]
	mission_name_label.text = str(mission.get("name", "Mission"))
	mission_description_label.text = str(mission.get("description", ""))
	mission_difficulty_label.text = "Difficulté : %s" % str(mission.get("difficulty", "Non définie"))
	mission_selected_status_label.text = "Mission sélectionnée par l'hôte."
	_refresh_mission_button_states()


func _refresh_mission_button_states() -> void:
	for mission_index: int in range(mission_buttons.size()):
		var mission_button: TextureButton = mission_buttons[mission_index]
		var selected: bool = mission_index == selected_mission_index

		if mission_button.has_method("set_selected_visual"):
			mission_button.call("set_selected_visual", selected)
		else:
			mission_button.set_pressed_no_signal(selected)


func _update_mission_controls() -> void:
	var is_host: bool = _is_local_host()
	var has_network_peer: bool = NetworkManager.multiplayer.multiplayer_peer != null
	var network_can_start: bool = has_network_peer and NetworkManager.can_start_game()
	var has_selection: bool = selected_mission_index >= 0 and selected_mission_index < MISSIONS.size()
	var can_launch: bool = is_host and has_selection and network_can_start and not countdown_in_progress

	for mission_button: TextureButton in mission_buttons:
		if mission_button.has_method("set_interactable"):
			mission_button.call("set_interactable", is_host and not countdown_in_progress)
		else:
			mission_button.disabled = not is_host or countdown_in_progress

	mission_launch_button.visible = is_host
	mission_launch_button.disabled = not can_launch
	mission_back_button.visible = is_host
	mission_back_button.disabled = countdown_in_progress

	if countdown_in_progress:
		return

	if not mission_selection_open:
		return

	if not is_host and selected_mission_index < 0:
		mission_selected_status_label.text = "En attente du choix de l'hôte."
	elif is_host and selected_mission_index < 0:
		mission_selected_status_label.text = "Sélectionnez une mission pour déverrouiller le lancement."
	elif not network_can_start:
		mission_selected_status_label.text = "Tous les joueurs doivent être prêts."
	elif is_host:
		mission_selected_status_label.text = "Mission sélectionnée. Vous pouvez lancer la partie."
	else:
		mission_selected_status_label.text = "Mission sélectionnée par l'hôte."


func _on_copy_lobby_id_button_pressed() -> void:
	if not steam_lobby_mode:
		return

	var lobby_id: String = str(SteamLobbyManager.current_lobby_id)
	DisplayServer.clipboard_set(lobby_id)
	status_label.text = "ID du lobby copié."
	lobby_id_line_edit.grab_focus()
	lobby_id_line_edit.select_all()


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

	if NetworkManager.multiplayer.multiplayer_peer == null:
		status_label.text = "Connexion réseau inactive."
		return

	if not _is_local_host():
		status_label.text = "Seul l'hôte peut choisir une mission."
		start_button.visible = false
		return

	if not NetworkManager.can_start_game():
		status_label.text = "Tous les joueurs doivent être prêts."
		return

	_rpc_open_mission_selection.rpc()


@rpc("authority", "call_local", "reliable")
func _rpc_open_mission_selection() -> void:
	mission_selection_open = true
	countdown_in_progress = false
	countdown_layer.visible = false
	_set_selected_mission(-1)
	_reset_map_view()
	_play_background_animation(SELECT_MISSION_ANIMATION)
	_refresh_ui()


func _on_mission_back_button_pressed() -> void:
	if not _is_local_host():
		return

	if countdown_in_progress:
		return

	_rpc_close_mission_selection.rpc()


@rpc("authority", "call_local", "reliable")
func _rpc_close_mission_selection() -> void:
	mission_selection_open = false
	countdown_in_progress = false
	map_is_dragging = false
	countdown_layer.visible = false
	_refresh_ui()


func _on_mission_launch_button_pressed() -> void:
	if not _is_local_host():
		return

	if countdown_in_progress:
		return

	if NetworkManager.multiplayer.multiplayer_peer == null:
		mission_selected_status_label.text = "Connexion réseau inactive."
		_update_mission_controls()
		return

	if selected_mission_index < 0 or selected_mission_index >= MISSIONS.size():
		mission_selected_status_label.text = "Sélectionnez une mission avant de lancer."
		_update_mission_controls()
		return

	if not NetworkManager.can_start_game():
		mission_selected_status_label.text = "Tous les joueurs doivent être prêts."
		_update_mission_controls()
		return

	_rpc_start_launch_countdown.rpc(selected_mission_index)


@rpc("authority", "call_local", "reliable")
func _rpc_start_launch_countdown(mission_index: int) -> void:
	if countdown_in_progress:
		return

	if mission_index < 0 or mission_index >= MISSIONS.size():
		return

	_set_selected_mission(mission_index)
	countdown_in_progress = true
	countdown_layer.visible = true
	_refresh_ui()

	var mission: Dictionary = MISSIONS[mission_index]
	var scene_path: String = str(mission.get("scene_path", ""))
	_run_launch_countdown(scene_path)


func _run_launch_countdown(scene_path: String) -> void:
	for value: int in range(COUNTDOWN_SECONDS, 0, -1):
		if not is_inside_tree():
			return

		countdown_label.text = "Lancement dans %s" % value
		mission_selected_status_label.text = "Lancement dans %s..." % value
		await get_tree().create_timer(1.0).timeout

	if not is_inside_tree():
		return

	countdown_label.text = "Lancement..."
	mission_selected_status_label.text = "Lancement..."

	if _is_local_host():
		if scene_path.is_empty():
			_rpc_cancel_launch_countdown.rpc("Chemin de mission invalide.")
			return

		if not NetworkManager.can_start_game():
			_rpc_cancel_launch_countdown.rpc("Lancement annulé. Un joueur n'est plus prêt.")
			return

		_network_start_game(scene_path)


@rpc("authority", "call_local", "reliable")
func _rpc_cancel_launch_countdown(message: String) -> void:
	countdown_in_progress = false
	countdown_layer.visible = false
	status_label.text = message
	mission_selected_status_label.text = message
	_refresh_ui()


func _network_start_game(scene_path: String) -> void:
	var method_list: Array = NetworkManager.get_method_list()
	
	GameSessionState.reset_run_state()
	
	for method_data: Dictionary in method_list:
		if str(method_data.get("name", "")) != "start_game":
			continue

		var argument_count: int = 0
		if method_data.has("args") and method_data["args"] is Array:
			var args: Array = method_data["args"] as Array
			argument_count = args.size()

		if argument_count >= 1:
			NetworkManager.call("start_game", scene_path)
		else:
			NetworkManager.call("start_game")
		return

	_rpc_cancel_launch_countdown.rpc("NetworkManager.start_game() est introuvable.")


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


func _is_local_host() -> bool:
	if NetworkManager.has_method("is_host"):
		return bool(NetworkManager.call("is_host"))

	return NetworkManager.multiplayer.is_server()


func _play_background_animation(animation_name: String) -> void:
	if background_animation_player == null:
		return

	if background_animation_player.has_animation(animation_name):
		background_animation_player.play(animation_name)


func _on_debug_start_button_up():
	if not is_inside_tree():
		return
	
	if NetworkManager.multiplayer.multiplayer_peer == null:
		status_label.text = "Connexion réseau inactive."
		return
	
	NetworkManager.set_local_ready(not NetworkManager.is_local_player_ready())
	
	if _is_local_host():
		_network_start_game("res://scenes/game/NetworkMain.tscn")
