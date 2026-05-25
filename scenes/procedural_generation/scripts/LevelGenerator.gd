extends Node3D

signal generation_finished(database_dictionary: Dictionary)

const DatabaseScript: Script = preload("res://scenes/procedural_generation/scripts/LevelGenerationDatabase.gd")
const CARDINAL_DIRECTIONS: Array[String] = ["north", "east", "south", "west"]
const OPPOSITE_DIRECTIONS: Dictionary = {
	"north": "south",
	"east": "west",
	"south": "north",
	"west": "east",
}
const DIRECTION_TO_GRID_OFFSET: Dictionary = {
	"north": Vector2i(0, -1),
	"east": Vector2i(1, 0),
	"south": Vector2i(0, 1),
	"west": Vector2i(-1, 0),
}
const AVAILABLE_LAYOUTS: Dictionary = {
	"line_3": [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0)],
	"corner_ne": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, -1)],
	"corner_se": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
	"corner_nw": [Vector2i(0, 0), Vector2i(0, -1), Vector2i(-1, -1)],
	"corner_sw": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(-1, 1)],
}
const SIDE_PROFILE_NONE: String = "none"
const SIDE_PROFILE_SEA: String = "sea"
const DEFAULT_SECONDARY_POI_SCENE_PATHS: Array[String] = [
	"res://scenes/procedural_generation/poi_secondary/POI_AbandonedCamp.tscn",
	"res://scenes/procedural_generation/poi_secondary/POI_SmallResourceCache.tscn",
	"res://scenes/procedural_generation/poi_secondary/POI_RadioRelay.tscn",
	"res://scenes/procedural_generation/poi_secondary/POI_CrashedConvoy.tscn",
	"res://scenes/procedural_generation/poi_secondary/POI_RiverFishingDock.tscn",
	"res://scenes/procedural_generation/poi_secondary/POI_SeaShipwreck.tscn",
]

@export_group("Generation")
@export var auto_generate_on_ready: bool = false
@export var default_block_count: int = 3
@export var block_size: float = 150.0
@export var layout_id: String = "random_3"
@export var database_save_path: String = "user://last_procedural_level.json"
@export var max_generation_attempts: int = 128
@export var allow_duplicate_blocks: bool = false
@export var require_neighbor_connection: bool = true
@export var penalize_exposed_roads: bool = true
@export var sea_candidate_bonus: int = 0
@export var candidate_score_jitter: int = 3
@export_enum("random valid", "scored") var candidate_selection_mode: String = "random valid"
@export_range(0.0, 1.0, 0.01) var sea_block_generation_chance: float = 0.25
@export var max_river_blocks_per_generation: int = 1
@export var max_sea_blocks_per_generation: int = 1

@export_group("Scene Roots")
@export var generated_root_path: NodePath = ^"../GeneratedLevel"
@export var spawn_points_output_path: NodePath = ^"../SpawnPoints"
@export var vehicle_spawns_output_path: NodePath = ^"../VehicleSpawns"

@export_group("Packed Scenes")
@export var block_scenes: Array[PackedScene] = []
@export var poi_scenes: Array[PackedScene] = []
@export var secondary_poi_scenes: Array[PackedScene] = []
@export var spawn_secondary_pois: bool = true
@export_range(0.0, 1.0, 0.01) var secondary_poi_spawn_chance: float = 1.0
@export var spawn_rig_scene: PackedScene

@export_group("POI Variety")
@export var avoid_duplicate_main_pois: bool = true
@export var avoid_duplicate_secondary_pois: bool = true

@export_group("Spawn Rig")
@export_enum("snap socket 90", "follow socket", "follow block", "ignore rotation") var spawn_rig_rotation_mode: String = "snap socket 90"
@export_range(-180.0, 180.0, 1.0) var spawn_rig_rotation_offset_degrees: float = 0.0

@export_group("Debug")
@export var debug_print_database: bool = true

var last_database: Resource = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("procedural_level_generator")
	if auto_generate_on_ready:
		generate_random(0)


func generate_random(requested_seed: int = 0) -> Resource:
	var final_seed: int = requested_seed
	if final_seed == 0:
		final_seed = int(Time.get_unix_time_from_system()) ^ randi()

	_clear_current_level()

	var database = DatabaseScript.new()
	database.generation_seed = final_seed
	database.generated_at_unix = int(Time.get_unix_time_from_system())
	database.block_size = block_size

	var plan: Dictionary = _build_generation_plan(final_seed)
	if plan.is_empty():
		push_warning("[LevelGenerator] Impossible de trouver une combinaison valide pour la génération.")
		last_database = database
		_emit_generation_finished(database)
		return database

	var chosen_layout_id: String = String(plan.get("layout_id", "line_3"))
	var assignments: Array[Dictionary] = _dictionary_array_from_variant(plan.get("assignments", []))
	database.layout_id = chosen_layout_id
	database.connection_records = _get_assignment_connection_records(assignments)
	database.connection_errors = _get_assignment_connection_errors(assignments)
	if not database.connection_errors.is_empty():
		push_warning("[LevelGenerator] Plan rejeté après validation finale : %s" % JSON.stringify(database.connection_errors))
		last_database = database
		_emit_generation_finished(database)
		return database

	var generated_blocks: Array[Node3D] = []
	var used_main_poi_scene_keys: Array[String] = []
	var used_secondary_poi_scene_keys: Array[String] = []
	for assignment: Dictionary in assignments:
		var blueprint: Dictionary = assignment.get("blueprint", {})
		var block_scene: PackedScene = blueprint.get("scene", null) as PackedScene
		var block_node: Node3D = _instantiate_block_from_scene(block_scene)
		if block_node == null:
			continue

		var slot_record: Dictionary = assignment.get("slot_record", {})
		var slot_position: Vector3 = slot_record.get("world_position", Vector3.ZERO)
		var rotation_steps: int = int(assignment.get("rotation_steps", 0))
		var rotation_degrees: int = rotation_steps * 90
		var slot_index: int = int(slot_record.get("slot_index", generated_blocks.size()))

		block_node.position = slot_position
		block_node.rotation.y = deg_to_rad(float(rotation_degrees))
		var objective_selection: Dictionary = _select_random_objective_for_block(block_node)
		_get_generated_root().add_child(block_node)
		generated_blocks.append(block_node)

		# Les connexions sont d'abord calculées en directions MONDE.
		# Les nodes Connectors/North/East/South/West sont, eux, des côtés LOCAUX du bloc.
		# Il faut donc convertir monde -> local en tenant compte de la rotation du bloc.
		var connected_world_sides: PackedStringArray = _get_connected_world_sides_for_assignment(assignment, assignments)
		var connected_local_sides: PackedStringArray = _world_sides_to_local_sides(connected_world_sides, rotation_steps)
		_apply_block_connectors(block_node, connected_local_sides)

		var block_record: Dictionary = _make_block_record(block_node, block_scene, slot_index, slot_record, rotation_degrees, assignment)
		if not objective_selection.is_empty():
			block_record["objective_selection"] = objective_selection.duplicate(true)
		block_record["connected_sides_world"] = Array(connected_world_sides)
		block_record["connected_sides_local"] = Array(connected_local_sides)
		# Compatibilité debug ancienne : maintenant cette clé contient les côtés LOCAUX.
		block_record["connected_sides"] = Array(connected_local_sides)
		database.block_records.append(block_record)

		var poi_scene: PackedScene = _pick_poi_scene_for_block(block_node, used_main_poi_scene_keys)
		if poi_scene != null:
			var poi_rotation_degrees: int = 0
			var allow_random_poi_rotation: bool = _read_bool_property(block_node, "allow_random_poi_rotation", true)
			if allow_random_poi_rotation:
				poi_rotation_degrees = rng.randi_range(0, 3) * 90
			var poi_node: Node3D = _spawn_poi_on_block(block_node, poi_scene, poi_rotation_degrees)
			if poi_node != null:
				var poi_record: Dictionary = _make_poi_record(poi_node, poi_scene, slot_index, poi_rotation_degrees, allow_random_poi_rotation, "main", -1, "POISocket", {})
				database.poi_records.append(poi_record)
				_mark_scene_key_as_used(poi_scene, used_main_poi_scene_keys)

		_spawn_secondary_pois_for_block(database, block_node, slot_index, used_secondary_poi_scene_keys)

	_spawn_rig_for_database(database, generated_blocks)

	last_database = database
	_emit_generation_finished(database)
	return database


