extends CanvasLayer
class_name VehicleLoadoutMenu

var vehicle: Vehicle = null
var interactor: VehicleInteractor = null
var station = null
var selected_shop_index: int = -1

const VEHICLE_SEAT_ENTRY_SCENE: PackedScene = preload("res://vehicle_system/ui/VehicleSeatEntry.tscn")
const VEHICLE_SHOP_ENTRY_SCENE: PackedScene = preload("res://vehicle_system/ui/VehicleShopEntry.tscn")

@onready var title_label: Label = %Title #$Root/Margin/VBox/Header/Title
@onready var money_label: Label = %Money #$Root/Margin/VBox/Header/Money
@onready var chassis_label: Label = %CurrentChassis #$Root/Margin/VBox/Header/CurrentChassis
@onready var selected_label: Label = %SelectedTurret #$Root/Margin/VBox/Header/SelectedTurret
@onready var seat_list: VBoxContainer = %SeatList #$Root/Margin/VBox/Body/LeftPanel/SeatScroll/SeatList
@onready var turret_list: VBoxContainer = %TurretList #$Root/Margin/VBox/Body/RightPanel/RightVBox/TurretSection/TurretScroll/TurretList
@onready var chassis_list: VBoxContainer = %ChassisList #$Root/Margin/VBox/Body/RightPanel/RightVBox/ChassisSection/ChassisScroll/ChassisList
@onready var close_button: Button = %CloseButton #$Root/Margin/VBox/Footer/CloseButton
@onready var clear_button: Button = %ClearSelectionButton #$Root/Margin/VBox/Footer/ClearSelectionButton


func _ready() -> void:
	if close_button != null and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)

	if clear_button != null and not clear_button.pressed.is_connected(_on_clear_selection_pressed):
		clear_button.pressed.connect(_on_clear_selection_pressed)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()


func setup(target_vehicle: Vehicle, owner_interactor: VehicleInteractor, owner_station = null) -> void:
	_disconnect_vehicle_signals()

	vehicle = target_vehicle
	interactor = owner_interactor
	station = owner_station

	if interactor != null and interactor.player_body != null:
		interactor.player_body.set_ui_input_blocked(true)

	_connect_vehicle_signals()
	_refresh()


func retarget_vehicle(target_vehicle: Vehicle) -> void:
	setup(target_vehicle, interactor, station)


func _connect_vehicle_signals() -> void:
	if vehicle == null:
		return

	if not vehicle.loadout_state_changed.is_connected(_on_vehicle_data_changed):
		vehicle.loadout_state_changed.connect(_on_vehicle_data_changed)

	if not vehicle.seat_layout_changed.is_connected(_on_vehicle_data_changed):
		vehicle.seat_layout_changed.connect(_on_vehicle_data_changed)

	if not vehicle.tree_exited.is_connected(_on_vehicle_tree_exited):
		vehicle.tree_exited.connect(_on_vehicle_tree_exited)


func _disconnect_vehicle_signals() -> void:
	if vehicle == null or not is_instance_valid(vehicle):
		return

	if vehicle.loadout_state_changed.is_connected(_on_vehicle_data_changed):
		vehicle.loadout_state_changed.disconnect(_on_vehicle_data_changed)

	if vehicle.seat_layout_changed.is_connected(_on_vehicle_data_changed):
		vehicle.seat_layout_changed.disconnect(_on_vehicle_data_changed)

	if vehicle.tree_exited.is_connected(_on_vehicle_tree_exited):
		vehicle.tree_exited.disconnect(_on_vehicle_tree_exited)


func _on_vehicle_tree_exited() -> void:
	vehicle = null
	queue_free()


func _on_vehicle_data_changed() -> void:
	_refresh()


func _refresh() -> void:
	if vehicle == null or not is_instance_valid(vehicle):
		return

	title_label.text = vehicle.vehicle_display_name
	money_label.text = "Argent : %d" % vehicle.shop_money
	chassis_label.text = "Châssis actuel : %s" % vehicle.vehicle_display_name

	if selected_shop_index == -1:
		selected_label.text = "Tourelle sélectionnée : aucune"
	else:
		var selected_entry := _get_shop_entry_by_index(selected_shop_index)
		if selected_entry.is_empty():
			selected_shop_index = -1
			selected_label.text = "Tourelle sélectionnée : aucune"
		else:
			selected_label.text = "Tourelle sélectionnée : %s, taille %d, prix %d" % [
				String(selected_entry.get("turret_label", "")),
				int(selected_entry.get("turret_size", 0)),
				int(selected_entry.get("turret_price", 0))
			]

	_rebuild_turret_list()
	_rebuild_seat_list()
	_rebuild_chassis_list()


