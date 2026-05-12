extends CanvasLayer
class_name PlayerHUD

signal respawn_requested

#const PLAYER_NAME_MARKER_SCENE: PackedScene = preload("res://scenes/ui/PlayerNameMarker.tscn")
const VEHICLE_MOD_SLOT_SCENE: PackedScene = preload("res://scenes/ui/VehicleModSlotHUD.tscn")

@export var refresh_every_frame: bool = true
@export var show_local_player_name_marker: bool = false
@export var name_marker_margin: float = 24.0
@export var name_marker_scene: PackedScene #= PLAYER_NAME_MARKER_SCENE
@export var vehicle_name_marker_scene: PackedScene
@export var show_vehicle_name_marker: bool = true
@export var vehicle_marker_world_height: float = 2.6

@export_group("Repair Target Bar")
@export var repair_bar_screen_offset: Vector2 = Vector2(0.0, -84.0)
@export var repair_bar_world_height: float = 2.4
@export var repair_bar_hide_delay: float = 1.0

@onready var common_panel: PanelContainer = %CommonPanel #$Root/LeftMargin/LeftVBox/CommonPanel
@onready var hp_label: Label = %HPLabel #$Root/LeftMargin/LeftVBox/CommonPanel/CommonMargin/CommonVBox/HPLabel
@onready var health_progress_bar: ProgressBar = %HealthProgressBar
@onready var ammo_9mm: Label = %Ammo_9MM
@onready var ammo_rifle: Label = %Ammo_Rifle
@onready var ammo_shell: Label = %Ammo_Shell
@onready var ammo_rocket: Label = %Ammo_Rocket
@onready var ammo_energy := %Ammo_Energy

@onready var on_foot_panel: PanelContainer = %OnFootPanel
@onready var equipped_weapon_label: Label = %EquippedWeaponLabel
@onready var weapon_1_label: Label = %Weapon1Label
@onready var weapon_2_label: Label = %Weapon2Label
@onready var ammo_label: Label = %AmmoLabel
@onready var money_label: Label = %MoneyLabel
@onready var reserve_label: Label = %ReserveLabel
@onready var reload_panel: PanelContainer = %ReloadPanel
@onready var reload_label: Label = %ReloadLabel
@onready var reload_progress_bar: ProgressBar = %ReloadProgress

@onready var vehicle_panel: PanelContainer = %VehiclePanel
@onready var vehicle_name_label: Label = %VehicleNameLabel
@onready var vehicle_health_label = %VehicleHealthLabel
@onready var vehicle_fuel_progress_bar: ProgressBar = %VehicleFuelProgress
@onready var vehicle_fuel_value_label: Label = %VehicleFuelValueLabel
@onready var current_seat_label: Label = %CurrentSeatLabel
@onready var seat_1_label: RichTextLabel = %Seat1Label
@onready var seat_2_label: RichTextLabel = %Seat2Label
@onready var seat_3_label: RichTextLabel = %Seat3Label
@onready var seat_4_label: RichTextLabel = %Seat4Label
@onready var seat_5_label: RichTextLabel = %Seat5Label
@onready var seat_6_label: RichTextLabel = %Seat6Label
@onready var turret_label: Label = %TurretLabel
@onready var turret_ammo_label: Label = %TurretAmmo
@onready var vehicle_mods_panel: PanelContainer = %VehicleModsPanel
@onready var vehicle_mods_grid: GridContainer = %VehicleModsGrid

var player: Node = null
var _seat_labels: Array[RichTextLabel] = []
var _vehicle_mod_slot_nodes: Array[Control] = []
@onready var death_overlay: Control = %DeathOverlay
@onready var death_message_label: Label = %DeathMessageLabel
@onready var respawn_countdown_label: Label = %RespawnCountdownLabel
@onready var death_revive_label: Label = %DeathReviveLabel
@onready var death_revive_progress: ProgressBar = %DeathReviveProgress
@onready var respawn_button: Button = %RespawnButton
@onready var revive_panel: PanelContainer = %RevivePanel
@onready var revive_label: Label = %ReviveLabel
@onready var revive_progress_bar: ProgressBar = %ReviveProgress
@onready var player_name_layer: Control = %PlayerNameLayer
@onready var vehicle_name_layer: Control = %VehicleNameLayer
@onready var tank_health_panel: PanelContainer = %TankHealthPanel
@onready var tank_health_name_label: Label = %TankHealthNameLabel
@onready var tank_health_progress_bar: ProgressBar = %TankHealthProgress
@onready var tank_health_value_label: Label = %TankHealthValueLabel
@onready var passage_panel: PanelContainer = %PassagePanel
@onready var passage_label: Label = %PassageLabel
@onready var passage_progress: ProgressBar = %PassageProgress
@onready var repair_target_panel: PanelContainer = %RepairTargetPanel
@onready var repair_target_label: Label = %RepairTargetLabel
@onready var repair_target_progress: ProgressBar = %RepairTargetProgress
var respawn_pending: bool = false
var _name_marker_labels: Dictionary = {}
var _vehicle_name_marker: Control = null
var _vehicle_marker_target_id: int = 0
var _passage_prompt_owner_id: int = 0
var _repair_target: Node = null
var _repair_target_hide_timer: float = 0.0

const SELF_COLOR := "#7CFF7C"
const EMPTY_SEAT_TEXT := "Libre"

func _ready() -> void:
	add_to_group("player_huds")
	layer = 1
	_seat_labels = [
		seat_1_label,
		seat_2_label,
		seat_3_label,
		seat_4_label,
		seat_5_label,
		seat_6_label,
	]

	for label in _seat_labels:
		label.bbcode_enabled = true
		label.fit_content = true
		label.scroll_active = false

	if not respawn_button.pressed.is_connected(_on_respawn_button_pressed):
		respawn_button.pressed.connect(_on_respawn_button_pressed)

	death_overlay.visible = false
	death_revive_label.visible = false
	death_revive_progress.visible = false
	revive_panel.visible = false
	hide_passage_prompt()
	hide_repair_target(true)
	hide_reload_progress()
	_hide_vehicle_fuel_bar()
	_hide_vehicle_mod_slots()
	_hide_tank_health_bar()
	_hide_vehicle_name_marker()
	_refresh_all()

func _process(delta: float) -> void:
	if refresh_every_frame:
		_refresh_all()

	_update_repair_target_bar(delta)

