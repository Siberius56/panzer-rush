@tool
extends Node3D
class_name GrassObjectField3D

const GRASS_NODE_NAME: String = "GrassObjectMultiMesh"
const DEFAULT_SHADER_PATH: String = "res://GrassObjectField3D/GrassObjectInteractive.gdshader"
const MAX_SHADER_INTERACTORS: int = 8
const FAR_INTERACTOR_VECTOR4: Vector4 = Vector4(99999.0, 99999.0, 99999.0, 0.0)

@export_category("Editor Buttons")
@export_tool_button("Setup / Regenerate Objects") var setup_objects_button: Callable = setup_grass
@export_tool_button("Clear Objects") var clear_objects_button: Callable = clear_grass
@export_tool_button("Refresh Material Params") var refresh_material_button: Callable = refresh_material_params
@export_tool_button("Create Exclusion Box") var create_exclusion_box_button: Callable = create_exclusion_box

@export_category("Source Object")
@export var source_mesh: Mesh
@export var source_scene: PackedScene
@export var align_mesh_base_to_origin: bool = true
@export var center_mesh_on_xz: bool = true

@export_category("Generation")
@export var auto_generate_on_ready: bool = false
@export var update_in_editor: bool = true
@export var zone_size: Vector2 = Vector2(40.0, 40.0)
@export_range(0, 200000, 1) var object_count: int = 2500
@export var generation_seed: int = 12345
@export var randomize_seed_on_generate: bool = false
@export_range(0.0, 1.0, 0.01) var position_jitter: float = 1.0

@export_category("Object Scale")
@export_range(0.01, 20.0, 0.01) var uniform_scale_min: float = 0.85
@export_range(0.01, 20.0, 0.01) var uniform_scale_max: float = 1.35
@export_range(0.01, 20.0, 0.01) var width_scale_min: float = 0.85
@export_range(0.01, 20.0, 0.01) var width_scale_max: float = 1.25
@export_range(0.01, 20.0, 0.01) var height_scale_min: float = 0.85
@export_range(0.01, 20.0, 0.01) var height_scale_max: float = 1.25

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
@export var use_albedo_texture: bool = false
@export var albedo_texture: Texture2D
@export_range(0.0, 1.0, 0.01) var normal_up_blend: float = 0.95
@export_range(0.0, 1.0, 0.01) var minimum_light: float = 0.75
@export_range(0.0, 1.0, 0.01) var emission_strength: float = 0.08
@export_range(0.0, 1.0, 0.01) var light_response: float = 0.15
@export_range(0.0, 0.5, 0.01) var color_variation_strength: float = 0.04
@export var ground_blend_color: Color = Color(0.16, 0.29, 0.09, 1.0)
@export_range(0.0, 1.0, 0.01) var ground_blend_strength: float = 0.25

@export_category("Wind")
@export_range(0.0, 45.0, 0.1) var wind_strength_degrees: float = 7.0
@export_range(0.0, 10.0, 0.01) var wind_speed: float = 1.25
@export_range(0.0, 10.0, 0.01) var wind_frequency: float = 1.8
@export var wind_direction: Vector2 = Vector2(1.0, 0.35)
@export_range(0.0, 1.0, 0.01) var wind_flattened_multiplier: float = 0.35

@export_category("Interaction")
@export var player_group: StringName = &"grass_player"
@export var vehicle_group: StringName = &"grass_vehicle"
@export_range(0.1, 20.0, 0.1) var player_radius: float = 1.35
@export_range(0.0, 1.0, 0.01) var player_bend_strength: float = 0.70
@export_range(0.1, 30.0, 0.1) var vehicle_radius: float = 3.25
@export_range(0.0, 1.0, 0.01) var vehicle_bend_strength: float = 1.0
@export_range(0.0, 89.0, 0.1) var max_bend_degrees: float = 78.0

var active_instance_count: int = 0
var mesh_base_y_cache: float = 0.0
var mesh_height_cache: float = 1.0

var instance_local_positions: Array[Vector3] = []
var instance_wind_phases: Array[float] = []
var instance_color_variations: Array[float] = []
var instance_bend_variations: Array[float] = []
var instance_bend_amounts: Array[float] = []
var instance_bend_angles: Array[float] = []
var instance_recovery_delays: Array[float] = []

