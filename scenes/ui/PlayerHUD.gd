extends CanvasLayer
class_name PlayerHUD

signal respawn_requested

@export var refresh_every_frame: bool = true
@export var show_local_player_name_marker: bool = false
@export var name_marker_margin: float = 24.0

@onready var common_panel: PanelContainer = %CommonPanel #$Root/LeftMargin/LeftVBox/CommonPanel
@onready var hp_label: Label = %HPLabel #$Root/LeftMargin/LeftVBox/CommonPanel/CommonMargin/CommonVBox/HPLabel
@onready var health_progress_bar: ProgressBar = %HealthProgressBar
@onready var ammo_9mm: Label = %Ammo_9MM
@onready var ammo_rifle: Label = %Ammo_Rifle
@onready var ammo_shell: Label = %Ammo_Shell
@onready var ammo_rocket: Label = %Ammo_Rocket

@onready var on_foot_panel: PanelContainer = %OnFootPanel #$Root/LeftMargin/LeftVBox/OnFootPanel
@onready var equipped_weapon_label: Label = %EquippedWeaponLabel #$Root/LeftMargin/LeftVBox/OnFootPanel/OnFootMargin/OnFootVBox/EquippedWeaponLabel
@onready var weapon_1_label: Label = %Weapon1Label #$Root/LeftMargin/LeftVBox/OnFootPanel/OnFootMargin/OnFootVBox/Weapon1Label
@onready var weapon_2_label: Label = %Weapon2Label #$Root/LeftMargin/LeftVBox/OnFootPanel/OnFootMargin/OnFootVBox/Weapon2Label
@onready var ammo_label: Label = %AmmoLabel #$Root/LeftMargin/LeftVBox/OnFootPanel/OnFootMargin/OnFootVBox/AmmoLabel
@onready var money_label: Label = %MoneyLabel #$Root/LeftMargin/LeftVBox/OnFootPanel/OnFootMargin/OnFootVBox/MoneyLabel
@onready var reserve_label: Label = %ReserveLabel

@onready var vehicle_panel: PanelContainer = %VehiclePanel #$Root/RightMargin/VehiclePanel
@onready var vehicle_name_label: Label = %VehicleNameLabel #$Root/RightMargin/VehiclePanel/VehicleMargin/VehicleVBox/VehicleNameLabel
@onready var vehicle_health_label = %VehicleHealthLabel
@onready var current_seat_label: Label = %CurrentSeatLabel #$Root/RightMargin/VehiclePanel/VehicleMargin/VehicleVBox/CurrentSeatLabel
@onready var seat_1_label: RichTextLabel = %Seat1Label #$Root/RightMargin/VehiclePanel/VehicleMargin/VehicleVBox/SeatsVBox/Seat1Label
@onready var seat_2_label: RichTextLabel = %Seat2Label #$Root/RightMargin/VehiclePanel/VehicleMargin/VehicleVBox/SeatsVBox/Seat2Label
@onready var seat_3_label: RichTextLabel = %Seat3Label #$Root/RightMargin/VehiclePanel/VehicleMargin/VehicleVBox/SeatsVBox/Seat3Label
@onready var seat_4_label: RichTextLabel = %Seat4Label #$Root/RightMargin/VehiclePanel/VehicleMargin/VehicleVBox/SeatsVBox/Seat4Label
@onready var seat_5_label: RichTextLabel = %Seat5Label #$Root/RightMargin/VehiclePanel/VehicleMargin/VehicleVBox/SeatsVBox/Seat5Label
@onready var seat_6_label: RichTextLabel = %Seat6Label #$Root/RightMargin/VehiclePanel/VehicleMargin/VehicleVBox/SeatsVBox/Seat6Label
@onready var turret_label: Label = %TurretLabel #$Root/RightMargin/VehiclePanel/VehicleMargin/VehicleVBox/TurretLabel
@onready var turret_ammo_label: Label = %TurretAmmo

var player: Node = null
var _seat_labels: Array[RichTextLabel] = []
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
@onready var passage_panel: PanelContainer = %PassagePanel
@onready var passage_label: Label = %PassageLabel
@onready var passage_progress: ProgressBar = %PassageProgress
var respawn_pending: bool = false
var _name_marker_labels: Dictionary = {}
var _passage_prompt_owner_id: int = 0

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
	_refresh_all()

