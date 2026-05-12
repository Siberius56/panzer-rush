extends Button

signal resource_pressed(resource_data: Dictionary)

var resource_data: Dictionary = {}


func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)


func setup(data: Dictionary) -> void:
	resource_data = data.duplicate(true)

	var display_name: String = str(resource_data.get("display_name", "Module"))
	var score_cost: int = int(resource_data.get("score_cost", 0))
	var size: int = int(resource_data.get("mod_size", 0))
	var placement_text: String = str(resource_data.get("placement_text", ""))
	var unlocked: bool = bool(resource_data.get("unlocked", false))
	var affordable: bool = bool(resource_data.get("affordable", true))
	var selected: bool = bool(resource_data.get("selected", false))
	var selectable: bool = bool(resource_data.get("selectable", true))

	text = "%s\nCoût : %d | Taille : %d" % [display_name, score_cost, size]
	if not placement_text.is_empty():
		text += "\n%s" % placement_text
	if not unlocked:
		text += "\nVerrouillé"
	elif not affordable:
		text += "\nScore insuffisant"

	disabled = not unlocked or not affordable or not selectable
	toggle_mode = true
	set_pressed_no_signal(selected)
	tooltip_text = str(resource_data.get("scene_path", ""))


func _on_pressed() -> void:
	emit_signal("resource_pressed", resource_data.duplicate(true))
