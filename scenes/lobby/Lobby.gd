extends Control

const MENU_SCENE_PATH: String = "res://scenes/menu/MainMenu.tscn"
const START_LOBBY_ANIMATION: String = "start_lobby"
const SELECT_MISSION_ANIMATION: String = "select_mission"
const TANK_CUSTOMIZATION_ANIMATION: String = "tank_customization"
const COUNTDOWN_SECONDS: int = 3

const START_LOBBY_CAMERA_TWEEN_DURATION: float = 1.5
const START_LOBBY_CAMERA_POSITION: Vector3 = Vector3(-6.0, 3.5, 0.0)
const START_LOBBY_CAMERA_ROTATION: Vector3 = Vector3(-0.17453292, -1.5707964, 0.0)
const START_LOBBY_DOF_FAR_DISTANCE: float = 11.0
const START_LOBBY_FADE_DURATION: float = 0.45

const SELECT_MISSION_CAMERA_TWEEN_DURATION: float = 1.5
const SELECT_MISSION_CAMERA_POSITION: Vector3 = Vector3(-2.0, 2.75, 0.0)
const SELECT_MISSION_CAMERA_ROTATION: Vector3 = Vector3(-0.7853982, -1.5707964, 0.0)
const SELECT_MISSION_DOF_FAR_DISTANCE: float = 6.0

const TANK_CUSTOMIZATION_CAMERA_TWEEN_DURATION: float = 1.1
const TANK_CUSTOMIZATION_CAMERA_POSITION: Vector3 = Vector3(-2.75, 3.3, -5.0)
const TANK_CUSTOMIZATION_CAMERA_LOOK_AT: Vector3 = Vector3(2.2, 1.2, -3.5)
const TANK_CUSTOMIZATION_DOF_FAR_DISTANCE: float = 5.5

const CUSTOMIZATION_SUB_TAB_MISSION: String = "mission"
const CUSTOMIZATION_SUB_TAB_TANK: String = "tank_customization"
const CHASSIS_SCAN_ROOT: String = "res://vehicle_system/chassis"
const TURRET_SCAN_ROOT: String = "res://vehicle_system/turrets"
const MOD_SCAN_ROOT: String = "res://vehicle_system/mods/examples"
const DEFAULT_PREVIEW_CHASSIS_PATH: String = "res://vehicle_system/chassis/Tank_Light.tscn"
const SLOT_BUTTON_SIZE: Vector2 = Vector2(92.0, 38.0)
const SLOT_UPGRADE_NAME_MAX_LENGTH: int = 18

const LOBBY_RESOURCE_DATABASE: Dictionary = {
	"chassis": {
		"tank_light": {"unlocked": true, "score_total": 100},
		"light_tank": {"unlocked": true, "score_total": 100},
		"tank_medium": {"unlocked": true, "score_total": 130},
		"medium_tank": {"unlocked": true, "score_total": 130},
		"tank_heavy": {"unlocked": false, "score_total": 170},
		"heavy_tank": {"unlocked": false, "score_total": 170},
	},
	"turrets": {
		"turret_light": {"unlocked": true, "score_cost": 25},
		"light_turret": {"unlocked": true, "score_cost": 25},
		"turret_medium": {"unlocked": true, "score_cost": 30},
		"medium_turret": {"unlocked": true, "score_cost": 30},
		"turret_heavy": {"unlocked": false, "score_cost": 45},
		"heavy_turret": {"unlocked": false, "score_cost": 45},
	},
	"mods": {
		"shield": {"unlocked": true, "score_cost": 20},
		"mod_shield": {"unlocked": true, "score_cost": 20},
		"armor": {"unlocked": true, "score_cost": 20},
		"ammo": {"unlocked": true, "score_cost": 15},
	}
}


const MISSIONS: Array[Dictionary] = [
	{
		"id": "first_mission",
		"name": "Defend the Coast",
		"description": "Mission prototype. Les joueurs entrent dans le hangar et doivent survivre aux premières vagues ennemies.",
		"difficulty": 1,
		"scene_path": "res://scenes/game/Mission_01_A_Outpost.tscn",
		"position": Vector2(780.0, 270.0)
	},
	{
		"id": "second_mission",
		"name": "Force Landing",
		"description": "Mission prototype 2. Les joueurs entrent dans le hangar et doivent survivre aux premières vagues ennemies.",
		"difficulty": 3,
		"scene_path": "res://scenes/game/Mission_01_A_Outpost.tscn",
		"position": Vector2(650.0, 400.0)
	}
]

@export_category("Mission Pins")
var mission_pin_button_scene: PackedScene = preload("uid://vwyc3iay7o37")


@export_category("Tank Customization")
@export var chassis_button_scene: PackedScene = preload("res://scenes/lobby/LobbyChassisButton.tscn")
@export var turret_button_scene: PackedScene = preload("res://scenes/lobby/LobbyTurretButton.tscn")
@export var mod_button_scene: PackedScene = preload("res://scenes/lobby/LobbyModButton.tscn")
@export var customization_host_only_by_default: bool = true
@export var default_shield_keywords: PackedStringArray = ["shield", "bouclier"]
@export var background_animation_tween_transition: Tween.TransitionType = Tween.TRANS_SINE
@export var background_animation_tween_ease: Tween.EaseType = Tween.EASE_IN_OUT

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
@onready var black_fade_intro: ColorRect = get_node_or_null("Node3D/CanvasLayer/BlackFade_Intro") as ColorRect

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

@onready var mission_main_container: Control = get_node_or_null("MissionLayer/MainContainer") as Control
@onready var mission_tab_button: Button = get_node_or_null("MissionLayer/MissionTabs/MissionTabButton") as Button
@onready var tank_customization_tab_button: Button = get_node_or_null("MissionLayer/MissionTabs/TankCustomizationTabButton") as Button
@onready var customization_edit_mode_check_button: CheckButton = get_node_or_null("MissionLayer/MissionTabs/CustomizationEditModeCheckButton") as CheckButton

@onready var tank_customization_root: Control = get_node_or_null("MissionLayer/TankCustomizationRoot") as Control
@onready var tank_slot_overlay: Control = get_node_or_null("MissionLayer/TankCustomizationRoot/TankSlotOverlay") as Control
@onready var tank_customization_status_label: Label = get_node_or_null("MissionLayer/TankCustomizationRoot/TopInfoPanel/MarginContainer/VBoxContainer/TankCustomizationStatusLabel") as Label
@onready var tank_chassis_name_label: Label = get_node_or_null("MissionLayer/TankCustomizationRoot/TopInfoPanel/MarginContainer/VBoxContainer/TankChassisNameLabel") as Label
@onready var tank_score_label: Label = get_node_or_null("MissionLayer/TankCustomizationRoot/TopInfoPanel/MarginContainer/VBoxContainer/TankScoreLabel") as Label
@onready var clear_selection_button: Button = get_node_or_null("MissionLayer/TankCustomizationRoot/TopInfoPanel/MarginContainer/VBoxContainer/ClearCustomizationSelectionButton") as Button
@onready var show_chassis_list_button: Button = get_node_or_null("MissionLayer/TankCustomizationRoot/TopInfoPanel/MarginContainer/VBoxContainer/ShowChassisListButton") as Button
@onready var chassis_list_panel: PanelContainer = get_node_or_null("MissionLayer/TankCustomizationRoot/ChassisListPanel") as PanelContainer
@onready var chassis_list: VBoxContainer = get_node_or_null("MissionLayer/TankCustomizationRoot/ChassisListPanel/MarginContainer/VBoxContainer/ChassisScroll/ChassisList") as VBoxContainer
@onready var turret_list: VBoxContainer = get_node_or_null("MissionLayer/TankCustomizationRoot/TurretListPanel/MarginContainer/VBoxContainer/TurretScroll/TurretList") as VBoxContainer
@onready var mod_list: VBoxContainer = get_node_or_null("MissionLayer/TankCustomizationRoot/ModListPanel/MarginContainer/VBoxContainer/ModScroll/ModList") as VBoxContainer

@onready var hangar_root_3d: Node3D = get_node_or_null("Node3D") as Node3D
@onready var hangar_camera: Camera3D = get_node_or_null("Node3D/Camera3D") as Camera3D
@onready var tank_preview_spawn: Marker3D = get_node_or_null("Node3D/TankPreviewSpawn") as Marker3D
@onready var tank_preview_root: Node3D = get_node_or_null("Node3D/TankPreviewRoot") as Node3D
@onready var tank_preview_spotlight: Light3D = _find_tank_preview_spotlight()
@onready var vehicle_decors_root: Node3D = get_node_or_null("Node3D/Vehicle_Decors") as Node3D
@onready var static_tank_light: Node3D = get_node_or_null("Node3D/Tank_Light") as Node3D
@onready var static_tank_medium: Node3D = get_node_or_null("Node3D/Tank_Medium") as Node3D

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


var current_mission_sub_tab: String = CUSTOMIZATION_SUB_TAB_MISSION
var customization_host_only: bool = true
var tank_customization_state: Dictionary = {}
var chassis_database: Array[Dictionary] = []
var turret_database: Array[Dictionary] = []
var mod_database: Array[Dictionary] = []
var chassis_database_by_path: Dictionary = {}
var turret_database_by_path: Dictionary = {}
var mod_database_by_path: Dictionary = {}
var selected_customization_type: String = ""
var selected_customization_scene_path: String = ""
var preview_vehicle: Node = null
var slot_overlay_buttons: Dictionary = {}
var background_animation_tweens: Array[Tween] = []