func _process(_delta: float) -> void:
	if refresh_every_frame:
		_refresh_all()

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
		return

	visible = true

	var player_data: Dictionary = _get_player_hud_data()
	var in_vehicle: bool = bool(player_data.get("in_vehicle", false))
	var is_dead: bool = bool(player_data.get("is_dead", false))

	_refresh_player_name_markers()

	if is_dead:
		common_panel.visible = false
		on_foot_panel.visible = false
		vehicle_panel.visible = false
		_show_death_overlay(player_data)
		_refresh_revive_panel(player_data)
		return

	_hide_death_overlay()
	_refresh_common(player_data)
	_refresh_on_foot(player_data)
	_refresh_vehicle(player_data)
	_refresh_revive_panel(player_data)

	common_panel.visible = true
	on_foot_panel.visible = not in_vehicle
	vehicle_panel.visible = in_vehicle

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

func _refresh_player_name_markers() -> void:
	if player_name_layer == null:
		return

	var camera := _get_hud_camera()
	if camera == null:
		_clear_name_markers()
		return

	var active_keys := {}
	for target in get_tree().get_nodes_in_group("players"):
		if target == null or not is_instance_valid(target):
			continue
		if target == player and not show_local_player_name_marker:
			continue
		if not (target is Node3D):
			continue

		var key := str(target.get_instance_id())
		active_keys[key] = true
		var label := _get_or_create_name_marker(key)
		label.text = _get_player_marker_text(target)
		var world_position := _get_player_marker_world_position(target)
		var screen_data := _world_position_to_clamped_screen(camera, world_position)
		var label_size := label.get_combined_minimum_size()
		label.size = label_size
		label.position = Vector2(screen_data.get("x", 0.0), screen_data.get("y", 0.0)) - label_size * 0.5
		label.visible = true

	for key in _name_marker_labels.keys():
		if active_keys.has(key):
			continue
		var stale_label = _name_marker_labels.get(key)
		if stale_label != null and is_instance_valid(stale_label):
			stale_label.queue_free()
		_name_marker_labels.erase(key)

func _get_or_create_name_marker(key: String) -> Label:
	var existing = _name_marker_labels.get(key, null)
	if existing != null and is_instance_valid(existing):
		return existing as Label

	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 18)
	player_name_layer.add_child(label)
	_name_marker_labels[key] = label
	return label

func _clear_name_markers() -> void:
	for key in _name_marker_labels.keys():
		var label = _name_marker_labels.get(key)
		if label != null and is_instance_valid(label):
			label.queue_free()
	_name_marker_labels.clear()

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

func _refresh_vehicle(player_data: Dictionary) -> void:
	var vehicle_data: Dictionary = _get_vehicle_hud_data(player_data)
	var vehicle_name: String = str(vehicle_data.get("vehicle_name", "Véhicule"))
	var vehicle_health : int = vehicle_data.get("health", -1)
	var vehicle_health_max : int = vehicle_data.get("max_health", -1)
	var current_seat_name: String = str(vehicle_data.get("current_seat_name", ""))
	var turret_name: String = str(vehicle_data.get("turret_name", ""))
	var seats: Array = vehicle_data.get("seats", [])

	vehicle_name_label.text = vehicle_name
	
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
		if equipped_ammo_type == "9mm":
			ammo_rifle.text = "> "+ammo_rifle.text
	
	if reserves.has("shell"):
		ammo_shell.text = str(int(reserves.get("shell", 0)))
		if equipped_ammo_type == "9mm":
			ammo_shell.text = "> "+ammo_shell.text
		
	if reserves.has("rocket"):
		ammo_rocket.text = str(int(reserves.get("rocket", 0)))
		if equipped_ammo_type == "9mm":
			ammo_rocket.text = "> "+ammo_rocket.text


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

func _get_vehicle_hud_data(player_data: Dictionary) -> Dictionary:
	var vehicle = player_data.get("vehicle", null)
	if vehicle != null and is_instance_valid(vehicle) and vehicle.has_method("get_hud_data_for_player"):
		var data = vehicle.call("get_hud_data_for_player", player)
		if data is Dictionary:
			return data
	return {}
