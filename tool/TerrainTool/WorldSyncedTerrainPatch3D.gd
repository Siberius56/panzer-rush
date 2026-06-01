@tool
class_name WorldSyncedTerrainPatch3D
extends Node3D

# v6: Top-side winding with manually upward normals. No negative node scale required.

const DEFAULT_GROUND_LAYERS: int = 136 # Godot layers 4 + 8, values 8 + 128.
const GENERATED_MESH_NODE_NAME: StringName = &"GeneratedMesh"
const COLLISION_BODY_NODE_NAME: StringName = &"GeneratedCollisionBody"
const COLLISION_SHAPE_NODE_NAME: StringName = &"CollisionShape3D"

# Keep the enum order stable. Existing scenes save the integer value.
enum TerrainMode {
	FLAT,
	WAVY,
	BROKEN
}

@export_group("Tools")
@export_tool_button("Rebuild Terrain", "Reload") var rebuild_terrain_button: Callable = _editor_rebuild_terrain
@export_tool_button("Apply Flat Preset", "PlaneMesh") var apply_flat_preset_button: Callable = _editor_apply_flat_preset
@export_tool_button("Apply Wavy Preset", "PlaneMesh") var apply_wavy_preset_button: Callable = _editor_apply_wavy_preset
@export_tool_button("Apply Broken Preset", "PlaneMesh") var apply_broken_preset_button: Callable = _editor_apply_broken_preset
@export_tool_button("Fade All Edges", "GradientTexture2D") var fade_all_edges_button: Callable = _editor_fade_all_edges
@export_tool_button("No Edge Fade", "Remove") var no_edge_fade_button: Callable = _editor_no_edge_fade
@export_tool_button("Clear Generated Mesh", "Clear") var clear_generated_mesh_button: Callable = _editor_clear_generated_mesh

@export_group("Terrain")
@export var terrain_mode: TerrainMode = TerrainMode.WAVY
@export var size_x: float = 30.0
@export var size_z: float = 30.0
@export var cells_x: int = 20
@export var cells_z: int = 20
@export var local_base_height: float = 0.0
@export_range(0.0, 5.0, 0.05, "or_greater") var height_multiplier: float = 1.0

@export_group("Noise")
@export var use_world_space_noise: bool = true
@export var noise_seed: int = 1207
@export var noise_frequency: float = 0.075
@export var noise_offset: Vector2 = Vector2.ZERO
@export var height_amplitude: float = 0.55
@export var noise_strength: float = 0.65
@export var wave_strength: float = 0.45
@export var wave_frequency: float = 0.35
@export var detail_strength: float = 0.35
@export var detail_frequency_multiplier: float = 2.65

@export_group("Edge Fade To Flat")
@export var edge_fade_enabled: bool = false
@export var edge_fade_distance: float = 4.0
@export var edge_fade_power: float = 1.0
@export var fade_x_negative: bool = true
@export var fade_x_positive: bool = true
@export var fade_z_negative: bool = true
@export var fade_z_positive: bool = true

@export_group("Visual")
@export var terrain_material: Material
@export var fallback_preview_color: Color = Color(0.38, 0.52, 0.30, 1.0)
@export var use_world_space_uv: bool = true
@export var uv_scale: float = 8.0

@export_group("Collision")
@export var collision_enabled: bool = true
@export_flags_3d_physics var generated_collision_layer: int = DEFAULT_GROUND_LAYERS

@export_group("Generation")
@export var generate_on_ready: bool = true
@export var generate_in_editor_on_ready: bool = true
@export var rebuild_on_transform_changed: bool = false

var _rebuild_queued: bool = false
var _fallback_material: StandardMaterial3D


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		_ensure_child_nodes()


func _ready() -> void:
	set_notify_transform(true)
	_ensure_child_nodes()
	_rebuild_queued = false

	if not generate_on_ready:
		return

	if Engine.is_editor_hint() and not generate_in_editor_on_ready:
		return

	_schedule_rebuild()


func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSFORM_CHANGED:
		return

	if not Engine.is_editor_hint():
		return

	if not rebuild_on_transform_changed:
		return

	if not use_world_space_noise and not use_world_space_uv:
		return

	_schedule_rebuild()


func _editor_rebuild_terrain() -> void:
	_rebuild_now()


