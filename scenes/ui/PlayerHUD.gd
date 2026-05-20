extends CanvasLayer
class_name PlayerHUD

signal respawn_requested
signal spectate_next_requested

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

@export_group("Aim Feedback")
@export var show_aim_target_reticle: bool = true
@export var aim_target_reticle_size: Vector2 = Vector2(64.0, 64.0)
@export var aim_target_screen_margin: float = 18.0
@export var show_vehicle_turret_reticle: bool = true
@export var vehicle_turret_reticle_size: Vector2 = Vector2(64.0, 64.0)

@export_group("Damage Feedback")
@export var damage_feedback_color: Color = Color(1.0, 0.06, 0.02, 0.34)
@export var damage_feedback_fade_duration: float = 0.28


@onready var hp_label: Label = %HPLabel
@onready var health_progress_bar: ProgressBar = %HealthProgressBar
@onready var health_label = %HealthLabel

@onready var ammo_9mm: Label = %Ammo_9mm
@onready var ammo_rifle: Label = %Ammo_Rifle
@onready var ammo_shell: Label = %Ammo_Shell
@onready var ammo_rocket: Label = %Ammo_Rocket
@onready var ammo_energy: Label = %Ammo_Energy

@onready var panel_9mm: Panel = %Panel_9mm
@onready var panel_rifle: Panel = %Panel_Rifle
@onready var panel_shell: Panel = %Panel_Shell
@onready var panel_rocket: Panel = %Panel_Rocket
@onready var panel_energy: Panel = %Panel_Energy

@onready var on_foot_panel := %OnFootPanel
@onready var weapon_1_slot: PanelContainer = %Weapon1Slot
@onready var weapon_1_texture_rect: TextureRect = %Weapon1TextureRect
@onready var weapon_1_ammo_label: Label = %Weapon1AmmoLabel
@onready var weapon_2_slot: PanelContainer = %Weapon2Slot
@onready var weapon_2_texture_rect: TextureRect = %Weapon2TextureRect
@onready var weapon_2_ammo_label: Label = %Weapon2AmmoLabel
@onready var money_label: Label = %MoneyLabel
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
@onready var vehicle_mods_grid: HBoxContainer = %VehicleModsGrid

var player: Node = null
var _seat_labels: Array[RichTextLabel] = []
var _vehicle_mod_slot_nodes: Array[Control] = []
var _weapon_slot_panels: Array[PanelContainer] = []
var _weapon_slot_icons: Array[TextureRect] = []
var _weapon_slot_ammo_labels: Array[Label] = []
var _weapon_icon_paths: Dictionary = {}
var _weapon_icon_textures: Dictionary = {}
var _weapon_slot_last_ammo_texts: Array[String] = ["", ""]
var _weapon_slot_last_weapon_names: Array[String] = ["", ""]
var _weapon_ammo_text_by_name: Dictionary = {}
var _weapon_slot_normal_style: StyleBoxFlat = null
var _weapon_slot_equipped_style: StyleBoxFlat = null
@onready var death_overlay: Control = %DeathOverlay
@onready var death_message_label: Label = %DeathMessageLabel
@onready var final_death_countdown_label: Label = %FinalDeathCountdownLabel
@onready var final_death_progress: ProgressBar = %FinalDeathProgress
@onready var death_revive_label: Label = %DeathReviveLabel
@onready var death_revive_progress: ProgressBar = %DeathReviveProgress
@onready var respawn_button: Button = %RespawnButton
@onready var spectate_next_button: Button = %SpectateNextButton
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
@onready var aim_target_reticle: TextureRect = get_node_or_null("%AimTargetReticle") as TextureRect
@onready var vehicle_turret_reticle: TextureRect = get_node_or_null("%VehicleTurretReticle") as TextureRect
@onready var damage_feedback_overlay: ColorRect = get_node_or_null("%DamageFeedbackOverlay") as ColorRect
var respawn_pending: bool = false
var _name_marker_labels: Dictionary = {}
var _vehicle_name_marker: Control = null
var _vehicle_marker_target_id: int = 0
var _passage_prompt_owner_id: int = 0
var _repair_target: Node = null
var _repair_target_hide_timer: float = 0.0
var _damage_feedback_tween: Tween = null

const SELF_COLOR := "#7CFF7C"
const EMPTY_SEAT_TEXT := "Libre"
const WEAPON_ICON_DIR: String = "res://asset/ui/weapon/"
const WEAPON_ICON_PREFIX: String = "weapon_"
const WEAPON_ICON_EXTENSION: String = ".png"
const AMMO_PANEL_SELECTED_MODULATE: Color = Color(1.0, 1.0, 1.0, 1.0)
const AMMO_PANEL_UNSELECTED_MODULATE: Color = Color(0.0, 0.0, 0.0, 1.0)

func _ready() -> void:
	add_to_group("player_huds")
	layer = 1
	set_process_input(true)
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

	_configure_death_overlay_input()
	_configure_aim_feedback_nodes()
	_configure_damage_feedback_nodes()

	if not respawn_button.pressed.is_connected(_on_respawn_button_pressed):
		respawn_button.pressed.connect(_on_respawn_button_pressed)
	respawn_button.mouse_filter = Control.MOUSE_FILTER_STOP
	respawn_button.focus_mode = Control.FOCUS_ALL
	respawn_button.z_index = 10

	if spectate_next_button != null:
		spectate_next_button.mouse_filter = Control.MOUSE_FILTER_STOP
		spectate_next_button.focus_mode = Control.FOCUS_ALL
		spectate_next_button.z_index = 100
		spectate_next_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		if not spectate_next_button.pressed.is_connected(_on_spectate_next_button_pressed):
			spectate_next_button.pressed.connect(_on_spectate_next_button_pressed)

	death_overlay.visible = false
	death_revive_label.visible = false
	death_revive_progress.visible = false
	if final_death_countdown_label != null:
		final_death_countdown_label.visible = false
	if final_death_progress != null:
		final_death_progress.visible = false
	if spectate_next_button != null:
		spectate_next_button.visible = false
	revive_panel.visible = false
	hide_passage_prompt()
	hide_repair_target(true)
	hide_reload_progress()
	_scan_weapon_icon_folder()
	_cache_weapon_slot_nodes()
	_setup_weapon_slot_styles()
	_clear_editor_vehicle_mod_slots()
	_hide_vehicle_fuel_bar()
	_hide_vehicle_mod_slots()
	_hide_tank_health_bar()
	_hide_vehicle_name_marker()
	_refresh_all()

