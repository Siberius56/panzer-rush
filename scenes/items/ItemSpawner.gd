extends Node3D
class_name ItemSpawner

@export_group("Spawn")
@export var spawn_on_ready: bool = true
@export_range(0, 128, 1) var spawn_count: int = 1
@export_enum("munition", "arme", "gravity_gun", "repair_tool", "bomb", "encryption_remote", "argent", "custom") var item_type: String = "arme"
@export var preferred_item_ids: Array[String] = []
@export var spawn_as_sibling: bool = true
@export var spawn_on_all_peers: bool = true
@export var deterministic_seed: int = 0
@export_range(0.0, 5.0, 0.01) var stack_jitter_radius: float = 0.12
@export var random_y_rotation: bool = true
@export var debug_print_spawns: bool = false

@export_group("World Weapon")
@export var world_weapon_scene: PackedScene

@export_group("Weapon Data Source Scenes")
@export var pistol_weapon_scene: PackedScene
@export var smg_weapon_scene: PackedScene
@export var rifle_weapon_scene: PackedScene
@export var shotgun_weapon_scene: PackedScene
@export var gravity_gun_scene: PackedScene
@export var repair_tool_scene: PackedScene
@export var bomb_scene: PackedScene
@export var encryption_remote_scene: PackedScene
@export var extra_weapon_items: Array[ItemSpawnEntry] = []

@export_group("Ammo Scenes")
@export var ammo_9mm_scene: PackedScene
@export var ammo_rifle_scene: PackedScene
@export var ammo_shotgun_scene: PackedScene
@export var ammo_energy_scene: PackedScene
@export var extra_ammo_items: Array[ItemSpawnEntry] = []

@export_group("Other Scenes")
@export var money_pick_scene: PackedScene
@export var custom_items: Array[ItemSpawnEntry] = []

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _spawned_nodes: Array[Node] = []

func _ready() -> void:
	if spawn_on_ready:
		_spawn_items_after_first_frame()

func _spawn_items_after_first_frame() -> void:
	await get_tree().process_frame

	if not is_inside_tree():
		return

	spawn_items()

func spawn_items() -> void:
	if spawn_count <= 0:
		return

	if not spawn_on_all_peers and multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	var markers: Array[Marker3D] = _get_spawn_markers()
	if markers.is_empty():
		push_warning("ItemSpawner has no Marker3D children: %s" % str(get_path()))
		return

	_setup_rng()

	var marker_sequence: Array[Marker3D] = _build_marker_sequence(markers, spawn_count)
	for spawn_index: int in range(marker_sequence.size()):
		var marker: Marker3D = marker_sequence[spawn_index]
		var spawn_transform: Transform3D = _get_spawn_transform(marker, spawn_index >= markers.size())
		_spawn_one_item(spawn_transform)

func clear_spawned_items() -> void:
	for node: Node in _spawned_nodes:
		if is_instance_valid(node):
			node.queue_free()

	_spawned_nodes.clear()

func _spawn_one_item(spawn_transform: Transform3D) -> void:
	match item_type:
		"arme":
			_spawn_random_entry(spawn_transform, _get_weapon_entries(), true, "arme", "weapon", true)
		"gravity_gun":
			_spawn_world_weapon_from_source_scene(spawn_transform, gravity_gun_scene, "gravity_gun")
		"repair_tool":
			_spawn_world_weapon_from_source_scene(spawn_transform, repair_tool_scene, "repair_tool")
		"bomb":
			_spawn_world_weapon_from_source_scene(spawn_transform, bomb_scene, "bomb")
		"encryption_remote":
			_spawn_world_weapon_from_source_scene(spawn_transform, encryption_remote_scene, "encryption_remote")
		"munition":
			_spawn_random_entry(spawn_transform, _get_ammo_entries(), true, "munition", "ammo", false)
		"argent":
			_spawn_scene(spawn_transform, money_pick_scene, "moneyPick")
		"custom":
			_spawn_random_entry(spawn_transform, custom_items, true, "custom", "custom", false)
		_:
			push_warning("Unknown item_type on ItemSpawner: %s" % item_type)

