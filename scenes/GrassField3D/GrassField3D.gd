@tool
extends Node3D
class_name GrassField3D

const GRASS_NODE_NAME: String = "GrassMultiMesh"
const DEFAULT_SHADER_PATH: String = "res://GrassField3D/GrassBladeInteractive.gdshader"
const MAX_INTERACTORS: int = 8

const BLADE_SINGLE_PLANE: int = 0
const BLADE_CROSS_PLANES: int = 1

@export_category("Editor Buttons")
@export_tool_button("Setup / Regenerate Grass") var setup_grass_button: Callable = setup_grass
@export_tool_button("Clear Grass") var clear_grass_button: Callable = clear_grass
@export_tool_button("Refresh Material Params") var refresh_material_button: Callable = refresh_material_params
@export_tool_button("Create Exclusion Box") var create_exclusion_box_button: Callable = create_exclusion_box

@export_category("Generation")
@export var auto_generate_on_ready: bool = false
@export var update_in_editor: bool = true
@export var zone_size: Vector2 = Vector2(40.0, 40.0)
@export_range(0, 200000, 1) var blade_count: int = 3500
@export var generation_seed: int = 12345
@export var randomize_seed_on_generate: bool = false
@export_enum("Single Plane", "Cross Planes") var blade_mesh_mode: int = BLADE_CROSS_PLANES

@export_category("Blade Shape")
@export_range(0.02, 2.0, 0.01) var blade_width_min: float = 0.18
@export_range(0.02, 2.0, 0.01) var blade_width_max: float = 0.34
@export_range(0.05, 4.0, 0.01) var blade_height_min: float = 0.55
@export_range(0.05, 4.0, 0.01) var blade_height_max: float = 1.15
@export_range(0.0, 1.0, 0.01) var position_jitter: float = 1.0

@export_category("Ground Placement")
@export var ground_y: float = 0.0
@export var use_ground_raycast: bool = false
@export var ground_collision_mask: int = 1
@export_range(1.0, 500.0, 1.0) var raycast_height: float = 80.0
@export_range(1.0, 500.0, 1.0) var raycast_depth: float = 120.0

@export_category("Exclusion")
@export var use_exclusion_volumes: bool = true
@export var exclusion_group_name: StringName = &"grass_exclusion"
@export var use_exclusion_name_detection: bool = true
@export var exclusion_name_prefix: String = "GrassExclusion"
@export var default_exclusion_box_size: Vector3 = Vector3(8.0, 4.0, 20.0)
@export_range(1, 32, 1) var max_spawn_attempt_multiplier: int = 8

@export_category("Material")
@export var grass_shader: Shader
@export var generated_material: ShaderMaterial
@export var bottom_color: Color = Color(0.12, 0.30, 0.08, 1.0)
@export var top_color: Color = Color(0.46, 0.72, 0.22, 1.0)

@export_category("Wind")
@export_range(0.0, 2.0, 0.01) var wind_strength: float = 0.12
@export_range(0.0, 10.0, 0.01) var wind_speed: float = 1.25
@export_range(0.0, 10.0, 0.01) var wind_frequency: float = 1.8
@export var wind_direction: Vector2 = Vector2(1.0, 0.35)

@export_category("Interaction")
@export var player_group: StringName = &"grass_player"
@export var vehicle_group: StringName = &"grass_vehicle"
@export_range(0.1, 20.0, 0.1) var player_radius: float = 1.35
@export_range(0.0, 3.0, 0.01) var player_bend_strength: float = 0.48
@export_range(0.1, 30.0, 0.1) var vehicle_radius: float = 3.25
@export_range(0.0, 5.0, 0.01) var vehicle_bend_strength: float = 1.15
@export_range(0.0, 2.0, 0.01) var vertical_push: float = 0.35
@export_range(0.0, 3.0, 0.01) var bend_response: float = 1.0

