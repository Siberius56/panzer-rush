extends Node3D
class_name VehicleGateUnlockButton

signal activated(player_node: Node)

@export_group("Groups")
@export var player_group_name: String = "player"
@export var player_group_fallback_name: String = "players"

@export_group("Nodes")
@export var gate_path: NodePath = ^".."
@export var activation_area_path: NodePath = ^"ActivationArea"
@export var button_mesh_path: NodePath = ^"ButtonMesh"

@export_group("Behavior")
@export var auto_activate_on_player_enter: bool = false
@export var disable_after_activation: bool = true
@export var debug_button: bool = false

@export_group("Visual")
@export var enabled_color: Color = Color(1.0, .85, 0.4, 1.0)
@export var disabled_color: Color = Color(0.25, 0.25, 0.25, 1.0)
@export var used_local_offset: Vector3 = Vector3(0.0, -0.08, 0.0)
@export var used_scale_multiplier: float = 0.9

@onready var activation_area: Area3D = get_node_or_null(activation_area_path) as Area3D
@onready var button_mesh: MeshInstance3D = get_node_or_null(button_mesh_path) as MeshInstance3D

var _players_inside: Dictionary = {}
var _is_used: bool = false
#var _base_mesh_position: Vector3 = Vector3.ZERO
#var _base_mesh_scale: Vector3 = Vector3.ONE
var _button_material: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("interactables")
	add_to_group("gate_buttons")

	_setup_visual_cache()
	_setup_activation_area()
	_apply_used_visual(_is_used)


func interact(interactor: Node = null) -> bool:
	return activate(interactor)


func use(interactor: Node = null) -> bool:
	return activate(interactor)


func press(interactor: Node = null) -> bool:
	return activate(interactor)


func activate(interactor: Node = null) -> bool:
	if _is_used and disable_after_activation:
		return false

	var player_node: Node = _get_player_from_detector(interactor)
	if player_node == null:
		player_node = _get_first_player_inside()

	if player_node == null:
		if debug_button:
			print("[VehicleGateUnlockButton] Activation refusée : aucun joueur détecté.")
		return false

	var gate_node: Node = _get_gate()
	if gate_node == null:
		if debug_button:
			print("[VehicleGateUnlockButton] Activation refusée : gate introuvable.")
		return false

	if not gate_node.has_method("request_complete_from_player"):
		if debug_button:
			print("[VehicleGateUnlockButton] Activation refusée : la gate ne possède pas request_complete_from_player().")
		return false

	var success: bool = bool(gate_node.call("request_complete_from_player", player_node))
	if not success:
		if debug_button:
			print("[VehicleGateUnlockButton] Activation refusée par la gate.")
		return false

	# En multi, le visuel définitif est appliqué par VehicleBlockingGate.rpc_apply_gate_state().
	# Cela évite que seul le client qui appuie voie le bouton désactivé.
	if disable_after_activation and (not multiplayer.has_multiplayer_peer() or multiplayer.is_server()):
		set_used(true)

	activated.emit(player_node)

	if debug_button:
		print("[VehicleGateUnlockButton] Bouton activé : ", get_path())

	return true


func can_interact(interactor: Node = null) -> bool:
	if _is_used and disable_after_activation:
		return false

	var gate_node: Node = _get_gate()
	if gate_node != null and gate_node.has_method("is_completed") and bool(gate_node.call("is_completed")):
		return false

	if interactor != null:
		return _get_player_from_detector(interactor) != null

	return _players_inside.size() > 0


func set_used(value: bool) -> void:
	_is_used = value
	_apply_used_visual(value)

	if activation_area != null:
		activation_area.monitoring = not (value and disable_after_activation)


func is_used() -> bool:
	return _is_used


func _setup_activation_area() -> void:
	if activation_area == null:
		return

	activation_area.monitoring = true
	activation_area.monitorable = true

	if not activation_area.body_entered.is_connected(_on_detector_entered):
		activation_area.body_entered.connect(_on_detector_entered)
	if not activation_area.body_exited.is_connected(_on_detector_exited):
		activation_area.body_exited.connect(_on_detector_exited)
	if not activation_area.area_entered.is_connected(_on_detector_entered):
		activation_area.area_entered.connect(_on_detector_entered)
	if not activation_area.area_exited.is_connected(_on_detector_exited):
		activation_area.area_exited.connect(_on_detector_exited)


func _setup_visual_cache() -> void:
	if button_mesh == null:
		return

	var current_material: Material = button_mesh.get_surface_override_material(0)
	if current_material == null and button_mesh.mesh != null:
		current_material = button_mesh.mesh.surface_get_material(0)

	if current_material is StandardMaterial3D:
		_button_material = (current_material as StandardMaterial3D).duplicate() as StandardMaterial3D
	else:
		_button_material = StandardMaterial3D.new()
		_button_material.roughness = 0.75

	button_mesh.set_surface_override_material(0, _button_material)


func _apply_used_visual(value: bool) -> void:
	if button_mesh == null:
		return

	if _button_material != null:
		_button_material.albedo_color = disabled_color if value else enabled_color


func _on_detector_entered(detector: Node) -> void:
	var player_node: Node = _get_player_from_detector(detector)
	if player_node == null:
		return

	_players_inside[player_node.get_instance_id()] = player_node

	if auto_activate_on_player_enter:
		activate(player_node)


func _on_detector_exited(detector: Node) -> void:
	var player_node: Node = _get_player_from_detector(detector)
	if player_node == null:
		return

	_players_inside.erase(player_node.get_instance_id())


func _get_first_player_inside() -> Node:
	for player_node in _players_inside.values():
		if player_node != null and is_instance_valid(player_node):
			return player_node
	return null


func _get_gate() -> Node:
	var gate_node: Node = get_node_or_null(gate_path)
	if gate_node != null:
		return gate_node

	var parent_node: Node = get_parent()
	while parent_node != null:
		if parent_node.has_method("request_complete_from_player"):
			return parent_node
		parent_node = parent_node.get_parent()

	return null


func _get_player_from_detector(detector: Node) -> Node:
	if detector == null:
		return null

	var current: Node = detector
	while current != null:
		if _is_player_node(current):
			return current
		current = current.get_parent()

	return null


func _is_player_node(node: Node) -> bool:
	if node == null:
		return false
	if not player_group_name.is_empty() and node.is_in_group(player_group_name):
		return true
	if not player_group_fallback_name.is_empty() and node.is_in_group(player_group_fallback_name):
		return true
	return false
