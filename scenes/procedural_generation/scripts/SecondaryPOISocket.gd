extends Node3D

# Script à mettre directement sur les sockets secondaires :
# - POISocket_Side1
# - POISocket_Side2
# - ou tout autre Node3D utilisé comme socket de POI secondaire.
#
# Le générateur NE déduit plus automatiquement le type du socket.
# Il lit uniquement ce script.

const ENV_ANY: String = "any"
const ENV_LAND: String = "land"
const ENV_RIVER: String = "river"
const ENV_SEA: String = "sea"
const ENV_WATER: String = "water"

const ROTATION_USE_POI_SETTING: String = "use poi setting"
const ROTATION_RANDOM_90: String = "random 90"
const ROTATION_FOLLOW_BLOCK: String = "follow block"
const ROTATION_FOLLOW_SOCKET: String = "follow socket"

@export_group("Secondary POI Socket")
@export var socket_enabled: bool = true
@export_enum("any", "land", "river", "sea", "water") var secondary_socket_environment: String = "land"
@export_range(0.0, 1.0, 0.01) var socket_spawn_chance: float = 1.0

@export_group("Rotation")
@export_enum("use poi setting", "random 90", "follow block", "follow socket") var rotation_mode_override: String = "follow socket" #"random 90"


func get_secondary_socket_environment() -> String:
	if secondary_socket_environment in [ENV_ANY, ENV_LAND, ENV_RIVER, ENV_SEA, ENV_WATER]:
		return secondary_socket_environment
	return ENV_LAND


func get_socket_spawn_chance() -> float:
	return clampf(socket_spawn_chance, 0.0, 1.0)


func is_secondary_socket_enabled() -> bool:
	return socket_enabled


func can_accept_secondary_poi(poi_node: Node) -> bool:
	if not socket_enabled:
		return false
	if poi_node == null:
		return false

	var socket_environment: String = get_secondary_socket_environment()
	var required_environment: String = _read_poi_required_environment(poi_node)

	if required_environment == ENV_ANY:
		return true
	if socket_environment == ENV_ANY:
		return true
	if required_environment == ENV_WATER:
		return socket_environment == ENV_RIVER or socket_environment == ENV_SEA or socket_environment == ENV_WATER
	if socket_environment == ENV_WATER:
		return required_environment == ENV_RIVER or required_environment == ENV_SEA or required_environment == ENV_WATER

	return socket_environment == required_environment


func get_secondary_rotation_mode_for_poi(poi_node: Node, poi_default_rotation_mode: String = ROTATION_RANDOM_90) -> String:
	if rotation_mode_override != ROTATION_USE_POI_SETTING:
		return _sanitize_rotation_mode(rotation_mode_override)

	if poi_node != null:
		if poi_node.has_method("get_secondary_rotation_mode"):
			return _sanitize_rotation_mode(String(poi_node.call("get_secondary_rotation_mode")))
		var value: String = _read_string_property(poi_node, "secondary_rotation_mode", poi_default_rotation_mode)
		return _sanitize_rotation_mode(value)

	return _sanitize_rotation_mode(poi_default_rotation_mode)


func get_database_summary() -> Dictionary:
	return {
		"socket_enabled": socket_enabled,
		"secondary_socket_environment": get_secondary_socket_environment(),
		"socket_spawn_chance": get_socket_spawn_chance(),
		"rotation_mode_override": rotation_mode_override,
	}


func _read_poi_required_environment(poi_node: Node) -> String:
	if poi_node.has_method("get_effective_placement_type"):
		var method_value: String = String(poi_node.call("get_effective_placement_type"))
		return _sanitize_environment(method_value)

	var property_value: String = _read_string_property(poi_node, "secondary_placement_type", ENV_LAND)
	return _sanitize_environment(property_value)


func _sanitize_environment(value: String) -> String:
	if value in [ENV_ANY, ENV_LAND, ENV_RIVER, ENV_SEA, ENV_WATER]:
		return value
	return ENV_LAND


func _sanitize_rotation_mode(value: String) -> String:
	if value in [ROTATION_RANDOM_90, ROTATION_FOLLOW_BLOCK, ROTATION_FOLLOW_SOCKET]:
		return value
	return ROTATION_RANDOM_90


func _read_string_property(target: Object, property_name: String, fallback: String) -> String:
	if target == null:
		return fallback
	for property_info: Dictionary in target.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return String(target.get(property_name))
	return fallback
