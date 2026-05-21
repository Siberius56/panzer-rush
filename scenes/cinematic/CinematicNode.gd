extends Node3D
class_name CinematicNode

signal cinematic_started
signal cinematic_finished

@export_group("Trigger")
@export var watched_node_path: NodePath
@export var watched_signal_name: StringName = &"objectif_completed"
@export var trigger_only_once: bool = true

@export_group("Animation")
@export var cinematic_animation_name: StringName = &"cinematic"
@export var fade_duration: float = 0.35
@export var black_screen_hold_duration: float = 0.05

@export_group("Players")
@export var make_players_invulnerable: bool = true
@export var player_groups: Array[String] = ["players", "player", "network_players"]

@onready var cinematic_camera: Camera3D = %CinematicCamera
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var fade_rect: ColorRect = %FadeRect

var _watched_node: Node = null
var _is_playing: bool = false
var _has_played: bool = false
var _previous_camera: Camera3D = null
var _fade_tween: Tween = null
var _tracked_invulnerable_players: Array[Node] = []
var _saved_player_damage_states: Dictionary = {}


func _ready() -> void:
	_configure_fade_rect()
	call_deferred("_connect_to_watched_node")


func _configure_fade_rect() -> void:
	if fade_rect == null:
		return

	fade_rect.visible = false
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	fade_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _connect_to_watched_node() -> void:
	if watched_node_path.is_empty():
		push_warning("CinematicNode: aucun watched_node_path n'est défini.")
		return

	_watched_node = get_node_or_null(watched_node_path)
	if _watched_node == null:
		push_warning("CinematicNode: le node à surveiller est introuvable: %s" % str(watched_node_path))
		return

	if not _watched_node.has_signal(watched_signal_name):
		push_warning("CinematicNode: le node %s ne possède pas le signal %s." % [_watched_node.name, str(watched_signal_name)])
		return

	var completed_callable: Callable = Callable(self, "_on_watched_objective_completed")
	if not _watched_node.is_connected(watched_signal_name, completed_callable):
		_watched_node.connect(watched_signal_name, completed_callable)


func _on_watched_objective_completed(_objective_id: String = "") -> void:
	play_cinematic()


func play_cinematic() -> void:
	if _is_playing:
		return
	if trigger_only_once and _has_played:
		return

	_has_played = true
	_is_playing = true
	_previous_camera = get_viewport().get_camera_3d()
	cinematic_started.emit()

	if make_players_invulnerable:
		_set_players_cinematic_invulnerable(true)

	await _fade_to_alpha(1.0)
	_set_cinematic_camera_current()
	await _wait_black_screen_hold()
	await _fade_to_alpha(0.0)
	await _play_cinematic_animation()
	await _fade_to_alpha(1.0)
	_restore_previous_camera()
	await _wait_black_screen_hold()
	await _fade_to_alpha(0.0)

	if make_players_invulnerable:
		_set_players_cinematic_invulnerable(false)

	_is_playing = false
	cinematic_finished.emit()


func _set_cinematic_camera_current() -> void:
	if cinematic_camera == null:
		return

	cinematic_camera.current = true


func _restore_previous_camera() -> void:
	if _previous_camera != null and is_instance_valid(_previous_camera):
		_previous_camera.current = true
		return

	var fallback_camera: Camera3D = _find_fallback_player_camera()
	if fallback_camera != null:
		fallback_camera.current = true


func _find_fallback_player_camera() -> Camera3D:
	var candidates: Array[Node] = _collect_player_nodes()
	for candidate: Node in candidates:
		var camera: Camera3D = _find_camera_in_node(candidate)
		if camera != null:
			return camera

	return null


func _find_camera_in_node(root: Node) -> Camera3D:
	if root == null or not is_instance_valid(root):
		return null

	if root is Camera3D:
		return root as Camera3D

	for child: Node in root.get_children():
		var camera: Camera3D = _find_camera_in_node(child)
		if camera != null:
			return camera

	return null


func _wait_black_screen_hold() -> void:
	var duration: float = max(black_screen_hold_duration, 0.0)
	if duration <= 0.0:
		await get_tree().process_frame
		return

	await get_tree().create_timer(duration).timeout


