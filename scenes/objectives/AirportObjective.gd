extends Node3D

# AirportObjective.gd
# Godot 4.x
#
# Rôle :
# - S'enregistre comme provider d'objectif.
# - Observe 4 sous-objectifs destructibles, ou tout enfant dans le groupe airport_objective_targets.
# - Termine l'objectif quand tous les appareils sont détruits.
# - Utilise la même logique HUD que BombRadarObjective.gd.

signal objective_registered(objective_id: String, objective_text: String)
signal objective_completed(objective_id: String)
signal objective_removed(objective_id: String)
signal sub_objective_completed(target_id: String, destroyed_count: int, total_count: int)

@export_group("Objective")
@export var objective_id: String = "airport_objective"
@export var objective_text: String = "Destroy enemy aircraft at the airport"
@export var completed_text: String = "Airport aircraft destroyed"
@export var register_on_ready: bool = true
@export var remove_from_hud_on_exit: bool = true

@export_group("Targets")
@export var target_node_paths: Array[NodePath] = []
@export var auto_collect_targets_from_children: bool = true
@export var target_group_name: StringName = &"airport_objective_targets"
@export var require_at_least_one_target: bool = true

@export_group("Progress Text")
@export var show_progress_in_objective_text: bool = true
@export var progress_suffix_format: String = " (%d/%d)"

@export_group("Debug")
@export var debug_logs: bool = false

var is_destroyed: bool = false
var _is_registered: bool = false
var _targets: Array[Node] = []
var _completed_target_keys: Dictionary = {}


func _ready() -> void:
	add_to_group("objective_providers")

	_collect_and_connect_targets()
	_refresh_progress(false)

	if register_on_ready:
		call_deferred("_deferred_register_objective")


func _exit_tree() -> void:
	if remove_from_hud_on_exit and _is_registered and not is_destroyed:
		_safe_call_player_huds("unregister_objective", [get_objective_id()])
		objective_removed.emit(get_objective_id())

	_is_registered = false
	_targets.clear()
	_completed_target_keys.clear()


func get_objective_id() -> String:
	if not objective_id.strip_edges().is_empty():
		return objective_id.strip_edges()

	var path_text: String = ""
	if is_inside_tree():
		path_text = str(get_path())
	else:
		path_text = name

	return "%s_%d" % [name, path_text.hash()]


func get_objective_text() -> String:
	if not show_progress_in_objective_text:
		return objective_text

	var total_count: int = _targets.size()
	if total_count <= 0:
		return objective_text

	return objective_text + progress_suffix_format % [_completed_target_keys.size(), total_count]


func is_objective_completed() -> bool:
	return is_destroyed


func register_objective_now() -> void:
	_deferred_register_objective()


func complete_objective() -> void:
	if is_destroyed:
		return

	is_destroyed = true
	objective_completed.emit(get_objective_id())

	_safe_call_player_huds("complete_objective", [get_objective_id(), completed_text])
	_safe_call_player_huds("set_objective_completed", [get_objective_id(), true])
	_safe_call_player_huds("update_objective_status", [get_objective_id(), true])


func fail_or_remove_objective() -> void:
	if not _is_registered:
		return

	_safe_call_player_huds("unregister_objective", [get_objective_id()])
	objective_removed.emit(get_objective_id())
	_is_registered = false


func reset_objective() -> void:
	is_destroyed = false
	_is_registered = false
	_completed_target_keys.clear()

	for target: Node in _targets:
		if target != null and is_instance_valid(target) and target.has_method("reset_target"):
			target.reset_target()

	_refresh_progress(false)
	_deferred_register_objective()


func notify_destroyed() -> void:
	complete_objective()


func mark_completed() -> void:
	complete_objective()


func set_completed(value: bool = true) -> void:
	if value:
		complete_objective()
	else:
		is_destroyed = false
		_safe_call_player_huds("set_objective_completed", [get_objective_id(), false])
		_safe_call_player_huds("update_objective_status", [get_objective_id(), false])


func _deferred_register_objective() -> void:
	if not is_inside_tree():
		return

	var tree: SceneTree = get_tree()
	if tree == null:
		return

	var id: String = get_objective_id()
	if id.strip_edges().is_empty():
		return

	_is_registered = true
	objective_registered.emit(id, get_objective_text())

	_safe_call_player_huds("register_objective", [id, get_objective_text(), is_destroyed])
	_safe_call_player_huds("set_objective_completed", [id, is_destroyed])
	_safe_call_player_huds("update_objective_status", [id, is_destroyed])


func _collect_and_connect_targets() -> void:
	_targets.clear()

	for path: NodePath in target_node_paths:
		if path.is_empty():
			continue

		var target: Node = get_node_or_null(path)
		_add_target_if_valid(target)

	if auto_collect_targets_from_children:
		_collect_targets_recursive(self)

	for target: Node in _targets:
		_connect_target(target)

	if debug_logs:
		print("[AirportObjective:%s] targets=%d" % [name, _targets.size()])

	if require_at_least_one_target and _targets.is_empty():
		push_warning("AirportObjective has no targets. Add AirportTargetDestructible children or set target_node_paths.")