func _ready() -> void:
	var steam_lobby_manager: Node = _get_steam_lobby_manager()
	steam_lobby_mode = steam_lobby_manager != null and int(steam_lobby_manager.get("current_lobby_id")) != 0
	_play_background_animation(START_LOBBY_ANIMATION)

	_connect_network_signals()
	_connect_steam_lobby_signals()
	_connect_ui_signals()
	_setup_mission_map()
	_build_mission_buttons()
	_set_selected_mission(-1)
	_setup_tank_customization()
	_setup_vehicle_decors()

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

	if current_mission_sub_tab != CUSTOMIZATION_SUB_TAB_MISSION:
		return

	if event is InputEventMouseButton:
		_handle_map_mouse_button(event as InputEventMouseButton)
		return

	if event is InputEventMouseMotion:
		_handle_map_mouse_motion(event as InputEventMouseMotion)
		return



func _process(_delta: float) -> void:
	if not mission_selection_open:
		return

	if current_mission_sub_tab != CUSTOMIZATION_SUB_TAB_TANK:
		return

	_update_slot_overlay_positions()


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

	_connect_tank_customization_ui_signals()


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
	_update_mission_sub_tab_visibility()

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
	_update_tank_customization_controls()
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
		if current_mission_sub_tab == CUSTOMIZATION_SUB_TAB_TANK:
			status_label.text = "Customisation du tank."
		elif is_host:
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

	mission_launch_button.visible = is_host and current_mission_sub_tab == CUSTOMIZATION_SUB_TAB_MISSION
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



func _setup_vehicle_decors() -> void:
	if vehicle_decors_root != null:
		_lock_vehicle_decors_recursive(vehicle_decors_root)
		return

	# Fallback pour les anciennes scènes où les véhicules décoratifs étaient directement sous Node3D.
	if static_tank_light != null:
		_lock_lobby_decor_vehicle(static_tank_light)

	if static_tank_medium != null:
		_lock_lobby_decor_vehicle(static_tank_medium)


func _lock_vehicle_decors_recursive(node: Node) -> void:
	if node == null:
		return

	if node != vehicle_decors_root and node is VehicleBody3D:
		_lock_lobby_decor_vehicle(node)
		return

	for child: Node in node.get_children():
		_lock_vehicle_decors_recursive(child)


func _lock_lobby_decor_vehicle(vehicle_node: Node) -> void:
	if vehicle_node == null:
		return

	var saved_transform: Transform3D = Transform3D.IDENTITY
	var has_transform: bool = vehicle_node is Node3D
	if has_transform:
		saved_transform = (vehicle_node as Node3D).global_transform

	vehicle_node.set_meta("lobby_decor_vehicle", true)
	_disable_lobby_decor_runtime_nodes(vehicle_node)

	if vehicle_node.has_method("set_use_area_enabled"):
		vehicle_node.call_deferred("set_use_area_enabled", false)

	if has_transform:
		var node_3d: Node3D = vehicle_node as Node3D
		node_3d.global_transform = saved_transform
		node_3d.set_deferred("global_transform", saved_transform)


func _disable_lobby_decor_runtime_nodes(node: Node) -> void:
	if node == null:
		return

	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	node.set_process_unhandled_key_input(false)

	if node is CollisionObject3D:
		var collision_object: CollisionObject3D = node as CollisionObject3D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0

	if node is RigidBody3D:
		var rigid_body: RigidBody3D = node as RigidBody3D
		rigid_body.linear_velocity = Vector3.ZERO
		rigid_body.angular_velocity = Vector3.ZERO
		rigid_body.freeze = true
		rigid_body.sleeping = true
		rigid_body.can_sleep = true
		rigid_body.contact_monitor = false

	if node is VehicleBody3D:
		var vehicle_body: VehicleBody3D = node as VehicleBody3D
		vehicle_body.engine_force = 0.0
		vehicle_body.brake = 0.0
		vehicle_body.steering = 0.0

	for child: Node in node.get_children():
		_disable_lobby_decor_runtime_nodes(child)


func _connect_tank_customization_ui_signals() -> void:
	if mission_tab_button != null and not mission_tab_button.pressed.is_connected(_on_mission_tab_button_pressed):
		mission_tab_button.pressed.connect(_on_mission_tab_button_pressed)

	if tank_customization_tab_button != null and not tank_customization_tab_button.pressed.is_connected(_on_tank_customization_tab_button_pressed):
		tank_customization_tab_button.pressed.connect(_on_tank_customization_tab_button_pressed)

	if customization_edit_mode_check_button != null and not customization_edit_mode_check_button.toggled.is_connected(_on_customization_edit_mode_toggled):
		customization_edit_mode_check_button.toggled.connect(_on_customization_edit_mode_toggled)

	if clear_selection_button != null and not clear_selection_button.pressed.is_connected(_on_clear_customization_selection_pressed):
		clear_selection_button.pressed.connect(_on_clear_customization_selection_pressed)

	if show_chassis_list_button != null and not show_chassis_list_button.pressed.is_connected(_on_show_chassis_list_button_pressed):
		show_chassis_list_button.pressed.connect(_on_show_chassis_list_button_pressed)


func _setup_tank_customization() -> void:
	customization_host_only = customization_host_only_by_default
	_scan_lobby_resource_database()
	tank_customization_state = _build_default_tank_customization_state()
	_apply_tank_customization_state_local(tank_customization_state)
	_update_mission_sub_tab_visibility()
	_update_tank_customization_controls()


func _scan_lobby_resource_database() -> void:
	chassis_database.clear()
	turret_database.clear()
	mod_database.clear()
	chassis_database_by_path.clear()
	turret_database_by_path.clear()
	mod_database_by_path.clear()

	var chassis_paths: Array[String] = _scan_tscn_paths(CHASSIS_SCAN_ROOT, false)
	for scene_path: String in chassis_paths:
		var chassis_entry: Dictionary = _build_chassis_database_entry(scene_path)
		if chassis_entry.is_empty():
			continue
		_register_database_entry(chassis_database, chassis_database_by_path, chassis_entry)

	var turret_paths: Array[String] = _scan_tscn_paths(TURRET_SCAN_ROOT, true)
	for scene_path: String in turret_paths:
		var turret_entry: Dictionary = _build_turret_database_entry(scene_path)
		if turret_entry.is_empty():
			continue
		_register_database_entry(turret_database, turret_database_by_path, turret_entry)

	var mod_paths: Array[String] = _scan_tscn_paths(MOD_SCAN_ROOT, true)
	for scene_path: String in mod_paths:
		var mod_entry: Dictionary = _build_mod_database_entry(scene_path)
		if mod_entry.is_empty():
			continue
		_register_database_entry(mod_database, mod_database_by_path, mod_entry)

	chassis_database.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("score_total", 0)) < int(b.get("score_total", 0))
	)
	turret_database.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("display_name", "")) < str(b.get("display_name", ""))
	)
	mod_database.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("display_name", "")) < str(b.get("display_name", ""))
	)


func _scan_tscn_paths(root_path: String, recursive: bool) -> Array[String]:
	var result: Array[String] = []
	var directory: DirAccess = DirAccess.open(root_path)
	if directory == null:
		return result

	directory.list_dir_begin()
	while true:
		var entry_name: String = directory.get_next()
		if entry_name.is_empty():
			break

		if entry_name.begins_with("."):
			continue

		var full_path: String = root_path.path_join(entry_name)
		if directory.current_is_dir():
			if recursive:
				result.append_array(_scan_tscn_paths(full_path, recursive))
			continue

		if entry_name.ends_with(".tscn"):
			result.append(full_path)

	directory.list_dir_end()
	return result


func _register_database_entry(database: Array[Dictionary], path_lookup: Dictionary, entry: Dictionary) -> void:
	var scene_path: String = str(entry.get("scene_path", ""))
	if scene_path.is_empty():
		return

	for existing_entry: Dictionary in database:
		if str(existing_entry.get("scene_path", "")) == scene_path:
			return

	database.append(entry)
	path_lookup[scene_path] = entry


func _build_chassis_database_entry(scene_path: String) -> Dictionary:
	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		return {}

	var info: Dictionary = Vehicle.inspect_chassis_scene(scene)
	var fallback_id: String = _to_resource_id(scene_path.get_file().get_basename())
	var chassis_id: String = str(info.get("chassis_id", fallback_id))
	if chassis_id.is_empty():
		chassis_id = fallback_id

	var display_name: String = str(info.get("vehicle_display_name", scene_path.get_file().get_basename()))
	var override_data: Dictionary = _get_resource_override("chassis", chassis_id, scene_path)
	var mount_data: Dictionary = _inspect_chassis_scene_mount_data(scene)
	var score_total: int = int(override_data.get("score_total", _guess_chassis_score_total(chassis_id, display_name, scene_path)))
	var unlocked: bool = bool(override_data.get("unlocked", true))

	return {
		"resource_id": chassis_id,
		"display_name": display_name,
		"scene_path": scene_path,
		"score_total": score_total,
		"unlocked": unlocked,
		"turret_slots": mount_data.get("turret_slots", []),
		"mod_slots": mount_data.get("mod_slots", []),
		"default_turrets": mount_data.get("default_turrets", {}),
		"default_mods": mount_data.get("default_mods", {}),
	}