func generate_from_dictionary(database_dictionary: Dictionary) -> Resource:
	_clear_current_level()

	var database = DatabaseScript.new()
	database.from_dictionary(database_dictionary)
	block_size = float(database.block_size)
	layout_id = String(database.layout_id)

	var generated_blocks: Array[Node3D] = []
	for block_record: Dictionary in database.block_records:
		var scene_path: String = String(block_record.get("scene_path", ""))
		var block_scene: PackedScene = _load_scene(scene_path)
		var block_node: Node3D = _instantiate_block_from_scene(block_scene)
		if block_node == null:
			continue

		var slot_position: Vector3 = _vector3_from_array(block_record.get("slot_position", [0.0, 0.0, 0.0]))
		var rotation_degrees: float = float(block_record.get("rotation_y_degrees", 0.0))
		block_node.position = slot_position
		block_node.rotation.y = deg_to_rad(rotation_degrees)
		_apply_saved_objective_selection_to_block(block_node, block_record)
		_get_generated_root().add_child(block_node)
		generated_blocks.append(block_node)

	_apply_connectors_from_block_records(generated_blocks, database.block_records)

	for poi_record: Dictionary in database.poi_records:
		_spawn_poi_from_record(poi_record, generated_blocks, database.block_records, false)

	for poi_record: Dictionary in database.secondary_poi_records:
		_spawn_poi_from_record(poi_record, generated_blocks, database.block_records, true)

	_spawn_rig_from_record(database.spawn_record, generated_blocks, database.block_records)
	if database.connection_records.is_empty():
		database.connection_records = _get_block_record_connection_records(database.block_records)
	database.connection_errors = _get_block_record_connection_errors(database.block_records)

	last_database = database
	_emit_generation_finished(database)
	return database


func generate_from_json_file(path: String) -> Resource:
	var final_path: String = path
	if final_path.is_empty():
		final_path = database_save_path

	var data: Dictionary = DatabaseScript.load_dictionary_from_json(final_path)
	if data.is_empty():
		return null
	return generate_from_dictionary(data)


func save_current_database(path: String = "") -> bool:
	if last_database == null:
		return false

	var final_path: String = path
	if final_path.is_empty():
		final_path = database_save_path

	if not last_database.has_method("save_to_json"):
		return false

	return bool(last_database.call("save_to_json", final_path))


func get_database_dictionary() -> Dictionary:
	if last_database == null:
		return {}
	if not last_database.has_method("to_dictionary"):
		return {}
	var value: Variant = last_database.call("to_dictionary")
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func get_database_text() -> String:
	if last_database == null:
		return "{}"
	if not last_database.has_method("to_json_text"):
		return "{}"
	return String(last_database.call("to_json_text"))


func get_spawn_points_root() -> Node3D:
	return _get_or_create_root(spawn_points_output_path, "SpawnPoints")


func get_vehicle_spawns_root() -> Node3D:
	return _get_or_create_root(vehicle_spawns_output_path, "VehicleSpawns")


func _build_generation_plan(seed_value: int) -> Dictionary:
	var block_blueprints: Array[Dictionary] = _collect_block_blueprints()
	if block_blueprints.is_empty():
		return {}

	block_blueprints = _filter_blueprints_for_generation(block_blueprints)
	if block_blueprints.is_empty():
		return {}

	var target_block_count: int = min(default_block_count, block_blueprints.size())
	if allow_duplicate_blocks:
		target_block_count = default_block_count
	if target_block_count <= 0:
		return {}

	var safe_attempt_count: int = maxi(1, max_generation_attempts)
	for attempt_index: int in range(safe_attempt_count):
		rng.seed = seed_value + (attempt_index * 7919)
		var chosen_layout_id: String = _choose_layout_id_for_attempt()
		var layout_slots: Array[Dictionary] = _build_layout_slots(chosen_layout_id, target_block_count)
		if layout_slots.is_empty():
			continue

		var slot_lookup: Dictionary = _build_slot_lookup(layout_slots)
		var assignments: Array[Dictionary] = []
		var used_scene_paths: Array[String] = []
		var solved: bool = _solve_layout_recursive(0, layout_slots, slot_lookup, block_blueprints, used_scene_paths, assignments)
		if solved and assignments.size() == layout_slots.size():
			var validation_errors: Array[Dictionary] = _get_assignment_connection_errors(assignments)
			if validation_errors.is_empty():
				return {
					"layout_id": chosen_layout_id,
					"layout_slots": layout_slots,
					"assignments": assignments,
				}

	return {}


func _choose_layout_id_for_attempt() -> String:
	if layout_id.is_empty() or layout_id == "random_3" or not AVAILABLE_LAYOUTS.has(layout_id):
		var layout_keys: Array = AVAILABLE_LAYOUTS.keys()
		if layout_keys.is_empty():
			return "line_3"
		var random_index: int = rng.randi_range(0, layout_keys.size() - 1)
		return String(layout_keys[random_index])
	return layout_id


