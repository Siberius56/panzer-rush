extends Node3D

# Script racine des blocs de niveau 150 x 150.
# Les bords doivent rester à la même hauteur pour permettre l'assemblage.
# Le générateur utilise un seul profil complet par côté.
# Deux blocs voisins sont compatibles uniquement si les deux côtés opposés ont le même profil.
# Exceptions volontaires :
# - "none" face à "none" est refusé, car cela ne crée aucun passage.
# - "sea" ne peut toucher aucun bloc. La mer doit rester vers l'extérieur du niveau.
#
# Sockets :
# - POISocket est le socket du POI principal.
# - Les POI secondaires sont trouvés automatiquement : il suffit de mettre
#   SecondaryPOISocket.gd sur POISocket_Side1, POISocket_Side2, etc.
# - Les spawns joueurs/véhicules sont trouvés automatiquement dans le node SpawnSockets.
# - Les connecteurs de bord sont trouvés dans Connectors/North, East, South, West.
#   Si un côté touche un autre bloc, son connecteur est caché et abaissé.

const CARDINAL_DIRECTIONS: Array[String] = ["north", "east", "south", "west"]
const SIDE_PROFILE_NONE: String = "none"
const SIDE_PROFILE_ROAD_CENTER: String = "road center"
const SIDE_PROFILE_ROAD_SPLIT: String = "road split"
const SIDE_PROFILE_ROAD_CENTER_RIVER: String = "road center river"
const SIDE_PROFILE_ROAD_SPLIT_RIVER: String = "road split river"
const SIDE_PROFILE_RIVER: String = "river"
const SIDE_PROFILE_SEA: String = "sea"

@export var block_id: String = "block"
@export var block_type: String = "generic"
@export var block_size: float = 150.0
@export var compatible_poi_tags: PackedStringArray = PackedStringArray(["land"])
@export var has_water_near_poi: bool = false
@export_enum("none", "river", "sea") var poi_water_type: String = "none"

# Compatibilité avec les anciennes scènes qui stockaient encore :
# - north_road_profile / east_road_profile / south_road_profile / west_road_profile
# - river_connection_sides
# - required_exterior_sides
# Ces variables sont stockées mais masquées de l’inspecteur.
# Elles évitent que les anciens blocs perdent leurs profils et retombent tous sur "none".
@export_storage var required_exterior_sides: PackedStringArray = PackedStringArray()
@export_storage var river_connection_sides: PackedStringArray = PackedStringArray()
@export_storage var north_road_profile: String = "center"
@export_storage var east_road_profile: String = "center"
@export_storage var south_road_profile: String = "center"
@export_storage var west_road_profile: String = "center"

@export_group("Block side profiles")
@export_enum("none", "road center", "road split", "road center river", "road split river", "river", "sea") var north_side_profile: String = "none"
@export_enum("none", "road center", "road split", "road center river", "road split river", "river", "sea") var east_side_profile: String = "none"
@export_enum("none", "road center", "road split", "road center river", "road split river", "river", "sea") var south_side_profile: String = "none"
@export_enum("none", "road center", "road split", "road center river", "road split river", "river", "sea") var west_side_profile: String = "none"

@export_group("POI")
@export var allow_random_poi_rotation: bool = true

@export_group("Sockets")
@export var poi_socket_path: NodePath = ^"POISocket"

@export_group("Connectors")
@export var connector_root_path: NodePath = ^"Connectors"
@export var hidden_connector_y_offset: float = -20.0
@export var disable_connector_collisions_when_hidden: bool = true


func get_poi_socket() -> Node3D:
	var socket: Node3D = get_node_or_null(poi_socket_path) as Node3D
	if socket != null:
		return socket
	return get_node_or_null("POISocket") as Node3D


func get_secondary_poi_sockets() -> Array[Node3D]:
	var result: Array[Node3D] = []
	_collect_secondary_poi_sockets_recursive(self, result)
	return result


func get_secondary_poi_socket(index: int) -> Node3D:
	var sockets: Array[Node3D] = get_secondary_poi_sockets()
	if sockets.is_empty():
		return null

	var safe_index: int = clampi(index, 0, sockets.size() - 1)
	return sockets[safe_index]


func _collect_secondary_poi_sockets_recursive(root: Node, result: Array[Node3D]) -> void:
	for child: Node in root.get_children():
		if child is Node3D and child.has_method("get_secondary_socket_environment"):
			var socket: Node3D = child as Node3D
			if not result.has(socket):
				result.append(socket)

		_collect_secondary_poi_sockets_recursive(child, result)


func get_spawn_sockets() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var root: Node = get_node_or_null("SpawnSockets")
	if root == null:
		return result

	_collect_node3d_children_recursive(root, result)
	return result


func get_spawn_socket(index: int) -> Node3D:
	GameSessionState.horde_director 
	var sockets: Array[Node3D] = get_spawn_sockets()
	if sockets.is_empty():
		return null

	var safe_index: int = clampi(index, 0, sockets.size() - 1)
	return sockets[safe_index]


func _collect_node3d_children_recursive(root: Node, result: Array[Node3D]) -> void:
	for child: Node in root.get_children():
		if child is Node3D:
			result.append(child as Node3D)
		_collect_node3d_children_recursive(child, result)