func _build_turret_database_entry(scene_path: String) -> Dictionary:
	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		return {}

	var info: Dictionary = VehicleTurretBase.inspect_scene(scene)
	if info.is_empty():
		return {}

	var fallback_id: String = _to_resource_id(scene_path.get_file().get_basename())
	var turret_id: String = str(info.get("turret_id", fallback_id))
	if turret_id.is_empty() or turret_id == "driver_turret":
		return {}

	var display_name: String = str(info.get("turret_label", scene_path.get_file().get_basename()))
	var turret_size: int = int(info.get("turret_size", 0))
	if turret_size <= 0:
		return {}

	var override_data: Dictionary = _get_resource_override("turrets", turret_id, scene_path)
	var score_cost: int = int(override_data.get("score_cost", _guess_turret_score_cost(turret_id, display_name, turret_size)))
	var unlocked: bool = bool(override_data.get("unlocked", true))

	return {
		"resource_id": turret_id,
		"display_name": display_name,
		"scene_path": scene_path,
		"turret_size": turret_size,
		"score_cost": score_cost,
		"unlocked": unlocked,
	}


func _build_mod_database_entry(scene_path: String) -> Dictionary:
	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		return {}

	var info: Dictionary = VehicleModBase.inspect_scene(scene)
	if info.is_empty():
		return {}

	var fallback_id: String = _to_resource_id(scene_path.get_file().get_basename())
	var mod_id: String = str(info.get("mod_id", fallback_id))
	if mod_id.is_empty():
		return {}

	var display_name: String = str(info.get("mod_label", scene_path.get_file().get_basename()))
	var mod_size: int = int(info.get("mod_size", 0))
	if mod_size <= 0:
		return {}

	var allowed_placements: Array = info.get("allowed_placements", [])
	var override_data: Dictionary = _get_resource_override("mods", mod_id, scene_path)
	var score_cost: int = int(override_data.get("score_cost", _guess_mod_score_cost(mod_id, display_name, mod_size)))
	var unlocked: bool = bool(override_data.get("unlocked", true))

	return {
		"resource_id": mod_id,
		"display_name": display_name,
		"scene_path": scene_path,
		"mod_size": mod_size,
		"allowed_placements": allowed_placements.duplicate(true),
		"score_cost": score_cost,
		"unlocked": unlocked,
		"placement_text": _build_allowed_placements_text(allowed_placements),
	}


func _inspect_chassis_scene_mount_data(scene: PackedScene) -> Dictionary:
	var output: Dictionary = {
		"turret_slots": [],
		"mod_slots": [],
		"default_turrets": {},
		"default_mods": {},
	}

	var instance: Node = scene.instantiate()
	if instance == null:
		return output

	var turret_mounts_found: Array[VehicleTurretMount] = []
	var mod_mounts_found: Array[VehicleModMount] = []
	_collect_turret_mounts_from_node(instance, turret_mounts_found)
	_collect_mod_mounts_from_node(instance, mod_mounts_found)

	turret_mounts_found.sort_custom(func(a: VehicleTurretMount, b: VehicleTurretMount) -> bool:
		return int(a.seat_index) < int(b.seat_index)
	)
	mod_mounts_found.sort_custom(func(a: VehicleModMount, b: VehicleModMount) -> bool:
		return int(a.mod_use_id) < int(b.mod_use_id)
	)

	for mount: VehicleTurretMount in turret_mounts_found:
		var scene_path: String = ""
		if mount.has_method("get_turret_scene_path"):
			scene_path = str(mount.call("get_turret_scene_path"))
		elif mount.get("turret_scene") != null:
			var turret_scene: PackedScene = mount.get("turret_scene") as PackedScene
			if turret_scene != null:
				scene_path = turret_scene.resource_path

		var slot_data: Dictionary = {
			"seat_index": int(mount.seat_index),
			"label": str(mount.seat_label),
			"turret_size": int(mount.turret_size),
			"driver_turret": bool(mount.driver_turret),
		}
		output["turret_slots"].append(slot_data)
		if not scene_path.is_empty():
			output["default_turrets"][str(mount.seat_index)] = scene_path

	for mod_mount: VehicleModMount in mod_mounts_found:
		var mod_scene_path: String = ""
		if mod_mount.has_method("get_mod_scene_path"):
			mod_scene_path = str(mod_mount.call("get_mod_scene_path"))
		elif mod_mount.get("mod_scene") != null:
			var mod_scene: PackedScene = mod_mount.get("mod_scene") as PackedScene
			if mod_scene != null:
				mod_scene_path = mod_scene.resource_path

		var mod_slot_data: Dictionary = {
			"mod_use_id": int(mod_mount.mod_use_id),
			"label": str(mod_mount.mount_label),
			"max_mod_size": int(mod_mount.max_mod_size),
			"placement": str(mod_mount.placement),
		}
		output["mod_slots"].append(mod_slot_data)
		if not mod_scene_path.is_empty():
			output["default_mods"][str(mod_mount.mod_use_id)] = mod_scene_path

	instance.queue_free()
	return output


func _collect_turret_mounts_from_node(node: Node, output: Array[VehicleTurretMount]) -> void:
	for child: Node in node.get_children():
		if child is VehicleTurretMount:
			output.append(child as VehicleTurretMount)
		_collect_turret_mounts_from_node(child, output)


func _collect_mod_mounts_from_node(node: Node, output: Array[VehicleModMount]) -> void:
	for child: Node in node.get_children():
		if child is VehicleModMount:
			output.append(child as VehicleModMount)
		_collect_mod_mounts_from_node(child, output)


func _get_resource_override(category: String, resource_id: String, scene_path: String) -> Dictionary:
	var category_data: Dictionary = LOBBY_RESOURCE_DATABASE.get(category, {})
	var normalized_id: String = _to_resource_id(resource_id)
	if category_data.has(normalized_id):
		return category_data[normalized_id].duplicate(true)

	var path_id: String = _to_resource_id(scene_path.get_file().get_basename())
	if category_data.has(path_id):
		return category_data[path_id].duplicate(true)

	return {}


func _guess_chassis_score_total(resource_id: String, display_name: String, scene_path: String) -> int:
	var haystack: String = _to_resource_id("%s_%s_%s" % [resource_id, display_name, scene_path])
	if haystack.contains("light") or haystack.contains("leger") or haystack.contains("l_xe9ger"):
		return 100
	if haystack.contains("medium") or haystack.contains("moyen"):
		return 130
	if haystack.contains("heavy") or haystack.contains("lourd"):
		return 170
	return 100


func _guess_turret_score_cost(resource_id: String, display_name: String, turret_size: int) -> int:
	var haystack: String = _to_resource_id("%s_%s" % [resource_id, display_name])
	if haystack.contains("light") or haystack.contains("leger") or haystack.contains("small"):
		return 25
	if haystack.contains("medium") or haystack.contains("moyen"):
		return 30
	if haystack.contains("heavy") or haystack.contains("large") or haystack.contains("lourd"):
		return 45
	return max(15, turret_size * 25)


func _guess_mod_score_cost(resource_id: String, display_name: String, mod_size: int) -> int:
	var haystack: String = _to_resource_id("%s_%s" % [resource_id, display_name])
	if haystack.contains("shield") or haystack.contains("bouclier"):
		return 20
	if haystack.contains("ammo") or haystack.contains("reserve"):
		return 15
	if haystack.contains("armor") or haystack.contains("armure"):
		return 20
	return max(10, mod_size * 15)


func _build_allowed_placements_text(placements: Array) -> String:
	if placements.is_empty():
		return "Placement : tous"

	var labels: Array[String] = []
	for placement_value in placements:
		labels.append(str(placement_value))
	return "Placement : %s" % ", ".join(labels)


func _to_resource_id(raw_value: String) -> String:
	var output: String = raw_value.strip_edges().to_lower()
	output = output.replace("res://", "")
	output = output.replace("/", "_")
	output = output.replace(".", "_")
	output = output.replace("-", "_")
	output = output.replace(" ", "_")
	output = output.replace("é", "e")
	output = output.replace("è", "e")
	output = output.replace("ê", "e")
	output = output.replace("à", "a")
	output = output.replace("ç", "c")
	while output.contains("__"):
		output = output.replace("__", "_")
	return output


func _build_default_tank_customization_state() -> Dictionary:
	var chassis_entry: Dictionary = _find_default_chassis_entry()
	if chassis_entry.is_empty():
		return {}

	return _build_state_from_chassis_entry(chassis_entry, true)


func _find_default_chassis_entry() -> Dictionary:
	if chassis_database_by_path.has(DEFAULT_PREVIEW_CHASSIS_PATH):
		return chassis_database_by_path[DEFAULT_PREVIEW_CHASSIS_PATH].duplicate(true)

	for entry: Dictionary in chassis_database:
		var scene_path: String = str(entry.get("scene_path", ""))
		var resource_id: String = str(entry.get("resource_id", ""))
		if scene_path.to_lower().contains("tank_light") or resource_id.to_lower().contains("light"):
			return entry.duplicate(true)

	if not chassis_database.is_empty():
		return chassis_database[0].duplicate(true)

	return {}