func _collect_targets_recursive(node: Node) -> void:
	for child: Node in node.get_children():
		if child.is_in_group(target_group_name):
			_add_target_if_valid(child)
		_collect_targets_recursive(child)


func _add_target_if_valid(target: Node) -> void:
	if target == null:
		return
	if not is_instance_valid(target):
		return
	if target == self:
		return
	if _targets.has(target):
		return

	_targets.append(target)


func _connect_target(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return

	if target.has_signal("destroyed"):
		var callable_destroyed: Callable = Callable(self, "_on_target_destroyed_signal").bind(target)
		if not target.is_connected("destroyed", callable_destroyed):
			target.connect("destroyed", callable_destroyed)
		return

	if target.has_signal("objective_completed"):
		var callable_completed: Callable = Callable(self, "_on_target_destroyed_signal").bind(target)
		if not target.is_connected("objective_completed", callable_completed):
			target.connect("objective_completed", callable_completed)
		return

	if target.has_signal("tree_exiting"):
		var callable_exit: Callable = Callable(self, "_on_target_tree_exiting").bind(target)
		if not target.is_connected("tree_exiting", callable_exit):
			target.connect("tree_exiting", callable_exit)


func _on_target_destroyed_signal(arg0: Variant = null, arg1: Variant = null) -> void:
	var target: Node = null
	var target_id: String = ""

	if arg1 is Node:
		target = arg1 as Node
	if arg0 is Node:
		target = arg0 as Node
	elif arg0 != null:
		target_id = str(arg0)

	if target == null and not target_id.is_empty():
		target = _find_target_by_id(target_id)

	if target == null:
		_refresh_progress(true)
		return

	_mark_target_completed(target, true)


func _on_target_tree_exiting(target: Node) -> void:
	if target == null:
		return

	_mark_target_completed(target, true)


func _mark_target_completed(target: Node, emit_progress_signal: bool) -> void:
	if target == null or not is_instance_valid(target):
		return

	var key: int = target.get_instance_id()
	if _completed_target_keys.has(key):
		return

	_completed_target_keys[key] = true

	var target_id: String = _get_target_id(target)
	if emit_progress_signal:
		sub_objective_completed.emit(target_id, _completed_target_keys.size(), _targets.size())

	if debug_logs:
		print("[AirportObjective:%s] destroyed %s %d/%d" % [name, target_id, _completed_target_keys.size(), _targets.size()])

	_update_hud_progress()
	_check_completion()


func _refresh_progress(update_hud: bool) -> void:
	_completed_target_keys.clear()

	for target: Node in _targets:
		if target == null or not is_instance_valid(target):
			continue
		if _is_target_destroyed(target):
			_completed_target_keys[target.get_instance_id()] = true

	if update_hud:
		_update_hud_progress()

	_check_completion()


func _check_completion() -> void:
	if is_destroyed:
		return
	if require_at_least_one_target and _targets.is_empty():
		return
	if _targets.is_empty():
		return

	if _completed_target_keys.size() >= _targets.size():
		complete_objective()


func _update_hud_progress() -> void:
	if not _is_registered:
		return

	var id: String = get_objective_id()
	var text: String = get_objective_text()

	# Plusieurs noms possibles. Les appels absents sont ignorés.
	_safe_call_player_huds("update_objective_text", [id, text])
	_safe_call_player_huds("set_objective_text", [id, text])
	_safe_call_player_huds("register_objective", [id, text, is_destroyed])
	_safe_call_player_huds("update_objective_status", [id, is_destroyed])


func _find_target_by_id(target_id: String) -> Node:
	for target: Node in _targets:
		if target == null or not is_instance_valid(target):
			continue
		if _get_target_id(target) == target_id:
			return target
	return null


func _get_target_id(target: Node) -> String:
	if target == null:
		return ""
	if target.has_method("get_target_id"):
		return str(target.call("get_target_id"))

	var property_value = _safe_get_property(target, "target_id")
	if property_value != null:
		var text: String = str(property_value).strip_edges()
		if not text.is_empty():
			return text

	return target.name


func _is_target_destroyed(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return true

	if target.has_method("is_target_destroyed"):
		return bool(target.call("is_target_destroyed"))

	if target.has_method("is_objective_completed"):
		return bool(target.call("is_objective_completed"))

	var property_value = _safe_get_property(target, "is_destroyed")
	if property_value != null:
		return bool(property_value)

	return false


func _safe_get_property(object: Object, property_name: String) -> Variant:
	if object == null:
		return null

	for property_data in object.get_property_list():
		if String(property_data.name) == property_name:
			return object.get(property_name)

	return null


func _safe_call_player_huds(method_name: String, args: Array = []) -> void:
	if not is_inside_tree():
		return

	var tree: SceneTree = get_tree()
	if tree == null:
		return

	for hud_node: Node in tree.get_nodes_in_group("player_huds"):
		if hud_node == null:
			continue
		if not is_instance_valid(hud_node):
			continue
		if not hud_node.has_method(method_name):
			continue

		hud_node.callv(method_name, args)
