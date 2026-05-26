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
@export var hide_poi_placeholders_on_ready: bool = true
@export var poi_placeholder_name_keywords: PackedStringArray = PackedStringArray(["placeholder"])

@export_group("Objectives")
@export var objective_root_path: NodePath = ^"node_objective"

@export_group("Sockets")
@export var poi_socket_path: NodePath = ^"POISocket"

@export_group("Connectors")
@export var connector_root_path: NodePath = ^"Connectors"
@export var hidden_connector_y_offset: float = -20.0
@export var disable_connector_collisions_when_hidden: bool = true

@export_group("Runtime Activation")
@export var runtime_activation_enabled: bool = true
@export var disable_renderers_when_inactive: bool = false
@export var disable_static_collisions_when_inactive: bool = true
@export var kill_child_enemies_when_inactive: bool = true
@export var enemy_groups_to_kill_on_inactive: PackedStringArray = PackedStringArray(["zombies", "enemies", "enemy"])
@export_storage var runtime_slot_index: int = -1

var runtime_is_active: bool = true
var _runtime_cache_ready: bool = false
var _runtime_collision_objects: Array[CollisionObject3D] = []
var _runtime_rigid_bodies: Array[RigidBody3D] = []
var _runtime_character_bodies: Array[CharacterBody3D] = []
var _runtime_areas: Array[Area3D] = []
var _runtime_visual_nodes: Array[Node3D] = []
var _runtime_spawn_zones: Array[Node] = []
var _runtime_multiplayer_nodes: Array[Node] = []
var _runtime_destructible_props: Array[Node] = []


func _ready() -> void:
	if hide_poi_placeholders_on_ready:
		hide_poi_placeholders()
	refresh_runtime_cache()


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


func hide_poi_placeholders() -> void:
	var main_socket: Node3D = get_poi_socket()
	if main_socket != null:
		_hide_placeholder_nodes_recursive(main_socket)

	var secondary_sockets: Array[Node3D] = get_secondary_poi_sockets()
	for socket: Node3D in secondary_sockets:
		_hide_placeholder_nodes_recursive(socket)


func _hide_placeholder_nodes_recursive(root: Node) -> void:
	for child: Node in root.get_children():
		if _is_poi_placeholder_node(child):
			_set_node_visible_if_supported(child, false)
			continue

		_hide_placeholder_nodes_recursive(child)


func _is_poi_placeholder_node(node: Node) -> bool:
	var normalized_name: String = String(node.name).strip_edges().to_lower()
	for keyword: String in poi_placeholder_name_keywords:
		var normalized_keyword: String = String(keyword).strip_edges().to_lower()
		if normalized_keyword.is_empty():
			continue
		if normalized_name.contains(normalized_keyword):
			return true

	return false


func _set_node_visible_if_supported(target: Node, is_visible: bool) -> void:
	if target == null:
		return
	if not _object_has_property(target, "visible"):
		return

	target.set("visible", is_visible)


func _collect_secondary_poi_sockets_recursive(root: Node, result: Array[Node3D]) -> void:
	for child: Node in root.get_children():
		if child is Node3D and child.has_method("get_secondary_socket_environment"):
			var socket: Node3D = child as Node3D
			if not result.has(socket):
				result.append(socket)

		_collect_secondary_poi_sockets_recursive(child, result)


func get_objective_root() -> Node:
	var root: Node = get_node_or_null(objective_root_path)
	if root != null:
		return root

	for fallback_name: String in ["node_objective", "NodeObjective", "Objectives"]:
		root = get_node_or_null(fallback_name)
		if root != null:
			return root

	return null


func get_objective_candidates() -> Array[Node]:
	var result: Array[Node] = []
	var root: Node = get_objective_root()
	if root == null:
		return result

	for child: Node in root.get_children():
		if child is Node3D:
			result.append(child)

	return result


func get_objective_candidate_count() -> int:
	return get_objective_candidates().size()


func select_objective_by_index(index: int) -> Dictionary:
	var root: Node = get_objective_root()
	if root == null:
		return {}

	var candidates: Array[Node] = get_objective_candidates()
	if candidates.is_empty():
		return {
			"objective_root_path": String(objective_root_path),
			"objective_count": 0,
			"selected_objective": false,
		}

	var safe_index: int = clampi(index, 0, candidates.size() - 1)
	var selected_objective: Node = candidates[safe_index]
	var selected_name: String = String(selected_objective.name)

	for objective: Node in candidates:
		if objective == selected_objective:
			if objective is Node3D:
				var objective_node_3d: Node3D = objective as Node3D
				objective_node_3d.visible = true
			objective.process_mode = Node.PROCESS_MODE_INHERIT
			continue

		var objective_parent: Node = objective.get_parent()
		if objective_parent != null:
			objective_parent.remove_child(objective)
		objective.free()

	return {
		"objective_root_path": String(objective_root_path),
		"objective_count": candidates.size(),
		"selected_objective": true,
		"selected_objective_index": safe_index,
		"selected_objective_name": selected_name,
	}


