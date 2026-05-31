extends Node3D

# Script racine des points d'intérêt.
# Le volume utile doit rester dans un carré de 50 x 50 unités.

@export var poi_id: String = "poi"
@export var poi_type: String = "generic"
@export var poi_size: float = 50.0
@export var poi_tags: PackedStringArray = PackedStringArray(["land"])
@export var requires_water_near_poi: bool = false
@export_enum("none", "any_water", "river", "sea") var required_water_type: String = "none"

@export_group("Objective dependency")
@export var poi_objective_scene: PackedScene


func can_spawn_on_block(block_node: Node) -> bool:
	if block_node == null:
		return false

	var block_has_water: bool = _read_bool_property(block_node, "has_water_near_poi", false)
	var block_poi_water_type: String = _read_string_property(block_node, "poi_water_type", "none")

	if required_water_type != "none":
		if required_water_type == "any_water" and not block_has_water:
			return false
		elif required_water_type == "river" and block_poi_water_type != "river":
			return false
		elif required_water_type == "sea" and block_poi_water_type != "sea":
			return false
	elif requires_water_near_poi and not block_has_water:
		return false

	var block_tags: PackedStringArray = _read_string_array_property(block_node, "compatible_poi_tags")
	if block_tags.is_empty():
		return true

	for poi_tag: String in poi_tags:
		for block_tag: String in block_tags:
			if poi_tag == block_tag:
				return true

	return false


func get_database_summary() -> Dictionary:
	return {
		"poi_id": poi_id,
		"poi_type": poi_type,
		"poi_size": poi_size,
		"poi_tags": Array(poi_tags),
		"requires_water_near_poi": requires_water_near_poi,
		"required_water_type": required_water_type,
		"has_objective_secondary_poi": poi_objective_scene != null,
		"objective_secondary_poi_scene_path": _get_packed_scene_path(poi_objective_scene),
	}


func get_objective_secondary_poi_scene() -> PackedScene:
	return poi_objective_scene


func has_objective_secondary_poi_scene() -> bool:
	return poi_objective_scene != null


func _get_packed_scene_path(scene: PackedScene) -> String:
	if scene == null:
		return ""
	return scene.resource_path


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


func _read_string_array_property(target: Object, property_name: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if target == null:
		return result

	for property_info: Dictionary in target.get_property_list():
		if String(property_info.get("name", "")) != property_name:
			continue

		var value: Variant = target.get(property_name)
		if value is PackedStringArray:
			return value as PackedStringArray
		if value is Array:
			for item: Variant in value:
				result.append(String(item))
		return result

	return result
