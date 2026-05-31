@tool
extends Node3D
class_name EditableCable3D

const MARKER_A_NAME: String = "CablePoint_A"
const MARKER_B_NAME: String = "CablePoint_B"
const CABLE_MESH_NAME: String = "GeneratedCableMesh"

@export_group("Editor Actions")
@export_tool_button("Initiate Markers") var initiate_markers_action: Callable = initiate_markers
@export_tool_button("Apply / Refresh Cable") var apply_refresh_action: Callable = apply_refresh
@export_tool_button("Clear Cable") var clear_cable_action: Callable = clear_cable

@export_group("Cable Shape")
@export_range(0.005, 2.0, 0.005) var radius: float = 0.045:
	set(value):
		radius = max(value, 0.001)
		_queue_rebuild_if_auto()

@export_range(0.0, 20.0, 0.05) var sag: float = 0.75:
	set(value):
		sag = max(value, 0.0)
		_queue_rebuild_if_auto()

@export_range(2, 96, 1) var segments: int = 24:
	set(value):
		segments = max(value, 2)
		_queue_rebuild_if_auto()

@export_range(3, 24, 1) var sides: int = 8:
	set(value):
		sides = max(value, 3)
		_queue_rebuild_if_auto()

@export var cap_ends: bool = true:
	set(value):
		cap_ends = value
		_queue_rebuild_if_auto()

@export_group("Visual")
@export var cable_color: Color = Color(0.03, 0.03, 0.03, 1.0):
	set(value):
		cable_color = value
		_queue_rebuild_if_auto()

@export var custom_material: Material:
	set(value):
		custom_material = value
		_queue_rebuild_if_auto()

@export_group("Update")
@export var auto_refresh_when_value_changes: bool = true

@export var live_update_in_editor: bool = false:
	set(value):
		live_update_in_editor = value
		if is_inside_tree():
			set_process(Engine.is_editor_hint() and live_update_in_editor)

var _refresh_queued: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(live_update_in_editor)
	else:
		set_process(false)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and live_update_in_editor:
		_rebuild_cable()


func initiate_markers() -> void:
	var marker_a: Marker3D = _get_marker(MARKER_A_NAME)
	var marker_b: Marker3D = _get_marker(MARKER_B_NAME)

	if marker_a == null:
		marker_a = Marker3D.new()
		marker_a.name = MARKER_A_NAME
		marker_a.gizmo_extents = 0.35
		add_child(marker_a)
		_set_scene_owner(marker_a)
		marker_a.position = Vector3(-1.0, 0.0, 0.0)

	if marker_b == null:
		marker_b = Marker3D.new()
		marker_b.name = MARKER_B_NAME
		marker_b.gizmo_extents = 0.35
		add_child(marker_b)
		_set_scene_owner(marker_b)
		marker_b.position = Vector3(1.0, 0.0, 0.0)

	_ensure_cable_mesh_node()


func apply_refresh() -> void:
	initiate_markers()
	_rebuild_cable()


func clear_cable() -> void:
	var cable_mesh: MeshInstance3D = _get_cable_mesh_node()
	if cable_mesh == null:
		return

	cable_mesh.mesh = null


func _queue_rebuild_if_auto() -> void:
	if not auto_refresh_when_value_changes:
		return

	if not is_inside_tree():
		return

	if _refresh_queued:
		return

	_refresh_queued = true
	call_deferred("_deferred_rebuild")


func _deferred_rebuild() -> void:
	_refresh_queued = false
	_rebuild_cable()


func _get_marker(marker_name: String) -> Marker3D:
	return get_node_or_null(marker_name) as Marker3D


func _get_cable_mesh_node() -> MeshInstance3D:
	return get_node_or_null(CABLE_MESH_NAME) as MeshInstance3D


func _ensure_cable_mesh_node() -> MeshInstance3D:
	var cable_mesh: MeshInstance3D = _get_cable_mesh_node()

	if cable_mesh != null:
		return cable_mesh

	cable_mesh = MeshInstance3D.new()
	cable_mesh.name = CABLE_MESH_NAME
	add_child(cable_mesh)
	_set_scene_owner(cable_mesh)

	return cable_mesh


func _set_scene_owner(target_node: Node) -> void:
	if not Engine.is_editor_hint():
		return

	if not is_inside_tree():
		return

	var scene_root: Node = get_tree().edited_scene_root

	if scene_root != null and scene_root.is_ancestor_of(target_node):
		target_node.owner = scene_root
		return

	if owner != null:
		target_node.owner = owner


