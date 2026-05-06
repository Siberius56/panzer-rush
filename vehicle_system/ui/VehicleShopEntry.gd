extends Container
class_name VehicleShopEntry

var _select_callback: Callable = Callable()

@onready var info_label: Label = %InfoLabel #$InfoLabel
@onready var select_button: Button = %SelectButton #$SelectButton


func _ready() -> void:
	if select_button != null and not select_button.pressed.is_connected(_on_select_pressed):
		select_button.pressed.connect(_on_select_pressed)


func setup(entry: Dictionary, is_selected: bool, select_callback: Callable) -> void:
	setup_custom(
		"%s | taille %d | prix %d" % [
			String(entry.get("turret_label", "")),
			int(entry.get("turret_size", 0)),
			int(entry.get("turret_price", 0))
		],
		"Sélectionnée" if is_selected else "Choisir",
		is_selected,
		select_callback
	)


func setup_chassis(
	entry: Dictionary,
	trade_in: int,
	total_after: int,
	is_current: bool,
	can_buy: bool,
	buy_callback: Callable
) -> void:
	var chassis_name := String(entry.get("vehicle_display_name", ""))
	var price := int(entry.get("chassis_price", 0))
	var button_text := "Actuel" if is_current else "Acheter ce tank"

	setup_custom(
		"%s | prix %d | reprise %d | argent après achat %d" % [
			chassis_name,
			price,
			trade_in,
			total_after
		],
		button_text,
		is_current or not can_buy,
		buy_callback
	)


func setup_custom(info_text: String, button_text: String, is_disabled: bool, callback: Callable) -> void:
	_select_callback = callback

	if info_label != null:
		info_label.text = info_text

	if select_button != null:
		select_button.text = button_text
		select_button.disabled = is_disabled


func _on_select_pressed() -> void:
	if _select_callback.is_valid():
		_select_callback.call()