func set_player(p_player: Node) -> void:
	player = p_player
	_refresh_all()

func get_player() -> Node:
	return player

func show_passage_prompt(message: String, progress: float = -1.0, owner_node: Node = null) -> void:
	if passage_panel == null or passage_label == null:
		return

	if owner_node != null and is_instance_valid(owner_node):
		_passage_prompt_owner_id = owner_node.get_instance_id()
	else:
		_passage_prompt_owner_id = 0

	passage_panel.visible = true
	passage_panel.modulate.a = 1.0
	passage_label.visible = true
	passage_label.text = message

	if passage_progress == null:
		return

	if progress >= 0.0:
		passage_progress.visible = true
		passage_progress.value = clamp(progress, 0.0, 1.0) * 100.0
	else:
		passage_progress.visible = false
		passage_progress.value = 0.0


func hide_passage_prompt(owner_node: Node = null) -> void:
	if owner_node != null and is_instance_valid(owner_node):
		var owner_id: int = owner_node.get_instance_id()
		if _passage_prompt_owner_id != 0 and _passage_prompt_owner_id != owner_id:
			return

	_passage_prompt_owner_id = 0

	if passage_panel != null:
		passage_panel.visible = false
	if passage_label != null:
		passage_label.text = ""
	if passage_progress != null:
		passage_progress.visible = false
		passage_progress.value = 0.0

func _refresh_all() -> void:
	if not is_instance_valid(player):
		visible = false
		_clear_name_markers()
		_hide_vehicle_name_marker()
		_hide_tank_health_bar()
		_hide_vehicle_fuel_bar()
		_hide_vehicle_mod_slots()
		hide_repair_target(true)
		hide_reload_progress()
		return

	visible = true

	var player_data: Dictionary = _get_player_hud_data()
	var in_vehicle: bool = bool(player_data.get("in_vehicle", false))
	var is_dead: bool = bool(player_data.get("is_dead", false))
	var tracked_vehicle: Node = _get_tracked_vehicle(player_data)

	_refresh_player_name_markers()
	_refresh_tank_health_bar(player_data, tracked_vehicle)
	_refresh_vehicle_name_marker(player_data, tracked_vehicle, in_vehicle, is_dead)

	if is_dead:
		common_panel.visible = false
		on_foot_panel.visible = false
		vehicle_panel.visible = false
		_hide_vehicle_fuel_bar()
		_hide_vehicle_mod_slots()
		hide_repair_target(true)
		hide_reload_progress()
		_show_death_overlay(player_data)
		_refresh_revive_panel(player_data)
		return

	_hide_death_overlay()
	_refresh_common(player_data)
	_refresh_on_foot(player_data)
	_refresh_reload_progress(player_data)
	_refresh_vehicle(player_data, tracked_vehicle)
	_refresh_revive_panel(player_data)

	common_panel.visible = true
	on_foot_panel.visible = not in_vehicle
	vehicle_panel.visible = in_vehicle
	if not in_vehicle:
		_hide_vehicle_fuel_bar()
		_hide_vehicle_mod_slots()

func _show_death_overlay(player_data: Dictionary) -> void:
	death_overlay.visible = true

	var hp: int = int(player_data.get("hp", 0))
	death_message_label.text = "Vous êtes mort." if hp <= 0 else "Vous êtes hors combat."

	var remaining: float = float(player_data.get("respawn_remaining", 0.0))
	var respawn_available: bool = bool(player_data.get("respawn_available", true))

	if respawn_available:
		respawn_countdown_label.text = "Respawn disponible."
		respawn_button.text = "Respawn"
	else:
		respawn_countdown_label.text = "Respawn disponible dans %.1fs" % remaining
		respawn_button.text = "Respawn (%.1fs)" % remaining

	respawn_button.disabled = respawn_pending or not respawn_available
	if respawn_available and not respawn_pending and not respawn_button.has_focus():
		respawn_button.grab_focus()

	_refresh_death_revive_progress(player_data)

func _hide_death_overlay() -> void:
	respawn_pending = false
	death_overlay.visible = false
	death_revive_label.visible = false
	death_revive_progress.visible = false
	respawn_button.text = "Respawn"
	respawn_button.disabled = false

func _on_respawn_button_pressed() -> void:
	if respawn_pending or respawn_button.disabled:
		return

	respawn_pending = true
	respawn_button.disabled = true
	emit_signal("respawn_requested")

func _refresh_death_revive_progress(player_data: Dictionary) -> void:
	var active: bool = bool(player_data.get("revive_active", false))
	var role: int = int(player_data.get("revive_role", 0))

	if not active or role != 2:
		death_revive_label.visible = false
		death_revive_progress.visible = false
		death_revive_progress.value = 0.0
		return

	var other_name: String = str(player_data.get("revive_other_player_name", "un allié"))
	var progress_value: float = clamp(float(player_data.get("revive_progress", 0.0)), 0.0, 1.0)
	death_revive_label.visible = true
	death_revive_progress.visible = true
	death_revive_label.text = "Réanimation par %s" % other_name
	death_revive_progress.value = progress_value * 100.0

func _refresh_revive_panel(player_data: Dictionary) -> void:
	var active: bool = bool(player_data.get("revive_active", false))
	var role: int = int(player_data.get("revive_role", 0))

	if not active or role != 1:
		revive_panel.visible = false
		revive_progress_bar.value = 0.0
		return

	var other_name: String = str(player_data.get("revive_other_player_name", "un allié"))
	var progress_value: float = clamp(float(player_data.get("revive_progress", 0.0)), 0.0, 1.0)
	revive_panel.visible = true
	revive_label.text = "Réanimation de %s" % other_name
	revive_progress_bar.value = progress_value * 100.0