func _ready() -> void:
	set_process(true)

	if not Engine.is_editor_hint() and auto_generate_on_ready:
		setup_grass()
	else:
		refresh_material_params()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and not update_in_editor:
		return

	_update_interactors()
	_update_wind_and_color_uniforms()

func setup_grass() -> void:
	if randomize_seed_on_generate:
		var seed_random: RandomNumberGenerator = RandomNumberGenerator.new()
		seed_random.randomize()
		generation_seed = seed_random.randi()

	var grass_instance: MultiMeshInstance3D = _get_or_create_grass_instance()
	var grass_mesh: ArrayMesh = _create_grass_mesh()
	var material: ShaderMaterial = _get_or_create_material()

	var new_multimesh: MultiMesh = MultiMesh.new()
	new_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	new_multimesh.use_custom_data = true
	new_multimesh.mesh = grass_mesh
	new_multimesh.instance_count = blade_count
	new_multimesh.visible_instance_count = 0

	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = generation_seed

	var space_state: PhysicsDirectSpaceState3D = null
	if use_ground_raycast and is_inside_tree() and get_world_3d() != null:
		space_state = get_world_3d().direct_space_state

	var exclusion_nodes: Array[Node] = _get_exclusion_candidate_nodes()

	var placed_count: int = 0
	var attempts: int = 0
	var max_attempts: int = max(blade_count, blade_count * max_spawn_attempt_multiplier)

	while placed_count < blade_count and attempts < max_attempts:
		attempts += 1

		var local_position: Vector3 = _get_random_local_position(random, space_state)
		var world_position: Vector3 = global_transform * local_position

		if _is_world_position_excluded(world_position, exclusion_nodes):
			continue

		var rotation_y: float = random.randf_range(0.0, TAU)
		var blade_width: float = random.randf_range(blade_width_min, blade_width_max)
		var blade_height: float = random.randf_range(blade_height_min, blade_height_max)

		var blade_basis: Basis = Basis.IDENTITY
		blade_basis = blade_basis.rotated(Vector3.UP, rotation_y)
		blade_basis = blade_basis.scaled(Vector3(blade_width, blade_height, blade_width))

		var blade_transform: Transform3D = Transform3D(blade_basis, local_position)
		new_multimesh.set_instance_transform(placed_count, blade_transform)

		var phase: float = random.randf()
		var color_variation: float = random.randf()
		var bend_variation: float = random.randf()
		new_multimesh.set_instance_custom_data(placed_count, Color(phase, color_variation, bend_variation, 1.0))

		placed_count += 1

	new_multimesh.visible_instance_count = placed_count

	var margin: float = max(vehicle_radius, player_radius) + max(blade_height_max, 1.0) + wind_strength + 2.0
	new_multimesh.custom_aabb = AABB(
		Vector3(-zone_size.x * 0.5 - margin, -margin, -zone_size.y * 0.5 - margin),
		Vector3(zone_size.x + margin * 2.0, blade_height_max + margin * 2.0, zone_size.y + margin * 2.0)
	)

	grass_instance.multimesh = new_multimesh
	grass_instance.material_override = material
	grass_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	refresh_material_params()
	_update_interactors()

	if Engine.is_editor_hint():
		print("[GrassField3D] Grass generated: %s/%s blades in area %s." % [placed_count, blade_count, zone_size])


func create_exclusion_box() -> void:
	var exclusion_area: Area3D = Area3D.new()
	exclusion_area.name = "GrassExclusion_%02d" % _get_next_exclusion_index()
	add_child(exclusion_area)

	var editor_owner: Node = _get_editor_owner_node()
	if editor_owner != null:
		exclusion_area.owner = editor_owner

	if exclusion_group_name != StringName():
		exclusion_area.add_to_group(exclusion_group_name, true)

	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	exclusion_area.add_child(collision_shape)

	if editor_owner != null:
		collision_shape.owner = editor_owner

	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = default_exclusion_box_size
	collision_shape.shape = box_shape

	if Engine.is_editor_hint():
		print("[GrassField3D] Exclusion box created: %s. Move and scale its CollisionShape3D, then regenerate grass." % exclusion_area.name)

