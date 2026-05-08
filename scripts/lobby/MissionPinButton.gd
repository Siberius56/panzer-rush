extends TextureButton

signal mission_pressed(mission_index: int)

@export var hover_scale: float = 1.12
@export var hover_tween_duration: float = 0.10

@onready var name_label = %NameLabel
@onready var star_container = %StarContainer
@onready var node_selected = %NodeSelected

var mission_index: int = -1
var mission_data: Dictionary = {}
var is_selected: bool = false
var scale_tween: Tween = null


func _ready() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	scale = Vector2.ONE

	_update_pivot_offset()
	_set_node_selected_visible(false)

	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)

	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)


func setup(index: int, data: Dictionary) -> void:
	mission_index = index
	mission_data = data

	if name_label != null:
		name_label.text = str(data.get("name", "Mission"))

	var difficulty_value: int = _get_difficulty_value(data)
	_set_difficulty_stars(difficulty_value)
	set_selected_visual(false)


func set_selected_visual(selected: bool) -> void:
	is_selected = selected
	set_pressed_no_signal(selected)
	z_index = 10 if selected else 0
	_set_node_selected_visible(selected)

	# Ajoute ici ton visuel sélectionné si besoin.
	# Exemple : jouer une animation, changer une texture, modifier une couleur.


func set_interactable(value: bool) -> void:
	disabled = not value
	mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE

	if not value:
		_set_hovered(false)


func _set_difficulty_stars(difficulty_value: int) -> void:
	if star_container == null:
		return

	var star_count: int = star_container.get_child_count()
	var visible_count: int = int(clamp(difficulty_value, 0, star_count))

	for child_index in range(star_count):
		var star_node: Node = star_container.get_child(child_index)
		if star_node is CanvasItem:
			var star_canvas_item: CanvasItem = star_node as CanvasItem
			star_canvas_item.visible = child_index < visible_count


func _get_difficulty_value(data: Dictionary) -> int:
	var value: Variant = data.get("difficulty", data.get("difficulty_level", 0))

	match typeof(value):
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			return int(round(float(value)))
		TYPE_STRING:
			return _get_difficulty_value_from_string(str(value))
		_:
			return 0


func _get_difficulty_value_from_string(value: String) -> int:
	var cleaned_value: String = value.strip_edges().to_lower()

	if cleaned_value.is_valid_int():
		return int(cleaned_value)

	match cleaned_value:
		"tres facile", "très facile", "very easy":
			return 1
		"facile", "easy":
			return 1
		"normal":
			return 2
		"moyen", "medium":
			return 3
		"difficile", "hard":
			return 4
		"extreme", "extrême", "very hard", "nightmare":
			return 5
		_:
			return 0


func _set_node_selected_visible(value: bool) -> void:
	if node_selected == null:
		return

	node_selected.visible = value


func _set_hovered(value: bool) -> void:
	var target_scale: float = hover_scale if value else 1.0

	if scale_tween != null:
		scale_tween.kill()
		scale_tween = null

	if not is_inside_tree():
		scale = Vector2.ONE * target_scale
		return

	scale_tween = create_tween()
	scale_tween.tween_property(self, "scale", Vector2.ONE * target_scale, hover_tween_duration)


func _update_pivot_offset() -> void:
	pivot_offset = size * 0.5


func _on_pressed() -> void:
	mission_pressed.emit(mission_index)


func _on_mouse_entered() -> void:
	if disabled:
		return

	_set_hovered(true)


func _on_mouse_exited() -> void:
	_set_hovered(false)


func _on_resized() -> void:
	_update_pivot_offset()