func _rebuild_cable() -> void:
	var marker_a: Marker3D = _get_marker(MARKER_A_NAME)
	var marker_b: Marker3D = _get_marker(MARKER_B_NAME)

	if marker_a == null or marker_b == null:
		return

	var cable_mesh: MeshInstance3D = _ensure_cable_mesh_node()
	var center_points: Array[Vector3] = _build_center_points(marker_a, marker_b)

	if center_points.size() < 2:
		return

	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()

	_build_tube_geometry(center_points, vertices, normals, uvs, indices)

	if cap_ends:
		_build_end_caps(center_points, vertices, normals, uvs, indices)

	var mesh_arrays: Array = []
	mesh_arrays.resize(Mesh.ARRAY_MAX)
	mesh_arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh_arrays[Mesh.ARRAY_NORMAL] = normals
	mesh_arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh_arrays[Mesh.ARRAY_INDEX] = indices

	var array_mesh: ArrayMesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
	array_mesh.surface_set_material(0, _get_final_material())

	cable_mesh.mesh = array_mesh


func _build_center_points(marker_a: Marker3D, marker_b: Marker3D) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var world_start: Vector3 = marker_a.global_position
	var world_end: Vector3 = marker_b.global_position

	for segment_index: int in range(segments + 1):
		var progress: float = float(segment_index) / float(segments)
		var world_point: Vector3 = world_start.lerp(world_end, progress)
		var sag_amount: float = sin(progress * PI) * sag
		world_point += Vector3.DOWN * sag_amount
		result.append(to_local(world_point))

	return result


func _build_tube_geometry(
	center_points: Array[Vector3],
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array
) -> void:
	for point_index: int in range(center_points.size()):
		var frame_data: Dictionary = _get_ring_frame(center_points, point_index)
		var right_axis: Vector3 = frame_data["right_axis"]
		var up_axis: Vector3 = frame_data["up_axis"]

		for side_index: int in range(sides):
			var angle: float = TAU * float(side_index) / float(sides)
			var normal_direction: Vector3 = (right_axis * cos(angle) + up_axis * sin(angle)).normalized()
			var vertex_position: Vector3 = center_points[point_index] + normal_direction * radius

			vertices.append(vertex_position)
			normals.append(normal_direction)
			uvs.append(Vector2(float(side_index) / float(sides), float(point_index) / float(segments)))

	for segment_index: int in range(segments):
		for side_index: int in range(sides):
			var current_a: int = segment_index * sides + side_index
			var current_b: int = segment_index * sides + ((side_index + 1) % sides)
			var next_a: int = (segment_index + 1) * sides + side_index
			var next_b: int = (segment_index + 1) * sides + ((side_index + 1) % sides)

			indices.append(current_a)
			indices.append(next_a)
			indices.append(current_b)

			indices.append(current_b)
			indices.append(next_a)
			indices.append(next_b)


func _build_end_caps(
	center_points: Array[Vector3],
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array
) -> void:
	var start_center_index: int = vertices.size()
	var start_normal: Vector3 = (center_points[0] - center_points[1]).normalized()
	vertices.append(center_points[0])
	normals.append(start_normal)
	uvs.append(Vector2(0.5, 0.5))

	for side_index: int in range(sides):
		var ring_a: int = side_index
		var ring_b: int = (side_index + 1) % sides
		indices.append(start_center_index)
		indices.append(ring_b)
		indices.append(ring_a)

	var end_center_index: int = vertices.size()
	var last_point_index: int = center_points.size() - 1
	var end_normal: Vector3 = (center_points[last_point_index] - center_points[last_point_index - 1]).normalized()
	vertices.append(center_points[last_point_index])
	normals.append(end_normal)
	uvs.append(Vector2(0.5, 0.5))

	var end_ring_start: int = last_point_index * sides

	for side_index: int in range(sides):
		var ring_a: int = end_ring_start + side_index
		var ring_b: int = end_ring_start + ((side_index + 1) % sides)
		indices.append(end_center_index)
		indices.append(ring_a)
		indices.append(ring_b)


func _get_ring_frame(center_points: Array[Vector3], point_index: int) -> Dictionary:
	var previous_index: int = max(point_index - 1, 0)
	var next_index: int = min(point_index + 1, center_points.size() - 1)
	var tangent: Vector3 = center_points[next_index] - center_points[previous_index]

	if tangent.length_squared() < 0.0001:
		tangent = Vector3.FORWARD
	else:
		tangent = tangent.normalized()

	var reference_up: Vector3 = Vector3.UP

	if abs(tangent.dot(reference_up)) > 0.95:
		reference_up = Vector3.RIGHT

	var right_axis: Vector3 = tangent.cross(reference_up).normalized()
	var up_axis: Vector3 = right_axis.cross(tangent).normalized()

	return {
		"right_axis": right_axis,
		"up_axis": up_axis,
		"tangent": tangent,
	}


func _get_final_material() -> Material:
	if custom_material != null:
		return custom_material

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = cable_color
	material.roughness = 0.85
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
