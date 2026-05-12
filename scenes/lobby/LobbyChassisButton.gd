extends Button

signal resource_pressed(resource_data: Dictionary)

var resource_data: Dictionary = {}


func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)


func setup(data: Dictionary) -> void:
	resource_data = data.duplicate(true)

	var display_name: String = str(resource_data.get("display_name", "Châssis"))
	var score_total: int = int(resource_data.get("score_total", 0))
	var unlocked: bool = bool(resource_data.get("unlocked", false))
	var selected: bool = bool(resource_data.get("selected", false))
	var selectable: bool = bool(resource_data.get("selectable", true))

	text = "%s\nScore : %d" % [display_name, score_total]
	if not unlocked:
		text += "\nVerrouillé"

	disabled = not unlocked or not selectable
	toggle_mode = true
	set_pressed_no_signal(selected)
	tooltip_text = str(resource_data.get("scene_path", ""))


func _on_pressed() -> void:
	emit_signal("resource_pressed", resource_data.duplicate(true))
