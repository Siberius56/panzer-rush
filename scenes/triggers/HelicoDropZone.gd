extends Area3D
class_name TransportHelicopterDropZone

signal transport_helicopter_requested(
	spawn_transform: Transform3D,
	destination_position: Vector3,
	unit_set_id: String
)

@export var unit_set_id: String = "rifle_8"
@export var spawn_marker_path: NodePath = ^"HelicopterSpawn"
@export var destination_marker_path: NodePath = ^"HelicopterDestination"

@export_group("Trigger")
@export var trigger_once: bool = true
@export var retrigger_delay: float = 5.0
@export var server_only: bool = true
@export var disable_collision_after_trigger: bool = true

@export_group("Player Detection")
@export var player_group_name: StringName = &"players"
@export var accepted_extra_player_groups: Array[StringName] = [&"network_players", &"player"]


var _locked: bool = false


func _ready() -> void:
	add_to_group("transport_helicopter_drop_zones")

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _locked:
		return

	if server_only and multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return

	if not _is_player_or_player_child(body):
		return

	_locked = true

	var spawn_transform: Transform3D = _get_spawn_transform()
	var destination_position: Vector3 = _get_destination_position()

	transport_helicopter_requested.emit(spawn_transform, destination_position, unit_set_id)

	var network_main: Node = _find_network_main()
	if network_main != null and network_main.has_method("request_transport_helicopter"):
		network_main.call("request_transport_helicopter", spawn_transform, destination_position, unit_set_id)
	else:
		push_warning("[TransportHelicopterDropZone] NetworkMain introuvable ou méthode request_transport_helicopter absente.")

	if trigger_once:
		if disable_collision_after_trigger:
			set_deferred("monitoring", false)
			set_deferred("monitorable", false)
		return

	_unlock_after_delay()


func _unlock_after_delay() -> void:
	if retrigger_delay <= 0.0:
		_locked = false
		return

	await get_tree().create_timer(retrigger_delay).timeout
	_locked = false


func _get_spawn_transform() -> Transform3D:
	var marker: Node3D = get_node_or_null(spawn_marker_path) as Node3D
	if marker != null and is_instance_valid(marker):
		return marker.global_transform

	return global_transform


func _get_destination_position() -> Vector3:
	var marker: Node3D = get_node_or_null(destination_marker_path) as Node3D
	if marker != null and is_instance_valid(marker):
		return marker.global_position

	return global_position


func _find_network_main() -> Node:
	var network_main: Node = get_tree().get_first_node_in_group("network_main")
	if network_main != null and is_instance_valid(network_main):
		return network_main

	var current_scene: Node = get_tree().current_scene
	if current_scene != null and current_scene.is_in_group("network_main"):
		return current_scene

	return null


func _is_player_or_player_child(body: Node) -> bool:
	var current: Node = body
	var depth: int = 0

	while current != null and depth < 6:
		if _is_player_node(current):
			return true

		current = current.get_parent()
		depth += 1

	return false


func _is_player_node(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false

	if player_group_name != StringName("") and node.is_in_group(player_group_name):
		return true

	for group_name: StringName in accepted_extra_player_groups:
		if group_name != StringName("") and node.is_in_group(group_name):
			return true

	if String(node.name).begins_with("Player_"):
		return true

	if node.has_method("get_player_id"):
		return true

	return _has_property(node, "player_id")


func _has_property(target: Object, property_name: String) -> bool:
	if target == null:
		return false

	for property_info in target.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return true

	return false