func clear_grass() -> void:
	var existing_node: Node = get_node_or_null(GRASS_NODE_NAME)
	if existing_node == null:
		return

	remove_child(existing_node)
	existing_node.free()

	if Engine.is_editor_hint():
		print("[GrassField3D] Grass cleared.")

func refresh_material_params() -> void:
	var material: ShaderMaterial = _get_or_create_material()
	_update_wind_and_color_uniforms()
	_reset_all_interactor_uniforms(material)

	var grass_instance: MultiMeshInstance3D = get_node_or_null(GRASS_NODE_NAME) as MultiMeshInstance3D
	if grass_instance != null:
		grass_instance.material_override = material

func _get_or_create_grass_instance() -> MultiMeshInstance3D:
	var existing_node: Node = get_node_or_null(GRASS_NODE_NAME)
	if existing_node is MultiMeshInstance3D:
		return existing_node as MultiMeshInstance3D

	var grass_instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	grass_instance.name = GRASS_NODE_NAME
	add_child(grass_instance)

	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		grass_instance.owner = get_tree().edited_scene_root

	return grass_instance

func _get_or_create_material() -> ShaderMaterial:
	if generated_material == null:
		generated_material = ShaderMaterial.new()
		generated_material.resource_local_to_scene = true

	if grass_shader == null:
		grass_shader = load(DEFAULT_SHADER_PATH) as Shader

	if grass_shader != null:
		generated_material.shader = grass_shader
	else:
		push_warning("[GrassField3D] Missing grass shader. Expected: %s" % DEFAULT_SHADER_PATH)

	return generated_material

func _create_grass_mesh() -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()

	_add_vertical_quad(vertices, uvs, normals, indices, Vector3.RIGHT, Vector3.FORWARD)

	if blade_mesh_mode == BLADE_CROSS_PLANES:
		_add_vertical_quad(vertices, uvs, normals, indices, Vector3.FORWARD, Vector3.RIGHT)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _add_vertical_quad(
	vertices: PackedVector3Array,
	uvs: PackedVector2Array,
	normals: PackedVector3Array,
	indices: PackedInt32Array,
	right_axis: Vector3,
	normal: Vector3
) -> void:
	var base_index: int = vertices.size()
	var half_right: Vector3 = right_axis * 0.5

	vertices.push_back(-half_right + Vector3(0.0, 0.0, 0.0))
	vertices.push_back(half_right + Vector3(0.0, 0.0, 0.0))
	vertices.push_back(-half_right + Vector3(0.0, 1.0, 0.0))
	vertices.push_back(half_right + Vector3(0.0, 1.0, 0.0))

	uvs.push_back(Vector2(0.0, 0.0))
	uvs.push_back(Vector2(1.0, 0.0))
	uvs.push_back(Vector2(0.0, 1.0))
	uvs.push_back(Vector2(1.0, 1.0))

	for n in range(4):
		normals.push_back(normal.normalized())

	indices.push_back(base_index + 0)
	indices.push_back(base_index + 2)
	indices.push_back(base_index + 1)
	indices.push_back(base_index + 1)
	indices.push_back(base_index + 2)
	indices.push_back(base_index + 3)