func _ready() -> void:
	set_process(true)

	if not Engine.is_editor_hint() and auto_generate_on_ready:
		setup_grass()
	else:
		_sync_arrays_from_existing_multimesh_if_needed()
		refresh_material_params()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and not update_in_editor:
		return

	_update_wind_and_material_uniforms()
	_update_interactor_uniforms()

func setup_grass() -> void:
	if randomize_seed_on_generate:
		var seed_random: RandomNumberGenerator = RandomNumberGenerator.new()
		seed_random.randomize()
		generation_seed = seed_random.randi()

	var source_object_mesh: Mesh = _get_mesh_for_multimesh()
	if source_object_mesh == null:
		push_warning("[GrassObjectField3D] No source mesh found. A fallback cross-plane mesh was generated.")
		source_object_mesh = _create_fallback_grass_mesh()

	_update_mesh_bounds_cache(source_object_mesh)

	var grass_instance: MultiMeshInstance3D = _get_or_create_grass_instance()
	var material: ShaderMaterial = _get_or_create_material()

	var new_multimesh: MultiMesh = MultiMesh.new()
	new_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	new_multimesh.use_custom_data = true
	new_multimesh.mesh = source_object_mesh
	new_multimesh.instance_count = object_count
	new_multimesh.visible_instance_count = 0

	_clear_runtime_arrays()

	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = generation_seed

	var space_state: PhysicsDirectSpaceState3D = null
	if use_ground_raycast and is_inside_tree() and get_world_3d() != null:
		space_state = get_world_3d().direct_space_state

	var exclusion_nodes: Array[Node] = _get_exclusion_candidate_nodes()

	var placed_count: int = 0
	var attempts: int = 0
	var max_attempts: int = max(object_count, object_count * max_spawn_attempt_multiplier)

	while placed_count < object_count and attempts < max_attempts:
		attempts += 1

		var local_position: Vector3 = _get_random_local_position(random, space_state)
		var world_position: Vector3 = global_transform * local_position

		if _is_world_position_excluded(world_position, exclusion_nodes):
			continue

		var rotation_y: float = random.randf_range(0.0, TAU)
		var uniform_scale: float = random.randf_range(uniform_scale_min, uniform_scale_max)
		var width_scale: float = random.randf_range(width_scale_min, width_scale_max) * uniform_scale
		var height_scale: float = random.randf_range(height_scale_min, height_scale_max) * uniform_scale

		var object_basis: Basis = Basis.IDENTITY
		object_basis = object_basis.rotated(Vector3.UP, rotation_y)
		object_basis = object_basis.scaled(Vector3(width_scale, height_scale, width_scale))

		var object_transform: Transform3D = Transform3D(object_basis, local_position)
		new_multimesh.set_instance_transform(placed_count, object_transform)

		var wind_phase: float = random.randf()
		var bend_angle: float = random.randf_range(0.0, TAU)
		var bend_angle_normalized: float = _angle_to_normalized_unit(bend_angle)
		var bend_amount: float = 0.0
		var color_variation: float = random.randf()
		var bend_variation: float = random.randf_range(0.85, 1.15)

		new_multimesh.set_instance_custom_data(placed_count, Color(wind_phase, bend_angle_normalized, bend_amount, color_variation))

		instance_local_positions.append(local_position)
		instance_wind_phases.append(wind_phase)
		instance_color_variations.append(color_variation)
		instance_bend_variations.append(bend_variation)
		instance_bend_amounts.append(bend_amount)
		instance_bend_angles.append(bend_angle)
		instance_recovery_delays.append(0.0)

		placed_count += 1

	active_instance_count = placed_count
	new_multimesh.visible_instance_count = placed_count

	var mesh_aabb: AABB = source_object_mesh.get_aabb()
	var max_object_height: float = max(mesh_aabb.size.y * height_scale_max * uniform_scale_max, 1.0)
	var margin: float = max(vehicle_radius, player_radius) + max_object_height + wind_strength_degrees * 0.05 + 2.0
	new_multimesh.custom_aabb = AABB(
		Vector3(-zone_size.x * 0.5 - margin, -margin, -zone_size.y * 0.5 - margin),
		Vector3(zone_size.x + margin * 2.0, max_object_height + margin * 2.0, zone_size.y + margin * 2.0)
	)

	grass_instance.multimesh = new_multimesh
	grass_instance.material_override = material
	grass_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	refresh_material_params()

	if Engine.is_editor_hint():
		print("[GrassObjectField3D] Generated %s/%s objects in area %s." % [placed_count, object_count, zone_size])