func _process(delta: float) -> void:
	if refresh_every_frame:
		_refresh_all()

	_update_repair_target_bar(delta)
	_refresh_aim_target_reticle_from_player()

func _input(event: InputEvent) -> void:
	if _try_consume_spectate_button_click(event):
		get_viewport().set_input_as_handled()


func _try_consume_spectate_button_click(event: InputEvent) -> bool:
	if death_overlay == null or not death_overlay.visible:
		return false
	if spectate_next_button == null or not spectate_next_button.visible or spectate_next_button.disabled:
		return false

	var click_position: Vector2 = Vector2.INF
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return false
		click_position = mouse_event.position
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if not touch_event.pressed:
			return false
		click_position = touch_event.position
	else:
		return false

	if not spectate_next_button.get_global_rect().has_point(click_position):
		return false

	_on_spectate_next_button_pressed()
	return true


func _configure_death_overlay_input() -> void:
	if death_overlay != null:
		_set_mouse_filter_ignore(death_overlay)
		_set_mouse_filter_ignore(death_overlay.get_node_or_null("DeathDim") as Control)
		_set_mouse_filter_ignore(death_overlay.get_node_or_null("DeathCenter") as Control)
		_set_mouse_filter_ignore(death_overlay.get_node_or_null("DeathCenter/DeathPanel") as Control)
		_set_mouse_filter_ignore(death_overlay.get_node_or_null("DeathCenter/DeathPanel/DeathMargin") as Control)
		_set_mouse_filter_ignore(death_overlay.get_node_or_null("DeathCenter/DeathPanel/DeathMargin/DeathVBox") as Control)

	if respawn_button != null:
		respawn_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if spectate_next_button != null:
		spectate_next_button.mouse_filter = Control.MOUSE_FILTER_STOP


func _set_mouse_filter_ignore(control: Control) -> void:
	if control == null:
		return
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_player(p_player: Node) -> void:
	var damage_callable := Callable(self, "_on_player_damage_taken")
	if player != null and is_instance_valid(player) and player.has_signal("damage_taken"):
		if player.is_connected("damage_taken", damage_callable):
			player.disconnect("damage_taken", damage_callable)

	player = p_player

	if player != null and is_instance_valid(player) and player.has_signal("damage_taken"):
		if not player.is_connected("damage_taken", damage_callable):
			player.connect("damage_taken", damage_callable)

	_refresh_all()

func get_player() -> Node:
	return player

func _configure_aim_feedback_nodes() -> void:
	_configure_reticle_node(aim_target_reticle, aim_target_reticle_size)
	_configure_reticle_node(vehicle_turret_reticle, vehicle_turret_reticle_size)


func _configure_reticle_node(reticle: TextureRect, reticle_size: Vector2) -> void:
	if reticle == null:
		return
	reticle.visible = false
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reticle.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reticle.size = reticle_size
	reticle.pivot_offset = reticle_size * 0.5

func _configure_damage_feedback_nodes() -> void:
	if damage_feedback_overlay == null:
		return
	damage_feedback_overlay.visible = false
	damage_feedback_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_feedback_overlay.color = damage_feedback_color
	damage_feedback_overlay.modulate.a = 0.0

func _on_player_damage_taken(_amount: int) -> void:
	show_damage_feedback()