func show_repair_target(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return

	_repair_target = target
	_repair_target_hide_timer = max(repair_bar_hide_delay, 0.0)

	if repair_target_panel != null:
		repair_target_panel.visible = true
		repair_target_panel.modulate.a = 1.0

	_update_repair_target_bar(0.0)


func hide_repair_target(force: bool = false) -> void:
	if force:
		_repair_target = null
		_repair_target_hide_timer = 0.0
		if repair_target_panel != null:
			repair_target_panel.visible = false
		return

	_repair_target_hide_timer = min(_repair_target_hide_timer, repair_bar_hide_delay)


func _update_repair_target_bar(delta: float) -> void:
	if repair_target_panel == null:
		return

	if _repair_target_hide_timer > 0.0:
		_repair_target_hide_timer = max(_repair_target_hide_timer - delta, 0.0)

	if _repair_target == null or not is_instance_valid(_repair_target):
		hide_repair_target(true)
		return

	if _repair_target_hide_timer <= 0.0:
		hide_repair_target(true)
		return

	var data := _get_repair_target_data(_repair_target)
	var current_hp: int = int(data.get("health", 0))
	var max_hp: int = max(int(data.get("max_health", 0)), 1)
	var target_name: String = str(data.get("name", "Tank"))

	repair_target_label.text = "%s : %d / %d" % [target_name, current_hp, max_hp]
	repair_target_progress.min_value = 0.0
	repair_target_progress.max_value = float(max_hp)
	repair_target_progress.value = float(clampi(current_hp, 0, max_hp))

	_update_repair_target_screen_position(_repair_target)
	repair_target_panel.visible = true


func _get_repair_target_data(target: Node) -> Dictionary:
	if target == null or not is_instance_valid(target):
		return {}

	if target.has_method("get_hud_data_for_player"):
		var hud_data = target.call("get_hud_data_for_player", player)
		if hud_data is Dictionary:
			return {
				"name": str(hud_data.get("vehicle_name", target.name)),
				"health": int(hud_data.get("health", 0)),
				"max_health": int(hud_data.get("max_health", 1)),
			}

	var out := {
		"name": _read_repair_target_name(target),
		"health": _read_repair_target_int(target, ["health", "current_health", "hp"], 0),
		"max_health": _read_repair_target_int(target, ["max_health", "maximum_health", "max_hp"], 1),
	}
	return out


func _read_repair_target_name(target: Node) -> String:
	if target == null or not is_instance_valid(target):
		return "Tank"

	for property_name in ["vehicle_display_name", "display_name", "hud_name"]:
		var value = target.get(property_name)
		if value != null and not str(value).is_empty():
			return str(value)

	return target.name


func _read_repair_target_int(target: Node, property_names: Array, fallback: int) -> int:
	if target == null or not is_instance_valid(target):
		return fallback

	for property_name in property_names:
		var getter_name := "get_%s" % str(property_name)
		if target.has_method(getter_name):
			return int(target.call(getter_name))

		var value = target.get(str(property_name))
		if value != null:
			return int(value)

	return fallback


func _update_repair_target_screen_position(target: Node) -> void:
	var camera := _get_hud_camera()
	if camera == null or repair_target_panel == null:
		return

	var world_position := _get_repair_target_world_position(target)
	if camera.is_position_behind(world_position):
		repair_target_panel.visible = false
		return

	var screen_position := camera.unproject_position(world_position) + repair_bar_screen_offset
	var panel_size := repair_target_panel.get_combined_minimum_size()
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		panel_size = repair_target_panel.size

	repair_target_panel.size = panel_size
	repair_target_panel.position = screen_position - panel_size * 0.5


func _get_repair_target_world_position(target: Node) -> Vector3:
	if target != null and target.has_method("get_repair_hud_world_position"):
		var value = target.call("get_repair_hud_world_position")
		if value is Vector3:
			return value

	if target is Node3D:
		return (target as Node3D).global_position + Vector3.UP * repair_bar_world_height

	return Vector3.ZERO


func _refresh_player_name_markers() -> void:
	if player_name_layer == null:
		return

	var camera: Camera3D = _get_hud_camera()
	if camera == null:
		_clear_name_markers()
		return

	var active_keys: Dictionary = {}
	for target in get_tree().get_nodes_in_group("players"):
		if target == null or not is_instance_valid(target):
			continue
		if target == player and not show_local_player_name_marker:
			continue
		if not (target is Node3D):
			continue

		var key: String = str(target.get_instance_id())
		active_keys[key] = true
		var marker: Control = _get_or_create_name_marker(key)
		if marker == null:
			continue

		_set_name_marker_text(marker, _get_player_marker_text(target))
		var world_position: Vector3 = _get_player_marker_world_position(target)
		var screen_data: Dictionary = _world_position_to_clamped_screen(camera, world_position)
		var marker_size: Vector2 = marker.get_combined_minimum_size()
		marker.size = marker_size
		marker.position = Vector2(screen_data.get("x", 0.0), screen_data.get("y", 0.0)) - marker_size * 0.5
		marker.visible = true

	for key in _name_marker_labels.keys():
		if active_keys.has(key):
			continue
		var stale_marker = _name_marker_labels.get(key)
		if stale_marker != null and is_instance_valid(stale_marker):
			stale_marker.queue_free()
		_name_marker_labels.erase(key)

func _get_or_create_name_marker(key: String) -> Control:
	var existing = _name_marker_labels.get(key, null)
	if existing != null and is_instance_valid(existing):
		return existing as Control

	if name_marker_scene == null:
		push_error("PlayerHUD.name_marker_scene est vide.")
		return null

	var marker: Control = name_marker_scene.instantiate() as Control
	if marker == null:
		push_error("La scène de marqueur de nom doit hériter de Control.")
		return null

	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_name_layer.add_child(marker)
	_name_marker_labels[key] = marker
	return marker

func _set_name_marker_text(marker: Control, text: String) -> void:
	if marker.has_method("set_marker_text"):
		marker.call("set_marker_text", text)
		return

	var label: Label = marker.get_node_or_null("NameLabel") as Label
	if label != null:
		label.text = text

func _clear_name_markers() -> void:
	for key in _name_marker_labels.keys():
		var marker = _name_marker_labels.get(key)
		if marker != null and is_instance_valid(marker):
			marker.queue_free()
	_name_marker_labels.clear()

func _refresh_tank_health_bar(player_data: Dictionary, tracked_vehicle: Node) -> void:
	if tank_health_panel == null:
		return

	var tank_data: Dictionary = _get_tracked_vehicle_hud_data(player_data, tracked_vehicle)
	if tank_data.is_empty():
		_hide_tank_health_bar()
		return

	var tank_name: String = str(tank_data.get("vehicle_name", tank_data.get("name", "Tank")))
	var max_hp: int = max(int(tank_data.get("max_health", tank_data.get("max_hp", 1))), 1)
	var hp: int = clampi(int(tank_data.get("health", tank_data.get("hp", 0))), 0, max_hp)

	tank_health_panel.visible = true
	tank_health_name_label.text = tank_name
	tank_health_progress_bar.min_value = 0.0
	tank_health_progress_bar.max_value = float(max_hp)
	tank_health_progress_bar.value = float(hp)
	tank_health_value_label.text = "%d/%d" % [hp, max_hp]


func _hide_tank_health_bar() -> void:
	if tank_health_panel != null:
		tank_health_panel.visible = false
	if tank_health_progress_bar != null:
		tank_health_progress_bar.value = 0.0
	if tank_health_value_label != null:
		tank_health_value_label.text = "0/0"


func _refresh_vehicle_name_marker(player_data: Dictionary, tracked_vehicle: Node, in_vehicle: bool, is_dead: bool) -> void:
	if not show_vehicle_name_marker or in_vehicle or is_dead:
		_hide_vehicle_name_marker()
		return

	if tracked_vehicle == null or not is_instance_valid(tracked_vehicle) or not (tracked_vehicle is Node3D):
		_hide_vehicle_name_marker()
		return

	var camera: Camera3D = _get_hud_camera()
	if camera == null:
		_hide_vehicle_name_marker()
		return

	var marker: Control = _get_or_create_vehicle_name_marker(tracked_vehicle)
	if marker == null:
		return

	var tank_data: Dictionary = _get_tracked_vehicle_hud_data(player_data, tracked_vehicle)
	_set_name_marker_text(marker, _get_vehicle_marker_text(tracked_vehicle, tank_data))

	var world_position: Vector3 = _get_vehicle_marker_world_position(tracked_vehicle)
	var screen_data: Dictionary = _world_position_to_clamped_screen(camera, world_position)
	var marker_size: Vector2 = marker.get_combined_minimum_size()
	marker.size = marker_size
	marker.position = Vector2(float(screen_data.get("x", 0.0)), float(screen_data.get("y", 0.0))) - marker_size * 0.5
	marker.visible = true


func _get_or_create_vehicle_name_marker(tracked_vehicle: Node) -> Control:
	var tracked_vehicle_id: int = tracked_vehicle.get_instance_id()
	if _vehicle_name_marker != null and is_instance_valid(_vehicle_name_marker) and _vehicle_marker_target_id == tracked_vehicle_id:
		return _vehicle_name_marker

	_hide_vehicle_name_marker()

	if vehicle_name_layer == null:
		return null

	if vehicle_name_marker_scene == null:
		push_error("PlayerHUD.vehicle_name_marker_scene est vide.")
		return null

	var marker: Control = vehicle_name_marker_scene.instantiate() as Control
	if marker == null:
		push_error("La scène de marqueur de véhicule doit hériter de Control.")
		return null

	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vehicle_name_layer.add_child(marker)
	_vehicle_name_marker = marker
	_vehicle_marker_target_id = tracked_vehicle_id
	return marker


func _hide_vehicle_name_marker() -> void:
	if _vehicle_name_marker != null and is_instance_valid(_vehicle_name_marker):
		_vehicle_name_marker.queue_free()
	_vehicle_name_marker = null
	_vehicle_marker_target_id = 0


func _get_tracked_vehicle(player_data: Dictionary) -> Node:
	var vehicle_from_data: Node = _find_vehicle_in_dictionary(player_data)
	if vehicle_from_data != null:
		return vehicle_from_data

	if player != null and is_instance_valid(player):
		var method_names: Array[String] = [
			"get_tracked_vehicle",
			"get_current_vehicle",
			"get_vehicle",
			"get_owned_vehicle",
			"get_last_vehicle",
			"get_tank",
			"get_assigned_vehicle",
		]
		for method_name: String in method_names:
			if player.has_method(method_name):
				var method_vehicle: Node = _as_valid_vehicle_node(player.call(method_name))
				if method_vehicle != null:
					return method_vehicle

		var property_names: Array[String] = [
			"vehicle",
			"current_vehicle",
			"owned_vehicle",
			"last_vehicle",
			"tank",
			"assigned_vehicle",
			"nearby_vehicle",
			"target_vehicle",
		]
		for property_name: String in property_names:
			var property_vehicle: Node = _as_valid_vehicle_node(player.get(property_name))
			if property_vehicle != null:
				return property_vehicle

	return _find_vehicle_in_common_groups()


func _find_vehicle_in_dictionary(data: Dictionary) -> Node:
	var key_names: Array[String] = [
		"vehicle",
		"current_vehicle",
		"owned_vehicle",
		"last_vehicle",
		"tank",
		"assigned_vehicle",
		"nearby_vehicle",
		"target_vehicle",
	]

	for key_name: String in key_names:
		var vehicle: Node = _as_valid_vehicle_node(data.get(key_name, null))
		if vehicle != null:
			return vehicle

	return null


func _find_vehicle_in_common_groups() -> Node:
	var group_names: Array[String] = ["tanks", "tank", "vehicles", "vehicle"]
	for group_name: String in group_names:
		for candidate in get_tree().get_nodes_in_group(group_name):
			var vehicle: Node = _as_valid_vehicle_node(candidate)
			if vehicle == null or not (vehicle is Node3D):
				continue
			if vehicle.has_method("get_hud_data_for_player") or vehicle.has_method("get_repair_hud_world_position"):
				return vehicle
			var max_health_value = vehicle.get("max_health")
			if max_health_value != null:
				return vehicle

	return null


func _as_valid_vehicle_node(value: Variant) -> Node:
	if value is Node and is_instance_valid(value):
		return value as Node
	return null


func _get_tracked_vehicle_hud_data(player_data: Dictionary, tracked_vehicle: Node) -> Dictionary:
	var data: Dictionary = {}

	if tracked_vehicle != null and is_instance_valid(tracked_vehicle) and tracked_vehicle.has_method("get_hud_data_for_player"):
		var method_data = tracked_vehicle.call("get_hud_data_for_player", player)
		if method_data is Dictionary:
			data = method_data

	if data.is_empty() and player_data.has("vehicle_data") and player_data["vehicle_data"] is Dictionary:
		data = player_data["vehicle_data"]

	if data.is_empty() and player_data.has("tank_data") and player_data["tank_data"] is Dictionary:
		data = player_data["tank_data"]

	if data.is_empty() and tracked_vehicle != null and is_instance_valid(tracked_vehicle):
		data = _get_repair_target_data(tracked_vehicle)

	if data.is_empty() and _player_data_has_flat_vehicle_health(player_data):
		data = {
			"vehicle_name": str(player_data.get("vehicle_name", player_data.get("tank_name", "Tank"))),
			"health": int(player_data.get("vehicle_health", player_data.get("tank_health", 0))),
			"max_health": int(player_data.get("vehicle_max_health", player_data.get("tank_max_health", 1))),
		}

	if data.is_empty():
		return {}

	return {
		"vehicle_name": str(data.get("vehicle_name", data.get("name", "Tank"))),
		"health": int(data.get("health", data.get("hp", 0))),
		"max_health": int(data.get("max_health", data.get("max_hp", 1))),
	}


func _player_data_has_flat_vehicle_health(player_data: Dictionary) -> bool:
	return player_data.has("vehicle_health") or player_data.has("tank_health")


func _get_vehicle_marker_text(tracked_vehicle: Node, tank_data: Dictionary) -> String:
	if not tank_data.is_empty():
		return str(tank_data.get("vehicle_name", tank_data.get("name", "Tank")))

	return _read_repair_target_name(tracked_vehicle)


func _get_vehicle_marker_world_position(tracked_vehicle: Node) -> Vector3:
	if tracked_vehicle.has_method("get_hud_vehicle_marker_position"):
		var vehicle_marker_position = tracked_vehicle.call("get_hud_vehicle_marker_position")
		if vehicle_marker_position is Vector3:
			return vehicle_marker_position

	if tracked_vehicle.has_method("get_hud_name_marker_position"):
		var name_marker_position = tracked_vehicle.call("get_hud_name_marker_position")
		if name_marker_position is Vector3:
			return name_marker_position

	if tracked_vehicle.has_method("get_repair_hud_world_position"):
		var repair_marker_position = tracked_vehicle.call("get_repair_hud_world_position")
		if repair_marker_position is Vector3:
			return repair_marker_position

	if tracked_vehicle is Node3D:
		return (tracked_vehicle as Node3D).global_position + Vector3.UP * vehicle_marker_world_height

	return Vector3.ZERO

func _get_hud_camera() -> Camera3D:
	if player != null and player.has_method("get_hud_camera"):
		var camera = player.call("get_hud_camera")
		if camera is Camera3D and is_instance_valid(camera):
			return camera
	return get_viewport().get_camera_3d()

func _get_player_marker_world_position(target: Node) -> Vector3:
	if target.has_method("get_hud_name_marker_position"):
		var position = target.call("get_hud_name_marker_position")
		if position is Vector3:
			return position

	if target is Node3D:
		return (target as Node3D).global_position + Vector3.UP * 2.1

	return Vector3.ZERO

func _get_player_marker_text(target: Node) -> String:
	var base_name := "Player"
	if "player_name" in target:
		base_name = str(target.get("player_name"))

	if bool(target.get("is_dead")):
		return "%s (KO)" % base_name

	return base_name

func _world_position_to_clamped_screen(camera: Camera3D, world_position: Vector3) -> Dictionary:
	var viewport_size := get_viewport().get_visible_rect().size
	var margin :float = max(name_marker_margin, 0.0)
	var center := viewport_size * 0.5
	var screen_position := camera.unproject_position(world_position)
	var behind_camera := camera.is_position_behind(world_position)

	if behind_camera:
		var local_position: Vector3 = camera.global_transform.affine_inverse() * world_position
		var direction := Vector2(local_position.x, -local_position.y)
		if direction.length_squared() <= 0.001:
			direction = Vector2(0.0, 1.0)
		screen_position = center + direction.normalized() * max(viewport_size.x, viewport_size.y)

	var clamped_position := Vector2(
		clamp(screen_position.x, margin, viewport_size.x - margin),
		clamp(screen_position.y, margin, viewport_size.y - margin)
	)

	return {
		"x": clamped_position.x,
		"y": clamped_position.y,
		"offscreen": behind_camera or clamped_position != screen_position,
	}

func _refresh_common(player_data: Dictionary) -> void:
	var hp: int = int(player_data.get("hp", 0))
	var max_hp: int = int(player_data.get("max_hp", 0))
	hp_label.text = "PV : "+str(hp)+" / "+str(max_hp) #) % [str(hp), str(max_hp)]
	health_progress_bar.value = hp
	health_progress_bar.max_value = max_hp

func _refresh_on_foot(player_data: Dictionary) -> void:
	var weapon_1_name: String = str(player_data.get("weapon_1_name", "Aucune"))
	var weapon_2_name: String = str(player_data.get("weapon_2_name", "Aucune"))
	var equipped_weapon_name: String = str(player_data.get("equipped_weapon_name", "Aucune"))
	var mag_ammo: int = int(player_data.get("mag_ammo", 0))
	var reserve_ammo: int = int(player_data.get("reserve_ammo", 0))
	var money: int = int(player_data.get("money", 0))

	equipped_weapon_label.text = "Arme équipée : %s" % equipped_weapon_name
	
	if equipped_weapon_name == weapon_1_name:
		weapon_1_label.modulate = Color.WHITE
	else:
		weapon_1_label.modulate = Color.GRAY
	
	if equipped_weapon_name == weapon_2_name:
		weapon_2_label.modulate = Color.WHITE
	else:
		weapon_2_label.modulate = Color.GRAY
	
	weapon_1_label.text = "Arme 1 : %s" % weapon_1_name
	weapon_2_label.text = "Arme 2 : %s" % weapon_2_name
	ammo_label.text = "Munitions : %d / %d" % [mag_ammo, reserve_ammo]
	
	_build_reserve_ui(player_data)
	
	#reserve_label.text = _build_reserve_text(player_data)
	money_label.text = str(money) #"Argent : %d" % money

func _refresh_reload_progress(player_data: Dictionary) -> void:
	var reload_active: bool = bool(player_data.get("reload_active", false))
	var reload_duration: float = max(float(player_data.get("reload_duration", 0.0)), 0.0)
	var reload_remaining: float = max(float(player_data.get("reload_remaining", 0.0)), 0.0)

	if not reload_active or reload_duration <= 0.0:
		hide_reload_progress()
		return

	var normalized_progress: float = 1.0 - (reload_remaining / reload_duration)
	show_reload_progress(normalized_progress)

func show_reload_progress(progress: float) -> void:
	if reload_panel == null or reload_progress_bar == null:
		return

	var normalized_progress: float = clamp(progress, 0.0, 1.0)
	reload_panel.visible = true
	reload_progress_bar.min_value = 0.0
	reload_progress_bar.max_value = 100.0
	reload_progress_bar.value = normalized_progress * 100.0

	if reload_label != null:
		reload_label.text = "Rechargement : %d s" % normalized_progress  #roundi(normalized_progress * 100.0)

func hide_reload_progress() -> void:
	if reload_panel != null:
		reload_panel.visible = false
	if reload_progress_bar != null:
		reload_progress_bar.value = 0.0

func _refresh_vehicle(player_data: Dictionary, tracked_vehicle: Node = null) -> void:
	var vehicle_data: Dictionary = _get_vehicle_hud_data(player_data, tracked_vehicle)
	var vehicle_name: String = str(vehicle_data.get("vehicle_name", "Véhicule"))
	var vehicle_health : int = vehicle_data.get("health", -1)
	var vehicle_health_max : int = vehicle_data.get("max_health", -1)
	var current_seat_name: String = str(vehicle_data.get("current_seat_name", ""))
	var turret_name: String = str(vehicle_data.get("turret_name", ""))
	var seats: Array = vehicle_data.get("seats", [])

	_refresh_vehicle_fuel_bar(vehicle_data, tracked_vehicle)
	_refresh_vehicle_mod_slots(vehicle_data)

	vehicle_name_label.text = vehicle_name
	vehicle_health_label.visible = false
	vehicle_health_label.text = str(vehicle_health) + "/" + str(vehicle_health_max)
	
	if current_seat_name.is_empty():
		current_seat_label.text = "Siège : inconnu"
	else:
		current_seat_label.text = "Siège : %s" % current_seat_name

	if turret_name.is_empty():
		turret_label.text = "Tourelle : aucune"
		turret_ammo_label.visible = false
		turret_ammo_label.text = "-/- ( - )"
	else:
		turret_label.text = "Tourelle : %s" % turret_name
		turret_ammo_label.visible = true
		turret_ammo_label.text = _build_turret_ammo_text(player_data, vehicle_data)

	for i in range(_seat_labels.size()):
		var label := _seat_labels[i]
		if i < seats.size():
			label.visible = true
			label.text = _format_seat_bbcode(seats[i])
		else:
			label.visible = false



func _refresh_vehicle_fuel_bar(vehicle_data: Dictionary, tracked_vehicle: Node = null) -> void:
	if vehicle_fuel_progress_bar == null or vehicle_fuel_value_label == null:
		return

	var max_fuel: float = _read_float_from_vehicle_sources(vehicle_data, tracked_vehicle, [
		"max_fuel",
		"fuel_max",
		"max_essence",
		"essence_max",
	], 0.0)

	if max_fuel <= 0.0:
		_hide_vehicle_fuel_bar()
		return

	var current_fuel: float = _read_float_from_vehicle_sources(vehicle_data, tracked_vehicle, [
		"current_fuel",
		"fuel",
		"fuel_current",
		"current_essence",
		"essence",
	], max_fuel)
	current_fuel = clampf(current_fuel, 0.0, max_fuel)

	var consumption: float = _get_current_fuel_consumption(vehicle_data, tracked_vehicle, current_fuel)

	vehicle_fuel_progress_bar.visible = true
	vehicle_fuel_progress_bar.min_value = 0.0
	vehicle_fuel_progress_bar.max_value = max_fuel
	vehicle_fuel_progress_bar.value = current_fuel

	vehicle_fuel_value_label.visible = true
	vehicle_fuel_value_label.text = "Essence %s/%s  |  Conso %s/s" % [
		_format_fuel_value(current_fuel),
		_format_fuel_value(max_fuel),
		_format_fuel_value(consumption),
	]


func _hide_vehicle_fuel_bar() -> void:
	if vehicle_fuel_progress_bar != null:
		vehicle_fuel_progress_bar.visible = false
		vehicle_fuel_progress_bar.value = 0.0
	if vehicle_fuel_value_label != null:
		vehicle_fuel_value_label.visible = false
		vehicle_fuel_value_label.text = ""


func _get_current_fuel_consumption(vehicle_data: Dictionary, tracked_vehicle: Node, current_fuel: float) -> float:
	var direct_consumption: float = _read_float_from_dictionary(vehicle_data, [
		"current_fuel_consumption",
		"fuel_consumption_current",
		"fuel_current_consumption",
		"fuel_consumption_rate",
		"real_time_fuel_consumption",
	], -1.0)
	if direct_consumption >= 0.0:
		return direct_consumption

	var base_consumption: float = _read_float_from_vehicle_sources(vehicle_data, tracked_vehicle, [
		"fuel_consumption_per_second",
		"fuel_consumption",
		"consumption_per_second",
		"essence_consumption_per_second",
	], 0.0)
	if base_consumption <= 0.0 or current_fuel <= 0.0:
		return 0.0

	var is_consuming_fuel: bool = _read_bool_from_dictionary(vehicle_data, [
		"is_consuming_fuel",
		"fuel_is_consuming",
	], false)
	if is_consuming_fuel:
		return base_consumption

	if tracked_vehicle == null or not is_instance_valid(tracked_vehicle):
		return base_consumption

	var drive_input: float = absf(_read_float_from_object(tracked_vehicle, "drive_input", 0.0))
	var speed: float = _read_vehicle_speed(tracked_vehicle)
	var min_speed: float = _read_float_from_object(tracked_vehicle, "fuel_min_speed_to_consume", 0.0)

	if drive_input > 0.01 and speed > min_speed:
		return base_consumption * drive_input

	return 0.0


func _read_vehicle_speed(tracked_vehicle: Node) -> float:
	var linear_velocity_value: Variant = tracked_vehicle.get("linear_velocity")
	if linear_velocity_value is Vector3:
		var velocity: Vector3 = linear_velocity_value
		return velocity.length()
	return 0.0


func _read_float_from_vehicle_sources(vehicle_data: Dictionary, tracked_vehicle: Node, keys: Array[String], fallback: float) -> float:
	var dictionary_value: float = _read_float_from_dictionary(vehicle_data, keys, INF)
	if dictionary_value != INF:
		return dictionary_value

	if tracked_vehicle != null and is_instance_valid(tracked_vehicle):
		for key: String in keys:
			var object_value: Variant = tracked_vehicle.get(key)
			if object_value is int or object_value is float:
				return float(object_value)

	return fallback


func _read_float_from_dictionary(data: Dictionary, keys: Array[String], fallback: float) -> float:
	for key: String in keys:
		if not data.has(key):
			continue
		var value: Variant = data[key]
		if value is int or value is float:
			return float(value)
		if value is String and value.is_valid_float():
			return value.to_float()
	return fallback


func _read_float_from_object(object: Object, property_name: String, fallback: float) -> float:
	if object == null:
		return fallback
	var value: Variant = object.get(property_name)
	if value is int or value is float:
		return float(value)
	if value is String and value.is_valid_float():
		return value.to_float()
	return fallback


func _read_bool_from_dictionary(data: Dictionary, keys: Array[String], fallback: bool) -> bool:
	for key: String in keys:
		if not data.has(key):
			continue
		return bool(data[key])
	return fallback


func _format_fuel_value(value: float) -> String:
	if absf(value - roundf(value)) < 0.05:
		return str(roundi(value))
	return "%.1f" % value


func _refresh_vehicle_mod_slots(vehicle_data: Dictionary) -> void:
	if vehicle_mods_panel == null or vehicle_mods_grid == null:
		return

	var mods: Array = vehicle_data.get("mods", [])
	if mods.is_empty():
		_hide_vehicle_mod_slots()
		return

	var is_driver: bool = bool(vehicle_data.get("is_driver", false))
	vehicle_mods_panel.visible = true
	_sync_vehicle_mod_slot_count(mods.size())

	for i in range(_vehicle_mod_slot_nodes.size()):
		var slot: Control = _vehicle_mod_slot_nodes[i]
		if slot == null:
			continue

		var slot_data: Dictionary = {}
		if i < mods.size() and mods[i] is Dictionary:
			slot_data = mods[i]

		if slot.has_method("set_slot_data"):
			slot.call("set_slot_data", slot_data, is_driver)


func _sync_vehicle_mod_slot_count(target_count: int) -> void:
	var clamped_count: int = clampi(target_count, 0, 6)

	while _vehicle_mod_slot_nodes.size() < clamped_count:
		var instance: Node = VEHICLE_MOD_SLOT_SCENE.instantiate()
		var slot: Control = instance as Control
		if slot == null:
			instance.queue_free()
			return

		vehicle_mods_grid.add_child(slot)
		_vehicle_mod_slot_nodes.append(slot)

	while _vehicle_mod_slot_nodes.size() > clamped_count:
		var last_index: int = _vehicle_mod_slot_nodes.size() - 1
		var slot_to_remove: Control = _vehicle_mod_slot_nodes[last_index]
		_vehicle_mod_slot_nodes.remove_at(last_index)
		if slot_to_remove != null:
			vehicle_mods_grid.remove_child(slot_to_remove)
			slot_to_remove.queue_free()


func _hide_vehicle_mod_slots() -> void:
	if vehicle_mods_panel != null:
		vehicle_mods_panel.visible = false



func _build_turret_ammo_text(player_data: Dictionary, vehicle_data: Dictionary) -> String:
	var ammo_data := _get_turret_ammo_data(player_data, vehicle_data)

	if ammo_data.is_empty():
		return "-/- ( - )"

	var magazine_ammo: int = int(ammo_data.get("magazine_ammo", 0))
	var magazine_max_ammo: int = int(ammo_data.get("magazine_max_ammo", 0))
	var reserve_ammo: int = int(ammo_data.get("reserve_ammo", 0))
	var reserve_max_ammo: int = int(ammo_data.get("reserve_max_ammo", 0))
	var infinite_ammo: bool = bool(ammo_data.get("infinite_ammo", false))
	
	var reserve_text := "∞" if infinite_ammo else str(reserve_ammo)
	if infinite_ammo:
		return "%d/%d (%s)" % [magazine_ammo, magazine_max_ammo, reserve_text]
	else:
		return "%d/%d (%s/%s)" % [magazine_ammo, magazine_max_ammo, reserve_text, reserve_max_ammo]


func _get_turret_ammo_data(player_data: Dictionary, vehicle_data: Dictionary) -> Dictionary:
	# Option 1 : Vehicle.gd envoie directement un dictionnaire "turret_ammo".
	if vehicle_data.has("turret_ammo") and vehicle_data["turret_ammo"] is Dictionary:
		return vehicle_data["turret_ammo"]

	# Option 2 : Vehicle.gd envoie les valeurs à plat.
	if vehicle_data.has("turret_magazine_ammo"):
		return {
			"magazine_ammo": int(vehicle_data.get("turret_magazine_ammo", 0)),
			"magazine_max_ammo": int(vehicle_data.get("turret_magazine_max_ammo", 0)),
			"reserve_ammo": int(vehicle_data.get("turret_reserve_ammo", 0)),
			"reserve_max_ammo": int(vehicle_data.get("turret_reserve_max_ammo", 0)),
			"infinite_ammo": bool(vehicle_data.get("turret_infinite_ammo", false)),
		}

	# Option 3 : Player.gd envoie directement un dictionnaire "turret_ammo".
	if player_data.has("turret_ammo") and player_data["turret_ammo"] is Dictionary:
		return player_data["turret_ammo"]

	# Option 4 : on récupère le node de tourelle, si Vehicle.gd ou Player.gd le donne déjà.
	var turret = _find_current_turret(player_data, vehicle_data)
	if _is_valid_object(turret):
		return _get_turret_ammo_data_from_node(turret)

	return {}


func _find_current_turret(player_data: Dictionary, vehicle_data: Dictionary) -> Variant:
	var possible_keys: Array[String] = [
		"turret",
		"current_turret",
		"active_turret",
		"controlled_turret",
		"mounted_turret",
		"turret_node",
	]

	for key in possible_keys:
		var from_vehicle_data = vehicle_data.get(key, null)
		if _is_valid_object(from_vehicle_data):
			return from_vehicle_data

	for key in possible_keys:
		var from_player_data = player_data.get(key, null)
		if _is_valid_object(from_player_data):
			return from_player_data

	if _is_valid_object(player):
		for key in possible_keys:
			var from_player_property = player.get(key)
			if _is_valid_object(from_player_property):
				return from_player_property

	return null


func _get_turret_ammo_data_from_node(turret: Variant) -> Dictionary:
	var magazine_ammo := _read_turret_int(turret, "get_magazine_ammo", "magazine_ammo", 0)
	var magazine_max_ammo := _read_turret_int(turret, "get_magazine_max_ammo", "magazine_max_ammo", 0)
	var reserve_ammo := _read_turret_int(turret, "get_reserve_ammo", "reserve_ammo", 0)
	var reserve_max_ammo := _read_turret_int(turret, "get_reserve_max_ammo", "reserve_max_ammo", 0)
	var infinite_ammo := _read_turret_bool(turret, "has_infinite_ammo", "infinite_ammo", false)

	return {
		"magazine_ammo": magazine_ammo,
		"magazine_max_ammo": magazine_max_ammo,
		"reserve_ammo": reserve_ammo,
		"reserve_max_ammo": reserve_max_ammo,
		"infinite_ammo": infinite_ammo,
	}


func _read_turret_int(turret: Variant, method_name: String, property_name: String, fallback: int) -> int:
	if _is_valid_object(turret) and turret.has_method(method_name):
		return int(turret.call(method_name))

	if _is_valid_object(turret):
		var value = turret.get(property_name)
		if value != null:
			return int(value)

	return fallback


func _read_turret_bool(turret: Variant, method_name: String, property_name: String, fallback: bool) -> bool:
	if _is_valid_object(turret) and turret.has_method(method_name):
		return bool(turret.call(method_name))

	if _is_valid_object(turret):
		var value = turret.get(property_name)
		if value != null:
			return bool(value)

	return fallback


func _is_valid_object(value: Variant) -> bool:
	return value is Object and is_instance_valid(value)


func _build_reserve_ui(player_data: Dictionary) -> void:
	var reserves: Dictionary = player_data.get("ammo_reserve_data", {})
	var equipped_ammo_type: String = str(player_data.get("equipped_ammo_type", ""))

	if reserves.is_empty():
		return

	#var parts: Array[String] = []

	if reserves.has("9mm"):
		ammo_9mm.text = str(int(reserves.get("9mm", 0)))
		if equipped_ammo_type == "9mm":
			ammo_9mm.text = "> "+ammo_9mm.text
		
	if reserves.has("rifle"):
		ammo_rifle.text = str(int(reserves.get("rifle", 0)))
		if equipped_ammo_type == "rifle":
			ammo_rifle.text = "> "+ammo_rifle.text
	
	if reserves.has("shell"):
		ammo_shell.text = str(int(reserves.get("shell", 0)))
		if equipped_ammo_type == "shell":
			ammo_shell.text = "> "+ammo_shell.text
	
	if reserves.has("rocket"):
		ammo_rocket.text = str(int(reserves.get("rocket", 0)))
		if equipped_ammo_type == "rocket":
			ammo_rocket.text = "> "+ammo_rocket.text
	
	if reserves.has("energy"):
		ammo_energy.text = str(int(reserves.get("energy", 0)))
		if equipped_ammo_type == "energy":
			ammo_energy.text = "> "+ammo_energy.text

#func _build_reserve_text(player_data: Dictionary) -> String:
	#var reserves: Dictionary = player_data.get("ammo_reserve_data", {})
	#var equipped_ammo_type: String = str(player_data.get("equipped_ammo_type", ""))
#
	#if reserves.is_empty():
		#return "Réserve : aucune"
#
	#var parts: Array[String] = []
#
	#if reserves.has("9mm"):
		#var value_9mm := int(reserves.get("9mm", 0))
		#if equipped_ammo_type == "9mm":
			#parts.append("[9MM %d]" % value_9mm)
		#else:
			#parts.append("9MM %d" % value_9mm)
#
	#if reserves.has("rifle"):
		#var value_rifle := int(reserves.get("rifle", 0))
		#if equipped_ammo_type == "rifle":
			#parts.append("[RIF %d]" % value_rifle)
		#else:
			#parts.append("RIF %d" % value_rifle)
#
	#if reserves.has("shell"):
		#var value_shell := int(reserves.get("shell", 0))
		#if equipped_ammo_type == "shell":
			#parts.append("[SHL %d]" % value_shell)
		#else:
			#parts.append("SHL %d" % value_shell)
#
	#if reserves.has("energy"):
		#var value_energy := int(reserves.get("energy", 0))
		#if equipped_ammo_type == "energy":
			#parts.append("[NRJ %d]" % value_energy)
		#else:
			#parts.append("NRJ %d" % value_energy)
#
	#if reserves.has("rocket"):
		#var value_rocket := int(reserves.get("rocket", 0))
		#if equipped_ammo_type == "rocket":
			#parts.append("[ROC %d]" % value_rocket)
		#else:
			#parts.append("ROC %d" % value_rocket)
#
	#return "Réserve : " + "   ".join(parts)

func _format_seat_bbcode(seat_data: Dictionary) -> String:
	var seat_name: String = str(seat_data.get("seat_name", "Siège"))
	var occupant_name: String = str(seat_data.get("occupant_name", EMPTY_SEAT_TEXT))
	var is_self: bool = bool(seat_data.get("is_self", false))
	var line := "%s : %s" % [seat_name, occupant_name]

	if is_self:
		return "[color=%s]%s[/color]" % [SELF_COLOR, line]

	return line

func _get_player_hud_data() -> Dictionary:
	if player != null and player.has_method("get_hud_data"):
		var data = player.call("get_hud_data")
		if data is Dictionary:
			return data
	return {}

func _get_vehicle_hud_data(player_data: Dictionary, tracked_vehicle: Node = null) -> Dictionary:
	var vehicle: Node = _as_valid_vehicle_node(player_data.get("vehicle", null))
	if vehicle == null:
		vehicle = tracked_vehicle

	if vehicle != null and is_instance_valid(vehicle) and vehicle.has_method("get_hud_data_for_player"):
		var data = vehicle.call("get_hud_data_for_player", player)
		if data is Dictionary:
			return data

	if player_data.has("vehicle_data") and player_data["vehicle_data"] is Dictionary:
		return player_data["vehicle_data"]

	if player_data.has("tank_data") and player_data["tank_data"] is Dictionary:
		return player_data["tank_data"]

	return {}