func _get_weapon_entries() -> Array[ItemSpawnEntry]:
	var entries: Array[ItemSpawnEntry] = []
	_add_entry(entries, "pistol", pistol_weapon_scene, 1, ["pistol"])
	_add_entry(entries, "smg", smg_weapon_scene, 1, ["smg", "machinegun", "machine_gun"])
	_add_entry(entries, "rifle", rifle_weapon_scene, 1, ["rifle"])
	_add_entry(entries, "shotgun", shotgun_weapon_scene, 1, ["shotgun"])

	for entry: ItemSpawnEntry in extra_weapon_items:
		if entry != null:
			entries.append(entry)

	return entries

func _get_ammo_entries() -> Array[ItemSpawnEntry]:
	var entries: Array[ItemSpawnEntry] = []
	_add_entry(entries, "9mm", ammo_9mm_scene, 1, ["9mm"])
	_add_entry(entries, "rifle", ammo_rifle_scene, 1, ["rifle"])
	_add_entry(entries, "shotgun", ammo_shotgun_scene, 1, ["shotgun"])
	_add_entry(entries, "energy", ammo_energy_scene, 1, ["energy"])

	for entry: ItemSpawnEntry in extra_ammo_items:
		if entry != null:
			entries.append(entry)

	return entries

func _add_entry(entries: Array[ItemSpawnEntry], item_id: String, scene: PackedScene, weight: int, tags: Array[String]) -> void:
	if scene == null:
		return

	var entry: ItemSpawnEntry = ItemSpawnEntry.new()
	entry.item_id = item_id
	entry.scene = scene
	entry.weight = max(weight, 1)
	entry.tags = tags
	entries.append(entry)

func _spawn_random_entry(
	spawn_transform: Transform3D,
	entries: Array[ItemSpawnEntry],
	use_preferences: bool,
	label: String,
	normalize_context: String,
	spawn_as_world_weapon: bool
) -> void:
	var candidates: Array[ItemSpawnEntry] = []

	for entry: ItemSpawnEntry in entries:
		if entry == null or entry.scene == null:
			continue

		if use_preferences and not _entry_matches_preferences(entry, normalize_context):
			continue

		candidates.append(entry)

	if candidates.is_empty():
		if use_preferences and not preferred_item_ids.is_empty():
			push_warning("ItemSpawner found no %s matching preferred_item_ids: %s" % [label, str(preferred_item_ids)])
		else:
			push_warning("ItemSpawner has no configured scene for %s." % label)
		return

	var picked_entry: ItemSpawnEntry = _pick_weighted_entry(candidates)
	if spawn_as_world_weapon:
		_spawn_world_weapon_from_source_scene(spawn_transform, picked_entry.scene, picked_entry.item_id)
	else:
		_spawn_scene(spawn_transform, picked_entry.scene, picked_entry.item_id)

func _spawn_world_weapon_from_source_scene(spawn_transform: Transform3D, source_weapon_scene: PackedScene, debug_name: String) -> void:
	if source_weapon_scene == null:
		push_warning("ItemSpawner has no weapon source scene assigned for: %s" % debug_name)
		return

	if world_weapon_scene == null:
		push_warning("ItemSpawner needs world_weapon_scene assigned to spawn weapon: %s" % debug_name)
		return

	var weapon_data: Dictionary = _read_weapon_data_from_scene(source_weapon_scene, debug_name)
	if weapon_data.is_empty():
		return

	var world_weapon: Node = world_weapon_scene.instantiate()
	if world_weapon == null:
		push_warning("ItemSpawner could not instantiate WorldWeapon3D for: %s" % debug_name)
		return

	if _object_has_property(world_weapon, "editor_spawn_on_ready"):
		world_weapon.set("editor_spawn_on_ready", false)

	_add_spawned_node(world_weapon, spawn_transform, weapon_data)

	if debug_print_spawns:
		print(
			"ItemSpawner spawned WorldWeapon3D: ",
			weapon_data.get("weapon_id", debug_name),
			" at ",
			spawn_transform.origin
		)

