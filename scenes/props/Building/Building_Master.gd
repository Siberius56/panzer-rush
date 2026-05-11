extends Node3D

const MOUSE_COLLISION_LAYER: int = 8

@export var floor_prefix: String = "Floor_"
@export var area_prefix: String = "Area_"
@export var local_player_group: StringName = &"player"

var _floors_by_number: Dictionary = {}
var _active_area_floors: Array[int] = []
var _highest_floor_number: int = 0


func _ready() -> void:
	_cache_floors()
	_connect_areas()
	_show_full_building()


func _cache_floors() -> void:
	_floors_by_number.clear()
	_highest_floor_number = 0

	for child: Node in get_children():
		var floor_number: int = _get_number_from_name(String(child.name), floor_prefix)

		if floor_number < 0:
			continue

		_floors_by_number[floor_number] = child

		if floor_number > _highest_floor_number:
			_highest_floor_number = floor_number


func _connect_areas() -> void:
	for child: Node in get_children():
		if not child is Area3D:
			continue

		var area: Area3D = child as Area3D
		var area_floor: int = _get_number_from_name(String(area.name), area_prefix)

		if area_floor < 0:
			continue

		if not area.body_entered.is_connected(_on_area_body_entered):
			area.body_entered.connect(_on_area_body_entered.bind(area_floor))

		if not area.body_exited.is_connected(_on_area_body_exited):
			area.body_exited.connect(_on_area_body_exited.bind(area_floor))


func _get_number_from_name(node_name: String, prefix: String) -> int:
	if not node_name.begins_with(prefix):
		return -1

	var number_text: String = node_name.substr(prefix.length())

	if not number_text.is_valid_int():
		return -1

	return int(number_text)


func _on_area_body_entered(body: Node3D, area_floor: int) -> void:
	if not _is_local_player(body):
		return

	if not _active_area_floors.has(area_floor):
		_active_area_floors.append(area_floor)

	_apply_current_visibility()


func _on_area_body_exited(body: Node3D, area_floor: int) -> void:
	if not _is_local_player(body):
		return

	if _active_area_floors.has(area_floor):
		_active_area_floors.erase(area_floor)

	_apply_current_visibility()


func _is_local_player(body: Node) -> bool:
	if body == null:
		return false

	return body.is_in_group(local_player_group)


func _apply_current_visibility() -> void:
	if _active_area_floors.is_empty():
		_show_full_building()
		return

	var max_visible_floor: int = _get_highest_active_area_floor()
	_set_visible_floors(max_visible_floor)


func _get_highest_active_area_floor() -> int:
	var highest_floor: int = 0

	for floor_number: int in _active_area_floors:
		if floor_number > highest_floor:
			highest_floor = floor_number

	return highest_floor


func _show_full_building() -> void:
	_set_visible_floors(_highest_floor_number)


func _set_visible_floors(max_visible_floor: int) -> void:
	var floor_numbers: Array = _floors_by_number.keys()
	floor_numbers.sort()

	for floor_number_variant in floor_numbers:
		var floor_number: int = int(floor_number_variant)
		var floor_node: Node = _floors_by_number[floor_number]
		var should_be_visible: bool = floor_number <= max_visible_floor

		_set_floor_visible(floor_node, should_be_visible)
		_set_mouse_collision_layer_recursive(floor_node, should_be_visible)


func _set_floor_visible(floor_node: Node, should_be_visible: bool) -> void:
	if floor_node is Node3D:
		var floor_node_3d: Node3D = floor_node as Node3D
		floor_node_3d.visible = should_be_visible


func _set_mouse_collision_layer_recursive(node: Node, enabled: bool) -> void:
	if node is CollisionObject3D:
		var collision_object: CollisionObject3D = node as CollisionObject3D
		collision_object.set_collision_layer_value(MOUSE_COLLISION_LAYER, enabled)

	for child: Node in node.get_children():
		_set_mouse_collision_layer_recursive(child, enabled)