func clear_grass() -> void:
	var existing_node: Node = get_node_or_null(GRASS_NODE_NAME)
	if existing_node == null:
		return

	remove_child(existing_node)
	existing_node.free()
	_clear_runtime_arrays()
	active_instance_count = 0

	if Engine.is_editor_hint():
		print("[GrassObjectField3D] Objects cleared.")

func refresh_material_params() -> void:
	var material: ShaderMaterial = _get_or_create_material()
	_update_mesh_bounds_cache_from_current_source()
	_update_wind_and_material_uniforms()
	_update_interactor_uniforms()

	var grass_instance: MultiMeshInstance3D = get_node_or_null(GRASS_NODE_NAME) as MultiMeshInstance3D
	if grass_instance != null:
		grass_instance.material_override = material

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
		print("[GrassObjectField3D] Exclusion box created: %s. Move and scale its CollisionShape3D, then regenerate objects." % exclusion_area.name)

func _get_or_create_grass_instance() -> MultiMeshInstance3D:
	var existing_node: Node = get_node_or_null(GRASS_NODE_NAME)
	if existing_node is MultiMeshInstance3D:
		return existing_node as MultiMeshInstance3D

	var grass_instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	grass_instance.name = GRASS_NODE_NAME
	add_child(grass_instance)

	var editor_owner: Node = _get_editor_owner_node()
	if editor_owner != null:
		grass_instance.owner = editor_owner

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
		push_warning("[GrassObjectField3D] Missing grass shader. Expected: %s" % DEFAULT_SHADER_PATH)

	return generated_material

func _get_mesh_for_multimesh() -> Mesh:
	var input_mesh: Mesh = _get_source_mesh()
	if input_mesh == null:
		return null

	if align_mesh_base_to_origin or center_mesh_on_xz:
		var aligned_mesh: Mesh = _create_aligned_mesh_copy(input_mesh)
		if aligned_mesh != null:
			return aligned_mesh

	return input_mesh

func _get_source_mesh() -> Mesh:
	if source_mesh != null:
		return source_mesh

	if source_scene == null:
		return null

	var scene_root: Node = source_scene.instantiate()
	if scene_root == null:
		return null

	var mesh_instance: MeshInstance3D = _find_first_mesh_instance_recursive(scene_root)
	var found_mesh: Mesh = null

	if mesh_instance != null:
		found_mesh = mesh_instance.mesh

	scene_root.free()
	return found_mesh

func _find_first_mesh_instance_recursive(current_node: Node) -> MeshInstance3D:
	if current_node is MeshInstance3D:
		return current_node as MeshInstance3D

	var children: Array[Node] = current_node.get_children()
	for child_node in children:
		var found_node: MeshInstance3D = _find_first_mesh_instance_recursive(child_node)
		if found_node != null:
			return found_node

	return null