func _build_state_from_chassis_entry(chassis_entry: Dictionary, apply_default_shield: bool) -> Dictionary:
	var turrets: Dictionary = {}
	var default_turrets: Dictionary = chassis_entry.get("default_turrets", {})
	for key in default_turrets.keys():
		turrets[str(key)] = str(default_turrets[key])

	var mods: Dictionary = {}
	if not apply_default_shield:
		var default_mods: Dictionary = chassis_entry.get("default_mods", {})
		for key in default_mods.keys():
			mods[str(key)] = str(default_mods[key])
	else:
		var shield_assignment: Dictionary = _find_default_shield_assignment(chassis_entry)
		if not shield_assignment.is_empty():
			mods[str(shield_assignment.get("mod_use_id", -1))] = str(shield_assignment.get("scene_path", ""))

	var score_total: int = int(chassis_entry.get("score_total", 100))
	return {
		"chassis_scene_path": str(chassis_entry.get("scene_path", "")),
		"chassis_id": str(chassis_entry.get("resource_id", "")),
		"vehicle_display_name": str(chassis_entry.get("display_name", "Tank")),
		"score_total": score_total,
		"turrets": turrets,
		"mods": mods,
	}


func _find_default_shield_assignment(chassis_entry: Dictionary) -> Dictionary:
	var mod_slots: Array = chassis_entry.get("mod_slots", [])
	for mod_entry: Dictionary in mod_database:
		if not bool(mod_entry.get("unlocked", false)):
			continue

		var haystack: String = _to_resource_id("%s_%s_%s" % [str(mod_entry.get("resource_id", "")), str(mod_entry.get("display_name", "")), str(mod_entry.get("scene_path", ""))])
		var is_shield: bool = false
		for keyword: String in default_shield_keywords:
			if haystack.contains(_to_resource_id(keyword)):
				is_shield = true
				break

		if not is_shield:
			continue

		for slot_value in mod_slots:
			var slot: Dictionary = slot_value
			if str(slot.get("placement", "")).to_lower() != "center":
				continue
			if _is_mod_entry_compatible_with_slot(mod_entry, slot):
				return {
					"mod_use_id": int(slot.get("mod_use_id", -1)),
					"scene_path": str(mod_entry.get("scene_path", "")),
				}

	return {}


func _apply_tank_customization_state_local(new_state: Dictionary) -> void:
	if new_state.is_empty():
		return

	tank_customization_state = _normalize_tank_customization_state(new_state)
	selected_customization_type = ""
	selected_customization_scene_path = ""
	_spawn_tank_preview_from_state()
	_rebuild_customization_lists()
	_rebuild_slot_overlay_buttons()
	_update_tank_customization_controls()
	_save_lobby_vehicle_state_to_session_state()


func _normalize_tank_customization_state(raw_state: Dictionary) -> Dictionary:
	var normalized: Dictionary = raw_state.duplicate(true)
	if not normalized.has("turrets") or not (normalized["turrets"] is Dictionary):
		normalized["turrets"] = {}
	if not normalized.has("mods") or not (normalized["mods"] is Dictionary):
		normalized["mods"] = {}
	if not normalized.has("score_total"):
		var chassis_entry: Dictionary = _get_chassis_entry_for_path(str(normalized.get("chassis_scene_path", "")))
		normalized["score_total"] = int(chassis_entry.get("score_total", 100))
	return normalized


func _spawn_tank_preview_from_state() -> void:
	_clear_tank_preview()

	if tank_preview_root == null:
		return

	var chassis_scene_path: String = str(tank_customization_state.get("chassis_scene_path", ""))
	if chassis_scene_path.is_empty():
		return

	var chassis_scene: PackedScene = load(chassis_scene_path) as PackedScene
	if chassis_scene == null:
		return

	var instance: Node = chassis_scene.instantiate()
	if instance == null:
		return

	preview_vehicle = instance
	instance.set_meta("lobby_preview_vehicle", true)
	tank_preview_root.add_child(instance)
	if tank_preview_spawn != null and instance is Node3D:
		var instance_3d: Node3D = instance as Node3D
		instance_3d.global_transform = tank_preview_spawn.global_transform

	_disable_preview_runtime_nodes(instance)
	_apply_state_to_preview_vehicle()
	tank_preview_root.visible = true
	_set_preview_spotlight_enabled(mission_selection_open and current_mission_sub_tab == CUSTOMIZATION_SUB_TAB_TANK)


func _clear_tank_preview() -> void:
	var vehicle_to_clear: Node = preview_vehicle
	if vehicle_to_clear != null and is_instance_valid(vehicle_to_clear):
		vehicle_to_clear.queue_free()
	preview_vehicle = null

	if tank_preview_root != null:
		for child: Node in tank_preview_root.get_children():
			if child == vehicle_to_clear:
				continue
			if _is_tank_preview_helper_node(child):
				continue
			if bool(child.get_meta("lobby_preview_vehicle", false)):
				child.queue_free()

	_clear_slot_overlay_buttons()


func _is_tank_preview_helper_node(node: Node) -> bool:
	if node == null:
		return false

	if node.name == &"Spotlight3D_Preview":
		return true

	if node is Light3D and str(node.name).contains("Preview"):
		return true

	return false


func _find_tank_preview_spotlight() -> Light3D:
	var direct_node: Node = get_node_or_null("Node3D/TankPreviewRoot/Spotlight3D_Preview")
	if direct_node is Light3D:
		return direct_node as Light3D

	direct_node = get_node_or_null("Node3D/Spotlight3D_Preview")
	if direct_node is Light3D:
		return direct_node as Light3D

	direct_node = get_node_or_null("Node3D/TankPreviewSpawn/Spotlight3D_Preview")
	if direct_node is Light3D:
		return direct_node as Light3D

	if tank_preview_root != null:
		var recursive_node: Node = tank_preview_root.find_child("Spotlight3D_Preview", true, false)
		if recursive_node is Light3D:
			return recursive_node as Light3D

	if hangar_root_3d != null:
		var fallback_node: Node = hangar_root_3d.find_child("Spotlight3D_Preview", true, false)
		if fallback_node is Light3D:
			return fallback_node as Light3D

	return null


func _set_preview_spotlight_enabled(enabled: bool) -> void:
	if tank_preview_spotlight == null or not is_instance_valid(tank_preview_spotlight):
		tank_preview_spotlight = _find_tank_preview_spotlight()

	if tank_preview_spotlight == null:
		return

	tank_preview_spotlight.visible = enabled


func _disable_preview_runtime_nodes(node: Node) -> void:
	if node is CollisionObject3D:
		var collision_object: CollisionObject3D = node as CollisionObject3D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0

	if node is RigidBody3D:
		var rigid_body: RigidBody3D = node as RigidBody3D
		rigid_body.freeze = true
		rigid_body.sleeping = true
		rigid_body.set_physics_process(false)

	node.set_process(false)
	node.set_physics_process(false)

	for child: Node in node.get_children():
		_disable_preview_runtime_nodes(child)


func _apply_state_to_preview_vehicle() -> void:
	if preview_vehicle == null or not is_instance_valid(preview_vehicle):
		return

	var turret_config: Array[Dictionary] = []
	var turret_state: Dictionary = tank_customization_state.get("turrets", {})
	var chassis_entry: Dictionary = _get_current_chassis_entry()
	var turret_slots: Array = chassis_entry.get("turret_slots", [])
	for slot_value in turret_slots:
		var slot: Dictionary = slot_value
		var seat_index: int = int(slot.get("seat_index", -1))
		turret_config.append({
			"seat_index": seat_index,
			"turret_scene_path": str(turret_state.get(str(seat_index), "")),
		})

	var mod_config: Array[Dictionary] = []
	var mod_state: Dictionary = tank_customization_state.get("mods", {})
	var mod_slots: Array = chassis_entry.get("mod_slots", [])
	for slot_value in mod_slots:
		var slot: Dictionary = slot_value
		var mod_use_id: int = int(slot.get("mod_use_id", -1))
		mod_config.append({
			"mod_use_id": mod_use_id,
			"mod_scene_path": str(mod_state.get(str(mod_use_id), "")),
		})

	if preview_vehicle.has_method("_sync_loadout_state"):
		preview_vehicle.call("_sync_loadout_state", _get_score_remaining(), turret_config, mod_config)


func _get_current_chassis_entry() -> Dictionary:
	return _get_chassis_entry_for_path(str(tank_customization_state.get("chassis_scene_path", "")))


func _get_chassis_entry_for_path(scene_path: String) -> Dictionary:
	if chassis_database_by_path.has(scene_path):
		return chassis_database_by_path[scene_path].duplicate(true)
	return {}


func _get_turret_entry_for_path(scene_path: String) -> Dictionary:
	if turret_database_by_path.has(scene_path):
		return turret_database_by_path[scene_path].duplicate(true)
	return {}


func _get_mod_entry_for_path(scene_path: String) -> Dictionary:
	if mod_database_by_path.has(scene_path):
		return mod_database_by_path[scene_path].duplicate(true)
	return {}


func _get_score_remaining() -> int:
	return int(tank_customization_state.get("score_total", 0)) - _get_equipped_score_cost()


func _get_equipped_score_cost() -> int:
	var total_cost: int = 0
	var turret_state: Dictionary = tank_customization_state.get("turrets", {})
	for key in turret_state.keys():
		var turret_entry: Dictionary = _get_turret_entry_for_path(str(turret_state[key]))
		total_cost += int(turret_entry.get("score_cost", 0))

	var mod_state: Dictionary = tank_customization_state.get("mods", {})
	for key in mod_state.keys():
		var mod_entry: Dictionary = _get_mod_entry_for_path(str(mod_state[key]))
		total_cost += int(mod_entry.get("score_cost", 0))

	return total_cost


