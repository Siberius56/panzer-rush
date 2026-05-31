@tool
extends Area3D
class_name GrassExclusionVolume3D

@export_category("Setup")
@export var exclusion_size: Vector3 = Vector3(8.0, 4.0, 20.0):
	set(value):
		exclusion_size = value
		_refresh_shape()
		_refresh_debug_mesh()

@export var show_debug_box: bool = true:
	set(value):
		show_debug_box = value
		_refresh_debug_mesh()

@export var debug_color: Color = Color(1.0, 0.1, 0.0, 0.18):
	set(value):
		debug_color = value
		_refresh_debug_mesh()

var collision_shape_node: CollisionShape3D
var debug_mesh_node: MeshInstance3D

func _ready() -> void:
	add_to_group(&"grass_exclusion")
	_setup_nodes()
	_refresh_shape()
	_refresh_debug_mesh()

func _setup_nodes() -> void:
	collision_shape_node = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape_node == null:
		collision_shape_node = CollisionShape3D.new()
		collision_shape_node.name = "CollisionShape3D"
		add_child(collision_shape_node)
		_set_editor_owner(collision_shape_node)

	debug_mesh_node = get_node_or_null("DebugMesh") as MeshInstance3D
	if debug_mesh_node == null:
		debug_mesh_node = MeshInstance3D.new()
		debug_mesh_node.name = "DebugMesh"
		add_child(debug_mesh_node)
		_set_editor_owner(debug_mesh_node)

func _refresh_shape() -> void:
	if collision_shape_node == null:
		return

	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = exclusion_size
	collision_shape_node.shape = box_shape

func _refresh_debug_mesh() -> void:
	if debug_mesh_node == null:
		return

	debug_mesh_node.visible = show_debug_box

	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = exclusion_size
	debug_mesh_node.mesh = box_mesh

	var debug_material: StandardMaterial3D = StandardMaterial3D.new()
	debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	debug_material.albedo_color = debug_color
	debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_material.no_depth_test = true
	debug_mesh_node.material_override = debug_material

func _set_editor_owner(target_node: Node) -> void:
	if not Engine.is_editor_hint():
		return

	if get_tree() == null:
		return

	if get_tree().edited_scene_root == null:
		return

	target_node.owner = get_tree().edited_scene_root