func _create_aligned_mesh_copy(input_mesh: Mesh) -> Mesh:
	var source_array_mesh: ArrayMesh = input_mesh as ArrayMesh
	if source_array_mesh == null:
		return input_mesh

	var source_aabb: AABB = source_array_mesh.get_aabb()
	var offset: Vector3 = Vector3.ZERO

	if center_mesh_on_xz:
		offset.x = source_aabb.position.x + source_aabb.size.x * 0.5
		offset.z = source_aabb.position.z + source_aabb.size.z * 0.5

	if align_mesh_base_to_origin:
		offset.y = source_aabb.position.y

	var new_mesh: ArrayMesh = ArrayMesh.new()
	var surface_count: int = source_array_mesh.get_surface_count()

	for surface_index in range(surface_count):
		var arrays: Array = source_array_mesh.surface_get_arrays(surface_index)
		if arrays.size() <= Mesh.ARRAY_VERTEX:
			continue

		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		for vertex_index in range(vertices.size()):
			vertices[vertex_index] = vertices[vertex_index] - offset

		arrays[Mesh.ARRAY_VERTEX] = vertices
		new_mesh.add_surface_from_arrays(source_array_mesh.surface_get_primitive_type(surface_index), arrays)

		var surface_material: Material = source_array_mesh.surface_get_material(surface_index)
		if surface_material != null:
			new_mesh.surface_set_material(surface_index, surface_material)

	return new_mesh

func _create_fallback_grass_mesh() -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()

	_add_vertical_quad(vertices, uvs, normals, indices, Vector3.RIGHT, Vector3.FORWARD)
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

	for normal_index in range(4):
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

func _collect_interactors() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	if get_tree() == null:
		return result

	_append_group_interactors(result, player_group, player_radius, player_bend_strength)
	_append_group_interactors(result, vehicle_group, vehicle_radius, vehicle_bend_strength)

	return result

func _update_interactor_uniforms() -> void:
	var material: ShaderMaterial = generated_material
	if material == null:
		return

	var interactors: Array[Dictionary] = _collect_interactors()
	var safe_count: int = min(interactors.size(), MAX_SHADER_INTERACTORS)

	material.set_shader_parameter("interactor_count", safe_count)

	var positions: Array[Vector4] = []
	var strengths: Array[float] = []

	for interactor_index in range(MAX_SHADER_INTERACTORS):
		var interactor_vector: Vector4 = FAR_INTERACTOR_VECTOR4
		var interactor_strength: float = 0.0

		if interactor_index < safe_count:
			var interactor: Dictionary = interactors[interactor_index]
			var interactor_position: Vector3 = interactor["position"] as Vector3
			var interactor_radius: float = float(interactor["radius"])
			interactor_strength = float(interactor["strength"])
			interactor_vector = Vector4(interactor_position.x, interactor_position.y, interactor_position.z, interactor_radius)

		positions.append(interactor_vector)
		strengths.append(interactor_strength)

	for interactor_index in range(MAX_SHADER_INTERACTORS):
		material.set_shader_parameter("interactor_%d" % interactor_index, positions[interactor_index])

	material.set_shader_parameter("interactor_strengths_0", Vector4(strengths[0], strengths[1], strengths[2], strengths[3]))
	material.set_shader_parameter("interactor_strengths_1", Vector4(strengths[4], strengths[5], strengths[6], strengths[7]))

func _append_group_interactors(result: Array[Dictionary], group_name: StringName, radius: float, strength: float) -> void:
	if group_name == StringName():
		return

	if radius <= 0.001 or strength <= 0.001:
		return

	var nodes: Array[Node] = get_tree().get_nodes_in_group(group_name)
	for node in nodes:
		if not node is Node3D:
			continue

		var node_3d: Node3D = node as Node3D
		result.append({
			"position": node_3d.global_position,
			"radius": radius,
			"strength": strength
		})

func _write_instance_custom_data(multimesh: MultiMesh, instance_index: int) -> void:
	if multimesh == null:
		return

	if instance_index < 0 or instance_index >= multimesh.instance_count:
		return

	var wind_phase: float = instance_wind_phases[instance_index]
	var bend_angle_normalized: float = _angle_to_normalized_unit(instance_bend_angles[instance_index])
	var bend_amount: float = clamp(instance_bend_amounts[instance_index], 0.0, 1.0)
	var color_variation: float = instance_color_variations[instance_index]

	multimesh.set_instance_custom_data(instance_index, Color(wind_phase, bend_angle_normalized, bend_amount, color_variation))

func _smooth_falloff(radius: float, distance: float) -> float:
	var normalized_distance: float = clamp(1.0 - distance / max(radius, 0.001), 0.0, 1.0)
	return normalized_distance * normalized_distance * (3.0 - 2.0 * normalized_distance)