func _rebuild_customization_lists() -> void:
	_rebuild_chassis_list()
	_rebuild_turret_list()
	_rebuild_mod_list()


func _rebuild_chassis_list() -> void:
	if chassis_list == null:
		return

	_clear_children(chassis_list)
	for entry: Dictionary in chassis_database:
		if chassis_button_scene == null:
			continue
		var button_node: Node = chassis_button_scene.instantiate()
		var button: Button = button_node as Button
		if button == null:
			button_node.queue_free()
			continue

		var data: Dictionary = entry.duplicate(true)
		data["selected"] = str(entry.get("scene_path", "")) == str(tank_customization_state.get("chassis_scene_path", ""))
		data["selectable"] = _can_local_edit_customization() and not countdown_in_progress
		button.call("setup", data)
		chassis_list.add_child(button)
		var callback: Callable = Callable(self, "_on_chassis_entry_pressed")
		if button.has_signal("resource_pressed") and not button.is_connected("resource_pressed", callback):
			button.connect("resource_pressed", callback)


func _rebuild_turret_list() -> void:
	if turret_list == null:
		return

	_clear_children(turret_list)
	var remaining_score: int = _get_score_remaining()
	for entry: Dictionary in turret_database:
		if turret_button_scene == null:
			continue
		var button_node: Node = turret_button_scene.instantiate()
		var button: Button = button_node as Button
		if button == null:
			button_node.queue_free()
			continue

		var data: Dictionary = entry.duplicate(true)
		var scene_path: String = str(entry.get("scene_path", ""))
		data["selected"] = selected_customization_type == "turret" and selected_customization_scene_path == scene_path
		data["affordable"] = remaining_score >= int(entry.get("score_cost", 0))
		data["selectable"] = _can_local_edit_customization() and not countdown_in_progress
		button.call("setup", data)
		turret_list.add_child(button)
		var callback: Callable = Callable(self, "_on_turret_entry_pressed")
		if button.has_signal("resource_pressed") and not button.is_connected("resource_pressed", callback):
			button.connect("resource_pressed", callback)


func _rebuild_mod_list() -> void:
	if mod_list == null:
		return

	_clear_children(mod_list)
	var remaining_score: int = _get_score_remaining()
	for entry: Dictionary in mod_database:
		if mod_button_scene == null:
			continue
		var button_node: Node = mod_button_scene.instantiate()
		var button: Button = button_node as Button
		if button == null:
			button_node.queue_free()
			continue

		var data: Dictionary = entry.duplicate(true)
		var scene_path: String = str(entry.get("scene_path", ""))
		data["selected"] = selected_customization_type == "mod" and selected_customization_scene_path == scene_path
		data["affordable"] = remaining_score >= int(entry.get("score_cost", 0))
		data["selectable"] = _can_local_edit_customization() and not countdown_in_progress
		button.call("setup", data)
		mod_list.add_child(button)
		var callback: Callable = Callable(self, "_on_mod_entry_pressed")
		if button.has_signal("resource_pressed") and not button.is_connected("resource_pressed", callback):
			button.connect("resource_pressed", callback)


func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		child.queue_free()


func _rebuild_slot_overlay_buttons() -> void:
	_clear_slot_overlay_buttons()
	if tank_slot_overlay == null or preview_vehicle == null or not is_instance_valid(preview_vehicle):
		return

	var turret_mounts_value = preview_vehicle.get("turret_mounts")
	if turret_mounts_value is Array:
		for mount_value in turret_mounts_value:
			var mount: Node = mount_value as Node
			if mount == null:
				continue
			var seat_index: int = int(mount.get("seat_index"))
			var driver_turret: bool = bool(mount.get("driver_turret"))
			var turret_size: int = int(mount.get("turret_size"))
			if driver_turret or turret_size <= 0:
				continue
			var button: Button = _create_slot_button("turret", seat_index)
			tank_slot_overlay.add_child(button)
			slot_overlay_buttons["turret:%d" % seat_index] = {
				"button": button,
				"node": mount,
				"type": "turret",
				"slot_id": seat_index,
			}

	var mod_mounts_value = preview_vehicle.get("mod_mounts")
	if mod_mounts_value is Array:
		for mount_value in mod_mounts_value:
			var mod_mount: Node = mount_value as Node
			if mod_mount == null:
				continue
			var mod_use_id: int = int(mod_mount.get("mod_use_id"))
			var max_mod_size: int = int(mod_mount.get("max_mod_size"))
			if max_mod_size <= 0:
				continue
			var button: Button = _create_slot_button("mod", mod_use_id)
			tank_slot_overlay.add_child(button)
			slot_overlay_buttons["mod:%d" % mod_use_id] = {
				"button": button,
				"node": mod_mount,
				"type": "mod",
				"slot_id": mod_use_id,
			}

	_refresh_slot_overlay_button_states()
	_update_slot_overlay_positions()


func _create_slot_button(slot_type: String, slot_id: int) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = SLOT_BUTTON_SIZE
	button.size = SLOT_BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	if slot_type == "turret":
		button.text = "T%d" % slot_id
		button.pressed.connect(_on_turret_slot_pressed.bind(slot_id))
	else:
		button.text = "M%d" % slot_id
		button.pressed.connect(_on_mod_slot_pressed.bind(slot_id))
	return button


func _clear_slot_overlay_buttons() -> void:
	if tank_slot_overlay != null:
		for child: Node in tank_slot_overlay.get_children():
			child.queue_free()
	slot_overlay_buttons.clear()


func _refresh_slot_overlay_button_states() -> void:
	var can_edit: bool = _can_local_edit_customization() and not countdown_in_progress
	var turret_state: Dictionary = tank_customization_state.get("turrets", {})
	var mod_state: Dictionary = tank_customization_state.get("mods", {})

	for key in slot_overlay_buttons.keys():
		var data: Dictionary = slot_overlay_buttons[key]
		var button: Button = data.get("button", null) as Button
		if button == null:
			continue

		var slot_type: String = str(data.get("type", ""))
		var slot_id: int = int(data.get("slot_id", -1))
		var occupied: bool = false
		var selected_matches_type: bool = selected_customization_type == slot_type
		var enabled: bool = can_edit
		var label: String = ""

		if slot_type == "turret":
			occupied = turret_state.has(str(slot_id)) and not str(turret_state[str(slot_id)]).is_empty()
			label = _get_turret_slot_button_label(slot_id, occupied)
			if not occupied:
				enabled = enabled and selected_matches_type and _can_place_selected_turret_on_slot(slot_id)
		else:
			occupied = mod_state.has(str(slot_id)) and not str(mod_state[str(slot_id)]).is_empty()
			label = _get_mod_slot_button_label(slot_id, occupied)
			if not occupied:
				enabled = enabled and selected_matches_type and _can_place_selected_mod_on_slot(slot_id)

		button.text = label
		button.disabled = not enabled
		if occupied and can_edit:
			button.disabled = false


func _get_turret_slot_button_label(seat_index: int, occupied: bool) -> String:
	if occupied:
		var turret_name: String = _get_equipped_turret_display_name(seat_index)
		return "Retirer T%d\n%s" % [seat_index, _format_slot_upgrade_name(turret_name)]
	return "Tourelle\nT%d" % seat_index


func _get_mod_slot_button_label(mod_use_id: int, occupied: bool) -> String:
	if occupied:
		var mod_name: String = _get_equipped_mod_display_name(mod_use_id)
		return "Retirer M%d\n%s" % [mod_use_id, _format_slot_upgrade_name(mod_name)]
	return "Module\nM%d" % mod_use_id


func _get_equipped_turret_display_name(seat_index: int) -> String:
	var turret_state: Dictionary = tank_customization_state.get("turrets", {})
	var scene_path: String = str(turret_state.get(str(seat_index), ""))
	if scene_path.is_empty():
		return "Tourelle"

	var turret_entry: Dictionary = _get_turret_entry_for_path(scene_path)
	var display_name: String = str(turret_entry.get("display_name", "")).strip_edges()
	if not display_name.is_empty():
		return display_name

	return scene_path.get_file().get_basename().capitalize()


func _get_equipped_mod_display_name(mod_use_id: int) -> String:
	var mod_state: Dictionary = tank_customization_state.get("mods", {})
	var scene_path: String = str(mod_state.get(str(mod_use_id), ""))
	if scene_path.is_empty():
		return "Module"

	var mod_entry: Dictionary = _get_mod_entry_for_path(scene_path)
	var display_name: String = str(mod_entry.get("display_name", "")).strip_edges()
	if not display_name.is_empty():
		return display_name

	return scene_path.get_file().get_basename().capitalize()


func _format_slot_upgrade_name(upgrade_name: String) -> String:
	var clean_name: String = upgrade_name.strip_edges()
	if clean_name.is_empty():
		return "Inconnu"

	if clean_name.length() > SLOT_UPGRADE_NAME_MAX_LENGTH:
		return clean_name.substr(0, SLOT_UPGRADE_NAME_MAX_LENGTH - 3) + "..."

	return clean_name


func _update_slot_overlay_positions() -> void:
	if hangar_camera == null:
		return

	for key in slot_overlay_buttons.keys():
		var data: Dictionary = slot_overlay_buttons[key]
		var button: Button = data.get("button", null) as Button
		var node: Node3D = data.get("node", null) as Node3D
		if button == null or node == null or not is_instance_valid(node):
			continue

		var world_position: Vector3 = node.global_transform.origin
		if hangar_camera.is_position_behind(world_position):
			button.visible = false
			continue

		var screen_position: Vector2 = hangar_camera.unproject_position(world_position)
		button.global_position = screen_position - button.size * 0.5
		button.visible = tank_customization_root != null and tank_customization_root.visible