func _build_layout_slots(chosen_layout_id: String, requested_block_count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var base_positions_variant: Variant = AVAILABLE_LAYOUTS.get(chosen_layout_id, [])
	if not (base_positions_variant is Array):
		return result

	var base_positions: Array = base_positions_variant as Array
	var safe_count: int = min(requested_block_count, base_positions.size())
	for slot_index: int in range(safe_count):
		var grid_position: Vector2i = base_positions[slot_index]
		var world_position: Vector3 = Vector3(float(grid_position.x) * block_size, 0.0, float(grid_position.y) * block_size)
		result.append({
			"slot_index": slot_index,
			"grid_position": grid_position,
			"world_position": world_position,
		})
	return result


func _build_slot_lookup(layout_slots: Array[Dictionary]) -> Dictionary:
	var lookup: Dictionary = {}
	for slot_record: Dictionary in layout_slots:
		var grid_position: Vector2i = slot_record.get("grid_position", Vector2i.ZERO)
		lookup[_grid_key(grid_position)] = slot_record
	return lookup


func _grid_key(grid_position: Vector2i) -> String:
	return "%d,%d" % [grid_position.x, grid_position.y]


func _collect_block_blueprints() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for scene: PackedScene in block_scenes:
		if scene == null:
			continue

		var block_node: Node3D = _instantiate_block_from_scene(scene)
		if block_node == null:
			continue

		var summary: Dictionary = {}
		if block_node.has_method("get_database_summary"):
			var summary_value: Variant = block_node.call("get_database_summary")
			if summary_value is Dictionary:
				summary = (summary_value as Dictionary).duplicate(true)

		var block_type_value: String = String(summary.get("block_type", "generic"))
		var side_profiles_value: Dictionary = _dictionary_from_variant(summary.get("side_profiles", {}))
		var blueprint: Dictionary = {
			"scene": scene,
			"scene_path": _get_scene_path(scene),
			"block_id": String(summary.get("block_id", block_node.name)),
			"block_type": block_type_value,
			"block_category": _get_block_category_from_data(block_type_value, side_profiles_value),
			"compatible_poi_tags": summary.get("compatible_poi_tags", []),
			"has_water_near_poi": bool(summary.get("has_water_near_poi", false)),
			"poi_water_type": String(summary.get("poi_water_type", "none")),
			"allow_random_poi_rotation": bool(summary.get("allow_random_poi_rotation", true)),
			"side_profiles": _side_profiles_from_summary(summary),
		}
		result.append(blueprint)
		block_node.queue_free()
	return result


func _side_profiles_from_summary(summary: Dictionary) -> Dictionary:
	var default_profiles: Dictionary = {
		"north": SIDE_PROFILE_NONE,
		"east": SIDE_PROFILE_NONE,
		"south": SIDE_PROFILE_NONE,
		"west": SIDE_PROFILE_NONE,
	}
	var value: Variant = summary.get("side_profiles", {})
	if value is Dictionary:
		var source: Dictionary = value as Dictionary
		for side: String in CARDINAL_DIRECTIONS:
			default_profiles[side] = String(source.get(side, SIDE_PROFILE_NONE))
	return default_profiles


func _filter_blueprints_for_generation(source_blueprints: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var include_sea: bool = true
	if sea_block_generation_chance < 1.0:
		include_sea = rng.randf() <= sea_block_generation_chance

	for blueprint: Dictionary in source_blueprints:
		var category: String = String(blueprint.get("block_category", "generic"))
		if category == "sea" and not include_sea:
			continue
		result.append(blueprint)

	return result


func _is_candidate_category_allowed(candidate: Dictionary, assignments: Array[Dictionary]) -> bool:
	var blueprint: Dictionary = candidate.get("blueprint", {})
	var category: String = String(blueprint.get("block_category", "generic"))
	var current_count: int = 0
	for assignment: Dictionary in assignments:
		var other_blueprint: Dictionary = assignment.get("blueprint", {})
		if String(other_blueprint.get("block_category", "generic")) == category:
			current_count += 1

	if category == "river" and max_river_blocks_per_generation >= 0:
		return current_count < max_river_blocks_per_generation
	if category == "sea" and max_sea_blocks_per_generation >= 0:
		return current_count < max_sea_blocks_per_generation
	return true


func _get_block_category_from_data(block_type: String, side_profiles: Dictionary) -> String:
	var normalized_type: String = block_type.strip_edges().to_lower()
	if normalized_type == "sea" or _side_profiles_contain(side_profiles, SIDE_PROFILE_SEA):
		return "sea"
	if normalized_type.contains("river") or _side_profiles_contain_text(side_profiles, "river"):
		return "river"
	if normalized_type.contains("mountain"):
		return "mountain"
	if normalized_type.contains("forest"):
		return "forest"
	return normalized_type


func _side_profiles_contain(side_profiles: Dictionary, wanted_profile: String) -> bool:
	for side: String in CARDINAL_DIRECTIONS:
		if _normalize_side_profile(String(side_profiles.get(side, SIDE_PROFILE_NONE))) == wanted_profile:
			return true
	return false


func _side_profiles_contain_text(side_profiles: Dictionary, wanted_text: String) -> bool:
	for side: String in CARDINAL_DIRECTIONS:
		if _normalize_side_profile(String(side_profiles.get(side, SIDE_PROFILE_NONE))).contains(wanted_text):
			return true
	return false


func _solve_layout_recursive(slot_cursor: int, layout_slots: Array[Dictionary], slot_lookup: Dictionary, block_blueprints: Array[Dictionary], used_scene_paths: Array[String], assignments: Array[Dictionary]) -> bool:
	if slot_cursor >= layout_slots.size():
		return true

	var slot_record: Dictionary = layout_slots[slot_cursor]
	var candidate_entries: Array[Dictionary] = []
	var shuffled_blueprints: Array = block_blueprints.duplicate(true)
	shuffled_blueprints.shuffle()

	for item: Variant in shuffled_blueprints:
		if not (item is Dictionary):
			continue

		var blueprint: Dictionary = item as Dictionary
		var scene_path: String = String(blueprint.get("scene_path", ""))
		if not allow_duplicate_blocks and used_scene_paths.has(scene_path):
			continue

		var rotation_steps_order: Array[int] = [0, 1, 2, 3]
		rotation_steps_order.shuffle()

		for rotation_steps: int in rotation_steps_order:
			var candidate: Dictionary = _build_assignment_candidate(blueprint, slot_record, rotation_steps)
			if not _is_candidate_valid(candidate, slot_lookup, assignments):
				continue
			if not _is_candidate_category_allowed(candidate, assignments):
				continue
			if candidate_selection_mode == "scored":
				candidate["_sort_score"] = _score_candidate(candidate, slot_lookup, assignments) + rng.randi_range(0, maxi(0, candidate_score_jitter))
			candidate_entries.append(candidate)

	candidate_entries.shuffle()
	if candidate_selection_mode == "scored":
		candidate_entries.sort_custom(Callable(self, "_compare_candidate_sort_score"))

	for candidate: Dictionary in candidate_entries:
		var blueprint: Dictionary = candidate.get("blueprint", {})
		var scene_path: String = String(blueprint.get("scene_path", ""))
		assignments.append(candidate)
		if not allow_duplicate_blocks:
			used_scene_paths.append(scene_path)

		if _solve_layout_recursive(slot_cursor + 1, layout_slots, slot_lookup, block_blueprints, used_scene_paths, assignments):
			return true

		assignments.pop_back()
		if not allow_duplicate_blocks:
			used_scene_paths.erase(scene_path)

	return false


func _compare_candidate_sort_score(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("_sort_score", 0)) > int(b.get("_sort_score", 0))


func _build_assignment_candidate(blueprint: Dictionary, slot_record: Dictionary, rotation_steps: int) -> Dictionary:
	var side_profiles: Dictionary = _rotate_side_profiles(blueprint.get("side_profiles", {}), rotation_steps)
	return {
		"blueprint": blueprint,
		"slot_record": slot_record,
		"rotation_steps": rotation_steps,
		"side_profiles": side_profiles,
	}


func _is_candidate_valid(candidate: Dictionary, slot_lookup: Dictionary, assignments: Array[Dictionary]) -> bool:
	var slot_record: Dictionary = candidate.get("slot_record", {})
	var grid_position: Vector2i = slot_record.get("grid_position", Vector2i.ZERO)

	if require_neighbor_connection:
		for side: String in CARDINAL_DIRECTIONS:
			var neighbor_slot: Dictionary = _get_neighbor_slot_record(slot_lookup, grid_position, side)
			if neighbor_slot.is_empty():
				continue
			var candidate_future_profile: String = _get_assignment_side_profile(candidate, side)
			if candidate_future_profile == SIDE_PROFILE_NONE:
				return false
			# La mer doit rester vers l'extérieur du niveau.
			# Elle ne peut jamais toucher un autre bloc, même un autre côté sea.
			if candidate_future_profile == SIDE_PROFILE_SEA:
				return false

	for placed_assignment: Dictionary in assignments:
		var other_slot_record: Dictionary = placed_assignment.get("slot_record", {})
		var other_grid_position: Vector2i = other_slot_record.get("grid_position", Vector2i.ZERO)
		var direction_to_other: String = _get_direction_between(grid_position, other_grid_position)
		if direction_to_other.is_empty():
			continue

		var opposite_direction: String = String(OPPOSITE_DIRECTIONS.get(direction_to_other, ""))
		if opposite_direction.is_empty():
			continue

		var candidate_profile: String = _get_assignment_side_profile(candidate, direction_to_other)
		var other_profile: String = _get_assignment_side_profile(placed_assignment, opposite_direction)
		if not _are_side_profiles_compatible(candidate_profile, other_profile):
			return false

	return true


func _are_assignments_fully_valid(assignments: Array[Dictionary]) -> bool:
	return _get_assignment_connection_errors(assignments).is_empty()


func _get_assignment_connection_records(assignments: Array[Dictionary]) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var checked_pairs: Dictionary = {}
	for assignment: Dictionary in assignments:
		var slot_record: Dictionary = assignment.get("slot_record", {})
		var grid_position: Vector2i = slot_record.get("grid_position", Vector2i.ZERO)
		var slot_index: int = int(slot_record.get("slot_index", -1))

		for side: String in CARDINAL_DIRECTIONS:
			var neighbor_grid: Vector2i = grid_position + DIRECTION_TO_GRID_OFFSET.get(side, Vector2i.ZERO)
			var neighbor_assignment: Dictionary = _find_assignment_at_grid(assignments, neighbor_grid)
			if neighbor_assignment.is_empty():
				continue

			var neighbor_slot_record: Dictionary = neighbor_assignment.get("slot_record", {})
			var neighbor_slot_index: int = int(neighbor_slot_record.get("slot_index", -1))
			var pair_key: String = _connection_pair_key(slot_index, neighbor_slot_index)
			if checked_pairs.has(pair_key):
				continue
			checked_pairs[pair_key] = true

			var opposite_side: String = String(OPPOSITE_DIRECTIONS.get(side, ""))
			var profile_a: String = _get_assignment_side_profile(assignment, side)
			var profile_b: String = _get_assignment_side_profile(neighbor_assignment, opposite_side)
			records.append({
				"slot_a": slot_index,
				"side_a": side,
				"profile_a": profile_a,
				"slot_b": neighbor_slot_index,
				"side_b": opposite_side,
				"profile_b": profile_b,
				"valid": _are_side_profiles_compatible(profile_a, profile_b),
			})
	return records


func _get_assignment_connection_errors(assignments: Array[Dictionary]) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	for record: Dictionary in _get_assignment_connection_records(assignments):
		if bool(record.get("valid", false)):
			continue
		var profile_a: String = String(record.get("profile_a", SIDE_PROFILE_NONE))
		var profile_b: String = String(record.get("profile_b", SIDE_PROFILE_NONE))
		var reason: String = "side_profile_mismatch"
		if profile_a == SIDE_PROFILE_SEA or profile_b == SIDE_PROFILE_SEA:
			reason = "sea_must_face_exterior"
		elif profile_a == SIDE_PROFILE_NONE and profile_b == SIDE_PROFILE_NONE:
			reason = "none_against_none_has_no_connection"
		errors.append({
			"reason": reason,
			"slot_a": int(record.get("slot_a", -1)),
			"side_a": String(record.get("side_a", "")),
			"profile_a": profile_a,
			"slot_b": int(record.get("slot_b", -1)),
			"side_b": String(record.get("side_b", "")),
			"profile_b": profile_b,
		})
	return errors


func _connection_pair_key(slot_a: int, slot_b: int) -> String:
	var min_slot: int = mini(slot_a, slot_b)
	var max_slot: int = maxi(slot_a, slot_b)
	return "%d:%d" % [min_slot, max_slot]


func _find_assignment_at_grid(assignments: Array[Dictionary], grid_position: Vector2i) -> Dictionary:
	for assignment: Dictionary in assignments:
		var slot_record: Dictionary = assignment.get("slot_record", {})
		var other_grid_position: Vector2i = slot_record.get("grid_position", Vector2i.ZERO)
		if other_grid_position == grid_position:
			return assignment
	return {}


func _get_connected_world_sides_for_assignment(assignment: Dictionary, assignments: Array[Dictionary]) -> PackedStringArray:
	var connected_sides: PackedStringArray = PackedStringArray()
	var slot_record: Dictionary = assignment.get("slot_record", {})
	var grid_position: Vector2i = slot_record.get("grid_position", Vector2i.ZERO)

	for side: String in CARDINAL_DIRECTIONS:
		var neighbor_grid: Vector2i = grid_position + DIRECTION_TO_GRID_OFFSET.get(side, Vector2i.ZERO)
		var neighbor_assignment: Dictionary = _find_assignment_at_grid(assignments, neighbor_grid)
		if neighbor_assignment.is_empty():
			continue
		if not connected_sides.has(side):
			connected_sides.append(side)

	return connected_sides


func _apply_block_connectors(block_node: Node3D, connected_sides: PackedStringArray) -> void:
	if block_node == null:
		return
	if block_node.has_method("apply_connector_visibility"):
		block_node.call("apply_connector_visibility", connected_sides)


func _apply_connectors_from_block_records(generated_blocks: Array[Node3D], block_records: Array[Dictionary]) -> void:
	for block_node: Node3D in generated_blocks:
		if block_node == null:
			continue

		var slot_index: int = _find_block_slot_for_generated_node(block_node, generated_blocks, block_records)
		if slot_index < 0:
			continue

		var connected_local_sides: PackedStringArray = _get_local_connected_sides_for_block_slot(slot_index, block_records)
		_apply_block_connectors(block_node, connected_local_sides)


func _find_block_slot_for_generated_node(block_node: Node3D, generated_blocks: Array[Node3D], block_records: Array[Dictionary]) -> int:
	for i: int in range(generated_blocks.size()):
		if generated_blocks[i] != block_node:
			continue
		if i < block_records.size():
			return int(block_records[i].get("slot_index", -1))
	return -1


func _get_local_connected_sides_for_block_slot(slot_index: int, block_records: Array[Dictionary]) -> PackedStringArray:
	var connected_local_sides: PackedStringArray = PackedStringArray()
	var block_record: Dictionary = _find_block_record_by_slot(block_records, slot_index)
	if block_record.is_empty():
		return connected_local_sides

	# Nouvelle clé fiable : côtés LOCAUX à cacher, déjà convertis au moment de la génération.
	var saved_local_sides: Variant = block_record.get("connected_sides_local", [])
	if saved_local_sides is Array:
		for item: Variant in saved_local_sides:
			var local_side: String = String(item).strip_edges().to_lower()
			if CARDINAL_DIRECTIONS.has(local_side) and not connected_local_sides.has(local_side):
				connected_local_sides.append(local_side)
		if not connected_local_sides.is_empty():
			return connected_local_sides

	# Fallback : on recalcule les connexions en monde à partir de la grille,
	# puis on les convertit en local selon la rotation sauvegardée du bloc.
	var connected_world_sides: PackedStringArray = PackedStringArray()
	var grid_position: Vector2i = _grid_position_from_block_record(block_record)
	for world_side: String in CARDINAL_DIRECTIONS:
		var neighbor_grid: Vector2i = grid_position + DIRECTION_TO_GRID_OFFSET.get(world_side, Vector2i.ZERO)
		var neighbor_record: Dictionary = _find_block_record_at_grid(block_records, neighbor_grid)
		if neighbor_record.is_empty():
			continue
		if not connected_world_sides.has(world_side):
			connected_world_sides.append(world_side)

	var rotation_steps: int = _rotation_steps_from_block_record(block_record)
	return _world_sides_to_local_sides(connected_world_sides, rotation_steps)


func _find_block_record_by_slot(block_records: Array[Dictionary], slot_index: int) -> Dictionary:
	for block_record: Dictionary in block_records:
		if int(block_record.get("slot_index", -1)) == slot_index:
			return block_record
	return {}


func _find_block_record_at_grid(block_records: Array[Dictionary], grid_position: Vector2i) -> Dictionary:
	for block_record: Dictionary in block_records:
		if _grid_position_from_block_record(block_record) == grid_position:
			return block_record
	return {}


func _grid_position_from_block_record(block_record: Dictionary) -> Vector2i:
	var grid_array: Variant = block_record.get("grid_position", [0, 0])
	if grid_array is Array:
		var grid_values: Array = grid_array as Array
		if grid_values.size() >= 2:
			return Vector2i(int(grid_values[0]), int(grid_values[1]))
	return Vector2i.ZERO


func _are_side_profiles_compatible(profile_a: String, profile_b: String) -> bool:
	var normalized_a: String = _normalize_side_profile(profile_a)
	var normalized_b: String = _normalize_side_profile(profile_b)
	if normalized_a == SIDE_PROFILE_NONE and normalized_b == SIDE_PROFILE_NONE:
		return false
	if normalized_a == SIDE_PROFILE_SEA or normalized_b == SIDE_PROFILE_SEA:
		# La mer doit être sur un bord extérieur, jamais contre un autre bloc.
		return false
	return normalized_a == normalized_b


func _get_assignment_side_profile(assignment: Dictionary, side: String) -> String:
	var side_profiles: Dictionary = assignment.get("side_profiles", {})
	return _normalize_side_profile(String(side_profiles.get(side, SIDE_PROFILE_NONE)))


func _normalize_side_profile(profile: String) -> String:
	return profile.strip_edges().to_lower()


func _score_candidate(candidate: Dictionary, slot_lookup: Dictionary, assignments: Array[Dictionary]) -> int:
	var slot_record: Dictionary = candidate.get("slot_record", {})
	var grid_position: Vector2i = slot_record.get("grid_position", Vector2i.ZERO)
	var blueprint: Dictionary = candidate.get("blueprint", {})
	var block_type: String = String(blueprint.get("block_type", ""))
	var score: int = 0

	if block_type == "sea":
		score += sea_candidate_bonus

	for side: String in CARDINAL_DIRECTIONS:
		var has_neighbor_slot: bool = _get_neighbor_slot_record(slot_lookup, grid_position, side).size() > 0
		var profile: String = _get_assignment_side_profile(candidate, side)
		if has_neighbor_slot:
			if profile == SIDE_PROFILE_NONE:
				score -= 80
			elif profile == SIDE_PROFILE_SEA:
				score -= 30
			elif profile.contains("river") and profile.contains("road"):
				score += 20
			elif profile.contains("river"):
				score += 14
			elif profile.contains("road"):
				score += 10
		else:
			if profile == SIDE_PROFILE_SEA:
				score += 12
			elif penalize_exposed_roads and profile.contains("road"):
				score -= 5
			elif profile.contains("river"):
				score -= 2

	for placed_assignment: Dictionary in assignments:
		var other_slot_record: Dictionary = placed_assignment.get("slot_record", {})
		var other_grid_position: Vector2i = other_slot_record.get("grid_position", Vector2i.ZERO)
		var direction_to_other: String = _get_direction_between(grid_position, other_grid_position)
		if direction_to_other.is_empty():
			continue
		var opposite_direction: String = String(OPPOSITE_DIRECTIONS.get(direction_to_other, ""))
		var candidate_profile: String = _get_assignment_side_profile(candidate, direction_to_other)
		var other_profile: String = _get_assignment_side_profile(placed_assignment, opposite_direction)
		if _are_side_profiles_compatible(candidate_profile, other_profile):
			score += 16

	return score


func _get_neighbor_slot_record(slot_lookup: Dictionary, grid_position: Vector2i, direction: String) -> Dictionary:
	var offset: Vector2i = DIRECTION_TO_GRID_OFFSET.get(direction, Vector2i.ZERO)
	var neighbor_grid: Vector2i = grid_position + offset
	var value: Variant = slot_lookup.get(_grid_key(neighbor_grid), {})
	if value is Dictionary:
		return value as Dictionary
	return {}


func _get_direction_between(from_grid: Vector2i, to_grid: Vector2i) -> String:
	var delta: Vector2i = to_grid - from_grid
	for direction: String in CARDINAL_DIRECTIONS:
		var offset: Vector2i = DIRECTION_TO_GRID_OFFSET.get(direction, Vector2i.ZERO)
		if delta == offset:
			return direction
	return ""


func _rotate_side_profiles(source_value: Variant, rotation_steps: int) -> Dictionary:
	var local_profiles: Dictionary = {
		"north": SIDE_PROFILE_NONE,
		"east": SIDE_PROFILE_NONE,
		"south": SIDE_PROFILE_NONE,
		"west": SIDE_PROFILE_NONE,
	}
	if source_value is Dictionary:
		var source_dictionary: Dictionary = source_value as Dictionary
		for side: String in CARDINAL_DIRECTIONS:
			local_profiles[side] = String(source_dictionary.get(side, SIDE_PROFILE_NONE))

	var rotated_profiles: Dictionary = {}
	for local_side: String in CARDINAL_DIRECTIONS:
		var rotated_side: String = _rotate_side(local_side, rotation_steps)
		rotated_profiles[rotated_side] = String(local_profiles.get(local_side, SIDE_PROFILE_NONE))
	return rotated_profiles


func _rotate_side(local_side: String, rotation_steps: int) -> String:
	var direction_index: int = CARDINAL_DIRECTIONS.find(local_side)
	if direction_index == -1:
		return local_side
	# Godot positive Y rotation moves local north (-Z) toward world west.
	# The profile rotation must therefore subtract the 90-degree steps.
	var normalized_steps: int = ((rotation_steps % 4) + 4) % 4
	var rotated_index: int = (direction_index - normalized_steps + CARDINAL_DIRECTIONS.size()) % CARDINAL_DIRECTIONS.size()
	return CARDINAL_DIRECTIONS[rotated_index]


func _world_sides_to_local_sides(world_sides: PackedStringArray, rotation_steps: int) -> PackedStringArray:
	var local_sides: PackedStringArray = PackedStringArray()
	for world_side: String in world_sides:
		var local_side: String = _world_side_to_local_side(world_side, rotation_steps)
		if CARDINAL_DIRECTIONS.has(local_side) and not local_sides.has(local_side):
			local_sides.append(local_side)
	return local_sides


func _world_side_to_local_side(world_side: String, rotation_steps: int) -> String:
	var direction_index: int = CARDINAL_DIRECTIONS.find(world_side)
	if direction_index == -1:
		return world_side

	# Inverse de _rotate_side().
	# _rotate_side() convertit local -> monde avec : world = local - rotation_steps.
	# Ici on veut monde -> local : local = world + rotation_steps.
	var normalized_steps: int = ((rotation_steps % 4) + 4) % 4
	var local_index: int = (direction_index + normalized_steps) % CARDINAL_DIRECTIONS.size()
	return CARDINAL_DIRECTIONS[local_index]


func _rotation_steps_from_block_record(block_record: Dictionary) -> int:
	if block_record.has("rotation_steps"):
		return int(block_record.get("rotation_steps", 0))

	var rotation_degrees: float = float(block_record.get("rotation_y_degrees", 0.0))
	var rounded_steps: int = int(round(rotation_degrees / 90.0))
	return ((rounded_steps % 4) + 4) % 4


func _emit_generation_finished(database: Resource) -> void:
	var data: Dictionary = {}
	if database != null and database.has_method("to_dictionary"):
		var value: Variant = database.call("to_dictionary")
		if value is Dictionary:
			data = (value as Dictionary).duplicate(true)

	if debug_print_database:
		print("[LevelGenerator] Database générée :\n", JSON.stringify(data, "\t"))

	generation_finished.emit(data)


func _pick_poi_scene_for_block(block_node: Node, used_scene_keys: Array[String]) -> PackedScene:
	var candidates: Array[PackedScene] = _get_main_poi_candidates_for_block(block_node)
	return _pick_scene_with_duplicate_fallback(candidates, used_scene_keys, avoid_duplicate_main_pois, "POI principal", _get_node_debug_name(block_node))


func _pick_secondary_poi_scene_for_socket(block_node: Node3D, socket: Node3D, used_scene_keys: Array[String]) -> PackedScene:
	var candidates: Array[PackedScene] = []
	for scene: PackedScene in _get_effective_secondary_poi_scenes():
		if scene == null:
			continue
		if _secondary_poi_scene_can_spawn_on_socket(scene, block_node, socket):
			candidates.append(scene)

	return _pick_scene_with_duplicate_fallback(candidates, used_scene_keys, avoid_duplicate_secondary_pois, "POI secondaire", _get_node_debug_name(socket))


func _get_main_poi_candidates_for_block(block_node: Node) -> Array[PackedScene]:
	var candidates: Array[PackedScene] = []
	for scene: PackedScene in poi_scenes:
		if scene == null:
			continue
		if _poi_scene_can_spawn_on_block(scene, block_node):
			candidates.append(scene)
	return candidates


func _pick_scene_with_duplicate_fallback(candidates: Array[PackedScene], used_scene_keys: Array[String], avoid_duplicates: bool, poi_label: String, context_name: String) -> PackedScene:
	if candidates.is_empty():
		return null

	if not avoid_duplicates:
		return candidates[rng.randi_range(0, candidates.size() - 1)]

	var unused_candidates: Array[PackedScene] = []
	for scene: PackedScene in candidates:
		var scene_key: String = _get_scene_unique_key(scene)
		if not used_scene_keys.has(scene_key):
			unused_candidates.append(scene)

	if not unused_candidates.is_empty():
		return unused_candidates[rng.randi_range(0, unused_candidates.size() - 1)]

	var duplicate_scene: PackedScene = candidates[rng.randi_range(0, candidates.size() - 1)]
	print("[LevelGenerator] Doublon de %s nécessaire sur %s. Aucun candidat inutilisé compatible. Spawn du doublon : %s" % [poi_label, context_name, _get_scene_debug_name(duplicate_scene)])
	return duplicate_scene


func _mark_scene_key_as_used(scene: PackedScene, used_scene_keys: Array[String]) -> void:
	var scene_key: String = _get_scene_unique_key(scene)
	if scene_key.is_empty():
		return
	if not used_scene_keys.has(scene_key):
		used_scene_keys.append(scene_key)


func _get_scene_unique_key(scene: PackedScene) -> String:
	if scene == null:
		return ""
	var scene_path: String = _get_scene_path(scene)
	if not scene_path.is_empty():
		return scene_path
	return str(scene.get_instance_id())


func _get_scene_debug_name(scene: PackedScene) -> String:
	if scene == null:
		return "null"
	var scene_path: String = _get_scene_path(scene)
	if not scene_path.is_empty():
		return scene_path
	return "PackedScene#%s" % str(scene.get_instance_id())


func _get_node_debug_name(node: Node) -> String:
	if node == null:
		return "node inconnu"
	return String(node.name)


func _get_effective_secondary_poi_scenes() -> Array[PackedScene]:
	if not secondary_poi_scenes.is_empty():
		return secondary_poi_scenes

	var result: Array[PackedScene] = []
	for scene_path: String in DEFAULT_SECONDARY_POI_SCENE_PATHS:
		var scene: PackedScene = _load_scene(scene_path)
		if scene != null:
			result.append(scene)
	return result


func _poi_scene_can_spawn_on_block(scene: PackedScene, block_node: Node) -> bool:
	var poi: Node = scene.instantiate()
	if poi == null:
		return false

	var can_spawn: bool = true
	if poi.has_method("can_spawn_on_block"):
		can_spawn = bool(poi.call("can_spawn_on_block", block_node))
	poi.free()
	return can_spawn


func _secondary_poi_scene_can_spawn_on_socket(scene: PackedScene, block_node: Node3D, socket: Node3D) -> bool:
	if scene == null or block_node == null or socket == null:
		return false

	# Pas de détection automatique. Un socket secondaire doit avoir SecondaryPOISocket.gd.
	if not socket.has_method("can_accept_secondary_poi"):
		push_warning("[LevelGenerator] Socket secondaire sans SecondaryPOISocket.gd : %s" % socket.name)
		return false

	var poi: Node = scene.instantiate()
	if poi == null:
		return false

	var can_spawn: bool = bool(socket.call("can_accept_secondary_poi", poi))
	poi.free()
	return can_spawn


func _get_secondary_poi_rotation_mode(scene: PackedScene, socket: Node3D = null) -> String:
	if scene == null:
		return "follow block"

	var poi: Node = scene.instantiate()
	if poi == null:
		return "follow block"

	var rotation_mode: String = "follow block"
	if poi.has_method("get_secondary_rotation_mode"):
		rotation_mode = String(poi.call("get_secondary_rotation_mode"))
	else:
		rotation_mode = _read_string_property(poi, "secondary_rotation_mode", "follow block")

	# Le socket peut surcharger le mode de rotation.
	if socket != null and socket.has_method("get_secondary_rotation_mode_for_poi"):
		rotation_mode = String(socket.call("get_secondary_rotation_mode_for_poi", poi, rotation_mode))

	poi.free()
	return rotation_mode


func _get_secondary_poi_placement_type(scene: PackedScene) -> String:
	if scene == null:
		return "land"

	var poi: Node = scene.instantiate()
	if poi == null:
		return "land"

	var placement_type: String = "land"
	if poi.has_method("get_effective_placement_type"):
		placement_type = String(poi.call("get_effective_placement_type"))
	else:
		placement_type = _read_string_property(poi, "secondary_placement_type", "land")

	poi.free()
	return placement_type


func _get_secondary_socket_environment(block_node: Node3D, socket: Node3D, scene: PackedScene = null) -> String:
	if socket == null:
		return "missing_socket"

	# Pas de déduction automatique depuis la position du socket ou les côtés du bloc.
	# La source de vérité est uniquement SecondaryPOISocket.gd sur le Node3D du socket.
	if socket.has_method("get_secondary_socket_environment"):
		return String(socket.call("get_secondary_socket_environment"))

	return "missing_socket_script"


func _get_socket_environment_from_metadata(socket: Node) -> String:
	for property_info: Dictionary in socket.get_property_list():
		if String(property_info.get("name", "")) == "secondary_poi_environment":
			var property_value: String = String(socket.get("secondary_poi_environment"))
			if property_value in ["land", "river", "sea", "water"]:
				return property_value

	for key: String in ["secondary_poi_environment", "poi_environment", "environment", "placement_type"]:
		if socket.has_meta(key):
			var value: String = String(socket.get_meta(key))
			if value in ["land", "river", "sea", "water"]:
				return value
	return ""


func _get_closest_block_side_for_socket(block_node: Node3D, socket: Node3D) -> String:
	if block_node == null or socket == null:
		return "north"

	var local_position: Vector3 = block_node.global_transform.affine_inverse() * socket.global_position
	if absf(local_position.x) > absf(local_position.z):
		if local_position.x >= 0.0:
			return "east"
		return "west"

	if local_position.z >= 0.0:
		return "south"
	return "north"


func _get_block_side_profile(block_node: Node3D, side: String) -> String:
	if block_node == null:
		return SIDE_PROFILE_NONE

	if block_node.has_method("get_side_profile_for_side"):
		return String(block_node.call("get_side_profile_for_side", side, 0))

	var property_name: String = "%s_side_profile" % side
	return _read_string_property(block_node, property_name, SIDE_PROFILE_NONE)


func _side_profile_to_socket_environment(side_profile: String) -> String:
	if side_profile == SIDE_PROFILE_SEA:
		return "sea"
	if side_profile.find("river") != -1:
		return "river"
	return "land"


func _select_random_objective_for_block(block_node: Node3D) -> Dictionary:
	if block_node == null:
		return {}
	if not block_node.has_method("get_objective_candidate_count") or not block_node.has_method("select_objective_by_index"):
		return {}

	var objective_count: int = int(block_node.call("get_objective_candidate_count"))
	if objective_count <= 0:
		return {}

	var chosen_index: int = rng.randi_range(0, objective_count - 1)
	var selection_value: Variant = block_node.call("select_objective_by_index", chosen_index)
	if selection_value is Dictionary:
		return (selection_value as Dictionary).duplicate(true)
	return {
		"objective_count": objective_count,
		"selected_objective_index": chosen_index,
	}


func _apply_saved_objective_selection_to_block(block_node: Node3D, block_record: Dictionary) -> void:
	if block_node == null:
		return
	if not block_node.has_method("select_objective_by_index"):
		return

	var selection: Dictionary = _dictionary_from_variant(block_record.get("objective_selection", {}))
	if selection.is_empty():
		_select_random_objective_for_block(block_node)
		return

	var selected_name: String = String(selection.get("selected_objective_name", ""))
	if not selected_name.is_empty() and block_node.has_method("select_objective_by_name"):
		block_node.call("select_objective_by_name", selected_name)
		return

	var selected_index: int = int(selection.get("selected_objective_index", 0))
	block_node.call("select_objective_by_index", selected_index)

func _instantiate_block_from_scene(block_scene: PackedScene) -> Node3D:
	if block_scene == null:
		return null

	var node: Node = block_scene.instantiate()
	if not (node is Node3D):
		node.queue_free()
		push_warning("[LevelGenerator] Le bloc n'est pas un Node3D.")
		return null

	return node as Node3D


func _spawn_poi_on_block(block_node: Node3D, poi_scene: PackedScene, poi_rotation_degrees: int) -> Node3D:
	if block_node == null or poi_scene == null:
		return null

	var poi_socket: Node3D = null
	if block_node.has_method("get_poi_socket"):
		var socket_value: Variant = block_node.call("get_poi_socket")
		if socket_value is Node3D:
			poi_socket = socket_value as Node3D
	if poi_socket == null:
		poi_socket = block_node.get_node_or_null("POISocket") as Node3D
	if poi_socket == null:
		push_warning("[LevelGenerator] Bloc sans POISocket : %s" % block_node.name)
		return null

	return _spawn_poi_on_socket(block_node, poi_socket, poi_scene, poi_rotation_degrees, "POI")


func _spawn_secondary_pois_for_block(database, block_node: Node3D, block_slot: int, used_scene_keys: Array[String]) -> void:
	if not spawn_secondary_pois or block_node == null:
		return
	if secondary_poi_spawn_chance <= 0.0:
		return

	var sockets: Array[Node3D] = _get_secondary_poi_sockets_for_block(block_node)
	if sockets.is_empty():
		return

	for socket_index: int in range(sockets.size()):
		var socket: Node3D = sockets[socket_index]
		if not socket.has_method("get_secondary_socket_environment"):
			push_warning("[LevelGenerator] POI secondaire ignoré. Le socket n'a pas SecondaryPOISocket.gd : %s" % socket.name)
			continue
		if socket.has_method("is_secondary_socket_enabled") and not bool(socket.call("is_secondary_socket_enabled")):
			continue

		var final_spawn_chance: float = secondary_poi_spawn_chance
		if socket.has_method("get_socket_spawn_chance"):
			final_spawn_chance *= float(socket.call("get_socket_spawn_chance"))
		final_spawn_chance = clampf(final_spawn_chance, 0.0, 1.0)
		if final_spawn_chance < 1.0 and rng.randf() > final_spawn_chance:
			continue

		var secondary_scene: PackedScene = _pick_secondary_poi_scene_for_socket(block_node, socket, used_scene_keys)
		if secondary_scene == null:
			continue

		var rotation_mode: String = _get_secondary_poi_rotation_mode(secondary_scene, socket)
		var poi_rotation_degrees: int = 0
		if rotation_mode == "random 90":
			poi_rotation_degrees = rng.randi_range(0, 3) * 90

		var poi_node: Node3D = _spawn_poi_on_socket(block_node, socket, secondary_scene, poi_rotation_degrees, "SecondaryPOI", rotation_mode)
		if poi_node == null:
			continue

		var socket_environment: String = _get_secondary_socket_environment(block_node, socket, secondary_scene)
		var placement_type: String = _get_secondary_poi_placement_type(secondary_scene)
		var socket_summary: Dictionary = {}
		if socket.has_method("get_database_summary"):
			var socket_summary_value: Variant = socket.call("get_database_summary")
			if socket_summary_value is Dictionary:
				socket_summary = (socket_summary_value as Dictionary).duplicate(true)

		var extra_data: Dictionary = {
			"secondary_placement_type": placement_type,
			"secondary_rotation_mode": rotation_mode,
			"socket_environment": socket_environment,
			"socket_summary": socket_summary,
		}
		var poi_record: Dictionary = _make_poi_record(poi_node, secondary_scene, block_slot, poi_rotation_degrees, rotation_mode == "random 90", "secondary", socket_index, String(socket.name), extra_data)
		database.secondary_poi_records.append(poi_record)
		_mark_scene_key_as_used(secondary_scene, used_scene_keys)


func _get_secondary_poi_sockets_for_block(block_node: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = []
	if block_node == null:
		return result

	if block_node.has_method("get_secondary_poi_sockets"):
		var socket_value: Variant = block_node.call("get_secondary_poi_sockets")
		if socket_value is Array:
			for item: Variant in socket_value:
				if item is Node3D:
					var socket: Node3D = item as Node3D
					if socket.has_method("get_secondary_socket_environment"):
						result.append(socket)
					else:
						push_warning("[LevelGenerator] Socket secondaire ignoré car il n'a pas SecondaryPOISocket.gd : %s" % socket.name)

	if not result.is_empty():
		return result

	for socket_name: String in ["POISocket_Side1", "POISocket_Side2"]:
		var socket: Node3D = block_node.get_node_or_null(socket_name) as Node3D
		if socket != null:
			if socket.has_method("get_secondary_socket_environment"):
				result.append(socket)
			else:
				push_warning("[LevelGenerator] Socket secondaire ignoré car il n'a pas SecondaryPOISocket.gd : %s" % socket.name)

	return result


func _spawn_poi_on_socket(block_node: Node3D, socket: Node3D, poi_scene: PackedScene, poi_rotation_degrees: int, name_prefix: String, rotation_mode: String = "follow block") -> Node3D:
	if block_node == null or socket == null or poi_scene == null:
		return null

	var poi_node_base: Node = poi_scene.instantiate()
	if not (poi_node_base is Node3D):
		poi_node_base.queue_free()
		return null

	var poi_node: Node3D = poi_node_base as Node3D
	poi_node.name = "%s_%s" % [name_prefix, String(poi_node.name)]
	_get_generated_root().add_child(poi_node)
	poi_node.global_position = socket.global_position

	var base_rotation_y: float = block_node.global_rotation.y
	if rotation_mode == "follow socket":
		base_rotation_y = socket.global_rotation.y

	poi_node.global_rotation = Vector3(0.0, base_rotation_y + deg_to_rad(float(poi_rotation_degrees)), 0.0)
	return poi_node


func _spawn_poi_from_record(poi_record: Dictionary, generated_blocks: Array[Node3D], block_records: Array[Dictionary], use_secondary_socket: bool) -> Node3D:
	var scene_path: String = String(poi_record.get("scene_path", ""))
	var poi_scene: PackedScene = _load_scene(scene_path)
	if poi_scene == null:
		return null

	var block_slot: int = int(poi_record.get("block_slot", -1))
	var block_node: Node3D = _find_generated_block_by_slot(generated_blocks, block_records, block_slot)
	if block_node == null:
		return null

	var rotation_degrees: int = int(poi_record.get("rotation_y_degrees", 0))
	if not use_secondary_socket:
		return _spawn_poi_on_block(block_node, poi_scene, rotation_degrees)

	var socket_index: int = int(poi_record.get("socket_index", -1))
	var socket: Node3D = null
	if block_node.has_method("get_secondary_poi_socket") and socket_index >= 0:
		var socket_value: Variant = block_node.call("get_secondary_poi_socket", socket_index)
		if socket_value is Node3D:
			socket = socket_value as Node3D

	if socket == null:
		var sockets: Array[Node3D] = _get_secondary_poi_sockets_for_block(block_node)
		if socket_index >= 0 and socket_index < sockets.size():
			socket = sockets[socket_index]

	if socket == null:
		return _spawn_poi_at_saved_transform(poi_record, poi_scene, "SecondaryPOI")

	var rotation_mode: String = String(poi_record.get("secondary_rotation_mode", "follow block"))
	return _spawn_poi_on_socket(block_node, socket, poi_scene, rotation_degrees, "SecondaryPOI", rotation_mode)


func _spawn_poi_at_saved_transform(poi_record: Dictionary, poi_scene: PackedScene, name_prefix: String) -> Node3D:
	if poi_scene == null:
		return null

	var poi_node_base: Node = poi_scene.instantiate()
	if not (poi_node_base is Node3D):
		poi_node_base.queue_free()
		return null

	var poi_node: Node3D = poi_node_base as Node3D
	poi_node.name = "%s_%s" % [name_prefix, String(poi_node.name)]
	_get_generated_root().add_child(poi_node)
	poi_node.global_position = _vector3_from_array(poi_record.get("global_position", [0.0, 0.0, 0.0]))
	poi_node.global_rotation = Vector3(0.0, deg_to_rad(float(poi_record.get("global_rotation_y_degrees", poi_record.get("rotation_y_degrees", 0.0)))), 0.0)
	return poi_node


func _spawn_rig_for_database(database, generated_blocks: Array[Node3D]) -> void:
	if generated_blocks.is_empty():
		return

	var block_index: int = rng.randi_range(0, generated_blocks.size() - 1)
	var block_node: Node3D = generated_blocks[block_index]
	var sockets: Array[Node3D] = []
	if block_node.has_method("get_spawn_sockets"):
		var socket_value: Variant = block_node.call("get_spawn_sockets")
		if socket_value is Array:
			for item: Variant in socket_value:
				if item is Node3D:
					sockets.append(item as Node3D)

	if sockets.is_empty():
		return

	var socket_index: int = rng.randi_range(0, sockets.size() - 1)
	var spawn_socket: Node3D = sockets[socket_index]
	var spawn_transform: Transform3D = _make_spawn_rig_transform(spawn_socket, block_node)
	_spawn_rig_at_transform(spawn_transform)

	database.spawn_record = {
		"block_slot": block_index,
		"socket_index": socket_index,
		"global_position": _vector3_to_array(spawn_transform.origin),
		"global_rotation_y_degrees": rad_to_deg(spawn_transform.basis.get_euler().y),
		"rotation_mode": spawn_rig_rotation_mode,
		"rotation_offset_degrees": spawn_rig_rotation_offset_degrees,
		"scene_path": _get_scene_path(spawn_rig_scene),
	}


func _spawn_rig_from_record(spawn_record: Dictionary, generated_blocks: Array[Node3D], block_records: Array[Dictionary]) -> void:
	if spawn_record.is_empty():
		return

	var block_slot: int = int(spawn_record.get("block_slot", -1))
	var socket_index: int = int(spawn_record.get("socket_index", 0))
	var block_node: Node3D = _find_generated_block_by_slot(generated_blocks, block_records, block_slot)
	if block_node != null and block_node.has_method("get_spawn_socket"):
		var socket_value: Variant = block_node.call("get_spawn_socket", socket_index)
		if socket_value is Node3D:
			var spawn_transform: Transform3D = _make_spawn_rig_transform(socket_value as Node3D, block_node)
			_spawn_rig_at_transform(spawn_transform)
			return

	var fallback_position: Vector3 = _vector3_from_array(spawn_record.get("global_position", [0.0, 0.0, 0.0]))
	var fallback_rotation_degrees: float = float(spawn_record.get("global_rotation_y_degrees", 0.0))
	var fallback_transform: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(fallback_rotation_degrees)), fallback_position)
	_spawn_rig_at_transform(fallback_transform)


func _make_spawn_rig_transform(spawn_socket: Node3D, block_node: Node3D) -> Transform3D:
	if spawn_socket == null:
		return Transform3D.IDENTITY

	var y_degrees: float = 0.0
	match spawn_rig_rotation_mode:
		"follow socket":
			y_degrees = rad_to_deg(spawn_socket.global_rotation.y)
		"follow block":
			if block_node != null:
				y_degrees = rad_to_deg(block_node.global_rotation.y)
			else:
				y_degrees = rad_to_deg(spawn_socket.global_rotation.y)
		"ignore rotation":
			y_degrees = 0.0
		_:
			y_degrees = rad_to_deg(spawn_socket.global_rotation.y)
			y_degrees = round(y_degrees / 90.0) * 90.0

	y_degrees += spawn_rig_rotation_offset_degrees
	return Transform3D(Basis(Vector3.UP, deg_to_rad(y_degrees)), spawn_socket.global_position)


func _spawn_rig_at_transform(spawn_transform: Transform3D) -> void:
	_clear_spawn_output_roots()
	if spawn_rig_scene == null:
		push_warning("[LevelGenerator] spawn_rig_scene manquant.")
		return

	var rig_base: Node = spawn_rig_scene.instantiate()
	if not (rig_base is Node3D):
		rig_base.queue_free()
		return

	var rig: Node3D = rig_base as Node3D
	rig.name = "PlayerVehicleSpawnRig"
	_get_generated_root().add_child(rig)
	rig.global_transform = spawn_transform

	_copy_marker_children(rig.get_node_or_null("SpawnPoints"), get_spawn_points_root())
	_copy_marker_children(rig.get_node_or_null("VehicleSpawns"), get_vehicle_spawns_root())


func _copy_marker_children(source_root: Node, destination_root: Node3D) -> void:
	if source_root == null or destination_root == null:
		return

	var index: int = 0
	for child: Node in source_root.get_children():
		if not (child is Node3D):
			continue
		var source_marker: Node3D = child as Node3D
		var marker: Node3D = Node3D.new()
		marker.name = "%s_%02d" % [String(child.name), index]
		destination_root.add_child(marker)
		marker.global_transform = source_marker.global_transform
		index += 1


func _make_block_record(block_node: Node3D, block_scene: PackedScene, slot_index: int, slot_record: Dictionary, rotation_degrees: int, assignment: Dictionary) -> Dictionary:
	var data: Dictionary = {}
	if block_node.has_method("get_database_summary"):
		var summary_value: Variant = block_node.call("get_database_summary")
		if summary_value is Dictionary:
			data = (summary_value as Dictionary).duplicate(true)

	var grid_position: Vector2i = slot_record.get("grid_position", Vector2i.ZERO)
	var slot_position: Vector3 = slot_record.get("world_position", block_node.position)

	data["slot_index"] = slot_index
	data["slot_position"] = _vector3_to_array(slot_position)
	data["grid_position"] = [grid_position.x, grid_position.y]
	data["rotation_y_degrees"] = rotation_degrees
	data["rotation_steps"] = int(assignment.get("rotation_steps", 0))
	data["scene_path"] = _get_scene_path(block_scene)
	var blueprint: Dictionary = assignment.get("blueprint", {})
	data["block_category"] = String(blueprint.get("block_category", "generic"))
	var side_profiles_value: Variant = assignment.get("side_profiles", {})
	if side_profiles_value is Dictionary:
		data["side_profiles_rotated"] = (side_profiles_value as Dictionary).duplicate(true)
	else:
		data["side_profiles_rotated"] = {}
	return data


func _make_poi_record(poi_node: Node3D, poi_scene: PackedScene, block_slot: int, rotation_degrees: int, allow_random_poi_rotation: bool, poi_category: String, socket_index: int, socket_name: String, extra_data: Dictionary) -> Dictionary:
	var data: Dictionary = {}
	if poi_node.has_method("get_database_summary"):
		var summary_value: Variant = poi_node.call("get_database_summary")
		if summary_value is Dictionary:
			data = (summary_value as Dictionary).duplicate(true)

	for key: Variant in extra_data.keys():
		data[String(key)] = extra_data[key]

	data["block_slot"] = block_slot
	data["global_position"] = _vector3_to_array(poi_node.global_position)
	data["global_rotation_y_degrees"] = rad_to_deg(poi_node.global_rotation.y)
	data["rotation_y_degrees"] = rotation_degrees
	data["allow_random_poi_rotation"] = allow_random_poi_rotation
	data["poi_category"] = poi_category
	data["socket_index"] = socket_index
	data["socket_name"] = socket_name
	data["scene_path"] = _get_scene_path(poi_scene)
	return data


func _get_block_record_connection_records(block_records: Array[Dictionary]) -> Array[Dictionary]:
	var fake_assignments: Array[Dictionary] = []
	for block_record: Dictionary in block_records:
		var grid_array: Variant = block_record.get("grid_position", [0, 0])
		var grid_position: Vector2i = Vector2i.ZERO
		if grid_array is Array:
			var grid_values: Array = grid_array as Array
			if grid_values.size() >= 2:
				grid_position = Vector2i(int(grid_values[0]), int(grid_values[1]))
		var side_profiles: Dictionary = {}
		var side_profiles_value: Variant = block_record.get("side_profiles_rotated", {})
		if side_profiles_value is Dictionary:
			side_profiles = (side_profiles_value as Dictionary).duplicate(true)
		fake_assignments.append({
			"slot_record": {
				"slot_index": int(block_record.get("slot_index", -1)),
				"grid_position": grid_position,
			},
			"side_profiles": side_profiles,
		})
	return _get_assignment_connection_records(fake_assignments)


func _get_block_record_connection_errors(block_records: Array[Dictionary]) -> Array[Dictionary]:
	var fake_assignments: Array[Dictionary] = []
	for block_record: Dictionary in block_records:
		var grid_array: Variant = block_record.get("grid_position", [0, 0])
		var grid_position: Vector2i = Vector2i.ZERO
		if grid_array is Array:
			var grid_values: Array = grid_array as Array
			if grid_values.size() >= 2:
				grid_position = Vector2i(int(grid_values[0]), int(grid_values[1]))
		var side_profiles: Dictionary = {}
		var side_profiles_value: Variant = block_record.get("side_profiles_rotated", {})
		if side_profiles_value is Dictionary:
			side_profiles = (side_profiles_value as Dictionary).duplicate(true)
		fake_assignments.append({
			"slot_record": {
				"slot_index": int(block_record.get("slot_index", -1)),
				"grid_position": grid_position,
			},
			"side_profiles": side_profiles,
		})
	return _get_assignment_connection_errors(fake_assignments)


func _find_generated_block_by_slot(generated_blocks: Array[Node3D], block_records: Array[Dictionary], slot_index: int) -> Node3D:
	for i: int in range(block_records.size()):
		var record: Dictionary = block_records[i]
		if int(record.get("slot_index", -999)) == slot_index and i < generated_blocks.size():
			return generated_blocks[i]
	return null


func _clear_current_level() -> void:
	_clear_children(_get_generated_root())
	_clear_spawn_output_roots()


func _clear_spawn_output_roots() -> void:
	_clear_children(get_spawn_points_root())
	_clear_children(get_vehicle_spawns_root())


func _clear_children(root: Node) -> void:
	if root == null:
		return
	for child: Node in root.get_children():
		root.remove_child(child)
		child.queue_free()


func _get_generated_root() -> Node3D:
	return _get_or_create_root(generated_root_path, "GeneratedLevel")


func _get_or_create_root(root_path: NodePath, fallback_name: String) -> Node3D:
	var root: Node3D = get_node_or_null(root_path) as Node3D
	if root != null:
		return root

	if get_parent() != null:
		root = get_parent().get_node_or_null(fallback_name) as Node3D
		if root != null:
			return root

	root = Node3D.new()
	root.name = fallback_name
	if get_parent() != null:
		get_parent().add_child(root)
	else:
		add_child(root)
	return root


func _load_scene(scene_path: String) -> PackedScene:
	if scene_path.is_empty():
		return null
	if not ResourceLoader.exists(scene_path):
		push_warning("[LevelGenerator] Scène introuvable : %s" % scene_path)
		return null
	return load(scene_path) as PackedScene


func _get_scene_path(scene: PackedScene) -> String:
	if scene == null:
		return ""
	return scene.resource_path


func _vector3_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _vector3_from_array(value: Variant) -> Vector3:
	if value is Array:
		var array_value: Array = value as Array
		if array_value.size() >= 3:
			return Vector3(float(array_value[0]), float(array_value[1]), float(array_value[2]))
	return Vector3.ZERO


func _dictionary_from_variant(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _dictionary_array_from_variant(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item: Variant in value:
			if item is Dictionary:
				result.append((item as Dictionary).duplicate(true))
	return result


func _read_bool_property(target: Object, property_name: String, fallback: bool) -> bool:
	if target == null:
		return fallback
	for property_info: Dictionary in target.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return bool(target.get(property_name))
	return fallback


func _read_string_property(target: Object, property_name: String, fallback: String) -> String:
	if target == null:
		return fallback
	for property_info: Dictionary in target.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return String(target.get(property_name))
	return fallback