func _editor_apply_flat_preset() -> void:
	_apply_flat_preset()
	_rebuild_now()


func _editor_apply_wavy_preset() -> void:
	_apply_wavy_preset()
	_rebuild_now()


func _editor_apply_broken_preset() -> void:
	_apply_broken_preset()
	_rebuild_now()


func _editor_fade_all_edges() -> void:
	edge_fade_enabled = true
	fade_x_negative = true
	fade_x_positive = true
	fade_z_negative = true
	fade_z_positive = true
	_rebuild_now()


func _editor_no_edge_fade() -> void:
	edge_fade_enabled = false
	_rebuild_now()


func _editor_clear_generated_mesh() -> void:
	_ensure_child_nodes()

	var mesh_instance: MeshInstance3D = get_node_or_null(NodePath(GENERATED_MESH_NODE_NAME)) as MeshInstance3D
	if mesh_instance != null:
		mesh_instance.mesh = null

	var collision_shape: CollisionShape3D = get_node_or_null(NodePath(String(COLLISION_BODY_NODE_NAME) + "/" + String(COLLISION_SHAPE_NODE_NAME))) as CollisionShape3D
	if collision_shape != null:
		collision_shape.shape = null


func _schedule_rebuild() -> void:
	if not is_inside_tree():
		return

	if _rebuild_queued:
		return

	_rebuild_queued = true
	call_deferred("_rebuild_deferred")


func _rebuild_deferred() -> void:
	_rebuild_queued = false
	_rebuild_now()


func _rebuild_now() -> void:
	_ensure_child_nodes()
	_rebuild()


func _rebuild() -> void:
	var mesh_instance: MeshInstance3D = get_node_or_null(NodePath(GENERATED_MESH_NODE_NAME)) as MeshInstance3D
	var collision_body: StaticBody3D = get_node_or_null(NodePath(COLLISION_BODY_NODE_NAME)) as StaticBody3D
	var collision_shape: CollisionShape3D = get_node_or_null(NodePath(String(COLLISION_BODY_NODE_NAME) + "/" + String(COLLISION_SHAPE_NODE_NAME))) as CollisionShape3D

	if mesh_instance == null or collision_body == null or collision_shape == null:
		push_warning("WorldSyncedTerrainPatch3D: missing generated child nodes.")
		return

	var generated_mesh: ArrayMesh = _build_terrain_mesh()
	mesh_instance.mesh = generated_mesh
	mesh_instance.visible = true
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	var material_to_use: Material = _get_material_to_use()
	mesh_instance.set_surface_override_material(0, material_to_use)

	collision_body.collision_layer = generated_collision_layer
	collision_body.collision_mask = 0
	collision_shape.disabled = not collision_enabled

	if collision_enabled:
		collision_shape.shape = generated_mesh.create_trimesh_shape()
	else:
		collision_shape.shape = null


func _build_terrain_mesh() -> ArrayMesh:
	var safe_size_x: float = max(size_x, 0.01)
	var safe_size_z: float = max(size_z, 0.01)
	var safe_cells_x: int = max(cells_x, 1)
	var safe_cells_z: int = max(cells_z, 1)

	var main_noise: FastNoiseLite = _make_noise(noise_seed, noise_frequency)
	var detail_noise: FastNoiseLite = _make_noise(noise_seed + 1337, noise_frequency * max(detail_frequency_multiplier, 0.001))

	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)


	for z: int in range(safe_cells_z):
		for x: int in range(safe_cells_x):
			var p00: Vector3 = _make_point(x, z, safe_cells_x, safe_cells_z, safe_size_x, safe_size_z, main_noise, detail_noise)
			var p10: Vector3 = _make_point(x + 1, z, safe_cells_x, safe_cells_z, safe_size_x, safe_size_z, main_noise, detail_noise)
			var p01: Vector3 = _make_point(x, z + 1, safe_cells_x, safe_cells_z, safe_size_x, safe_size_z, main_noise, detail_noise)
			var p11: Vector3 = _make_point(x + 1, z + 1, safe_cells_x, safe_cells_z, safe_size_x, safe_size_z, main_noise, detail_noise)

			# Godot displays this winding from above with standard culling.
			# Normals are set manually in _add_triangle() so lighting stays upward.
			_add_triangle(surface_tool, p00, p11, p01, safe_size_x, safe_size_z)
			_add_triangle(surface_tool, p00, p10, p11, safe_size_x, safe_size_z)

	var mesh: ArrayMesh = surface_tool.commit()
	return mesh