func _update_tank_customization_controls() -> void:
	if tank_score_label != null:
		var total_score: int = int(tank_customization_state.get("score_total", 0))
		var remaining_score: int = _get_score_remaining()
		tank_score_label.text = "Score restant : %d / %d" % [remaining_score, total_score]

	if tank_chassis_name_label != null:
		tank_chassis_name_label.text = str(tank_customization_state.get("vehicle_display_name", "Tank"))

	if tank_customization_status_label != null:
		tank_customization_status_label.text = _get_customization_status_text()

	if customization_edit_mode_check_button != null:
		customization_edit_mode_check_button.disabled = not _is_local_host() or countdown_in_progress
		customization_edit_mode_check_button.set_pressed_no_signal(not customization_host_only)

	if show_chassis_list_button != null:
		show_chassis_list_button.disabled = not _can_local_edit_customization() or countdown_in_progress

	if clear_selection_button != null:
		clear_selection_button.disabled = selected_customization_type.is_empty()

	_rebuild_customization_lists()
	_refresh_slot_overlay_button_states()


func _get_customization_status_text() -> String:
	if countdown_in_progress:
		return "Lancement en cours. La customisation est verrouillée."

	if not _can_local_edit_customization():
		if customization_host_only:
			return "Lecture seule. Seul l'hôte peut modifier le tank."
		return "Lecture seule. Connexion inactive ou modification non autorisée."

	if selected_customization_type == "turret":
		return "Tourelle sélectionnée. Cliquez sur un emplacement de tourelle vide. Cliquez sur une tourelle équipée pour la retirer."

	if selected_customization_type == "mod":
		return "Module sélectionné. Cliquez sur un emplacement de module compatible. Cliquez sur un module équipé pour le retirer."

	return "Sélectionnez une tourelle ou un module. Le châssis se change avec la liste dédiée."


func _update_mission_sub_tab_visibility() -> void:
	var customization_open: bool = mission_selection_open and current_mission_sub_tab == CUSTOMIZATION_SUB_TAB_TANK

	if mission_main_container != null:
		mission_main_container.visible = mission_selection_open and not customization_open

	if tank_customization_root != null:
		tank_customization_root.visible = customization_open

	if tank_preview_root != null:
		tank_preview_root.visible = true

	_set_preview_spotlight_enabled(customization_open)

	if mission_tab_button != null:
		mission_tab_button.set_pressed_no_signal(current_mission_sub_tab == CUSTOMIZATION_SUB_TAB_MISSION)

	if tank_customization_tab_button != null:
		tank_customization_tab_button.set_pressed_no_signal(current_mission_sub_tab == CUSTOMIZATION_SUB_TAB_TANK)

	if tank_slot_overlay != null:
		tank_slot_overlay.visible = customization_open

	_update_slot_overlay_positions()


func _set_mission_sub_tab(tab_name: String) -> void:
	if countdown_in_progress:
		return

	if tab_name != CUSTOMIZATION_SUB_TAB_MISSION and tab_name != CUSTOMIZATION_SUB_TAB_TANK:
		return

	current_mission_sub_tab = tab_name

	if current_mission_sub_tab == CUSTOMIZATION_SUB_TAB_TANK:
		_play_background_animation(TANK_CUSTOMIZATION_ANIMATION)
	else:
		_play_background_animation(SELECT_MISSION_ANIMATION)

	_update_mission_sub_tab_visibility()
	_update_mission_controls()
	_update_tank_customization_controls()


func _on_mission_tab_button_pressed() -> void:
	_set_mission_sub_tab(CUSTOMIZATION_SUB_TAB_MISSION)


func _on_tank_customization_tab_button_pressed() -> void:
	_set_mission_sub_tab(CUSTOMIZATION_SUB_TAB_TANK)


func _on_customization_edit_mode_toggled(button_pressed: bool) -> void:
	if not _is_local_host():
		return

	_rpc_set_customization_edit_mode.rpc(not button_pressed)


@rpc("authority", "call_local", "reliable")
func _rpc_set_customization_edit_mode(host_only: bool) -> void:
	customization_host_only = host_only
	_update_tank_customization_controls()


func _on_clear_customization_selection_pressed() -> void:
	selected_customization_type = ""
	selected_customization_scene_path = ""
	_update_tank_customization_controls()


func _on_show_chassis_list_button_pressed() -> void:
	if chassis_list_panel == null:
		return

	chassis_list_panel.visible = not chassis_list_panel.visible
	_rebuild_chassis_list()


func _on_chassis_entry_pressed(resource_data: Dictionary) -> void:
	if not _can_local_edit_customization():
		return

	var scene_path: String = str(resource_data.get("scene_path", ""))
	if scene_path.is_empty():
		return

	_request_customization_action("change_chassis", {"scene_path": scene_path})


func _on_turret_entry_pressed(resource_data: Dictionary) -> void:
	if not _can_local_edit_customization():
		return

	selected_customization_type = "turret"
	selected_customization_scene_path = str(resource_data.get("scene_path", ""))
	_update_tank_customization_controls()


func _on_mod_entry_pressed(resource_data: Dictionary) -> void:
	if not _can_local_edit_customization():
		return

	selected_customization_type = "mod"
	selected_customization_scene_path = str(resource_data.get("scene_path", ""))
	_update_tank_customization_controls()


func _on_turret_slot_pressed(seat_index: int) -> void:
	if not _can_local_edit_customization():
		return

	var turret_state: Dictionary = tank_customization_state.get("turrets", {})
	if turret_state.has(str(seat_index)) and not str(turret_state[str(seat_index)]).is_empty():
		_request_customization_action("remove_turret", {"seat_index": seat_index})
		return

	if selected_customization_type != "turret":
		return

	var turret_entry: Dictionary = _get_turret_entry_for_path(selected_customization_scene_path)
	if turret_entry.is_empty():
		return

	_request_customization_action("install_turret", {
		"seat_index": seat_index,
		"scene_path": str(turret_entry.get("scene_path", "")),
		"resource_id": str(turret_entry.get("resource_id", "")),
	})


func _on_mod_slot_pressed(mod_use_id: int) -> void:
	if not _can_local_edit_customization():
		return

	var mod_state: Dictionary = tank_customization_state.get("mods", {})
	if mod_state.has(str(mod_use_id)) and not str(mod_state[str(mod_use_id)]).is_empty():
		_request_customization_action("remove_mod", {"mod_use_id": mod_use_id})
		return

	if selected_customization_type != "mod":
		return

	var mod_entry: Dictionary = _get_mod_entry_for_path(selected_customization_scene_path)
	if mod_entry.is_empty():
		return

	_request_customization_action("install_mod", {
		"mod_use_id": mod_use_id,
		"scene_path": str(mod_entry.get("scene_path", "")),
		"resource_id": str(mod_entry.get("resource_id", "")),
	})


func _can_local_edit_customization() -> bool:
	if countdown_in_progress:
		return false

	if NetworkManager.multiplayer.multiplayer_peer == null:
		return false

	if _is_local_host():
		return true

	return not customization_host_only


func _request_customization_action(action: String, payload: Dictionary) -> void:
	if not _can_local_edit_customization():
		return

	var sanitized_payload: Dictionary = _sanitize_customization_action_payload(action, payload)
	if sanitized_payload.is_empty() and action.begins_with("install_"):
		return

	if _is_local_host():
		_host_apply_customization_action(action, sanitized_payload)
		return

	_rpc_request_customization_action.rpc_id(1, action, sanitized_payload)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_customization_action(action: String, payload: Dictionary) -> void:
	if not _is_local_host():
		return

	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	if not _can_peer_edit_customization(sender_peer_id):
		return

	_host_apply_customization_action(action, payload)


func _can_peer_edit_customization(peer_id: int) -> bool:
	if countdown_in_progress:
		return false

	if not customization_host_only:
		return true

	return peer_id == multiplayer.get_unique_id()


func _sanitize_customization_action_payload(action: String, payload: Dictionary) -> Dictionary:
	var sanitized: Dictionary = payload.duplicate(true)
	match action:
		"install_turret":
			var turret_scene_path: String = _resolve_resource_scene_path_from_payload("turret", sanitized)
			if turret_scene_path.is_empty():
				return {}
			var turret_entry: Dictionary = _get_turret_entry_for_path(turret_scene_path)
			sanitized["scene_path"] = turret_scene_path
			sanitized["resource_id"] = str(turret_entry.get("resource_id", sanitized.get("resource_id", "")))
			sanitized["seat_index"] = int(sanitized.get("seat_index", -1))
		"install_mod":
			var mod_scene_path: String = _resolve_resource_scene_path_from_payload("mod", sanitized)
			if mod_scene_path.is_empty():
				return {}
			var mod_entry: Dictionary = _get_mod_entry_for_path(mod_scene_path)
			sanitized["scene_path"] = mod_scene_path
			sanitized["resource_id"] = str(mod_entry.get("resource_id", sanitized.get("resource_id", "")))
			sanitized["mod_use_id"] = int(sanitized.get("mod_use_id", -1))
		"remove_turret":
			sanitized["seat_index"] = int(sanitized.get("seat_index", -1))
		"remove_mod":
			sanitized["mod_use_id"] = int(sanitized.get("mod_use_id", -1))
		"change_chassis":
			var chassis_scene_path: String = str(sanitized.get("scene_path", ""))
			if chassis_scene_path.is_empty():
				return {}
			sanitized["scene_path"] = chassis_scene_path
		_:
			return sanitized

	return sanitized