func _get_random_local_position(random: RandomNumberGenerator, space_state: PhysicsDirectSpaceState3D) -> Vector3:
	var x: float = random.randf_range(-zone_size.x * 0.5, zone_size.x * 0.5)
	var z: float = random.randf_range(-zone_size.y * 0.5, zone_size.y * 0.5)

	if position_jitter > 0.0:
		var jitter_x: float = random.randf_range(-position_jitter, position_jitter) * 0.15
		var jitter_z: float = random.randf_range(-position_jitter, position_jitter) * 0.15
		x += jitter_x
		z += jitter_z

	if use_ground_raycast and space_state != null:
		var from_local: Vector3 = Vector3(x, raycast_height, z)
		var ray_to_local: Vector3 = Vector3(x, -raycast_depth, z)
		var from_global: Vector3 = global_transform * from_local
		var ray_to_global: Vector3 = global_transform * ray_to_local
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_global, ray_to_global, ground_collision_mask)
		var hit: Dictionary = space_state.intersect_ray(query)

		if hit.has("position"):
			var hit_position: Vector3 = hit["position"] as Vector3
			return to_local(hit_position)

	return Vector3(x, ground_y, z)



func _get_exclusion_candidate_nodes() -> Array[Node]:
	var exclusion_nodes: Array[Node] = []

	if not use_exclusion_volumes:
		return exclusion_nodes

	if get_tree() == null:
		return exclusion_nodes

	if exclusion_group_name != StringName():
		var grouped_nodes: Array[Node] = get_tree().get_nodes_in_group(exclusion_group_name)
		for grouped_node in grouped_nodes:
			if not exclusion_nodes.has(grouped_node):
				exclusion_nodes.append(grouped_node)

	if use_exclusion_name_detection and not exclusion_name_prefix.strip_edges().is_empty():
		var search_root: Node = _get_exclusion_search_root()
		if search_root != null:
			_append_named_exclusion_nodes_recursive(search_root, exclusion_nodes)

	return exclusion_nodes

func _append_named_exclusion_nodes_recursive(current_node: Node, exclusion_nodes: Array[Node]) -> void:
	if current_node == null:
		return

	if _node_matches_exclusion_name(current_node) and not exclusion_nodes.has(current_node):
		exclusion_nodes.append(current_node)

	var children: Array[Node] = current_node.get_children()
	for child_node in children:
		_append_named_exclusion_nodes_recursive(child_node, exclusion_nodes)

func _node_matches_exclusion_name(node: Node) -> bool:
	if node == null:
		return false

	if exclusion_name_prefix.strip_edges().is_empty():
		return false

	var node_name: String = String(node.name)
	return node_name.begins_with(exclusion_name_prefix)

func _get_exclusion_search_root() -> Node:
	if get_tree() == null:
		return null

	if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
		return get_tree().edited_scene_root

	if get_tree().current_scene != null:
		return get_tree().current_scene

	return get_tree().root

func _get_editor_owner_node() -> Node:
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		return get_tree().edited_scene_root

	return owner

func _get_next_exclusion_index() -> int:
	var highest_index: int = 0
	var search_root: Node = _get_exclusion_search_root()

	if search_root == null:
		return 1

	var stack: Array[Node] = []
	stack.append(search_root)

	while not stack.is_empty():
		var current_node: Node = stack.pop_back()
		var node_name: String = String(current_node.name)

		if node_name.begins_with("GrassExclusion_"):
			var suffix: String = node_name.trim_prefix("GrassExclusion_")
			if suffix.is_valid_int():
				highest_index = max(highest_index, suffix.to_int())

		var children: Array[Node] = current_node.get_children()
		for child_node in children:
			stack.append(child_node)

	return highest_index + 1

func _is_world_position_excluded(world_position: Vector3, exclusion_nodes: Array[Node]) -> bool:
	if not use_exclusion_volumes:
		return false

	for exclusion_node in exclusion_nodes:
		if _is_position_inside_exclusion_node(world_position, exclusion_node):
			return true

	return false