func _make_noise(seed_value: int, frequency_value: float) -> FastNoiseLite:
	var generated_noise: FastNoiseLite = FastNoiseLite.new()
	generated_noise.seed = seed_value
	generated_noise.frequency = max(frequency_value, 0.0001)
	generated_noise.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
	generated_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	generated_noise.fractal_octaves = 3
	generated_noise.fractal_lacunarity = 2.0
	generated_noise.fractal_gain = 0.5
	return generated_noise


func _make_point(
	x_index: int,
	z_index: int,
	total_x: int,
	total_z: int,
	safe_size_x: float,
	safe_size_z: float,
	main_noise: FastNoiseLite,
	detail_noise: FastNoiseLite
) -> Vector3:
	var fx: float = float(x_index) / float(total_x)
	var fz: float = float(z_index) / float(total_z)

	var px: float = (fx - 0.5) * safe_size_x
	var pz: float = (fz - 0.5) * safe_size_z

	var sample_position: Vector2 = _get_noise_sample_position(px, pz)
	var raw_height: float = _get_raw_height(sample_position, main_noise, detail_noise)
	var edge_weight: float = _get_edge_weight(px, pz, safe_size_x, safe_size_z)
	var final_height: float = local_base_height + raw_height * edge_weight * height_multiplier

	return Vector3(px, final_height, pz)


func _get_noise_sample_position(local_x: float, local_z: float) -> Vector2:
	if use_world_space_noise:
		var world_position: Vector3 = global_transform * Vector3(local_x, 0.0, local_z)
		return Vector2(world_position.x, world_position.z) + noise_offset

	return Vector2(local_x, local_z) + noise_offset


func _get_raw_height(sample_position: Vector2, main_noise: FastNoiseLite, detail_noise: FastNoiseLite) -> float:
	if terrain_mode == TerrainMode.FLAT:
		return 0.0

	var main_value: float = main_noise.get_noise_2d(sample_position.x, sample_position.y)
	var detail_value: float = detail_noise.get_noise_2d(sample_position.x, sample_position.y)
	var height: float = 0.0

	if terrain_mode == TerrainMode.WAVY:
		var wave_x: float = sin(sample_position.x * wave_frequency)
		var wave_z: float = cos(sample_position.y * wave_frequency * 0.73)
		var wave_value: float = (wave_x + wave_z) * 0.5
		height = (main_value * noise_strength) + (wave_value * wave_strength) + (detail_value * detail_strength * 0.35)

	elif terrain_mode == TerrainMode.BROKEN:
		height = (main_value * noise_strength) + (detail_value * detail_strength)

	return height * height_amplitude


func _get_edge_weight(local_x: float, local_z: float, safe_size_x: float, safe_size_z: float) -> float:
	if not edge_fade_enabled:
		return 1.0

	var safe_distance: float = max(edge_fade_distance, 0.001)
	var half_x: float = safe_size_x * 0.5
	var half_z: float = safe_size_z * 0.5
	var closest_distance: float = INF

	if fade_x_negative:
		closest_distance = min(closest_distance, local_x + half_x)
	if fade_x_positive:
		closest_distance = min(closest_distance, half_x - local_x)
	if fade_z_negative:
		closest_distance = min(closest_distance, local_z + half_z)
	if fade_z_positive:
		closest_distance = min(closest_distance, half_z - local_z)

	if closest_distance == INF:
		return 1.0

	var t: float = clamp(closest_distance / safe_distance, 0.0, 1.0)
	var smooth_t: float = t * t * (3.0 - 2.0 * t)

	if edge_fade_power <= 0.001:
		return smooth_t

	return pow(smooth_t, edge_fade_power)


func _add_triangle(surface_tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, safe_size_x: float, safe_size_z: float) -> void:
	var triangle_normal: Vector3 = _get_upward_triangle_normal(a, b, c)

	_add_vertex(surface_tool, a, safe_size_x, safe_size_z, triangle_normal)
	_add_vertex(surface_tool, b, safe_size_x, safe_size_z, triangle_normal)
	_add_vertex(surface_tool, c, safe_size_x, safe_size_z, triangle_normal)


