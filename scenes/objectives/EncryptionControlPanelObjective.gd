extends Node3D

# EncryptionControlPanelObjective.gd
# Godot 4.x / 4.6
#
# Rôle :
# - S'enregistre comme provider d'objectif.
# - Détecte une WorldWeapon3D de type "encryption_remote" dans son Area3D.
# - Lance un compte à rebours serveur.
# - Demande une super horde au HordeDirector quand le compte à rebours démarre.
# - Termine l'objectif si la télécommande reste assez longtemps dans la zone.

signal objective_registered(objective_id: String, objective_text: String)
signal objective_completed(objective_id: String)
signal objective_removed(objective_id: String)
signal countdown_started(objective_id: String)
signal countdown_stopped(objective_id: String)
signal countdown_progress_changed(objective_id: String, remaining_seconds: float, duration_seconds: float)

@export_group("Objective")
@export var objective_id: String = ""
@export var objective_text: String = "Place the encryption remote near the control panel"
@export var active_text: String = "Encryption in progress"
@export var completed_text: String = "Control panel encrypted"
@export var register_on_ready: bool = true
@export var remove_from_hud_on_exit: bool = true

@export_group("Activation")
@export var required_weapon_id: String = "encryption_remote"
@export var hold_duration_seconds: float = 30.0
@export var reset_countdown_when_remote_leaves: bool = true
@export var consume_remote_on_complete: bool = true
@export var activation_area_path: NodePath = ^"ActivationArea"

@export_group("Super Horde")
@export var request_super_horde_on_countdown_start: bool = true
@export var request_super_horde_once: bool = true
@export var horde_director_group_name: String = "horde_director"
@export var super_horde_request_source: String = "encryption_control_panel"

@export_group("Display")
@export var countdown_label_path: NodePath = ^"VisualRoot/CountdownLabel"
@export var show_countdown_label_when_idle: bool = false
@export var idle_label_text: String = "REMOTE"
@export var completed_label_text: String = "DONE"

var is_completed: bool = false
var is_counting_down: bool = false
var remaining_seconds: float = 0.0

var _is_registered: bool = false
var _super_horde_requested: bool = false
var _activation_area: Area3D = null
var _countdown_label: Label3D = null
var _active_remote: Node = null
var _tracked_remotes: Array[Node] = []


func _ready() -> void:
	add_to_group("objective_providers")

	remaining_seconds = maxf(hold_duration_seconds, 0.0)
	_activation_area = get_node_or_null(activation_area_path) as Area3D
	_countdown_label = get_node_or_null(countdown_label_path) as Label3D

	_connect_activation_area()
	_update_countdown_label()

	if register_on_ready:
		call_deferred("_deferred_register_objective")

	call_deferred("_scan_existing_bodies")


func _exit_tree() -> void:
	if remove_from_hud_on_exit and _is_registered and not is_completed:
		_safe_call_player_huds("unregister_objective", [get_objective_id()])
		objective_removed.emit(get_objective_id())

	_is_registered = false
	_active_remote = null
	_tracked_remotes.clear()


func _process(delta: float) -> void:
	if is_completed:
		return

	if not _has_server_authority():
		return

	_update_countdown(delta)


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
	return objective_text


func is_objective_completed() -> bool:
	return is_completed


func register_objective_now() -> void:
	_deferred_register_objective()


func complete_objective() -> void:
	if is_completed:
		return

	is_completed = true
	is_counting_down = false
	remaining_seconds = 0.0

	objective_completed.emit(get_objective_id())
	_safe_call_player_huds("complete_objective", [get_objective_id(), completed_text])
	_safe_call_player_huds("set_objective_completed", [get_objective_id(), true])
	_safe_call_player_huds("update_objective_status", [get_objective_id(), true])

	_update_countdown_label()
	_disable_activation_area()
	_consume_active_remote_if_needed()


func fail_or_remove_objective() -> void:
	if not _is_registered:
		return

	_safe_call_player_huds("unregister_objective", [get_objective_id()])
	objective_removed.emit(get_objective_id())
	_is_registered = false


func reset_objective() -> void:
	is_completed = false
	is_counting_down = false
	remaining_seconds = maxf(hold_duration_seconds, 0.0)
	_super_horde_requested = false
	_active_remote = null
	_tracked_remotes.clear()

	if _activation_area != null:
		_activation_area.monitoring = true

	_update_countdown_label()
	_deferred_register_objective()


