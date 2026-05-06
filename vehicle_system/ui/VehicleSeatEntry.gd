extends PanelContainer
class_name VehicleSeatEntry

var _install_callback: Callable = Callable()
var _sell_callback: Callable = Callable()

@onready var title_label: Label = %TitleLabel #$TitleLabel
@onready var state_label: Label = %StateLabel #$StateLabel
@onready var occupant_label: Label = %OccupantLabel #$OccupantLabel
@onready var install_button: Button = %InstallButton #$Actions/InstallButton
@onready var sell_button: Button = %SellButton #$Actions/SellButton
@onready var lock_label: Label = %LockLabel #$Actions/LockLabel


func _ready() -> void:
	if install_button != null and not install_button.pressed.is_connected(_on_install_pressed):
		install_button.pressed.connect(_on_install_pressed)

	if sell_button != null and not sell_button.pressed.is_connected(_on_sell_pressed):
		sell_button.pressed.connect(_on_sell_pressed)


func setup(row: Dictionary, can_install: bool, install_callback: Callable, sell_callback: Callable) -> void:
	_install_callback = install_callback
	_sell_callback = sell_callback

	var seat_index := int(row.get("seat_index", 0))
	var mount_size := int(row.get("turret_slot_size", 0))
	var has_turret := bool(row.get("has_turret", false))
	var is_driver_slot := bool(row.get("is_driver_slot", false))
	var occupant_peer_id := int(row.get("occupant_peer_id", -1))

	if title_label != null:
		title_label.text = "%s | taille %d" % [
			String(row.get("seat_name", "Siège %d" % seat_index)),
			mount_size
		]

	if state_label != null:
		if has_turret:
			state_label.text = "Équipé : %s | prix %d" % [
				String(row.get("turret_name", "")),
				int(row.get("turret_price", 0))
			]
		else:
			state_label.text = String(row.get("empty_reason", "Vide"))

	if occupant_label != null:
		occupant_label.text = "Occupant : libre" if occupant_peer_id == -1 else "Occupant : peer %d" % occupant_peer_id

	if install_button != null:
		install_button.disabled = not can_install

	if sell_button != null:
		sell_button.disabled = not bool(row.get("can_sell", false))

	if lock_label != null:
		if is_driver_slot:
			lock_label.text = "Tourelle pilote, non vendable"
		elif mount_size == 0:
			lock_label.text = "Aucun montage possible"
		elif has_turret:
			lock_label.text = ""
		else:
			lock_label.text = ""


func _on_install_pressed() -> void:
	if _install_callback.is_valid():
		_install_callback.call()


func _on_sell_pressed() -> void:
	if _sell_callback.is_valid():
		_sell_callback.call()