func _angle_to_normalized_unit(angle: float) -> float:
	var wrapped_angle: float = fposmod(angle, TAU)
	return wrapped_angle / TAU

func _update_wind_and_material_uniforms() -> void:
	var material: ShaderMaterial = generated_material
	if material == null:
		return

	material.set_shader_parameter("bottom_color", bottom_color)
	material.set_shader_parameter("top_color", top_color)
	material.set_shader_parameter("use_albedo_texture", use_albedo_texture)
	if albedo_texture != null:
		material.set_shader_parameter("albedo_texture", albedo_texture)

	material.set_shader_parameter("mesh_base_y", mesh_base_y_cache)
	material.set_shader_parameter("mesh_height", mesh_height_cache)
	material.set_shader_parameter("normal_up_blend", normal_up_blend)
	material.set_shader_parameter("minimum_light", minimum_light)
	material.set_shader_parameter("emission_strength", emission_strength)
	material.set_shader_parameter("light_response", light_response)
	material.set_shader_parameter("color_variation_strength", color_variation_strength)
	material.set_shader_parameter("ground_blend_color", ground_blend_color)
	material.set_shader_parameter("ground_blend_strength", ground_blend_strength)

	material.set_shader_parameter("wind_strength_degrees", wind_strength_degrees)
	material.set_shader_parameter("wind_speed", wind_speed)
	material.set_shader_parameter("wind_frequency", wind_frequency)
	material.set_shader_parameter("wind_direction", wind_direction)
	material.set_shader_parameter("wind_flattened_multiplier", wind_flattened_multiplier)
	material.set_shader_parameter("max_bend_degrees", max_bend_degrees)

func _update_mesh_bounds_cache(input_mesh: Mesh) -> void:
	if input_mesh == null:
		mesh_base_y_cache = 0.0
		mesh_height_cache = 1.0
		return

	var mesh_aabb: AABB = input_mesh.get_aabb()
	mesh_base_y_cache = mesh_aabb.position.y
	mesh_height_cache = max(mesh_aabb.size.y, 0.001)

func _update_mesh_bounds_cache_from_current_source() -> void:
	var grass_instance: MultiMeshInstance3D = get_node_or_null(GRASS_NODE_NAME) as MultiMeshInstance3D
	if grass_instance != null and grass_instance.multimesh != null and grass_instance.multimesh.mesh != null:
		_update_mesh_bounds_cache(grass_instance.multimesh.mesh)
		return

	var current_mesh: Mesh = _get_mesh_for_multimesh()
	if current_mesh != null:
		_update_mesh_bounds_cache(current_mesh)

func _sync_arrays_from_existing_multimesh_if_needed() -> void:
	if instance_local_positions.size() > 0:
		return

	var grass_instance: MultiMeshInstance3D = get_node_or_null(GRASS_NODE_NAME) as MultiMeshInstance3D
	if grass_instance == null or grass_instance.multimesh == null:
		return

	var multimesh: MultiMesh = grass_instance.multimesh
	var visible_count: int = multimesh.visible_instance_count
	if visible_count < 0:
		visible_count = multimesh.instance_count

	active_instance_count = visible_count
	_clear_runtime_arrays()

	for instance_index in range(active_instance_count):
		var object_transform: Transform3D = multimesh.get_instance_transform(instance_index)
		var custom_data: Color = multimesh.get_instance_custom_data(instance_index)
		var bend_angle: float = custom_data.g * TAU

		instance_local_positions.append(object_transform.origin)
		instance_wind_phases.append(custom_data.r)
		instance_color_variations.append(custom_data.a)
		instance_bend_variations.append(1.0)
		instance_bend_amounts.append(custom_data.b)
		instance_bend_angles.append(bend_angle)
		instance_recovery_delays.append(0.0)

	if multimesh.mesh != null:
		_update_mesh_bounds_cache(multimesh.mesh)

func _clear_runtime_arrays() -> void:
	instance_local_positions.clear()
	instance_wind_phases.clear()
	instance_color_variations.clear()
	instance_bend_variations.clear()
	instance_bend_amounts.clear()
	instance_bend_angles.clear()
	instance_recovery_delays.clear()

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