func _read_weapon_data_from_scene(source_weapon_scene: PackedScene, fallback_id: String) -> Dictionary:
	var temporary_instance: Node = source_weapon_scene.instantiate()
	if temporary_instance == null:
		push_warning("ItemSpawner could not read weapon data from scene: %s" % fallback_id)
		return {}

	var weapon_id: String = str(_get_object_property(temporary_instance, "weapon_id", fallback_id)).strip_edges()
	if weapon_id.is_empty():
		weapon_id = fallback_id

	var magazine_size: int = int(_get_object_property(temporary_instance, "magazine_size", 0))
	var reserve_ammo: int = int(_get_object_property(temporary_instance, "reserve_ammo", 0))

	if magazine_size < 0:
		magazine_size = 0

	if reserve_ammo < 0:
		reserve_ammo = 0

	var weapon_behavior: String = str(_get_object_property(temporary_instance, "weapon_behavior", ""))
	var weapon_label: String = str(_get_object_property(temporary_instance, "weapon_label", weapon_id))

	temporary_instance.free()

	return {
		"weapon_id": weapon_id,
		"ammo_in_magazine": magazine_size,
		"reserve_ammo": reserve_ammo,
		"weapon_scene": source_weapon_scene,
		"weapon_behavior": weapon_behavior,
		"weapon_label": weapon_label,
		"objective_origin_transform": Transform3D.IDENTITY,
	}

func _spawn_scene(spawn_transform: Transform3D, scene: PackedScene, debug_name: String) -> void:
	if scene == null:
		push_warning("ItemSpawner has no scene assigned for: %s" % debug_name)
		return

	var instance: Node = scene.instantiate()
	_add_spawned_node(instance, spawn_transform)

	if debug_print_spawns:
		print("ItemSpawner spawned: ", debug_name, " at ", spawn_transform.origin)

func _add_spawned_node(instance: Node, spawn_transform: Transform3D, world_weapon_setup: Dictionary = {}) -> void:
	if instance == null:
		return

	var target_parent: Node = _get_spawn_parent()
	if target_parent == null:
		push_warning("ItemSpawner has no valid parent for spawned item: %s" % str(instance.name))
		return

	target_parent.add_child.call_deferred(instance)
	call_deferred("_finish_spawned_node_setup", instance, spawn_transform, world_weapon_setup)

func _finish_spawned_node_setup(instance: Node, spawn_transform: Transform3D, world_weapon_setup: Dictionary = {}) -> void:
	if instance == null or not is_instance_valid(instance):
		return

	if not instance.is_inside_tree():
		await get_tree().process_frame

	if instance == null or not is_instance_valid(instance):
		return

	var node_3d: Node3D = instance as Node3D
	if node_3d != null:
		node_3d.global_transform = spawn_transform
	else:
		push_warning("Spawned item is not a Node3D: %s" % str(instance.name))

	if not world_weapon_setup.is_empty():
		world_weapon_setup["objective_origin_transform"] = spawn_transform
		if instance.has_method("setup_from_state"):
			instance.call(
				"setup_from_state",
				str(world_weapon_setup.get("weapon_id", "")),
				int(world_weapon_setup.get("ammo_in_magazine", 0)),
				int(world_weapon_setup.get("reserve_ammo", 0)),
				world_weapon_setup
			)
		else:
			push_warning("Spawned world weapon has no setup_from_state() method: %s" % str(instance.name))

	var rigid_body: RigidBody3D = instance as RigidBody3D
	if rigid_body != null:
		rigid_body.linear_velocity = Vector3.ZERO
		rigid_body.angular_velocity = Vector3.ZERO
		rigid_body.sleeping = false

	_spawned_nodes.append(instance)