func notify_destroyed() -> void:
	complete_objective()


func mark_completed() -> void:
	complete_objective()


func set_completed(value: bool = true) -> void:
	if value:
		complete_objective()
	else:
		is_completed = false
		remaining_seconds = maxf(hold_duration_seconds, 0.0)
		_safe_call_player_huds("set_objective_completed", [get_objective_id(), false])
		_safe_call_player_huds("update_objective_status", [get_objective_id(), false])
		_update_countdown_label()


func _update_countdown(delta: float) -> void:
	_prune_tracked_remotes()

	var valid_remote: Node = _find_valid_remote_inside()
	if valid_remote == null:
		if is_counting_down:
			_stop_countdown()
		return

	if not is_counting_down:
		_start_or_resume_countdown(valid_remote)
	else:
		_active_remote = valid_remote

	remaining_seconds = maxf(remaining_seconds - delta, 0.0)
	countdown_progress_changed.emit(get_objective_id(), remaining_seconds, hold_duration_seconds)
	_update_countdown_label()

	if remaining_seconds <= 0.0:
		complete_objective()


func _start_or_resume_countdown(remote_node: Node) -> void:
	_active_remote = remote_node
	is_counting_down = true

	if remaining_seconds <= 0.0 or remaining_seconds > hold_duration_seconds:
		remaining_seconds = maxf(hold_duration_seconds, 0.0)

	_try_connect_remote_lost_signal(remote_node)
	countdown_started.emit(get_objective_id())

	if request_super_horde_on_countdown_start:
		_request_super_horde_if_allowed()

	_safe_call_player_huds("register_objective", [get_objective_id(), active_text, false])
	_update_countdown_label()


func _stop_countdown() -> void:
	is_counting_down = false
	_active_remote = null

	if reset_countdown_when_remote_leaves:
		remaining_seconds = maxf(hold_duration_seconds, 0.0)

	countdown_stopped.emit(get_objective_id())
	_safe_call_player_huds("register_objective", [get_objective_id(), objective_text, false])
	_update_countdown_label()


func _request_super_horde_if_allowed() -> void:
	if request_super_horde_once and _super_horde_requested:
		return

	_super_horde_requested = true

	if not is_inside_tree():
		return

	var tree: SceneTree = get_tree()
	if tree == null:
		return

	for director_node: Node in tree.get_nodes_in_group(horde_director_group_name):
		if director_node == null or not is_instance_valid(director_node):
			continue

		if director_node.has_method("request_super_horde_now"):
			director_node.call("request_super_horde_now", super_horde_request_source)
			return

		if director_node.has_method("request_mega_horde_now"):
			director_node.call("request_mega_horde_now", super_horde_request_source)
			return

		if director_node.has_method("force_mega_horde_now"):
			director_node.call("force_mega_horde_now")
			return


func _find_valid_remote_inside() -> Node:
	if _activation_area == null:
		return null

	var overlapping_bodies: Array = _activation_area.get_overlapping_bodies()
	for body_node: Node in overlapping_bodies:
		var remote_from_body: Node = _get_valid_remote_from_node(body_node)
		if remote_from_body != null:
			_add_tracked_remote(remote_from_body)
			return remote_from_body

	return null


func _scan_existing_bodies() -> void:
	if _activation_area == null:
		return

	for body_node: Node in _activation_area.get_overlapping_bodies():
		_on_activation_area_body_entered(body_node)


func _connect_activation_area() -> void:
	if _activation_area == null:
		return

	_try_connect_signal(_activation_area, "body_entered", Callable(self, "_on_activation_area_body_entered"))
	_try_connect_signal(_activation_area, "body_exited", Callable(self, "_on_activation_area_body_exited"))


func _on_activation_area_body_entered(body_node: Node) -> void:
	if is_completed:
		return

	var remote_node: Node = _get_valid_remote_from_node(body_node)
	if remote_node == null:
		return

	_add_tracked_remote(remote_node)


func _on_activation_area_body_exited(body_node: Node) -> void:
	var remote_node: Node = _get_valid_remote_from_node(body_node)
	if remote_node == null:
		return

	_tracked_remotes.erase(remote_node)

	if remote_node == _active_remote:
		call_deferred("_stop_countdown_if_no_valid_remote")