func _resolve_resource_scene_path_from_payload(resource_type: String, payload: Dictionary) -> String:
	var scene_path: String = str(payload.get("scene_path", "")).strip_edges()
	if not scene_path.is_empty():
		match resource_type:
			"turret":
				if not _get_turret_entry_for_path(scene_path).is_empty():
					return scene_path
			"mod":
				if not _get_mod_entry_for_path(scene_path).is_empty():
					return scene_path

	var resource_id: String = str(payload.get("resource_id", "")).strip_edges()
	if resource_id.is_empty():
		return ""

	var normalized_resource_id: String = _to_resource_id(resource_id)
	match resource_type:
		"turret":
			for entry: Dictionary in turret_database:
				if _to_resource_id(str(entry.get("resource_id", ""))) == normalized_resource_id:
					return str(entry.get("scene_path", ""))
		"mod":
			for entry: Dictionary in mod_database:
				if _to_resource_id(str(entry.get("resource_id", ""))) == normalized_resource_id:
					return str(entry.get("scene_path", ""))

	return ""


func _host_apply_customization_action(action: String, payload: Dictionary) -> void:
	if not _is_local_host():
		return

	var next_state: Dictionary = tank_customization_state.duplicate(true)
	match action:
		"change_chassis":
			var chassis_scene_path: String = str(payload.get("scene_path", ""))
			var chassis_entry: Dictionary = _get_chassis_entry_for_path(chassis_scene_path)
			if chassis_entry.is_empty() or not bool(chassis_entry.get("unlocked", false)):
				return
			next_state = _build_state_from_chassis_entry(chassis_entry, false)
		"install_turret":
			var turret_scene_path: String = _resolve_resource_scene_path_from_payload("turret", payload)
			if turret_scene_path.is_empty():
				return
			if not _try_write_turret_to_state(next_state, int(payload.get("seat_index", -1)), turret_scene_path):
				return
		"remove_turret":
			var seat_index: int = int(payload.get("seat_index", -1))
			var turret_state: Dictionary = next_state.get("turrets", {})
			turret_state.erase(str(seat_index))
			next_state["turrets"] = turret_state
		"install_mod":
			var mod_scene_path: String = _resolve_resource_scene_path_from_payload("mod", payload)
			if mod_scene_path.is_empty():
				return
			if not _try_write_mod_to_state(next_state, int(payload.get("mod_use_id", -1)), mod_scene_path):
				return
		"remove_mod":
			var mod_use_id: int = int(payload.get("mod_use_id", -1))
			var mod_state: Dictionary = next_state.get("mods", {})
			mod_state.erase(str(mod_use_id))
			next_state["mods"] = mod_state
		_:
			return

	_rpc_apply_customization_state.rpc(next_state)


@rpc("authority", "call_local", "reliable")
func _rpc_apply_customization_state(new_state: Dictionary) -> void:
	_apply_tank_customization_state_local(new_state)


func _try_write_turret_to_state(state: Dictionary, seat_index: int, scene_path: String) -> bool:
	var turret_entry: Dictionary = _get_turret_entry_for_path(scene_path)
	if turret_entry.is_empty() or not bool(turret_entry.get("unlocked", false)):
		return false

	var slot: Dictionary = _get_turret_slot_for_state(state, seat_index)
	if slot.is_empty() or not _is_turret_entry_compatible_with_slot(turret_entry, slot):
		return false

	var turret_state: Dictionary = state.get("turrets", {})
	if turret_state.has(str(seat_index)) and not str(turret_state[str(seat_index)]).is_empty():
		return false

	var cost: int = int(turret_entry.get("score_cost", 0))
	if _get_score_remaining_for_state(state) < cost:
		return false

	turret_state[str(seat_index)] = scene_path
	state["turrets"] = turret_state
	return true


func _try_write_mod_to_state(state: Dictionary, mod_use_id: int, scene_path: String) -> bool:
	var mod_entry: Dictionary = _get_mod_entry_for_path(scene_path)
	if mod_entry.is_empty() or not bool(mod_entry.get("unlocked", false)):
		return false

	var slot: Dictionary = _get_mod_slot_for_state(state, mod_use_id)
	if slot.is_empty() or not _is_mod_entry_compatible_with_slot(mod_entry, slot):
		return false

	var mod_state: Dictionary = state.get("mods", {})
	if mod_state.has(str(mod_use_id)) and not str(mod_state[str(mod_use_id)]).is_empty():
		return false

	var cost: int = int(mod_entry.get("score_cost", 0))
	if _get_score_remaining_for_state(state) < cost:
		return false

	mod_state[str(mod_use_id)] = scene_path
	state["mods"] = mod_state
	return true


func _get_turret_slot_for_state(state: Dictionary, seat_index: int) -> Dictionary:
	var chassis_entry: Dictionary = _get_chassis_entry_for_path(str(state.get("chassis_scene_path", "")))
	var turret_slots: Array = chassis_entry.get("turret_slots", [])
	for slot_value in turret_slots:
		var slot: Dictionary = slot_value
		if int(slot.get("seat_index", -1)) == seat_index:
			return slot.duplicate(true)
	return {}


func _get_mod_slot_for_state(state: Dictionary, mod_use_id: int) -> Dictionary:
	var chassis_entry: Dictionary = _get_chassis_entry_for_path(str(state.get("chassis_scene_path", "")))
	var mod_slots: Array = chassis_entry.get("mod_slots", [])
	for slot_value in mod_slots:
		var slot: Dictionary = slot_value
		if int(slot.get("mod_use_id", -1)) == mod_use_id:
			return slot.duplicate(true)
	return {}


func _is_turret_entry_compatible_with_slot(turret_entry: Dictionary, slot: Dictionary) -> bool:
	if bool(slot.get("driver_turret", false)):
		return false

	var slot_size: int = int(slot.get("turret_size", 0))
	var turret_size: int = int(turret_entry.get("turret_size", 0))
	return slot_size > 0 and turret_size > 0 and turret_size <= slot_size


func _is_mod_entry_compatible_with_slot(mod_entry: Dictionary, slot: Dictionary) -> bool:
	var max_mod_size: int = int(slot.get("max_mod_size", 0))
	var mod_size: int = int(mod_entry.get("mod_size", 0))
	if max_mod_size <= 0 or mod_size <= 0 or mod_size > max_mod_size:
		return false

	var allowed_placements: Array = mod_entry.get("allowed_placements", [])
	if allowed_placements.is_empty():
		return true

	var slot_placement: String = _normalize_placement(str(slot.get("placement", "")))
	for placement_value in allowed_placements:
		if _normalize_placement(str(placement_value)) == slot_placement:
			return true

	return false


func _normalize_placement(raw_value: String) -> String:
	var normalized: String = raw_value.strip_edges().to_lower()
	if normalized == "rear" or normalized == "back" or normalized == "arriere" or normalized == "arrière":
		return "rear"
	if normalized == "front" or normalized == "avant":
		return "front"
	if normalized == "side" or normalized == "lateral" or normalized == "latéral":
		return "side"
	if normalized == "center" or normalized == "centre":
		return "center"
	return normalized


func _can_place_selected_turret_on_slot(seat_index: int) -> bool:
	if selected_customization_type != "turret":
		return false

	var turret_entry: Dictionary = _get_turret_entry_for_path(selected_customization_scene_path)
	var slot: Dictionary = _get_turret_slot_for_state(tank_customization_state, seat_index)
	if turret_entry.is_empty() or slot.is_empty():
		return false

	if not _is_turret_entry_compatible_with_slot(turret_entry, slot):
		return false

	return _get_score_remaining() >= int(turret_entry.get("score_cost", 0))


func _can_place_selected_mod_on_slot(mod_use_id: int) -> bool:
	if selected_customization_type != "mod":
		return false

	var mod_entry: Dictionary = _get_mod_entry_for_path(selected_customization_scene_path)
	var slot: Dictionary = _get_mod_slot_for_state(tank_customization_state, mod_use_id)
	if mod_entry.is_empty() or slot.is_empty():
		return false

	if not _is_mod_entry_compatible_with_slot(mod_entry, slot):
		return false

	return _get_score_remaining() >= int(mod_entry.get("score_cost", 0))


func _get_score_remaining_for_state(state: Dictionary) -> int:
	var total_score: int = int(state.get("score_total", 0))
	var total_cost: int = 0
	var turret_state: Dictionary = state.get("turrets", {})
	for key in turret_state.keys():
		var turret_entry: Dictionary = _get_turret_entry_for_path(str(turret_state[key]))
		total_cost += int(turret_entry.get("score_cost", 0))

	var mod_state: Dictionary = state.get("mods", {})
	for key in mod_state.keys():
		var mod_entry: Dictionary = _get_mod_entry_for_path(str(mod_state[key]))
		total_cost += int(mod_entry.get("score_cost", 0))

	return total_score - total_cost


