extends CanvasLayer
class_name VictoryScreen

signal replay_requested
signal quit_requested

@export_file("*.tscn") var lobby_mission_select_scene_path: String = ""
@export_file("*.tscn") var main_menu_scene_path: String = ""
@export var pause_game_on_show: bool = true
@export var title_text: String = "VICTOIRE"
@export var subtitle_text: String = "Mission accomplie."
@export_multiline var stats_placeholder_text: String = "Statistiques de mission à venir."
@export var replay_button_text: String = "Rejouer"
@export var quit_button_text: String = "Quitter"

@onready var title_label: Label = $Root/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $Root/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SubtitleLabel
@onready var stats_label: Label = $Root/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatsLabel
@onready var replay_button: Button = $Root/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonRow/ReplayButton
@onready var quit_button: Button = $Root/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonRow/QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	_apply_static_texts()

	if replay_button != null and not replay_button.pressed.is_connected(_on_replay_pressed):
		replay_button.pressed.connect(_on_replay_pressed)

	if quit_button != null and not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)

	if pause_game_on_show:
		get_tree().paused = true


func show_victory(stats: Dictionary = {}) -> void:
	visible = true
	_apply_static_texts()
	_apply_stats(stats)

	if pause_game_on_show:
		get_tree().paused = true


func hide_victory() -> void:
	visible = false
	if pause_game_on_show:
		get_tree().paused = false


func set_scene_paths(lobby_path: String, menu_path: String) -> void:
	lobby_mission_select_scene_path = lobby_path
	main_menu_scene_path = menu_path


func _apply_static_texts() -> void:
	if title_label != null:
		title_label.text = title_text

	if subtitle_label != null:
		subtitle_label.text = subtitle_text

	if stats_label != null:
		stats_label.text = stats_placeholder_text

	if replay_button != null:
		replay_button.text = replay_button_text

	if quit_button != null:
		quit_button.text = quit_button_text


func _apply_stats(stats: Dictionary) -> void:
	if stats_label == null:
		return

	if stats.is_empty():
		stats_label.text = stats_placeholder_text
		return

	var lines: Array[String] = []
	for key in stats.keys():
		lines.append("%s : %s" % [String(key), str(stats[key])])

	var output: String = ""
	for i in range(lines.size()):
		if i > 0:
			output += "\n"
		output += lines[i]

	stats_label.text = output


func _on_replay_pressed() -> void:
	replay_requested.emit()
	_change_scene_or_warn(lobby_mission_select_scene_path, "VictoryScreen: lobby_mission_select_scene_path est vide.")


func _on_quit_pressed() -> void:
	quit_requested.emit()
	_change_scene_or_warn(main_menu_scene_path, "VictoryScreen: main_menu_scene_path est vide.")


func _change_scene_or_warn(scene_path: String, warning_message: String) -> void:
	if scene_path.is_empty():
		push_warning(warning_message)
		return

	if pause_game_on_show:
		get_tree().paused = false

	var error: Error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_warning("VictoryScreen: impossible de charger '%s'. Code d'erreur : %s." % [scene_path, error])