func _rebuild_turret_list() -> void:
	_clear_container(turret_list)

	if vehicle == null or not is_instance_valid(vehicle):
		return

	for entry in vehicle.get_available_shop_entries():
		var shop_index := int(entry.get("shop_index", -1))
		var shop_entry := VEHICLE_SHOP_ENTRY_SCENE.instantiate() as VehicleShopEntry
		if shop_entry == null:
			push_error("VehicleShopEntry.tscn doit avoir VehicleShopEntry.gd attaché à sa racine.")
			continue

		turret_list.add_child(shop_entry)
		shop_entry.setup(
			entry,
			selected_shop_index == shop_index,
			_make_select_shop_callback(shop_index)
		)


func _rebuild_seat_list() -> void:
	_clear_container(seat_list)

	if vehicle == null or not is_instance_valid(vehicle):
		return

	for row in vehicle.get_seat_ui_data():
		var seat_index := int(row.get("seat_index", 0))
		var seat_entry := VEHICLE_SEAT_ENTRY_SCENE.instantiate() as VehicleSeatEntry
		if seat_entry == null:
			push_error("VehicleSeatEntry.tscn doit avoir VehicleSeatEntry.gd attaché à sa racine.")
			continue

		seat_list.add_child(seat_entry)
		seat_entry.setup(
			row,
			_can_install_on_row(seat_index),
			_make_install_turret_callback(seat_index),
			_make_sell_turret_callback(seat_index)
		)


func _rebuild_chassis_list() -> void:
	_clear_container(chassis_list)

	if vehicle == null or not is_instance_valid(vehicle):
		return

	for entry in vehicle.get_available_chassis_entries():
		var chassis_index := int(entry.get("chassis_index", -1))
		var chassis_id := String(entry.get("chassis_id", ""))
		var price := int(entry.get("chassis_price", 0))
		var trade_in := vehicle.get_chassis_trade_in_value()
		var total_after := vehicle.shop_money + trade_in - price
		var is_current := chassis_id == vehicle.chassis_id
		var can_buy := station != null and total_after >= 0
		var chassis_entry := VEHICLE_SHOP_ENTRY_SCENE.instantiate() as VehicleShopEntry
		if chassis_entry == null:
			push_error("VehicleShopEntry.tscn doit avoir VehicleShopEntry.gd attaché à sa racine.")
			continue

		chassis_list.add_child(chassis_entry)
		chassis_entry.setup_chassis(
			entry,
			trade_in,
			total_after,
			is_current,
			can_buy,
			_make_buy_chassis_callback(chassis_index)
		)


func _clear_container(container: Node) -> void:
	if container == null:
		return

	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _get_shop_entry_by_index(shop_index: int) -> Dictionary:
	if vehicle == null or not is_instance_valid(vehicle):
		return {}

	for entry in vehicle.get_available_shop_entries():
		if int(entry.get("shop_index", -1)) == shop_index:
			return entry

	return {}


func _make_select_shop_callback(shop_index: int) -> Callable:
	return func() -> void:
		selected_shop_index = shop_index
		_refresh()


func _make_install_turret_callback(seat_index: int) -> Callable:
	return func() -> void:
		if vehicle == null or not is_instance_valid(vehicle):
			return

		if multiplayer.is_server():
			vehicle._server_install_turret(multiplayer.get_unique_id(), selected_shop_index, seat_index)
		else:
			vehicle.request_install_turret.rpc_id(1, selected_shop_index, seat_index)


func _make_sell_turret_callback(seat_index: int) -> Callable:
	return func() -> void:
		if vehicle == null or not is_instance_valid(vehicle):
			return

		if multiplayer.is_server():
			vehicle._server_sell_turret(multiplayer.get_unique_id(), seat_index)
		else:
			vehicle.request_sell_turret.rpc_id(1, seat_index)


func _make_buy_chassis_callback(chassis_index: int) -> Callable:
	return func() -> void:
		if station == null:
			return

		if multiplayer.is_server():
			station.server_buy_chassis_from_host(chassis_index)
		else:
			station.request_buy_chassis.rpc_id(1, chassis_index)


func _can_install_on_row(seat_index: int) -> bool:
	if selected_shop_index == -1:
		return false
	if vehicle == null:
		return false
	return vehicle.can_install_shop_entry_on_seat(selected_shop_index, seat_index)


func _on_clear_selection_pressed() -> void:
	selected_shop_index = -1
	_refresh()


func _on_close_pressed() -> void:
	queue_free()


func _exit_tree() -> void:
	_disconnect_vehicle_signals()

	if interactor != null and interactor.player_body != null:
		interactor.player_body.set_ui_input_blocked(false)