func _save_lobby_vehicle_state_to_session_state() -> void:
	if tank_customization_state.is_empty():
		return

	var vehicle_state: Dictionary = _build_session_vehicle_state_from_customization()
	if vehicle_state.is_empty():
		return

	if GameSessionState.has_method("set_pending_lobby_vehicle_state"):
		GameSessionState.call("set_pending_lobby_vehicle_state", vehicle_state)
		return

	GameSessionState.vehicles[0] = vehicle_state
	GameSessionState.vehicle_snapshot_active = true


func _build_session_vehicle_state_from_customization() -> Dictionary:
	var chassis_scene_path: String = str(tank_customization_state.get("chassis_scene_path", ""))
	if chassis_scene_path.is_empty():
		return {}

	var turret_config: Array[Dictionary] = []
	var turret_state: Dictionary = tank_customization_state.get("turrets", {})
	var chassis_entry: Dictionary = _get_current_chassis_entry()
	var turret_slots: Array = chassis_entry.get("turret_slots", [])
	for slot_value in turret_slots:
		var slot: Dictionary = slot_value
		var seat_index: int = int(slot.get("seat_index", -1))
		turret_config.append({
			"seat_index": seat_index,
			"turret_scene_path": str(turret_state.get(str(seat_index), "")),
		})

	var mod_config: Array[Dictionary] = []
	var mod_state: Dictionary = tank_customization_state.get("mods", {})
	var mod_slots: Array = chassis_entry.get("mod_slots", [])
	for slot_value in mod_slots:
		var slot: Dictionary = slot_value
		var mod_use_id: int = int(slot.get("mod_use_id", -1))
		mod_config.append({
			"mod_use_id": mod_use_id,
			"mod_scene_path": str(mod_state.get(str(mod_use_id), "")),
		})

	return {
		"vehicle_index": 0,
		"scene_path": chassis_scene_path,
		"vehicle_display_name": str(tank_customization_state.get("vehicle_display_name", "Tank")),
		"chassis_id": str(tank_customization_state.get("chassis_id", "")),
		"max_health": 600,
		"health": 600,
		"is_dead": false,
		"shop_money": _get_score_remaining(),
		"customization_score_total": int(tank_customization_state.get("score_total", 0)),
		"customization_score_remaining": _get_score_remaining(),
		"turret_config": turret_config,
		"mod_config": mod_config,
		"lobby_customization_state": tank_customization_state.duplicate(true),
	}


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
	current_mission_sub_tab = CUSTOMIZATION_SUB_TAB_MISSION
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
	current_mission_sub_tab = CUSTOMIZATION_SUB_TAB_MISSION
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

	_save_lobby_vehicle_state_to_session_state()
	_rpc_start_launch_countdown.rpc(selected_mission_index)


@rpc("authority", "call_local", "reliable")
func _rpc_start_launch_countdown(mission_index: int) -> void:
	if countdown_in_progress:
		return

	if mission_index < 0 or mission_index >= MISSIONS.size():
		return

	_set_selected_mission(mission_index)
	current_mission_sub_tab = CUSTOMIZATION_SUB_TAB_MISSION
	_save_lobby_vehicle_state_to_session_state()
	countdown_in_progress = true
	countdown_layer.visible = true
	_refresh_ui()

	var mission: Dictionary = MISSIONS[mission_index]
	var scene_path: String = str(mission.get("scene_path", "")).strip_edges()
	if scene_path.is_empty():
		if _is_local_host():
			_rpc_cancel_launch_countdown.rpc("Chemin de mission invalide.")
		return

	NetworkManager.GAME_SCENE_PATH = scene_path
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
	var resolved_scene_path: String = scene_path.strip_edges()
	if resolved_scene_path.is_empty():
		_rpc_cancel_launch_countdown.rpc("Chemin de mission invalide.")
		return

	if not NetworkManager.has_method("start_game"):
		_rpc_cancel_launch_countdown.rpc("NetworkManager.start_game() est introuvable.")
		return

	NetworkManager.call("start_game", resolved_scene_path)


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
	if hangar_camera == null:
		return

	_stop_background_animation_tweens()

	if background_animation_player != null:
		background_animation_player.stop(false)

	match animation_name:
		START_LOBBY_ANIMATION:
			_tween_background_to_start_lobby()
		SELECT_MISSION_ANIMATION:
			_tween_background_to_select_mission()
		TANK_CUSTOMIZATION_ANIMATION:
			_tween_background_to_tank_customization()
		_:
			return


func _stop_background_animation_tweens() -> void:
	for background_tween: Tween in background_animation_tweens:
		if background_tween != null and background_tween.is_valid():
			background_tween.kill()

	background_animation_tweens.clear()


func _tween_background_to_start_lobby() -> void:
	_set_black_fade_state(true, Color(1.0, 1.0, 1.0, 1.0))
	
	hangar_camera.position = Vector3(-8, 5, 0)
	hangar_camera.rotation_degrees = Vector3(-25, -90, 0)
	
	var tween: Tween = _create_background_camera_tween(START_LOBBY_CAMERA_TWEEN_DURATION)
	_tween_camera_position(tween, START_LOBBY_CAMERA_POSITION, START_LOBBY_CAMERA_TWEEN_DURATION)
	_tween_camera_rotation(tween, START_LOBBY_CAMERA_ROTATION, START_LOBBY_CAMERA_TWEEN_DURATION)
	_tween_camera_dof_far_distance(tween, START_LOBBY_DOF_FAR_DISTANCE, START_LOBBY_CAMERA_TWEEN_DURATION)
	_tween_black_fade_to_clear(tween, START_LOBBY_FADE_DURATION)


func _tween_background_to_select_mission() -> void:
	_set_black_fade_state(false, Color(1.0, 1.0, 1.0, 0.0))

	var tween: Tween = _create_background_camera_tween(SELECT_MISSION_CAMERA_TWEEN_DURATION)
	_tween_camera_position(tween, SELECT_MISSION_CAMERA_POSITION, SELECT_MISSION_CAMERA_TWEEN_DURATION)
	_tween_camera_rotation(tween, SELECT_MISSION_CAMERA_ROTATION, SELECT_MISSION_CAMERA_TWEEN_DURATION)
	_tween_camera_dof_far_distance(tween, SELECT_MISSION_DOF_FAR_DISTANCE, SELECT_MISSION_CAMERA_TWEEN_DURATION)


func _tween_background_to_tank_customization() -> void:
	_set_black_fade_state(false, Color(1.0, 1.0, 1.0, 0.0))

	var target_rotation: Vector3 = _get_camera_rotation_looking_at(
		TANK_CUSTOMIZATION_CAMERA_POSITION,
		TANK_CUSTOMIZATION_CAMERA_LOOK_AT
	)

	var tween: Tween = _create_background_camera_tween(TANK_CUSTOMIZATION_CAMERA_TWEEN_DURATION)
	_tween_camera_position(tween, TANK_CUSTOMIZATION_CAMERA_POSITION, TANK_CUSTOMIZATION_CAMERA_TWEEN_DURATION)
	_tween_camera_rotation(tween, target_rotation, TANK_CUSTOMIZATION_CAMERA_TWEEN_DURATION)
	_tween_camera_dof_far_distance(tween, TANK_CUSTOMIZATION_DOF_FAR_DISTANCE, TANK_CUSTOMIZATION_CAMERA_TWEEN_DURATION)


func _create_background_camera_tween(duration: float) -> Tween:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(background_animation_tween_transition)
	tween.set_ease(background_animation_tween_ease)
	background_animation_tweens.append(tween)
	return tween


func _tween_camera_position(tween: Tween, target_position: Vector3, duration: float) -> void:
	if tween == null or hangar_camera == null:
		return

	tween.tween_property(hangar_camera, "position", target_position, duration)


func _tween_camera_rotation(tween: Tween, target_rotation: Vector3, duration: float) -> void:
	if tween == null or hangar_camera == null:
		return

	tween.tween_property(hangar_camera, "rotation", target_rotation, duration)


func _tween_black_fade_to_clear(tween: Tween, duration: float) -> void:
	if tween == null or black_fade_intro == null:
		return

	tween.tween_property(black_fade_intro, "self_modulate", Color(1.0, 1.0, 1.0, 0.0), duration)
	tween.tween_callback(func() -> void:
		if black_fade_intro != null:
			black_fade_intro.visible = false
	).set_delay(duration)


func _tween_camera_dof_far_distance(tween: Tween, target_distance: float, duration: float) -> void:
	if tween == null or hangar_camera == null:
		return

	if hangar_camera.attributes == null:
		return

	tween.tween_property(hangar_camera.attributes, "dof_blur_far_distance", target_distance, duration)


func _get_camera_rotation_looking_at(camera_position: Vector3, look_at_position: Vector3) -> Vector3:
	var direction: Vector3 = look_at_position - camera_position
	if direction.length_squared() <= 0.0001:
		return hangar_camera.rotation

	var target_basis: Basis = Basis.looking_at(direction.normalized(), Vector3.UP)
	return target_basis.get_euler()


func _set_black_fade_state(is_visible: bool, modulate_color: Color) -> void:
	if black_fade_intro == null:
		return

	black_fade_intro.visible = is_visible
	black_fade_intro.self_modulate = modulate_color

func _on_debug_start_button_up():
	if not is_inside_tree():
		return
	
	if NetworkManager.multiplayer.multiplayer_peer == null:
		status_label.text = "Connexion réseau inactive."
		return
	
	NetworkManager.set_local_ready(not NetworkManager.is_local_player_ready())
	
	if _is_local_host():
		_network_start_game("res://scenes/game/Mission_01_A_Outpost.tscn")
