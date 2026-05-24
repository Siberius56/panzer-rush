extends Node3D

# Script racine des POI secondaires.
# Le POI déclare ce dont il a besoin.
# Le socket déclare ce qu'il est via SecondaryPOISocket.gd.
# Le générateur ne fait aucune détection automatique.

const PLACEMENT_ANY: String = "any"
const PLACEMENT_LAND: String = "land"
const PLACEMENT_RIVER: String = "river"
const PLACEMENT_SEA: String = "sea"
const PLACEMENT_WATER: String = "water"

const ROTATION_RANDOM_90: String = "random 90"
const ROTATION_FOLLOW_BLOCK: String = "follow block"
const ROTATION_FOLLOW_SOCKET: String = "follow socket"

@export_group("Identity")
@export var poi_id: String = "secondary_poi"
@export var poi_type: String = "secondary"
@export var poi_size: float = 24.0
@export var poi_tags: PackedStringArray = PackedStringArray(["secondary"])

@export_group("Secondary placement")
@export_enum("any", "land", "river", "sea", "water") var secondary_placement_type: String = "land"
@export_enum("random 90", "follow block", "follow socket") var secondary_rotation_mode: String = "random 90"

@export_group("Legacy compatibility")
@export var requires_water_near_poi: bool = false
@export_enum("none", "any_water", "river", "sea") var required_water_type: String = "none"


func can_spawn_on_secondary_socket(block_node: Node3D, socket: Node3D) -> bool:
	if socket == null:
		return false
	if not socket.has_method("can_accept_secondary_poi"):
		return false
	return bool(socket.call("can_accept_secondary_poi", self))


func can_spawn_on_block(block_node: Node) -> bool:
	# Compatibilité minimale avec d'anciens appels.
	# Le vrai filtrage se fait sur le socket secondaire.
	return block_node != null


func get_effective_placement_type() -> String:
	if secondary_placement_type in [PLACEMENT_ANY, PLACEMENT_LAND, PLACEMENT_RIVER, PLACEMENT_SEA, PLACEMENT_WATER]:
		return secondary_placement_type

	if required_water_type == "river":
		return PLACEMENT_RIVER
	if required_water_type == "sea":
		return PLACEMENT_SEA
	if required_water_type == "any_water":
		return PLACEMENT_WATER
	if requires_water_near_poi:
		return PLACEMENT_WATER

	return PLACEMENT_LAND


func get_secondary_rotation_mode() -> String:
	if secondary_rotation_mode in [ROTATION_RANDOM_90, ROTATION_FOLLOW_BLOCK, ROTATION_FOLLOW_SOCKET]:
		return secondary_rotation_mode
	return ROTATION_RANDOM_90


func get_socket_environment(block_node: Node3D, socket: Node3D) -> String:
	if socket != null and socket.has_method("get_secondary_socket_environment"):
		return String(socket.call("get_secondary_socket_environment"))
	return "missing_socket_script"


func get_database_summary() -> Dictionary:
	return {
		"poi_id": poi_id,
		"poi_type": poi_type,
		"poi_size": poi_size,
		"poi_tags": Array(poi_tags),
		"secondary_placement_type": get_effective_placement_type(),
		"secondary_rotation_mode": get_secondary_rotation_mode(),
		"requires_water_near_poi": requires_water_near_poi,
		"required_water_type": required_water_type,
	}