func _entry_matches_preferences(entry: ItemSpawnEntry, normalize_context: String) -> bool:
	if preferred_item_ids.is_empty():
		return true

	var entry_ids: Array[String] = []
	entry_ids.append(_normalize_item_id(entry.item_id, normalize_context))

	for tag: String in entry.tags:
		entry_ids.append(_normalize_item_id(tag, normalize_context))

	for raw_preference: String in preferred_item_ids:
		var preference: String = _normalize_item_id(raw_preference, normalize_context)
		if preference.is_empty():
			continue

		if entry_ids.has(preference):
			return true

	return false

func _normalize_item_id(raw_id: String, context: String) -> String:
	var id: String = raw_id.strip_edges().to_lower()
	id = id.replace(" ", "_")
	id = id.replace("-", "_")
	id = id.replace("ammo_", "")
	id = id.replace("_ammo", "")

	if id == "9_mm" or id == "nine_mm":
		id = "9mm"

	if id == "energie" or id == "énergie":
		id = "energy"

	if context == "weapon":
		if id == "machinegun" or id == "machine_gun" or id == "submachinegun":
			return "smg"

	return id

func _pick_weighted_entry(entries: Array[ItemSpawnEntry]) -> ItemSpawnEntry:
	var total_weight: int = 0
	for entry: ItemSpawnEntry in entries:
		total_weight += max(entry.weight, 1)

	var roll: int = _rng.randi_range(1, total_weight)
	var cursor: int = 0

	for entry: ItemSpawnEntry in entries:
		cursor += max(entry.weight, 1)
		if roll <= cursor:
			return entry

	return entries[entries.size() - 1]

func _get_spawn_markers() -> Array[Marker3D]:
	var markers: Array[Marker3D] = []
	_collect_markers_recursive(self, markers)
	return markers

func _collect_markers_recursive(node: Node, markers: Array[Marker3D]) -> void:
	for child: Node in node.get_children():
		var marker: Marker3D = child as Marker3D
		if marker != null:
			markers.append(marker)
		else:
			_collect_markers_recursive(child, markers)

func _build_marker_sequence(markers: Array[Marker3D], count: int) -> Array[Marker3D]:
	var sequence: Array[Marker3D] = []
	var pool: Array[Marker3D] = markers.duplicate()

	while sequence.size() < count:
		if pool.is_empty():
			pool = markers.duplicate()

		var index: int = _rng.randi_range(0, pool.size() - 1)
		sequence.append(pool[index])
		pool.remove_at(index)

	return sequence

func _get_spawn_transform(marker: Marker3D, allow_jitter: bool) -> Transform3D:
	var spawn_transform: Transform3D = marker.global_transform

	if allow_jitter and stack_jitter_radius > 0.0:
		var angle: float = _rng.randf_range(0.0, TAU)
		var distance: float = _rng.randf_range(0.0, stack_jitter_radius)
		spawn_transform.origin += Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)

	if random_y_rotation:
		spawn_transform.basis = spawn_transform.basis.rotated(Vector3.UP, _rng.randf_range(0.0, TAU))

	return spawn_transform

func _get_spawn_parent() -> Node:
	if spawn_as_sibling and get_parent() != null:
		return get_parent()

	return self

func _setup_rng() -> void:
	if deterministic_seed != 0:
		_rng.seed = deterministic_seed
		return

	_rng.randomize()

func _object_has_property(object: Object, property_name: String) -> bool:
	if object == null:
		return false

	var property_list: Array = object.get_property_list()
	for property_info: Dictionary in property_list:
		if String(property_info.get("name", "")) == property_name:
			return true

	return false

func _get_object_property(object: Object, property_name: String, fallback_value: Variant) -> Variant:
	if not _object_has_property(object, property_name):
		return fallback_value

	return object.get(property_name)