func select_objective_by_name(objective_name: String) -> Dictionary:
	var candidates: Array[Node] = get_objective_candidates()
	for index: int in range(candidates.size()):
		if String(candidates[index].name) == objective_name:
			return select_objective_by_index(index)

	if not objective_name.is_empty() and not candidates.is_empty():
		print("[LevelBlock] Objectif sauvegardé introuvable dans %s : %s. Fallback sur le premier objectif disponible." % [block_id, objective_name])

	return select_objective_by_index(0)

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



func set_runtime_slot_index(slot_index: int) -> void:
	runtime_slot_index = slot_index
	_set_spawn_zone_section_ids()


func get_runtime_slot_index() -> int:
	return runtime_slot_index


func is_block_runtime_active() -> bool:
	return runtime_is_active


func refresh_runtime_cache() -> void:
	_runtime_collision_objects.clear()
	_runtime_rigid_bodies.clear()
	_runtime_character_bodies.clear()
	_runtime_areas.clear()
	_runtime_visual_nodes.clear()
	_runtime_spawn_zones.clear()
	_runtime_multiplayer_nodes.clear()
	_runtime_destructible_props.clear()

	_collect_runtime_nodes_recursive(self)
	_set_spawn_zone_section_ids()
	_runtime_cache_ready = true


func set_network_zone_active(active: bool) -> void:
	set_block_runtime_active(active, true)


func set_block_runtime_active(active: bool, kill_enemies: bool = true) -> void:
	if not runtime_activation_enabled:
		return

	if not _runtime_cache_ready:
		refresh_runtime_cache()

	runtime_is_active = active
	visible = true

	_set_runtime_process_state(self, active)
	for visual_node: Node3D in _runtime_visual_nodes:
		if visual_node == null or not is_instance_valid(visual_node):
			continue
		if disable_renderers_when_inactive:
			visual_node.visible = active

	for collision_object: CollisionObject3D in _runtime_collision_objects:
		_set_runtime_collision_object_active(collision_object, active)

	for rigid_body: RigidBody3D in _runtime_rigid_bodies:
		_set_runtime_rigid_body_active(rigid_body, active)

	for character_body: CharacterBody3D in _runtime_character_bodies:
		if character_body != null and is_instance_valid(character_body):
			character_body.velocity = Vector3.ZERO

	for area: Area3D in _runtime_areas:
		_set_runtime_area_active(area, active)

	for multiplayer_node: Node in _runtime_multiplayer_nodes:
		_set_runtime_multiplayer_node_active(multiplayer_node, active)

	for spawn_zone: Node in _runtime_spawn_zones:
		_set_runtime_spawn_zone_active(spawn_zone, active)

	for destructible_prop: Node in _runtime_destructible_props:
		_set_runtime_destructible_prop_active(destructible_prop, active)

	if not active and kill_enemies and kill_child_enemies_when_inactive:
		kill_runtime_child_enemies()


func kill_runtime_child_enemies() -> void:
	var enemies_to_kill: Array[Node] = []
	_collect_runtime_child_enemies(self, enemies_to_kill)

	for enemy_node: Node in enemies_to_kill:
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		enemy_node.queue_free()


func _collect_runtime_nodes_recursive(root: Node) -> void:
	if root == null:
		return

	if root != self and _is_runtime_destructible_prop_root(root):
		if not _runtime_destructible_props.has(root):
			_runtime_destructible_props.append(root)
		return

	if root != self:
		if root is CollisionObject3D:
			_runtime_collision_objects.append(root as CollisionObject3D)
		if root is RigidBody3D:
			_runtime_rigid_bodies.append(root as RigidBody3D)
		if root is CharacterBody3D:
			_runtime_character_bodies.append(root as CharacterBody3D)
		if root is Area3D:
			_runtime_areas.append(root as Area3D)
		if root is MeshInstance3D or root is GPUParticles3D or root is CPUParticles3D:
			_runtime_visual_nodes.append(root as Node3D)
		if root is MultiplayerSynchronizer or root is MultiplayerSpawner:
			_runtime_multiplayer_nodes.append(root)
		if root.is_in_group("zombie_spawn_zone") or root.has_method("get_spawn_points"):
			if not _runtime_spawn_zones.has(root):
				_runtime_spawn_zones.append(root)

	for child: Node in root.get_children():
		_collect_runtime_nodes_recursive(child)