func _stop_countdown_if_no_valid_remote() -> void:
	if is_completed:
		return

	if _find_valid_remote_inside() == null and is_counting_down:
		_stop_countdown()


func _on_remote_tree_exiting(remote_node: Node) -> void:
	_on_remote_lost(remote_node)


func _on_remote_lost(remote_node: Node) -> void:
	if remote_node != null:
		_tracked_remotes.erase(remote_node)

	if is_counting_down:
		_stop_countdown()


func _add_tracked_remote(remote_node: Node) -> void:
	if remote_node == null:
		return

	if not _tracked_remotes.has(remote_node):
		_tracked_remotes.append(remote_node)

	_try_connect_remote_lost_signal(remote_node)


func _prune_tracked_remotes() -> void:
	var cleaned_remotes: Array[Node] = []
	for remote_node: Node in _tracked_remotes:
		if _is_valid_remote_node(remote_node):
			cleaned_remotes.append(remote_node)
	_tracked_remotes = cleaned_remotes


func _get_valid_remote_from_node(candidate_node: Node) -> Node:
	var cursor_node: Node = candidate_node
	while cursor_node != null:
		if _is_valid_remote_node(cursor_node):
			return cursor_node
		cursor_node = cursor_node.get_parent()

	return null


func _is_valid_remote_node(candidate_node: Node) -> bool:
	if candidate_node == null:
		return false

	if not is_instance_valid(candidate_node):
		return false

	if required_weapon_id.strip_edges().is_empty():
		return false

	if candidate_node.has_method("is_encryption_remote"):
		return bool(candidate_node.call("is_encryption_remote"))

	if candidate_node.has_method("is_objective_encryption_remote"):
		return bool(candidate_node.call("is_objective_encryption_remote"))

	var current_weapon_id_value: Variant = candidate_node.get("current_weapon_id")
	if current_weapon_id_value != null and str(current_weapon_id_value) == required_weapon_id:
		return true

	var editor_weapon_id_value: Variant = candidate_node.get("editor_weapon_id")
	if editor_weapon_id_value != null and str(editor_weapon_id_value) == required_weapon_id:
		return true

	return false


func _try_connect_remote_lost_signal(remote_node: Node) -> void:
	if remote_node == null:
		return

	_try_connect_signal(remote_node, "lost", Callable(self, "_on_remote_lost"))
	_try_connect_signal(remote_node, "tree_exiting", Callable(self, "_on_remote_tree_exiting").bind(remote_node))


func _consume_active_remote_if_needed() -> void:
	if not consume_remote_on_complete:
		return

	if _active_remote == null or not is_instance_valid(_active_remote):
		return

	if _active_remote.has_method("despawn"):
		_active_remote.call("despawn")
	else:
		_active_remote.queue_free()


func _disable_activation_area() -> void:
	if _activation_area == null:
		return

	_activation_area.set_deferred("monitoring", false)


func _update_countdown_label() -> void:
	if _countdown_label == null:
		return

	if is_completed:
		_countdown_label.text = completed_label_text
		_countdown_label.show()
		return

	if is_counting_down:
		_countdown_label.text = "%.1f" % maxf(remaining_seconds, 0.0)
		_countdown_label.show()
		return

	if show_countdown_label_when_idle:
		_countdown_label.text = idle_label_text
		_countdown_label.show()
	else:
		_countdown_label.hide()


func _deferred_register_objective() -> void:
	if not is_inside_tree():
		return

	var tree: SceneTree = get_tree()
	if tree == null:
		return

	var objective_key: String = get_objective_id()
	if objective_key.strip_edges().is_empty():
		return

	_is_registered = true
	objective_registered.emit(objective_key, objective_text)

	_safe_call_player_huds("register_objective", [objective_key, objective_text, is_completed])
	_safe_call_player_huds("set_objective_completed", [objective_key, is_completed])
	_safe_call_player_huds("update_objective_status", [objective_key, is_completed])


func _try_connect_signal(source: Object, signal_name: String, target_callable: Callable) -> void:
	if source == null:
		return
	if not source.has_signal(signal_name):
		return
	if source.is_connected(signal_name, target_callable):
		return

	source.connect(signal_name, target_callable)


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


func _has_server_authority() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true

	return multiplayer.is_server()
