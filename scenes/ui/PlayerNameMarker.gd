extends Control
class_name PlayerNameMarker

@onready var name_label: Label = %NameLabel
@onready var death_row: HBoxContainer = %DeathRow
@onready var death_icon_texture_rect: TextureRect = %DeathIconTextureRect
@onready var death_icon_fallback_label: Label = %DeathIconFallbackLabel
@onready var revive_timer_progress: ProgressBar = %ReviveTimerProgress


func _ready() -> void:
	set_death_state(false, false, 0.0)


func set_marker_text(value: String) -> void:
	if name_label == null:
		return

	name_label.text = value


func set_death_state(dead: bool, final_dead: bool = false, revive_progress: float = 0.0) -> void:
	var show_skull: bool = dead
	var show_timer: bool = dead and not final_dead
	var normalized_progress: float = clamp(revive_progress, 0.0, 1.0)

	if death_row != null:
		death_row.visible = show_skull

	if death_icon_texture_rect != null:
		death_icon_texture_rect.visible = show_skull and death_icon_texture_rect.texture != null
		death_icon_texture_rect.self_modulate = Color(1.0, 0.35, 0.35, 1.0) if final_dead else Color.WHITE

	if death_icon_fallback_label != null:
		var use_fallback: bool = death_icon_texture_rect == null or death_icon_texture_rect.texture == null
		death_icon_fallback_label.visible = show_skull and use_fallback
		death_icon_fallback_label.text = "☠"

	if revive_timer_progress != null:
		revive_timer_progress.visible = show_timer
		revive_timer_progress.min_value = 0.0
		revive_timer_progress.max_value = 100.0
		revive_timer_progress.value = normalized_progress * 100.0