func _fade_to_alpha(target_alpha: float) -> void:
	if fade_rect == null:
		return

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	fade_rect.visible = true
	_fade_tween = create_tween()
	_fade_tween.tween_property(
		fade_rect,
		"modulate:a",
		clamp(target_alpha, 0.0, 1.0),
		max(fade_duration, 0.01)
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	await _fade_tween.finished

	if target_alpha <= 0.0:
		fade_rect.visible = false


func _play_cinematic_animation() -> void:
	if animation_player == null:
		await get_tree().process_frame
		return

	if not animation_player.has_animation(cinematic_animation_name):
		push_warning("CinematicNode: l'animation %s est absente de l'AnimationPlayer." % str(cinematic_animation_name))
		await get_tree().process_frame
		return

	animation_player.play(cinematic_animation_name)
	while true:
		var finished_animation: StringName = await animation_player.animation_finished
		if finished_animation == cinematic_animation_name:
			break


func _set_players_cinematic_invulnerable(enabled: bool) -> void:
	if enabled:
		var players: Array[Node] = _collect_player_nodes()
		_tracked_invulnerable_players.clear()
		_saved_player_damage_states.clear()

		for player_node: Node in players:
			_tracked_invulnerable_players.append(player_node)
			_apply_cinematic_invulnerability(player_node, true)
		return

	for player_node: Node in _tracked_invulnerable_players:
		if player_node == null or not is_instance_valid(player_node):
			continue
		_apply_cinematic_invulnerability(player_node, false)

	_tracked_invulnerable_players.clear()
	_saved_player_damage_states.clear()


func _collect_player_nodes() -> Array[Node]:
	var result: Array[Node] = []
	var seen_ids: Dictionary = {}

	for group_name: String in player_groups:
		if group_name.strip_edges().is_empty():
			continue

		var group_nodes: Array[Node] = get_tree().get_nodes_in_group(group_name)
		for node: Node in group_nodes:
			_add_unique_player_node(node, result, seen_ids)

	var hud_nodes: Array[Node] = get_tree().get_nodes_in_group("player_huds")
	for hud: Node in hud_nodes:
		if hud == null or not is_instance_valid(hud):
			continue
		if not hud.has_method("get_player"):
			continue

		var hud_player: Variant = hud.call("get_player")
		if hud_player is Node:
			_add_unique_player_node(hud_player as Node, result, seen_ids)

	return result


func _add_unique_player_node(node: Node, result: Array[Node], seen_ids: Dictionary) -> void:
	if node == null or not is_instance_valid(node):
		return

	var instance_id: int = node.get_instance_id()
	if seen_ids.has(instance_id):
		return

	seen_ids[instance_id] = true
	result.append(node)


func _apply_cinematic_invulnerability(player_node: Node, enabled: bool) -> void:
	if player_node == null or not is_instance_valid(player_node):
		return

	player_node.set_meta("cinematic_invulnerable", enabled)
	_call_invulnerability_methods(player_node, enabled)
	_apply_invulnerability_properties(player_node, enabled)


func _call_invulnerability_methods(player_node: Node, enabled: bool) -> void:
	var true_methods: Array[String] = [
		"set_cinematic_invulnerable",
		"set_cutscene_invulnerable",
		"set_invulnerable",
	]
	for method_name: String in true_methods:
		if player_node.has_method(method_name):
			player_node.call(method_name, enabled)

	var false_methods: Array[String] = [
		"set_damage_enabled",
		"set_can_take_damage",
	]
	for method_name: String in false_methods:
		if player_node.has_method(method_name):
			player_node.call(method_name, not enabled)


func _apply_invulnerability_properties(player_node: Node, enabled: bool) -> void:
	var instance_id: int = player_node.get_instance_id()
	var saved_state: Dictionary = _saved_player_damage_states.get(instance_id, {})

	var true_when_enabled: Array[String] = [
		"cinematic_invulnerable",
		"cutscene_invulnerable",
		"invulnerable",
		"is_invulnerable",
		"god_mode",
	]
	var false_when_enabled: Array[String] = [
		"can_take_damage",
		"damage_enabled",
		"receives_damage",
	]

	for property_name: String in true_when_enabled:
		_apply_property_override(player_node, saved_state, property_name, enabled, enabled)

	for property_name: String in false_when_enabled:
		_apply_property_override(player_node, saved_state, property_name, not enabled, enabled)

	if enabled:
		_saved_player_damage_states[instance_id] = saved_state


func _apply_property_override(player_node: Node, saved_state: Dictionary, property_name: String, value: bool, enabled: bool) -> void:
	if not (property_name in player_node):
		return

	if enabled:
		if not saved_state.has(property_name):
			saved_state[property_name] = player_node.get(property_name)
		player_node.set(property_name, value)
		return

	var instance_id: int = player_node.get_instance_id()
	var previous_state: Dictionary = _saved_player_damage_states.get(instance_id, {})
	if previous_state.has(property_name):
		player_node.set(property_name, previous_state[property_name])