func _is_position_inside_exclusion_node(world_position: Vector3, exclusion_node: Node) -> bool:
	if exclusion_node == null:
		return false

	var direct_collision_shape: CollisionShape3D = exclusion_node as CollisionShape3D
	if direct_collision_shape != null:
		return _is_position_inside_collision_shape(world_position, direct_collision_shape)

	var shape_nodes: Array[Node] = exclusion_node.find_children("*", "CollisionShape3D", true, false)

	for shape_node in shape_nodes:
		var collision_shape: CollisionShape3D = shape_node as CollisionShape3D
		if collision_shape == null:
			continue

		if _is_position_inside_collision_shape(world_position, collision_shape):
			return true

	return false

func _is_position_inside_collision_shape(world_position: Vector3, collision_shape: CollisionShape3D) -> bool:
	if collision_shape.disabled:
		return false

	if collision_shape.shape == null:
		return false

	var local_position: Vector3 = collision_shape.global_transform.affine_inverse() * world_position

	var box_shape: BoxShape3D = collision_shape.shape as BoxShape3D
	if box_shape != null:
		var half_size: Vector3 = box_shape.size * 0.5
		return abs(local_position.x) <= half_size.x and abs(local_position.y) <= half_size.y and abs(local_position.z) <= half_size.z

	var sphere_shape: SphereShape3D = collision_shape.shape as SphereShape3D
	if sphere_shape != null:
		return local_position.length() <= sphere_shape.radius

	var cylinder_shape: CylinderShape3D = collision_shape.shape as CylinderShape3D
	if cylinder_shape != null:
		var half_height: float = cylinder_shape.height * 0.5
		var horizontal_distance: float = Vector2(local_position.x, local_position.z).length()
		return abs(local_position.y) <= half_height and horizontal_distance <= cylinder_shape.radius

	return false

func _update_wind_and_color_uniforms() -> void:
	var material: ShaderMaterial = generated_material
	if material == null:
		return

	material.set_shader_parameter("bottom_color", bottom_color)
	material.set_shader_parameter("top_color", top_color)
	material.set_shader_parameter("wind_strength", wind_strength)
	material.set_shader_parameter("wind_speed", wind_speed)
	material.set_shader_parameter("wind_frequency", wind_frequency)
	material.set_shader_parameter("wind_direction", wind_direction)
	material.set_shader_parameter("vertical_push", vertical_push)
	material.set_shader_parameter("bend_response", bend_response)

func _update_interactors() -> void:
	var material: ShaderMaterial = generated_material
	if material == null or get_tree() == null:
		return

	_reset_all_interactor_uniforms(material)

	var written_count: int = 0
	written_count = _write_group_interactors(material, player_group, player_radius, player_bend_strength, written_count)
	written_count = _write_group_interactors(material, vehicle_group, vehicle_radius, vehicle_bend_strength, written_count)

func _write_group_interactors(
	material: ShaderMaterial,
	group_name: StringName,
	radius: float,
	strength: float,
	start_index: int
) -> int:
	if group_name == StringName():
		return start_index

	var current_index: int = start_index
	var nodes: Array[Node] = get_tree().get_nodes_in_group(group_name)

	for node in nodes:
		if current_index >= MAX_INTERACTORS:
			return current_index

		if not node is Node3D:
			continue

		var node_3d: Node3D = node as Node3D
		_set_interactor_uniform(material, current_index, node_3d.global_position, radius, strength)
		current_index += 1

	return current_index

func _reset_all_interactor_uniforms(material: ShaderMaterial) -> void:
	for i in range(MAX_INTERACTORS):
		_set_interactor_uniform(material, i, Vector3(99999.0, 0.0, 99999.0), 0.0, 0.0)

func _set_interactor_uniform(material: ShaderMaterial, index: int, interactor_position: Vector3, radius: float, strength: float) -> void:
	var position_uniform_name: StringName = StringName("interactor_%d" % index)
	var strength_uniform_name: StringName = StringName("interactor_strength_%d" % index)

	material.set_shader_parameter(position_uniform_name, Vector4(interactor_position.x, interactor_position.y, interactor_position.z, radius))
	material.set_shader_parameter(strength_uniform_name, strength)
