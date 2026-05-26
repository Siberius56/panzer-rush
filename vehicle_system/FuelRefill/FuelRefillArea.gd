extends Area3D
class_name FuelRefillArea

@export_group("Fuel Refill")
@export var enabled: bool = true
@export var server_only: bool = true
@export var refill_per_second: float = 100.0
@export var consume_when_full: bool = false

@export_group("Vehicle Detection")
@export var vehicle_group: StringName = &"vehicles"
@export var require_vehicle_group: bool = false
@export var parent_search_depth: int = 8

@export_group("Debug")
@export var debug_print: bool = false

var _active_vehicles: Dictionary = {}


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	if not enabled:
		return

	if server_only and not multiplayer.is_server():
		return

	if _active_vehicles.is_empty():
		return

	var ids_to_remove: Array = []
	var added_total: float = 0.0

	for vehicle_id in _active_vehicles.keys():
		var vehicle: Node = _active_vehicles[vehicle_id] as Node

		if vehicle == null or not is_instance_valid(vehicle):
			ids_to_remove.append(vehicle_id)
			continue

		if _is_vehicle_fuel_full(vehicle):
			if consume_when_full:
				queue_free()
				return
			continue

		var added: float = refill_vehicle_fuel(vehicle, refill_per_second * delta)
		added_total += added

		if added > 0.0 and debug_print:
			print("FuelRefillArea: added %.2f fuel to %s. Fuel %.1f / %.1f" % [
				added,
				vehicle.name,
				_get_current_fuel(vehicle),
				_get_max_fuel(vehicle)
			])

		if consume_when_full and _is_vehicle_fuel_full(vehicle):
			queue_free()
			return

	for vehicle_id in ids_to_remove:
		_active_vehicles.erase(vehicle_id)


func _on_body_entered(body: Node) -> void:
	if not enabled:
		return

	if server_only and not multiplayer.is_server():
		return

	var vehicle: Node = _find_vehicle_root(body)
	if vehicle == null:
		return

	_active_vehicles[vehicle.get_instance_id()] = vehicle

	if debug_print:
		print("FuelRefillArea: vehicle entered ", vehicle.name)


func _on_body_exited(body: Node) -> void:
	var vehicle: Node = _find_vehicle_root(body)
	if vehicle == null:
		return

	_active_vehicles.erase(vehicle.get_instance_id())

	if debug_print:
		print("FuelRefillArea: vehicle exited ", vehicle.name)


func refill_vehicle_fuel(vehicle: Node, amount: float) -> float:
	if vehicle == null or not is_instance_valid(vehicle):
		return 0.0

	if amount <= 0.0:
		return 0.0

	if server_only and not multiplayer.is_server():
		return 0.0

	if vehicle.has_method("add_fuel"):
		return float(vehicle.call("add_fuel", amount))

	if not _has_property(vehicle, "current_fuel") or not _has_property(vehicle, "max_fuel"):
		return 0.0

	var max_fuel_value: float = float(vehicle.get("max_fuel"))
	if max_fuel_value <= 0.0:
		return 0.0

	var previous_fuel: float = float(vehicle.get("current_fuel"))
	var next_fuel: float = clampf(previous_fuel + amount, 0.0, max_fuel_value)
	vehicle.set("current_fuel", next_fuel)

	return next_fuel - previous_fuel


func _find_vehicle_root(from_node: Node) -> Node:
	var current: Node = from_node
	var depth: int = 0
	var max_depth: int = maxi(parent_search_depth, 1)

	while current != null and depth <= max_depth:
		if _is_vehicle_node(current):
			return current

		current = current.get_parent()
		depth += 1

	return null


func _is_vehicle_node(node: Node) -> bool:
	if node == null:
		return false

	if vehicle_group != &"" and node.is_in_group(vehicle_group):
		return true

	if require_vehicle_group:
		return false

	if node.has_method("add_fuel") and _has_property(node, "current_fuel") and _has_property(node, "max_fuel"):
		return true

	return false


func _is_vehicle_fuel_full(vehicle: Node) -> bool:
	var max_fuel_value: float = _get_max_fuel(vehicle)
	if max_fuel_value <= 0.0:
		return true

	return _get_current_fuel(vehicle) >= max_fuel_value


func _get_current_fuel(vehicle: Node) -> float:
	if vehicle == null or not is_instance_valid(vehicle):
		return 0.0

	if _has_property(vehicle, "current_fuel"):
		return float(vehicle.get("current_fuel"))

	return 0.0


func _get_max_fuel(vehicle: Node) -> float:
	if vehicle == null or not is_instance_valid(vehicle):
		return 0.0

	if _has_property(vehicle, "max_fuel"):
		return float(vehicle.get("max_fuel"))

	return 0.0


func _has_property(object: Object, property_name: String) -> bool:
	if object == null:
		return false

	for property in object.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true

	return false
