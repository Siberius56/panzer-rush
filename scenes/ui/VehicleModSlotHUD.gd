extends PanelContainer
class_name VehicleModSlotHUD

@export var empty_text: String = "empty"
@export var active_text: String = "ACTIVE"
@export var ready_text: String = "READY"
@export var cooldown_prefix: String = "CD"
@export var max_name_length: int = 12

@onready var mod_name_label: Label = %ModNameLabel
@onready var mod_type_label: Label = %ModTypeLabel
@onready var key_label: Label = %KeyLabel
@onready var cooldown_label: Label = %CooldownLabel
@onready var cooldown_progress: ProgressBar = %CooldownProgress


func set_slot_data(slot_data: Dictionary, is_driver: bool) -> void:
	var has_mod: bool = bool(slot_data.get("has_mod", false))
	if not has_mod:
		_show_empty_slot()
		return

	var mod_label: String = str(slot_data.get("mod_label", "Module")).strip_edges()
	if mod_label.is_empty():
		mod_label = "Module"

	var activation_mode: String = str(slot_data.get("activation_mode", "passive")).strip_edges().to_lower()
	var is_active_mod: bool = activation_mode == "active"
	var is_runtime_active: bool = bool(slot_data.get("is_active", false))
	var cooldown_remaining: float = maxf(float(slot_data.get("cooldown_remaining", 0.0)), 0.0)
	var cooldown_duration: float = maxf(float(slot_data.get("cooldown_duration", 0.0)), 0.0)
	var active_remaining: float = maxf(float(slot_data.get("active_remaining", 0.0)), 0.0)
	var active_duration: float = maxf(float(slot_data.get("active_duration", 0.0)), 0.0)

	mod_name_label.text = _shorten_name(mod_label)
	mod_type_label.visible = true
	mod_type_label.text = "ACTIVE" if is_active_mod else "PASSIVE"

	key_label.visible = is_driver and is_active_mod
	if key_label.visible:
		key_label.text = _build_key_text(slot_data)
	else:
		key_label.text = ""

	_refresh_state_display(is_active_mod, is_runtime_active, active_remaining, active_duration, cooldown_remaining, cooldown_duration)


func _show_empty_slot() -> void:
	mod_name_label.text = empty_text
	mod_type_label.visible = false
	mod_type_label.text = ""
	key_label.visible = false
	key_label.text = ""
	cooldown_label.visible = false
	cooldown_label.text = ""
	cooldown_progress.visible = false
	cooldown_progress.value = 0.0


func _refresh_state_display(
	is_active_mod: bool,
	is_runtime_active: bool,
	active_remaining: float,
	active_duration: float,
	cooldown_remaining: float,
	cooldown_duration: float
) -> void:
	if not is_active_mod:
		cooldown_label.visible = false
		cooldown_label.text = ""
		cooldown_progress.visible = false
		cooldown_progress.value = 0.0
		return

	if cooldown_remaining > 0.0:
		cooldown_label.visible = true
		cooldown_label.text = "%s %.1fs" % [cooldown_prefix, cooldown_remaining]
		cooldown_progress.visible = true
		cooldown_progress.value = _ratio_to_percent(cooldown_remaining, cooldown_duration)
		return

	if is_runtime_active:
		cooldown_label.visible = true
		cooldown_label.text = "%s %.1fs" % [active_text, active_remaining]
		cooldown_progress.visible = true
		cooldown_progress.value = _ratio_to_percent(active_remaining, active_duration)
		return

	cooldown_label.visible = true
	cooldown_label.text = ready_text
	cooldown_progress.visible = false
	cooldown_progress.value = 0.0


func _ratio_to_percent(remaining: float, duration: float) -> float:
	if duration <= 0.0:
		return 0.0
	return clampf(remaining / duration, 0.0, 1.0) * 100.0


func _build_key_text(slot_data: Dictionary) -> String:
	var fallback_label: String = str(slot_data.get("input_label", slot_data.get("mod_use_id", ""))).strip_edges()
	if fallback_label.is_empty():
		fallback_label = "?"

	var action_name: String = str(slot_data.get("input_action", "")).strip_edges()
	var input_label: String = _get_input_label(action_name, fallback_label)
	return "[%s]" % input_label


func _get_input_label(action_name: String, fallback_label: String) -> String:
	if action_name.is_empty():
		return fallback_label

	var action: StringName = StringName(action_name)
	if not InputMap.has_action(action):
		return fallback_label

	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if events.is_empty():
		return fallback_label

	var text: String = events[0].as_text().strip_edges()
	text = text.replace(" (Physical)", "")
	text = text.replace("Pressed", "")
	text = text.strip_edges()

	if text.is_empty() or text.length() > 10:
		return fallback_label

	return text


func _shorten_name(raw_name: String) -> String:
	if max_name_length <= 0:
		return raw_name
	if raw_name.length() <= max_name_length:
		return raw_name
	return raw_name.substr(0, max_name_length - 1) + "…"