func apply_connector_visibility(connected_sides: PackedStringArray) -> void:
	# connected_sides doit contenir des côtés LOCAUX du bloc.
	# Exemple : "north" cache Connectors/North, même si le bloc est tourné dans le monde.
	for side: String in CARDINAL_DIRECTIONS:
		var connector: Node3D = get_connector_node_for_side(side)
		if connector == null:
			continue

		var should_show_connector: bool = not connected_sides.has(side)
		_set_connector_enabled(connector, should_show_connector)


func apply_connector_visibility_from_array(connected_sides: Array) -> void:
	var packed_sides: PackedStringArray = PackedStringArray()
	for item: Variant in connected_sides:
		var side: String = String(item).strip_edges().to_lower()
		if CARDINAL_DIRECTIONS.has(side) and not packed_sides.has(side):
			packed_sides.append(side)
	apply_connector_visibility(packed_sides)


func apply_connector_visibility_from_world_sides(connected_world_sides: PackedStringArray) -> void:
	# Sécurité si un autre script envoie encore des directions monde.
	# Les nodes Connectors/North/East/South/West sont des côtés locaux du bloc.
	var local_sides: PackedStringArray = PackedStringArray()
	var rotation_steps: int = _get_current_rotation_steps()
	for world_side: String in connected_world_sides:
		var local_side: String = world_side_to_local_side(world_side, rotation_steps)
		if CARDINAL_DIRECTIONS.has(local_side) and not local_sides.has(local_side):
			local_sides.append(local_side)
	apply_connector_visibility(local_sides)


func world_side_to_local_side(world_side: String, rotation_steps: int) -> String:
	var direction_index: int = CARDINAL_DIRECTIONS.find(world_side.strip_edges().to_lower())
	if direction_index == -1:
		return world_side

	# Inverse de rotate_side().
	# rotate_side() fait local -> monde : world = local - rotation_steps.
	# Ici on fait monde -> local : local = world + rotation_steps.
	var normalized_steps: int = ((rotation_steps % 4) + 4) % 4
	var local_index: int = (direction_index + normalized_steps) % CARDINAL_DIRECTIONS.size()
	return CARDINAL_DIRECTIONS[local_index]


func _get_current_rotation_steps() -> int:
	var y_degrees: float = rad_to_deg(rotation.y)
	var rounded_steps: int = int(round(y_degrees / 90.0))
	return ((rounded_steps % 4) + 4) % 4


func get_connector_node_for_side(side: String) -> Node3D:
	var normalized_side: String = side.strip_edges().to_lower()
	var root: Node = get_node_or_null(connector_root_path)
	if root == null:
		root = get_node_or_null("Connectors")
	if root == null:
		return null

	var connector_name: String = _get_connector_node_name(normalized_side)
	var connector: Node3D = root.get_node_or_null(connector_name) as Node3D
	if connector != null:
		return connector

	for child: Node in root.get_children():
		if child is Node3D and String(child.name).strip_edges().to_lower() == normalized_side:
			return child as Node3D

	return null


func _get_connector_node_name(side: String) -> String:
	if side.is_empty():
		return side
	return side.substr(0, 1).to_upper() + side.substr(1)


func _set_connector_enabled(connector: Node3D, enabled: bool) -> void:
	var original_position: Vector3 = _get_connector_original_position(connector)
	if enabled:
		connector.visible = true
		connector.position = original_position
		_set_connector_collisions_enabled(connector, true)
	else:
		connector.visible = false
		connector.position = original_position + Vector3(0.0, hidden_connector_y_offset, 0.0)
		_set_connector_collisions_enabled(connector, false)


func _get_connector_original_position(connector: Node3D) -> Vector3:
	const META_ORIGINAL_POSITION: String = "procedural_connector_original_position"
	if connector.has_meta(META_ORIGINAL_POSITION):
		var stored_value: Variant = connector.get_meta(META_ORIGINAL_POSITION)
		if stored_value is Vector3:
			return stored_value as Vector3

	connector.set_meta(META_ORIGINAL_POSITION, connector.position)
	return connector.position


func _set_connector_collisions_enabled(root: Node, enabled: bool) -> void:
	if not disable_connector_collisions_when_hidden:
		return

	_apply_collision_disabled_state(root, not enabled)
	for child: Node in root.get_children():
		_set_connector_collisions_enabled(child, enabled)


func _apply_collision_disabled_state(target: Object, disabled: bool) -> void:
	if target == null:
		return
	if not _object_has_property(target, "disabled"):
		return

	const META_ORIGINAL_DISABLED: String = "procedural_connector_original_disabled"
	if not target.has_meta(META_ORIGINAL_DISABLED):
		target.set_meta(META_ORIGINAL_DISABLED, bool(target.get("disabled")))

	if disabled:
		target.set("disabled", true)
	else:
		target.set("disabled", bool(target.get_meta(META_ORIGINAL_DISABLED)))


func _object_has_property(target: Object, property_name: String) -> bool:
	for property_info: Dictionary in target.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return true
	return false