func _set_spawn_zone_section_ids() -> void:
	for spawn_zone: Node in _runtime_spawn_zones:
		if spawn_zone == null or not is_instance_valid(spawn_zone):
			continue
		if _object_has_property(spawn_zone, "section_id"):
			spawn_zone.set("section_id", runtime_slot_index)
		if spawn_zone.has_method("set_owner_level_block"):
			spawn_zone.call("set_owner_level_block", self, runtime_slot_index)
		else:
			spawn_zone.set_meta("owner_level_block_instance_id", get_instance_id())
			spawn_zone.set_meta("owner_level_block_slot", runtime_slot_index)


func _set_runtime_spawn_zone_active(spawn_zone: Node, active: bool) -> void:
	if spawn_zone == null or not is_instance_valid(spawn_zone):
		return
	if spawn_zone.has_method("set_zone_runtime_active"):
		spawn_zone.call("set_zone_runtime_active", active)
	else:
		spawn_zone.set_meta("runtime_active", active)


func _set_runtime_destructible_prop_active(destructible_prop: Node, active: bool) -> void:
	if destructible_prop == null or not is_instance_valid(destructible_prop):
		return

	if destructible_prop.has_method("set_level_block_runtime_active"):
		destructible_prop.call("set_level_block_runtime_active", active)
		return

	if destructible_prop.has_method("set_prop_runtime_active"):
		destructible_prop.call("set_prop_runtime_active", active)
		return

	destructible_prop.set_meta("runtime_active", active)


func _is_runtime_destructible_prop_root(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false

	if node.is_in_group("destructible_props"):
		return true
	if node.has_method("set_level_block_runtime_active"):
		return true
	if node.has_method("set_prop_runtime_active"):
		return true

	return false


func _set_runtime_collision_object_active(collision_object: CollisionObject3D, active: bool) -> void:
	if collision_object == null or not is_instance_valid(collision_object):
		return
	if not disable_static_collisions_when_inactive and not (collision_object is RigidBody3D) and not (collision_object is CharacterBody3D) and not (collision_object is Area3D):
		return

	const META_LAYER: String = "runtime_original_collision_layer"
	const META_MASK: String = "runtime_original_collision_mask"
	if not collision_object.has_meta(META_LAYER):
		collision_object.set_meta(META_LAYER, collision_object.collision_layer)
	if not collision_object.has_meta(META_MASK):
		collision_object.set_meta(META_MASK, collision_object.collision_mask)

	if active:
		collision_object.collision_layer = int(collision_object.get_meta(META_LAYER))
		collision_object.collision_mask = int(collision_object.get_meta(META_MASK))
	else:
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0


func _set_runtime_rigid_body_active(rigid_body: RigidBody3D, active: bool) -> void:
	if rigid_body == null or not is_instance_valid(rigid_body):
		return

	rigid_body.linear_velocity = Vector3.ZERO
	rigid_body.angular_velocity = Vector3.ZERO
	rigid_body.sleeping = not active
	if _object_has_property(rigid_body, "freeze"):
		rigid_body.set("freeze", not active)


func _set_runtime_area_active(area: Area3D, active: bool) -> void:
	if area == null or not is_instance_valid(area):
		return
	area.monitoring = active
	area.monitorable = active


func _set_runtime_multiplayer_node_active(multiplayer_node: Node, active: bool) -> void:
	if multiplayer_node == null or not is_instance_valid(multiplayer_node):
		return

	_set_runtime_process_state(multiplayer_node, active)
	if _object_has_property(multiplayer_node, "public_visibility"):
		multiplayer_node.set("public_visibility", active)


func _set_runtime_process_state(target: Node, active: bool) -> void:
	if target == null or not is_instance_valid(target):
		return

	const META_PROCESS_MODE: String = "runtime_original_process_mode"
	if not target.has_meta(META_PROCESS_MODE):
		target.set_meta(META_PROCESS_MODE, target.process_mode)

	if active:
		target.process_mode = int(target.get_meta(META_PROCESS_MODE))
	else:
		target.process_mode = Node.PROCESS_MODE_DISABLED


func _collect_runtime_child_enemies(root: Node, result: Array[Node]) -> void:
	if root == null or not is_instance_valid(root):
		return

	if root != self and _is_runtime_enemy_node(root):
		result.append(root)
		return

	for child: Node in root.get_children():
		_collect_runtime_child_enemies(child, result)


func _is_runtime_enemy_node(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false

	for group_name: String in enemy_groups_to_kill_on_inactive:
		if group_name.is_empty():
			continue
		if node.is_in_group(group_name):
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
		"objective_root_path": String(objective_root_path),
		"objective_candidate_count": get_objective_candidate_count(),
		"secondary_poi_socket_count": get_secondary_poi_sockets().size(),
		"spawn_socket_count": get_spawn_sockets().size(),
		"connector_root_path": String(connector_root_path),
		"hidden_connector_y_offset": hidden_connector_y_offset,
		"runtime_slot_index": runtime_slot_index,
		"runtime_activation_enabled": runtime_activation_enabled,
		"side_profiles": _get_local_side_profiles(),
	}