func show_damage_feedback() -> void:
	if damage_feedback_overlay == null:
		return

	if _damage_feedback_tween != null and _damage_feedback_tween.is_valid():
		_damage_feedback_tween.kill()

	damage_feedback_overlay.visible = true
	damage_feedback_overlay.color = damage_feedback_color
	damage_feedback_overlay.modulate = Color(1.0, 1.0, 1.0, 1.0)

	_damage_feedback_tween = create_tween()
	_damage_feedback_tween.tween_property(
		damage_feedback_overlay,
		"modulate:a",
		0.0,
		max(damage_feedback_fade_duration, 0.01)
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_damage_feedback_tween.tween_callback(_hide_damage_feedback_overlay)

func _hide_damage_feedback_overlay() -> void:
	if damage_feedback_overlay != null:
		damage_feedback_overlay.visible = false

func _refresh_aim_target_reticle_from_player() -> void:
	if player == null or not is_instance_valid(player):
		_hide_aim_target_reticle()
		_hide_vehicle_turret_reticle()
		return
	if bool(player.get("is_dead")):
		_hide_aim_target_reticle()
		_hide_vehicle_turret_reticle()
		return

	var player_data: Dictionary = _get_player_hud_data()
	var in_vehicle: bool = _is_player_in_vehicle(player_data)

	if in_vehicle:
		_hide_aim_target_reticle()
		_refresh_vehicle_turret_reticle(player_data)
		return

	_hide_vehicle_turret_reticle()
	_refresh_player_aim_target_reticle()


func _refresh_player_aim_target_reticle() -> void:
	if aim_target_reticle == null:
		return
	if not show_aim_target_reticle:
		_hide_aim_target_reticle()
		return

	var world_position := Vector3.ZERO
	if player.has_method("get_hud_aim_target_position"):
		var aim_value = player.call("get_hud_aim_target_position")
		if aim_value is Vector3:
			world_position = aim_value
		else:
			_hide_aim_target_reticle()
			return
	elif "aim_target_position" in player:
		var aim_property = player.get("aim_target_position")
		if aim_property is Vector3:
			world_position = aim_property
		else:
			_hide_aim_target_reticle()
			return
	else:
		_hide_aim_target_reticle()
		return

	if not _place_reticle_at_world_position(aim_target_reticle, world_position, aim_target_reticle_size):
		_hide_aim_target_reticle()


func _refresh_vehicle_turret_reticle(player_data: Dictionary) -> void:
	if vehicle_turret_reticle == null:
		return
	if not show_vehicle_turret_reticle:
		_hide_vehicle_turret_reticle()
		return

	var tracked_vehicle: Node = _get_tracked_vehicle(player_data)
	var vehicle_data: Dictionary = _get_vehicle_hud_data(player_data, tracked_vehicle)
	var turret = _find_current_turret(player_data, vehicle_data)

	if not _is_valid_object(turret):
		# Fallback : certains véhicules exposent seulement le nom de la tourelle au HUD.
		# Dans ce cas, on affiche tout de même le viseur véhicule à la position souris.
		var turret_name: String = str(vehicle_data.get("turret_name", ""))
		if turret_name.is_empty():
			_hide_vehicle_turret_reticle()
			return
		_place_reticle_at_screen_position(vehicle_turret_reticle, get_viewport().get_mouse_position(), vehicle_turret_reticle_size)
		return
	if not _turret_is_operated_by_local_player(turret):
		_hide_vehicle_turret_reticle()
		return

	var world_position := Vector3.ZERO
	if turret.has_method("get_hud_aim_target_position"):
		var aim_value = turret.call("get_hud_aim_target_position")
		if aim_value is Vector3:
			world_position = aim_value
		else:
			_hide_vehicle_turret_reticle()
			return
	else:
		var aim_property = turret.get("target_aim_world")
		if aim_property is Vector3:
			world_position = aim_property
		else:
			var replicated_aim_property = turret.get("replicated_aim_world")
			if replicated_aim_property is Vector3:
				world_position = replicated_aim_property
			else:
				_hide_vehicle_turret_reticle()
				return

	if not _place_reticle_at_world_position(vehicle_turret_reticle, world_position, vehicle_turret_reticle_size):
		_hide_vehicle_turret_reticle()


func _is_player_in_vehicle(player_data: Dictionary) -> bool:
	if bool(player_data.get("in_vehicle", false)):
		return true
	if player != null and is_instance_valid(player) and player.has_method("is_in_vehicle"):
		return bool(player.call("is_in_vehicle"))
	return false


func _place_reticle_at_world_position(reticle: TextureRect, world_position: Vector3, requested_size: Vector2) -> bool:
	if reticle == null:
		return false

	var camera := _get_hud_camera()
	if camera == null or camera.is_position_behind(world_position):
		return false

	var viewport_size := get_viewport().get_visible_rect().size
	var margin :float = max(aim_target_screen_margin, 0.0)
	var screen_position := camera.unproject_position(world_position)
	screen_position.x = clamp(screen_position.x, margin, viewport_size.x - margin)
	screen_position.y = clamp(screen_position.y, margin, viewport_size.y - margin)

	var final_size := requested_size
	if final_size.x <= 0.0 or final_size.y <= 0.0:
		final_size = reticle.size
	if final_size.x <= 0.0 or final_size.y <= 0.0:
		final_size = Vector2(36.0, 36.0)

	reticle.size = final_size
	reticle.pivot_offset = final_size * 0.5
	reticle.position = screen_position - final_size * 0.5
	reticle.visible = true
	return true


func _place_reticle_at_screen_position(reticle: TextureRect, screen_position: Vector2, requested_size: Vector2) -> void:
	if reticle == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var margin :float = max(aim_target_screen_margin, 0.0)
	screen_position.x = clamp(screen_position.x, margin, viewport_size.x - margin)
	screen_position.y = clamp(screen_position.y, margin, viewport_size.y - margin)

	var final_size := requested_size
	if final_size.x <= 0.0 or final_size.y <= 0.0:
		final_size = reticle.size
	if final_size.x <= 0.0 or final_size.y <= 0.0:
		final_size = Vector2(48.0, 48.0)

	reticle.size = final_size
	reticle.pivot_offset = final_size * 0.5
	reticle.position = screen_position - final_size * 0.5
	reticle.visible = true


func _turret_is_operated_by_local_player(turret: Variant) -> bool:
	if not _is_valid_object(turret):
		return false

	if turret.has_method("is_local_operator"):
		return bool(turret.call("is_local_operator"))

	var local_peer_id := multiplayer.get_unique_id()
	if turret.has_method("is_peer_operator"):
		return bool(turret.call("is_peer_operator", local_peer_id))
	if turret.has_method("is_operated_by_peer"):
		return bool(turret.call("is_operated_by_peer", local_peer_id))
	if turret.has_method("get_operator_peer_id"):
		return int(turret.call("get_operator_peer_id")) == local_peer_id

	var operator_peer_id = turret.get("operator_peer_id")
	if operator_peer_id is int:
		return int(operator_peer_id) == local_peer_id

	# Fallback : si le véhicule fournit déjà la tourelle courante au HUD,
	# on considère qu'elle correspond au siège occupé par le joueur local.
	return true


func _hide_aim_target_reticle() -> void:
	if aim_target_reticle != null:
		aim_target_reticle.visible = false


func _hide_vehicle_turret_reticle() -> void:
	if vehicle_turret_reticle != null:
		vehicle_turret_reticle.visible = false

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
		_hide_aim_target_reticle()
		_hide_vehicle_turret_reticle()
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
		#common_panel.visible = false
		on_foot_panel.visible = false
		vehicle_panel.visible = false
		_hide_vehicle_fuel_bar()
		_hide_vehicle_mod_slots()
		hide_repair_target(true)
		hide_reload_progress()
		_hide_aim_target_reticle()
		_hide_vehicle_turret_reticle()
		_show_death_overlay(player_data)
		_refresh_revive_panel(player_data)
		return

	_hide_death_overlay()
	_refresh_common(player_data)
	_refresh_on_foot(player_data)
	_refresh_reload_progress(player_data)
	_refresh_vehicle(player_data, tracked_vehicle)
	_refresh_revive_panel(player_data)

	#common_panel.visible = true
	on_foot_panel.visible = not in_vehicle
	vehicle_panel.visible = in_vehicle
	if not in_vehicle:
		_hide_vehicle_fuel_bar()
		_hide_vehicle_mod_slots()

func _show_death_overlay(player_data: Dictionary) -> void:
	death_overlay.visible = true
	_configure_death_overlay_input()

	var is_final_dead: bool = bool(player_data.get("is_final_dead", false))
	var team_lives: int = max(int(player_data.get("team_respawn_lives", 0)), 0)
	var remaining: float = float(player_data.get("respawn_remaining", 0.0))
	var respawn_delay_ready: bool = remaining <= 0.0
	var respawn_available: bool = bool(player_data.get("respawn_available", false))

	death_message_label.text = "Vous êtes mort définitivement." if is_final_dead else "Vous êtes à terre."

	if final_death_countdown_label != null and final_death_progress != null:
		_refresh_final_death_delay(player_data, is_final_dead)

	if team_lives <= 0:
		respawn_pending = false
		respawn_button.text = "Plus aucune vie d'équipe."
	elif respawn_delay_ready:
		respawn_button.text = _format_respawn_button_text(team_lives)
	else:
		respawn_button.text = "Respawn disponible dans %.1fs" % remaining
	
	respawn_button.disabled = respawn_pending or not respawn_available

	_refresh_spectate_button(player_data)
	_refresh_death_revive_progress(player_data)


func _refresh_final_death_delay(player_data: Dictionary, is_final_dead: bool) -> void:
	var delay: float = max(float(player_data.get("final_death_delay", 30.0)), 0.0)
	var remaining: float = max(float(player_data.get("final_death_remaining", delay)), 0.0)

	if is_final_dead:
		final_death_countdown_label.visible = true
		final_death_countdown_label.text = "Réanimation impossible. Respawn requis."
		final_death_progress.visible = false
		final_death_progress.value = 0.0
		return

	final_death_countdown_label.visible = true
	if bool(player_data.get("final_death_timer_paused", false)):
		final_death_countdown_label.text = "Mort définitive suspendue pendant la réanimation. %.1fs restantes" % remaining
	else:
		final_death_countdown_label.text = "Mort définitive dans %.1fs" % remaining
	final_death_progress.visible = true
	final_death_progress.min_value = 0.0
	final_death_progress.max_value = 100.0
	if delay <= 0.0:
		final_death_progress.value = 0.0
	else:
		final_death_progress.value = clamp(remaining / delay, 0.0, 1.0) * 100.0


func _format_respawn_button_text(team_lives: int) -> String:
	var suffix: String = "vie restante" if team_lives <= 1 else "vies restantes"
	return "Respawn (x%d %s)" % [team_lives, suffix]


func _refresh_spectate_button(player_data: Dictionary) -> void:
	if spectate_next_button == null:
		return

	var target_name: String = str(player_data.get("spectator_target_name", ""))
	spectate_next_button.visible = true
	spectate_next_button.disabled = false
	spectate_next_button.mouse_filter = Control.MOUSE_FILTER_STOP
	spectate_next_button.z_index = 100
	if bool(player_data.get("spectating", false)) and not target_name.is_empty():
		spectate_next_button.text = "Caméra suivante : %s" % target_name
	else:
		spectate_next_button.text = "Caméra suivante"

func _hide_death_overlay() -> void:
	respawn_pending = false
	death_overlay.visible = false
	death_revive_label.visible = false
	death_revive_progress.visible = false
	if final_death_countdown_label != null:
		final_death_countdown_label.visible = false
	if final_death_progress != null:
		final_death_progress.visible = false
	if spectate_next_button != null:
		spectate_next_button.visible = false
	respawn_button.text = "Respawn"
	respawn_button.disabled = false

func _on_respawn_button_pressed() -> void:
	if respawn_pending or respawn_button.disabled:
		return

	respawn_pending = true
	respawn_button.disabled = true
	emit_signal("respawn_requested")


func _on_spectate_next_button_pressed() -> void:
	emit_signal("spectate_next_requested")

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
		_set_name_marker_death_state(marker, target)
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


func _set_name_marker_death_state(marker: Control, target: Node) -> void:
	if marker == null or target == null or not is_instance_valid(target):
		return

	var dead: bool = bool(target.get("is_dead"))
	var final_dead: bool = _target_is_final_dead(target)
	var delay: float = 30.0
	if _target_has_property(target, "downed_to_final_death_seconds"):
		delay = max(float(target.get("downed_to_final_death_seconds")), 0.0)

	var elapsed: float = 0.0
	if _target_has_property(target, "death_elapsed_time"):
		elapsed = max(float(target.get("death_elapsed_time")), 0.0)

	var remaining: float = max(delay - elapsed, 0.0)
	var progress: float = 0.0
	if dead:
		progress = 0.0 if delay <= 0.0 else clamp(remaining / delay, 0.0, 1.0)

	if marker.has_method("set_death_state"):
		marker.call("set_death_state", dead, final_dead, progress)


func _target_is_final_dead(target: Node) -> bool:
	if not _target_has_property(target, "is_final_dead"):
		return false
	return bool(target.get("is_final_dead"))


func _target_has_property(target: Node, property_name: String) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	for property_data in target.get_property_list():
		if str(property_data.get("name", "")) == property_name:
			return true

	return false

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
		if _target_is_final_dead(target):
			return "%s (mort)" % base_name
		return "%s (à terre)" % base_name

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
	health_label.text = str(round(hp)) + "/" + str(round(max_hp))

func _cache_weapon_slot_nodes() -> void:
	_weapon_slot_panels.clear()
	_weapon_slot_icons.clear()
	_weapon_slot_ammo_labels.clear()

	if weapon_1_slot != null:
		_weapon_slot_panels.append(weapon_1_slot)
	if weapon_2_slot != null:
		_weapon_slot_panels.append(weapon_2_slot)

	if weapon_1_texture_rect != null:
		_weapon_slot_icons.append(weapon_1_texture_rect)
	if weapon_2_texture_rect != null:
		_weapon_slot_icons.append(weapon_2_texture_rect)

	if weapon_1_ammo_label != null:
		_weapon_slot_ammo_labels.append(weapon_1_ammo_label)
	if weapon_2_ammo_label != null:
		_weapon_slot_ammo_labels.append(weapon_2_ammo_label)


func _setup_weapon_slot_styles() -> void:
	_weapon_slot_normal_style = _make_weapon_slot_style(false)
	_weapon_slot_equipped_style = _make_weapon_slot_style(true)

	for panel in _weapon_slot_panels:
		if panel != null:
			panel.add_theme_stylebox_override("panel", _weapon_slot_normal_style)



func _refresh_weapon_slot_ui(player_data: Dictionary, weapon_1_name: String, weapon_2_name: String, equipped_weapon_name: String) -> void:
	if _weapon_slot_panels.is_empty() or _weapon_slot_icons.is_empty() or _weapon_slot_ammo_labels.is_empty():
		_cache_weapon_slot_nodes()

	var physical_weapon_names: Array[String] = [weapon_1_name, weapon_2_name]
	var display_weapon_names: Array[String] = _get_display_weapon_names(weapon_1_name, weapon_2_name, equipped_weapon_name)

	for display_slot_index in range(2):
		if display_slot_index >= _weapon_slot_panels.size() or display_slot_index >= _weapon_slot_icons.size() or display_slot_index >= _weapon_slot_ammo_labels.size():
			continue

		var weapon_name: String = display_weapon_names[display_slot_index]
		var source_slot_index: int = _find_weapon_source_slot_index(weapon_name, physical_weapon_names)
		if source_slot_index < 0:
			source_slot_index = display_slot_index

		var has_weapon: bool = not _is_empty_weapon_name(weapon_name)
		var is_equipped: bool = has_weapon and not _is_empty_weapon_name(equipped_weapon_name) and weapon_name == equipped_weapon_name

		var panel: PanelContainer = _weapon_slot_panels[display_slot_index]
		var icon: TextureRect = _weapon_slot_icons[display_slot_index]
		var ammo: Label = _weapon_slot_ammo_labels[display_slot_index]

		if panel != null:
			panel.add_theme_stylebox_override("panel", _weapon_slot_equipped_style if is_equipped else _weapon_slot_normal_style)
			panel.tooltip_text = weapon_name if has_weapon else "Aucune arme"

		if icon != null:
			icon.texture = _get_weapon_icon_texture(weapon_name) if has_weapon else null
			icon.visible = true
		
		if display_slot_index == 0:
			if ammo != null:
				ammo.visible = has_weapon
				if has_weapon:
					_update_weapon_slot_ammo_label(ammo, player_data, display_slot_index, source_slot_index, weapon_name, equipped_weapon_name)
				else:
					ammo.text = ""
					_set_weapon_slot_ammo_cache(display_slot_index, "", "")


func _get_display_weapon_names(weapon_1_name: String, weapon_2_name: String, equipped_weapon_name: String) -> Array[String]:
	var display_weapon_names: Array[String] = []

	if _is_empty_weapon_name(equipped_weapon_name):
		display_weapon_names.append(weapon_1_name)
		display_weapon_names.append(weapon_2_name)
		return display_weapon_names

	var backpack_weapon_name: String = "Aucune"
	if not _is_empty_weapon_name(weapon_1_name) and weapon_1_name != equipped_weapon_name:
		backpack_weapon_name = weapon_1_name
	elif not _is_empty_weapon_name(weapon_2_name) and weapon_2_name != equipped_weapon_name:
		backpack_weapon_name = weapon_2_name

	display_weapon_names.append(equipped_weapon_name)
	display_weapon_names.append(backpack_weapon_name)
	return display_weapon_names


func _find_weapon_source_slot_index(weapon_name: String, physical_weapon_names: Array[String]) -> int:
	if _is_empty_weapon_name(weapon_name):
		return -1

	var normalized_weapon_name: String = weapon_name.strip_edges().to_lower()
	for source_slot_index in range(physical_weapon_names.size()):
		var candidate_name: String = physical_weapon_names[source_slot_index]
		if candidate_name == weapon_name:
			return source_slot_index
		if candidate_name.strip_edges().to_lower() == normalized_weapon_name:
			return source_slot_index

	return -1


func _make_weapon_slot_style(is_equipped: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.82)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color.WHITE if is_equipped else Color.BLACK
	return style


func _scan_weapon_icon_folder() -> void:
	_weapon_icon_paths.clear()

	var dir: DirAccess = DirAccess.open(WEAPON_ICON_DIR)
	if dir == null:
		push_warning("Dossier d'icônes d'armes introuvable : %s" % WEAPON_ICON_DIR)
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == "png":
			var path: String = WEAPON_ICON_DIR + file_name
			_weapon_icon_paths[file_name] = path
			_weapon_icon_paths[file_name.to_lower()] = path
		file_name = dir.get_next()
	dir.list_dir_end()


func _get_weapon_icon_texture(weapon_name: String) -> Texture2D:
	var icon_path: String = _find_weapon_icon_path(weapon_name)
	if icon_path.is_empty():
		return null

	if _weapon_icon_textures.has(icon_path):
		var cached_texture: Variant = _weapon_icon_textures.get(icon_path)
		if cached_texture is Texture2D:
			return cached_texture
		return null

	var loaded_resource: Resource = load(icon_path)
	if loaded_resource is Texture2D:
		var texture: Texture2D = loaded_resource as Texture2D
		_weapon_icon_textures[icon_path] = texture
		return texture

	_weapon_icon_textures[icon_path] = null
	return null


func _find_weapon_icon_path(weapon_name: String) -> String:
	if _is_empty_weapon_name(weapon_name):
		return ""

	var candidates: Array[String] = _get_weapon_icon_candidates(weapon_name)
	for candidate in candidates:
		if _weapon_icon_paths.has(candidate):
			return str(_weapon_icon_paths[candidate])

		var lower_candidate: String = candidate.to_lower()
		if _weapon_icon_paths.has(lower_candidate):
			return str(_weapon_icon_paths[lower_candidate])

		var direct_path: String = WEAPON_ICON_DIR + candidate
		if ResourceLoader.exists(direct_path):
			return direct_path

	return ""


func _get_weapon_icon_candidates(weapon_name: String) -> Array[String]:
	var candidates: Array[String] = []
	var clean_name: String = weapon_name.strip_edges()
	var normalized_name: String = _normalize_weapon_icon_name(clean_name)

	_append_unique_string(candidates, WEAPON_ICON_PREFIX + clean_name + WEAPON_ICON_EXTENSION)
	if not normalized_name.is_empty():
		_append_unique_string(candidates, WEAPON_ICON_PREFIX + normalized_name + WEAPON_ICON_EXTENSION)

	return candidates


func _append_unique_string(values: Array[String], value: String) -> void:
	if value.is_empty():
		return
	if not values.has(value):
		values.append(value)


func _normalize_weapon_icon_name(weapon_name: String) -> String:
	return weapon_name.strip_edges().to_lower().replace(" ", "_").replace("-", "_")


func _is_empty_weapon_name(weapon_name: String) -> bool:
	var clean_name: String = weapon_name.strip_edges().to_lower()
	return clean_name.is_empty() or clean_name == "aucune" or clean_name == "none" or clean_name == "null" or clean_name == "-"


func _update_weapon_slot_ammo_label(ammo: Label, player_data: Dictionary, display_slot_index: int, source_slot_index: int, weapon_name: String, equipped_weapon_name: String) -> void:
	_ensure_weapon_slot_ammo_cache_size(display_slot_index)

	var cached_weapon_name: String = _weapon_slot_last_weapon_names[display_slot_index]
	if cached_weapon_name != weapon_name:
		_weapon_slot_last_weapon_names[display_slot_index] = weapon_name
		_weapon_slot_last_ammo_texts[display_slot_index] = ""
		ammo.text = _get_weapon_cached_ammo_text(weapon_name)

	var ammo_text: String = _get_weapon_slot_ammo_text(player_data, source_slot_index, weapon_name, equipped_weapon_name)
	if not ammo_text.is_empty():
		ammo.text = ammo_text
		_weapon_slot_last_ammo_texts[display_slot_index] = ammo_text
		_set_weapon_cached_ammo_text(weapon_name, ammo_text)
		return

	var cached_weapon_ammo_text: String = _get_weapon_cached_ammo_text(weapon_name)
	if not cached_weapon_ammo_text.is_empty():
		ammo.text = cached_weapon_ammo_text
		_weapon_slot_last_ammo_texts[display_slot_index] = cached_weapon_ammo_text
		return

	var cached_slot_ammo_text: String = _weapon_slot_last_ammo_texts[display_slot_index]
	if ammo.text.is_empty() and not cached_slot_ammo_text.is_empty():
		ammo.text = cached_slot_ammo_text


func _ensure_weapon_slot_ammo_cache_size(slot_index: int) -> void:
	while _weapon_slot_last_ammo_texts.size() <= slot_index:
		_weapon_slot_last_ammo_texts.append("")
	while _weapon_slot_last_weapon_names.size() <= slot_index:
		_weapon_slot_last_weapon_names.append("")


func _set_weapon_slot_ammo_cache(slot_index: int, weapon_name: String, ammo_text: String) -> void:
	_ensure_weapon_slot_ammo_cache_size(slot_index)
	_weapon_slot_last_weapon_names[slot_index] = weapon_name
	_weapon_slot_last_ammo_texts[slot_index] = ammo_text


func _get_weapon_cache_key(weapon_name: String) -> String:
	return weapon_name.strip_edges().to_lower()


func _get_weapon_cached_ammo_text(weapon_name: String) -> String:
	var cache_key: String = _get_weapon_cache_key(weapon_name)
	if cache_key.is_empty():
		return ""
	return str(_weapon_ammo_text_by_name.get(cache_key, ""))


func _set_weapon_cached_ammo_text(weapon_name: String, ammo_text: String) -> void:
	var cache_key: String = _get_weapon_cache_key(weapon_name)
	if cache_key.is_empty() or ammo_text.is_empty():
		return
	_weapon_ammo_text_by_name[cache_key] = ammo_text


func _get_weapon_slot_ammo_text(player_data: Dictionary, slot_index: int, weapon_name: String, equipped_weapon_name: String) -> String:
	var slot_data: Dictionary = _get_weapon_slot_data(player_data, slot_index, weapon_name)

	if weapon_name == equipped_weapon_name:
		var equipped_slot_data: Dictionary = slot_data.duplicate()
		var live_equipped_data: Dictionary = {}
		_copy_first_available_int(player_data, live_equipped_data, ["mag_ammo", "magazine_ammo", "current_ammo", "current_mag_ammo", "munition_actuelle", "munition_actuel", "ammo"], "mag_ammo")
		_copy_first_available_int(player_data, live_equipped_data, ["max_mag_ammo", "magazine_max_ammo", "max_magazine_ammo", "magazine_capacity", "magazine_size", "clip_size", "taille_du_chargeur", "taille_chargeur", "chargeur_max"], "max_mag_ammo")
		_copy_first_available_bool(player_data, live_equipped_data, ["infinite_ammo"], "infinite_ammo")

		for key in live_equipped_data.keys():
			equipped_slot_data[key] = live_equipped_data[key]

		if not equipped_slot_data.has("max_mag_ammo"):
			var inferred_mag_size: int = _find_weapon_magazine_size(player_data, slot_index, weapon_name, equipped_weapon_name)
			if inferred_mag_size >= 0:
				equipped_slot_data["max_mag_ammo"] = inferred_mag_size

		if not equipped_slot_data.is_empty():
			return _format_weapon_ammo_text(equipped_slot_data, player_data, slot_index, weapon_name, equipped_weapon_name)

	if not slot_data.is_empty():
		return _format_weapon_ammo_text(slot_data, player_data, slot_index, weapon_name, equipped_weapon_name)

	return ""


func _get_weapon_slot_data(player_data: Dictionary, slot_index: int, weapon_name: String) -> Dictionary:
	var slot_number: int = slot_index + 1
	var direct_key: String = "weapon_%d_ammo_data" % slot_number
	if player_data.has(direct_key) and player_data[direct_key] is Dictionary:
		return player_data[direct_key]

	var slot_data: Dictionary = {}

	var mag_keys: Array[String] = [
		"weapon_%d_mag_ammo" % slot_number,
		"weapon_%d_magazine_ammo" % slot_number,
		"weapon_%d_current_ammo" % slot_number,
		"weapon_%d_current_mag_ammo" % slot_number,
		"weapon_%d_munition_actuelle" % slot_number,
		"weapon_%d_munition_actuel" % slot_number,
		"weapon_%d_ammo" % slot_number,
	]
	var max_mag_keys: Array[String] = [
		"weapon_%d_max_mag_ammo" % slot_number,
		"weapon_%d_magazine_max_ammo" % slot_number,
		"weapon_%d_max_magazine_ammo" % slot_number,
		"weapon_%d_magazine_capacity" % slot_number,
		"weapon_%d_magazine_size" % slot_number,
		"weapon_%d_clip_size" % slot_number,
		"weapon_%d_taille_du_chargeur" % slot_number,
		"weapon_%d_taille_chargeur" % slot_number,
		"weapon_%d_chargeur_max" % slot_number,
	]
	var infinite_key: String = "weapon_%d_infinite_ammo" % slot_number
	var ammo_type_key: String = "weapon_%d_ammo_type" % slot_number

	_copy_first_available_int(player_data, slot_data, mag_keys, "mag_ammo")
	_copy_first_available_int(player_data, slot_data, max_mag_keys, "max_mag_ammo")
	if player_data.has(infinite_key):
		slot_data["infinite_ammo"] = bool(player_data.get(infinite_key, false))
	if player_data.has(ammo_type_key):
		slot_data["ammo_type"] = str(player_data.get(ammo_type_key, ""))

	if not slot_data.is_empty():
		return slot_data

	if player_data.has("weapon_slots") and player_data["weapon_slots"] is Array:
		var weapon_slots: Array = player_data["weapon_slots"]
		if slot_index >= 0 and slot_index < weapon_slots.size() and weapon_slots[slot_index] is Dictionary:
			return weapon_slots[slot_index]

	if player_data.has("weapons") and player_data["weapons"] is Array:
		var weapons_array: Array = player_data["weapons"]
		if slot_index >= 0 and slot_index < weapons_array.size() and weapons_array[slot_index] is Dictionary:
			return weapons_array[slot_index]

	if player_data.has("weapons") and player_data["weapons"] is Dictionary:
		var weapons_dict: Dictionary = player_data["weapons"]
		if weapons_dict.has(weapon_name) and weapons_dict[weapon_name] is Dictionary:
			return weapons_dict[weapon_name]

	return {}


func _format_weapon_ammo_text(slot_data: Dictionary, player_data: Dictionary, slot_index: int, weapon_name: String, equipped_weapon_name: String) -> String:
	if slot_data.has("ammo_text"):
		return str(slot_data.get("ammo_text", ""))

	var infinite_ammo: bool = bool(slot_data.get("infinite_ammo", false))
	var mag_ammo: int = _read_int_from_keys(slot_data, ["mag_ammo", "magazine_ammo", "current_ammo", "current_mag_ammo", "munition_actuelle", "munition_actuel", "ammo"], -1)
	var max_mag_ammo: int = _read_int_from_keys(slot_data, ["max_mag_ammo", "magazine_max_ammo", "max_magazine_ammo", "magazine_capacity", "magazine_size", "clip_size", "taille_du_chargeur", "taille_chargeur", "chargeur_max"], -1)

	if max_mag_ammo < 0:
		max_mag_ammo = _find_weapon_magazine_size(player_data, slot_index, weapon_name, equipped_weapon_name)

	if mag_ammo >= 0 and max_mag_ammo >= 0:
		return "%d / %d" % [mag_ammo, max_mag_ammo]
	if mag_ammo >= 0 and infinite_ammo:
		return "%d / ∞" % mag_ammo
	if infinite_ammo:
		return "∞"
	if mag_ammo >= 0:
		return str(mag_ammo)
	if max_mag_ammo >= 0:
		return "- / %d" % max_mag_ammo

	return ""


func _copy_first_available_int(source: Dictionary, target: Dictionary, keys: Array[String], target_key: String) -> void:
	for key in keys:
		if source.has(key):
			target[target_key] = int(source.get(key, 0))
			return


func _copy_first_available_bool(source: Dictionary, target: Dictionary, keys: Array[String], target_key: String) -> void:
	for key in keys:
		if source.has(key):
			target[target_key] = bool(source.get(key, false))
			return


func _read_int_from_keys(data: Dictionary, keys: Array[String], fallback: int) -> int:
	for key in keys:
		if data.has(key):
			return int(data.get(key, fallback))
	return fallback


func _find_weapon_magazine_size(player_data: Dictionary, slot_index: int, weapon_name: String, equipped_weapon_name: String) -> int:
	var slot_number: int = slot_index + 1
	var candidate_values: Array = []

	# Sources les plus fiables : dictionnaires déjà envoyés au HUD.
	var slot_data: Dictionary = _get_weapon_slot_data(player_data, slot_index, weapon_name)
	if not slot_data.is_empty():
		candidate_values.append(slot_data)

	if player_data.has("weapon_slots"):
		candidate_values.append(player_data.get("weapon_slots"))
	if player_data.has("weapons"):
		candidate_values.append(player_data.get("weapons"))

	# Sources possibles : l'arme ou les armes passées directement dans get_hud_data().
	var player_data_weapon_keys: Array[String] = [
		"weapon_%d" % slot_number,
		"weapon_%d_node" % slot_number,
		"weapon_%d_resource" % slot_number,
		"weapon_%d_data" % slot_number,
	]
	for key in player_data_weapon_keys:
		if player_data.has(key):
			candidate_values.append(player_data.get(key))

	if weapon_name == equipped_weapon_name:
		for key in ["equipped_weapon", "current_weapon", "active_weapon", "weapon"]:
			if player_data.has(key):
				candidate_values.append(player_data.get(key))

	# Dernier recours : lire directement dans le player si get_hud_data() n'envoie que l'arme équipée.
	if player != null and is_instance_valid(player):
		candidate_values.append(_call_method_if_available(player, "get_weapon", [slot_index]))
		candidate_values.append(_call_method_if_available(player, "get_weapon", [slot_number]))
		candidate_values.append(_call_method_if_available(player, "get_weapon_slot", [slot_index]))
		candidate_values.append(_call_method_if_available(player, "get_weapon_slot", [slot_number]))
		candidate_values.append(_call_method_if_available(player, "get_weapon_%d" % slot_number, []))
		if weapon_name == equipped_weapon_name:
			candidate_values.append(_call_method_if_available(player, "get_equipped_weapon", []))
			candidate_values.append(_call_method_if_available(player, "get_current_weapon", []))
			candidate_values.append(_call_method_if_available(player, "get_active_weapon", []))

		for key in ["weapon_%d" % slot_number, "weapon_%d_node" % slot_number, "weapon_%d_resource" % slot_number]:
			candidate_values.append(player.get(key))

		if weapon_name == equipped_weapon_name:
			for key in ["equipped_weapon", "current_weapon", "active_weapon", "weapon"]:
				candidate_values.append(player.get(key))

	for candidate in candidate_values:
		var value: int = _read_magazine_size_from_variant(candidate, slot_index, weapon_name, 0)
		if value >= 0:
			return value

	return -1


func _read_magazine_size_from_variant(value: Variant, slot_index: int, weapon_name: String, depth: int) -> int:
	if depth > 3 or value == null:
		return -1

	var magazine_size_keys: Array[String] = [
		"max_mag_ammo",
		"magazine_max_ammo",
		"max_magazine_ammo",
		"magazine_capacity",
		"magazine_size",
		"clip_size",
		"taille_du_chargeur",
		"taille_chargeur",
		"chargeur_max",
	]

	if value is Dictionary:
		var data: Dictionary = value as Dictionary
		var direct_value: int = _read_int_from_keys(data, magazine_size_keys, -1)
		if direct_value >= 0:
			return direct_value

		var slot_number: int = slot_index + 1
		for key in ["weapon_%d" % slot_number, "weapon_%d_data" % slot_number, "weapon_%d_resource" % slot_number]:
			if data.has(key):
				var nested_slot_value: int = _read_magazine_size_from_variant(data.get(key), slot_index, weapon_name, depth + 1)
				if nested_slot_value >= 0:
					return nested_slot_value

		if data.has(weapon_name):
			var named_weapon_value: int = _read_magazine_size_from_variant(data.get(weapon_name), slot_index, weapon_name, depth + 1)
			if named_weapon_value >= 0:
				return named_weapon_value

		for key in ["data", "weapon_data", "stats", "config", "definition", "resource"]:
			if data.has(key):
				var nested_data_value: int = _read_magazine_size_from_variant(data.get(key), slot_index, weapon_name, depth + 1)
				if nested_data_value >= 0:
					return nested_data_value

		return -1

	if value is Array:
		var values: Array = value as Array
		if slot_index >= 0 and slot_index < values.size():
			var slot_value: int = _read_magazine_size_from_variant(values[slot_index], slot_index, weapon_name, depth + 1)
			if slot_value >= 0:
				return slot_value
		return -1

	if value is Object:
		var object_value: Object = value as Object
		var method_names: Array[String] = [
			"get_max_mag_ammo",
			"get_magazine_max_ammo",
			"get_max_magazine_ammo",
			"get_magazine_capacity",
			"get_magazine_size",
			"get_clip_size",
			"get_taille_du_chargeur",
		]
		for method_name in method_names:
			if object_value.has_method(method_name):
				return int(object_value.call(method_name))

		for key in magazine_size_keys:
			var property_value: Variant = object_value.get(key)
			if property_value != null:
				return int(property_value)

		for key in ["data", "weapon_data", "stats", "config", "definition", "resource"]:
			var nested_value: Variant = object_value.get(key)
			var nested_result: int = _read_magazine_size_from_variant(nested_value, slot_index, weapon_name, depth + 1)
			if nested_result >= 0:
				return nested_result

	return -1


func _call_method_if_available(target: Object, method_name: String, arguments: Array) -> Variant:
	if target == null or not target.has_method(method_name):
		return null
	return target.callv(method_name, arguments)


func _refresh_on_foot(player_data: Dictionary) -> void:
	var weapon_1_name: String = str(player_data.get("weapon_1_name", "Aucune"))
	var weapon_2_name: String = str(player_data.get("weapon_2_name", "Aucune"))
	var equipped_weapon_name: String = str(player_data.get("equipped_weapon_name", "Aucune"))
	var money: int = int(player_data.get("money", 0))

	_refresh_weapon_slot_ui(player_data, weapon_1_name, weapon_2_name, equipped_weapon_name)
	_build_reserve_ui(player_data)
	money_label.text = str(money) #"Argent : %d" % money


func _refresh_reload_progress(player_data: Dictionary) -> void:
	var reload_active: bool = bool(player_data.get("reload_active", false))
	var reload_duration: float = max(float(player_data.get("reload_duration", 0.0)), 0.0)
	var reload_remaining: float = max(float(player_data.get("reload_remaining", 0.0)), 0.0)

	if not reload_active or reload_duration <= 0.0:
		hide_reload_progress()
		return

	var normalized_progress: float = 1.0 - (reload_remaining / reload_duration)
	show_reload_progress(normalized_progress, reload_remaining)


func show_reload_progress(progress: float, remaining_seconds: float = -1.0) -> void:
	if reload_panel == null or reload_progress_bar == null:
		return

	var normalized_progress: float = clamp(progress, 0.0, 1.0)
	reload_panel.visible = true
	reload_progress_bar.min_value = 0.0
	reload_progress_bar.max_value = 100.0
	reload_progress_bar.value = normalized_progress * 100.0

	if reload_label != null:
		if remaining_seconds >= 0.0:
			reload_label.text = "%.1f s" % max(remaining_seconds, 0.0) # "Rechargement : %.1f s" % max(remaining_seconds, 0.0)
		else:
			reload_label.text = "%d %%" % roundi(normalized_progress * 100.0)


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


func _clear_editor_vehicle_mod_slots() -> void:
	_vehicle_mod_slot_nodes.clear()

	if vehicle_mods_grid == null:
		return

	for child: Node in vehicle_mods_grid.get_children():
		vehicle_mods_grid.remove_child(child)
		child.queue_free()



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

		var player_interactor = player.get("vehicle_interactor")
		var from_interactor = _find_turret_on_object(player_interactor, possible_keys)
		if _is_valid_object(from_interactor):
			return from_interactor

	return null


func _find_turret_on_object(source: Variant, possible_keys: Array[String]) -> Variant:
	if not _is_valid_object(source):
		return null

	var possible_methods: Array[String] = [
		"get_current_turret",
		"get_controlled_turret",
		"get_active_turret",
		"get_mounted_turret",
		"get_turret",
	]

	for method_name in possible_methods:
		if source.has_method(method_name):
			var method_value = source.call(method_name)
			if _is_valid_object(method_value):
				return method_value

	for key in possible_keys:
		var property_value = source.get(key)
		if _is_valid_object(property_value):
			return property_value

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
	var equipped_ammo_type: String = str(player_data.get("equipped_ammo_type", "")).strip_edges().to_lower()

	_refresh_ammo_panel_selection(equipped_ammo_type)

	if reserves.is_empty():
		return

	if reserves.has("9mm"):
		ammo_9mm.text = str(int(reserves.get("9mm", 0)))

	if reserves.has("rifle"):
		ammo_rifle.text = str(int(reserves.get("rifle", 0)))

	if reserves.has("shell"):
		ammo_shell.text = str(int(reserves.get("shell", 0)))

	if reserves.has("rocket"):
		ammo_rocket.text = str(int(reserves.get("rocket", 0)))

	if reserves.has("energy"):
		ammo_energy.text = str(int(reserves.get("energy", 0)))


func _refresh_ammo_panel_selection(equipped_ammo_type: String) -> void:
	_set_ammo_panel_selected(panel_9mm, equipped_ammo_type == "9mm")
	_set_ammo_panel_selected(panel_rifle, equipped_ammo_type == "rifle")
	_set_ammo_panel_selected(panel_shell, equipped_ammo_type == "shell")
	_set_ammo_panel_selected(panel_rocket, equipped_ammo_type == "rocket")
	_set_ammo_panel_selected(panel_energy, equipped_ammo_type == "energy")


func _set_ammo_panel_selected(panel: Panel, is_selected: bool) -> void:
	if panel == null:
		return

	panel.self_modulate = AMMO_PANEL_SELECTED_MODULATE if is_selected else AMMO_PANEL_UNSELECTED_MODULATE


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