func has_compatible_tag(tag: String) -> bool:
	for current_tag: String in compatible_poi_tags:
		if current_tag == tag:
			return true
	return false


func get_side_profiles(rotation_steps: int = 0) -> Dictionary:
	var local_profiles: Dictionary = _get_local_side_profiles()
	var rotated_profiles: Dictionary = {}
	for local_side: String in CARDINAL_DIRECTIONS:
		var rotated_side: String = rotate_side(local_side, rotation_steps)
		rotated_profiles[rotated_side] = String(local_profiles.get(local_side, SIDE_PROFILE_NONE))
	return rotated_profiles


func get_side_profile_for_side(side: String, rotation_steps: int = 0) -> String:
	var profiles: Dictionary = get_side_profiles(rotation_steps)
	return String(profiles.get(side, SIDE_PROFILE_NONE))


func _get_local_side_profiles() -> Dictionary:
	var explicit_profiles: Dictionary = {
		"north": _normalize_side_profile(north_side_profile),
		"east": _normalize_side_profile(east_side_profile),
		"south": _normalize_side_profile(south_side_profile),
		"west": _normalize_side_profile(west_side_profile),
	}

	# Anciennes scènes : si les nouveaux profils sont tous à "none", mais que les
	# anciennes données existent encore dans le .tscn, on les convertit.
	# C’est la cause probable des générations biaisées : les anciens champs étaient
	# ignorés par le nouveau script, donc plusieurs blocs devenaient "none" partout.
	if _all_side_profiles_are_none(explicit_profiles) and _has_legacy_side_profile_data():
		return _get_legacy_converted_side_profiles()

	return explicit_profiles


func _all_side_profiles_are_none(profiles: Dictionary) -> bool:
	for side: String in CARDINAL_DIRECTIONS:
		if String(profiles.get(side, SIDE_PROFILE_NONE)) != SIDE_PROFILE_NONE:
			return false
	return true


func _has_legacy_side_profile_data() -> bool:
	if not required_exterior_sides.is_empty():
		return true
	if not river_connection_sides.is_empty():
		return true
	return (
		_normalize_legacy_road_profile(north_road_profile) != "center"
		or _normalize_legacy_road_profile(east_road_profile) != "center"
		or _normalize_legacy_road_profile(south_road_profile) != "center"
		or _normalize_legacy_road_profile(west_road_profile) != "center"
	)


func _get_legacy_converted_side_profiles() -> Dictionary:
	return {
		"north": _convert_legacy_side_profile("north", north_road_profile),
		"east": _convert_legacy_side_profile("east", east_road_profile),
		"south": _convert_legacy_side_profile("south", south_road_profile),
		"west": _convert_legacy_side_profile("west", west_road_profile),
	}


func _convert_legacy_side_profile(side: String, legacy_road_profile: String) -> String:
	if required_exterior_sides.has(side):
		return SIDE_PROFILE_SEA

	var road_profile: String = _normalize_legacy_road_profile(legacy_road_profile)
	var has_river: bool = river_connection_sides.has(side)

	if has_river:
		if road_profile == "center":
			return SIDE_PROFILE_ROAD_CENTER_RIVER
		if road_profile == "split":
			return SIDE_PROFILE_ROAD_SPLIT_RIVER
		return SIDE_PROFILE_RIVER

	if road_profile == "center":
		return SIDE_PROFILE_ROAD_CENTER
	if road_profile == "split":
		return SIDE_PROFILE_ROAD_SPLIT
	return SIDE_PROFILE_NONE


func _normalize_legacy_road_profile(profile: String) -> String:
	var normalized: String = profile.strip_edges().to_lower()
	match normalized:
		"road center", "center":
			return "center"
		"road split", "split":
			return "split"
		"", "none":
			return "none"
		_:
			return normalized


func _normalize_side_profile(profile: String) -> String:
	return profile.strip_edges().to_lower()


func rotate_side(side: String, rotation_steps: int) -> String:
	var direction_index: int = CARDINAL_DIRECTIONS.find(side)
	if direction_index == -1:
		return side

	# Godot positive Y rotation moves local north (-Z) toward world west.
	# The profile rotation must therefore subtract the 90-degree steps.
	var normalized_steps: int = ((rotation_steps % 4) + 4) % 4
	var rotated_index: int = (direction_index - normalized_steps + CARDINAL_DIRECTIONS.size()) % CARDINAL_DIRECTIONS.size()
	return CARDINAL_DIRECTIONS[rotated_index]


func get_database_summary() -> Dictionary:
	return {
		"block_id": block_id,
		"block_type": block_type,
		"block_size": block_size,
		"compatible_poi_tags": Array(compatible_poi_tags),
		"has_water_near_poi": has_water_near_poi,
		"poi_water_type": poi_water_type,
		"allow_random_poi_rotation": allow_random_poi_rotation,
		"secondary_poi_socket_count": get_secondary_poi_sockets().size(),
		"spawn_socket_count": get_spawn_sockets().size(),
		"connector_root_path": String(connector_root_path),
		"hidden_connector_y_offset": hidden_connector_y_offset,
		"side_profiles": _get_local_side_profiles(),
	}
