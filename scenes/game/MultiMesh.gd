@tool
extends Node3D

@export_group("Editor Buttons")
@export_tool_button("Setup Structure", "Callable") var setup_structure_button: Callable = setup_structure
@export_tool_button("Generate Trees", "Callable") var generate_trees_button: Callable = generate_trees
@export_tool_button("Clear Trees", "Callable") var clear_trees_button: Callable = clear_trees

@export_group("Tree Mesh")
@export var tree_mesh: Mesh
@export var material_override: Material
@export var multimesh_node_name: String = "Trees_MultiMesh"

@export_group("Forest Settings")
@export_range(1, 10000, 1) var tree_count: int = 200
@export var forest_size: Vector2 = Vector2(60.0, 60.0)
@export var ground_y: float = 0.0

@export_group("Random")
@export var use_position_as_seed: bool = true
@export var manual_seed: int = 12345
@export var seed_salt: String = "forest"
@export var position_snap: float = 1.0

@export_group("Scale")
@export var base_scale: float = 1.0
@export_range(0.0, 1.0, 0.01) var size_variation: float = 0.10

@export_group("Rotation")
@export var randomize_y_rotation: bool = true
@export var min_y_rotation_degrees: float = 0.0
@export var max_y_rotation_degrees: float = 360.0

@export_group("Culling")
@export var custom_aabb_height: float = 40.0
@export var custom_aabb_y_offset: float = -5.0

@export_group("Runtime")
@export var regenerate_on_ready_in_game: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if regenerate_on_ready_in_game:
		generate_trees()


func setup_structure() -> void:
	var tree_node: MultiMeshInstance3D = _get_or_create_multimesh_node()
	var new_multimesh: MultiMesh = MultiMesh.new()

	new_multimesh.resource_local_to_scene = true
	new_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	new_multimesh.use_colors = false
	new_multimesh.use_custom_data = false
	new_multimesh.visible_instance_count = -1
	new_multimesh.instance_count = 0

	if tree_mesh != null:
		new_multimesh.mesh = tree_mesh

	tree_node.multimesh = new_multimesh

	if material_override != null:
		tree_node.material_override = material_override

	_update_custom_aabb(new_multimesh)
	_mark_scene_unsaved()


func generate_trees() -> void:
	var tree_node: MultiMeshInstance3D = _get_or_create_multimesh_node()

	if tree_node.multimesh == null:
		setup_structure()

	if tree_node.multimesh == null:
		push_warning("Impossible de créer le MultiMesh.")
		return

	var target_mesh: Mesh = tree_mesh

	if target_mesh == null and tree_node.multimesh.mesh != null:
		target_mesh = tree_node.multimesh.mesh

	if target_mesh == null:
		push_warning("Assigne un Tree Mesh avant de générer la forêt.")
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()

	if use_position_as_seed:
		rng.seed = _get_seed_from_world_position()
	else:
		rng.seed = manual_seed

	var target_multimesh: MultiMesh = tree_node.multimesh
	target_multimesh.resource_local_to_scene = true
	target_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	target_multimesh.mesh = target_mesh
	target_multimesh.visible_instance_count = -1
	target_multimesh.instance_count = tree_count

	var safe_variation: float = clamp(size_variation, 0.0, 0.99)
	var min_scale: float = base_scale * (1.0 - safe_variation)
	var max_scale: float = base_scale * (1.0 + safe_variation)

	for i in range(tree_count):
		var random_x: float = rng.randf_range(-forest_size.x * 0.5, forest_size.x * 0.5)
		var random_z: float = rng.randf_range(-forest_size.y * 0.5, forest_size.y * 0.5)

		var position: Vector3 = Vector3(random_x, ground_y, random_z)

		var rotation_y_degrees: float = 0.0

		if randomize_y_rotation:
			rotation_y_degrees = rng.randf_range(min_y_rotation_degrees, max_y_rotation_degrees)

		var rotation_y_radians: float = deg_to_rad(rotation_y_degrees)
		var random_scale: float = rng.randf_range(min_scale, max_scale)

		var basis: Basis = Basis(Vector3.UP, rotation_y_radians)
		basis = basis.scaled(Vector3.ONE * random_scale)

		var tree_transform: Transform3D = Transform3D(basis, position)

		target_multimesh.set_instance_transform(i, tree_transform)

	_update_custom_aabb(target_multimesh)
	_mark_scene_unsaved()


func clear_trees() -> void:
	var tree_node: MultiMeshInstance3D = _get_multimesh_node()

	if tree_node == null:
		return

	if tree_node.multimesh == null:
		return

	tree_node.multimesh.instance_count = 0
	tree_node.multimesh.visible_instance_count = -1

	_mark_scene_unsaved()


func _get_multimesh_node() -> MultiMeshInstance3D:
	var existing_node: Node = get_node_or_null(multimesh_node_name)

	if existing_node == null:
		return null

	if existing_node is MultiMeshInstance3D:
		return existing_node as MultiMeshInstance3D

	push_warning("Un node existe déjà avec le nom '%s', mais ce n'est pas un MultiMeshInstance3D." % multimesh_node_name)
	return null


func _get_or_create_multimesh_node() -> MultiMeshInstance3D:
	var existing_multimesh_node: MultiMeshInstance3D = _get_multimesh_node()

	if existing_multimesh_node != null:
		return existing_multimesh_node

	var new_node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	new_node.name = multimesh_node_name
	new_node.position = Vector3.ZERO
	new_node.rotation = Vector3.ZERO
	new_node.scale = Vector3.ONE

	add_child(new_node)

	if Engine.is_editor_hint():
		var edited_scene_root: Node = get_tree().edited_scene_root

		if edited_scene_root != null:
			new_node.owner = edited_scene_root

	return new_node


func _update_custom_aabb(target_multimesh: MultiMesh) -> void:
	var aabb_position: Vector3 = Vector3(
		-forest_size.x * 0.5,
		ground_y + custom_aabb_y_offset,
		-forest_size.y * 0.5
	)

	var aabb_size: Vector3 = Vector3(
		forest_size.x,
		custom_aabb_height,
		forest_size.y
	)

	target_multimesh.custom_aabb = AABB(aabb_position, aabb_size)


func _get_seed_from_world_position() -> int:
	var snap: float = max(position_snap, 0.001)

	var snapped_x: int = int(round(global_position.x / snap))
	var snapped_y: int = int(round(global_position.y / snap))
	var snapped_z: int = int(round(global_position.z / snap))

	var seed_text: String = "%d|%d|%d|%s" % [
		snapped_x,
		snapped_y,
		snapped_z,
		seed_salt
	]

	return _hash_string_to_seed(seed_text)


func _hash_string_to_seed(text: String) -> int:
	var seed_value: int = 5381

	for i in range(text.length()):
		seed_value = ((seed_value << 5) + seed_value) + text.unicode_at(i)
		seed_value = seed_value & 0x7FFFFFFFFFFFFFFF

	return seed_value


func _mark_scene_unsaved() -> void:
	if Engine.is_editor_hint():
		EditorInterface.mark_scene_as_unsaved()
