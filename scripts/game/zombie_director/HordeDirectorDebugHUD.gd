extends PanelContainer

@export var director_path: NodePath = ^"../../ZombieHordeDirector_DEMO"
@export var refresh_interval: float = 0.15

@export_group("State Colors")
@export var idle_color: Color = Color.WHITE
@export var preparation_color: Color = Color(1.0, 0.86, 0.15)
@export var horde_color: Color = Color(1.0, 0.18, 0.12)
@export var super_horde_color: Color = Color(0.72, 0.25, 1.0)
@export var cooldown_color: Color = Color(0.45, 0.75, 1.0)
@export var missing_director_color: Color = Color(1.0, 0.35, 0.35)

var refresh_timer: float = 0.0
var director: Node = null

@onready var state_label: Label = $MarginContainer/VBoxContainer/StateLabel
@onready var timer_label: Label = $MarginContainer/VBoxContainer/TimerLabel
@onready var alive_label: Label = $MarginContainer/VBoxContainer/AliveLabel
@onready var zone_label: Label = $MarginContainer/VBoxContainer/ZoneLabel
@onready var remaining_label: Label = $MarginContainer/VBoxContainer/RemainingLabel
@onready var event_label: Label = $MarginContainer/VBoxContainer/EventLabel
@onready var hint_label: Label = $MarginContainer/VBoxContainer/HintLabel


func _ready() -> void:
	director = get_node_or_null(director_path)
	_update_panel()


func _process(delta: float) -> void:
	refresh_timer -= delta
	if refresh_timer > 0.0:
		return

	refresh_timer = refresh_interval
	_update_panel()


func _update_panel() -> void:
	if director == null or not is_instance_valid(director):
		director = get_node_or_null(director_path)

	if director == null or not director.has_method("get_debug_info"):
		state_label.text = "État : Director introuvable"
		timer_label.text = ""
		alive_label.text = ""
		zone_label.text = ""
		remaining_label.text = ""
		event_label.text = ""
		hint_label.text = "Vérifie le NodePath du HUD."
		_apply_state_color(missing_director_color)
		return

	var info: Dictionary = director.call("get_debug_info")
	var state_key: String = str(info.get("state_key", "unknown"))
	var state_color: Color = _get_color_for_state_key(state_key)

	state_label.text = "État : %s" % str(info.get("state", "?"))
	timer_label.text = "Timer : %.1f s" % float(info.get("timer", 0.0))
	alive_label.text = "Zombies actifs : %d / %d" % [int(info.get("alive", 0)), int(info.get("max_alive", 0))]
	zone_label.text = "Zone active : %s" % str(info.get("active_zone", "Aucune"))
	var hammer_remaining: int = int(info.get("hammer_remaining", 0))
	if hammer_remaining > 0:
		remaining_label.text = "Reste à spawner : %d | Hammers : %d" % [int(info.get("remaining", 0)), hammer_remaining]
	else:
		remaining_label.text = "Reste à spawner : %d" % int(info.get("remaining", 0))
	event_label.text = "Dernier événement : %s" % str(info.get("last_event", ""))
	hint_label.text = str(info.get("next_action", ""))

	_apply_state_color(state_color)


func _get_color_for_state_key(state_key: String) -> Color:
	if state_key == "idle":
		return idle_color
	if state_key == "preparation":
		return preparation_color
	if state_key == "horde":
		return horde_color
	if state_key == "super_horde":
		return super_horde_color
	if state_key == "cooldown":
		return cooldown_color
	return missing_director_color


func _apply_state_color(color: Color) -> void:
	state_label.add_theme_color_override("font_color", color)
	hint_label.add_theme_color_override("font_color", color)
	add_theme_color_override("border_color", color)