func _get_upward_triangle_normal(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var side_ab: Vector3 = b - a
	var side_ac: Vector3 = c - a
	var triangle_normal: Vector3 = side_ab.cross(side_ac).normalized()

	if triangle_normal == Vector3.ZERO:
		return Vector3.UP

	if triangle_normal.y < 0.0:
		triangle_normal = -triangle_normal

	return triangle_normal


func _add_vertex(surface_tool: SurfaceTool, position: Vector3, safe_size_x: float, safe_size_z: float, vertex_normal: Vector3) -> void:
	surface_tool.set_uv(_get_uv(position, safe_size_x, safe_size_z))
	surface_tool.set_normal(vertex_normal)
	surface_tool.add_vertex(position)


func _get_uv(position: Vector3, safe_size_x: float, safe_size_z: float) -> Vector2:
	var safe_uv_scale: float = max(uv_scale, 0.001)

	if use_world_space_uv:
		var world_position: Vector3 = global_transform * position
		return Vector2(world_position.x / safe_uv_scale, world_position.z / safe_uv_scale)

	return Vector2(
		(position.x / safe_size_x + 0.5) * safe_size_x / safe_uv_scale,
		(position.z / safe_size_z + 0.5) * safe_size_z / safe_uv_scale
	)


func _ensure_child_nodes() -> void:
	var mesh_instance: MeshInstance3D = get_node_or_null(NodePath(GENERATED_MESH_NODE_NAME)) as MeshInstance3D
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = GENERATED_MESH_NODE_NAME
		add_child(mesh_instance)
		_set_editor_owner(mesh_instance)

	var collision_body: StaticBody3D = get_node_or_null(NodePath(COLLISION_BODY_NODE_NAME)) as StaticBody3D
	if collision_body == null:
		collision_body = StaticBody3D.new()
		collision_body.name = COLLISION_BODY_NODE_NAME
		add_child(collision_body)
		_set_editor_owner(collision_body)

	var collision_shape: CollisionShape3D = collision_body.get_node_or_null(NodePath(COLLISION_SHAPE_NODE_NAME)) as CollisionShape3D
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = COLLISION_SHAPE_NODE_NAME
		collision_body.add_child(collision_shape)
		_set_editor_owner(collision_shape)

	collision_body.collision_layer = generated_collision_layer
	collision_body.collision_mask = 0


func _set_editor_owner(node_to_own: Node) -> void:
	if not Engine.is_editor_hint():
		return

	if get_tree() == null:
		return

	var edited_root: Node = get_tree().edited_scene_root
	if edited_root != null:
		node_to_own.owner = edited_root


func _get_material_to_use() -> Material:
	if terrain_material != null:
		return terrain_material

	if _fallback_material == null:
		_fallback_material = StandardMaterial3D.new()
		_fallback_material.resource_name = "GeneratedTerrainPreviewMaterial"
		_fallback_material.albedo_color = fallback_preview_color
		_fallback_material.roughness = 1.0

	return _fallback_material


func _apply_flat_preset() -> void:
	terrain_mode = TerrainMode.FLAT
	cells_x = 8
	cells_z = 8
	height_amplitude = 0.0
	height_multiplier = 1.0
	noise_frequency = 0.075
	wave_frequency = 0.35
	edge_fade_enabled = false


func _apply_wavy_preset() -> void:
	terrain_mode = TerrainMode.WAVY
	cells_x = 20
	cells_z = 20
	height_amplitude = 0.55
	height_multiplier = 1.0
	noise_frequency = 0.075
	noise_strength = 0.65
	wave_strength = 0.45
	wave_frequency = 0.35
	detail_strength = 0.20
	detail_frequency_multiplier = 2.0
	edge_fade_enabled = false


func _apply_broken_preset() -> void:
	terrain_mode = TerrainMode.BROKEN
	cells_x = 24
	cells_z = 24
	height_amplitude = 1.15
	height_multiplier = 1.0
	noise_frequency = 0.095
	noise_strength = 0.80
	wave_strength = 0.0
	detail_strength = 0.45
	detail_frequency_multiplier = 3.1
	edge_fade_enabled = false
