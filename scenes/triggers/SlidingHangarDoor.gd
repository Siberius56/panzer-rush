extends Node3D
class_name SlidingHangarDoor

signal opening_started
signal closing_started
signal opened
signal closed
signal state_changed(is_open: bool)

@export_group("Door nodes")
@export var left_panel_path: NodePath = ^"LeftDoor"
@export var right_panel_path: NodePath = ^"RightDoor"

@export_group("Door positions")
@export var positions_are_offsets_from_editor_position: bool = true
@export var left_closed_position: Vector3 = Vector3.ZERO
@export var right_closed_position: Vector3 = Vector3.ZERO
@export var left_open_position: Vector3 = Vector3(-2.8, 0.0, 0.0)
@export var right_open_position: Vector3 = Vector3(2.8, 0.0, 0.0)

@export_group("Start state")
@export var start_open: bool = false
@export var apply_start_state_on_ready: bool = true

@export_group("Animation")
@export_range(0.0, 10.0, 0.05) var animation_duration: float = 0.45
@export var tween_transition: Tween.TransitionType = Tween.TRANS_SINE
@export var tween_ease: Tween.EaseType = Tween.EASE_IN_OUT

@export_group("Orientation")
@export var lock_editor_orientation: bool = true
@export var debug_orientation_lock: bool = false

@onready var left_panel: Node3D = get_node_or_null(left_panel_path) as Node3D
@onready var right_panel: Node3D = get_node_or_null(right_panel_path) as Node3D

var _left_editor_position: Vector3 = Vector3.ZERO
var _right_editor_position: Vector3 = Vector3.ZERO

var _root_editor_rotation: Vector3 = Vector3.ZERO
var _root_editor_scale: Vector3 = Vector3.ONE
var _left_editor_rotation: Vector3 = Vector3.ZERO
var _left_editor_scale: Vector3 = Vector3.ONE
var _right_editor_rotation: Vector3 = Vector3.ZERO
var _right_editor_scale: Vector3 = Vector3.ONE

var _is_open: bool = false
var _is_animating: bool = false
var _active_tween: Tween = null


func _ready() -> void:
	_cache_editor_transform_values()
	force_editor_orientation()

	if apply_start_state_on_ready:
		set_open(start_open, true)
	else:
		_is_open = start_open


func open(immediate: bool = false) -> void:
	set_open(true, immediate)


func close(immediate: bool = false) -> void:
	set_open(false, immediate)


func toggle(immediate: bool = false) -> void:
	set_open(not _is_open, immediate)


func set_open(value: bool, immediate: bool = false) -> void:
	if left_panel == null and right_panel == null:
		return

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
		_active_tween = null

	force_editor_orientation()

	_is_open = value
	_is_animating = not immediate and animation_duration > 0.0

	var left_target_position: Vector3 = _get_left_target_position(value)
	var right_target_position: Vector3 = _get_right_target_position(value)

	if value:
		opening_started.emit()
	else:
		closing_started.emit()

	state_changed.emit(_is_open)

	if immediate or animation_duration <= 0.0:
		_apply_panel_positions(left_target_position, right_target_position)
		force_editor_orientation()
		_is_animating = false
		_emit_finished_signal(value)
		return

	var tween: Tween = create_tween()
	_active_tween = tween
	tween.set_parallel(true)
	tween.set_trans(tween_transition)
	tween.set_ease(tween_ease)

	if left_panel != null:
		tween.tween_property(left_panel, "position", left_target_position, animation_duration)

	if right_panel != null:
		tween.tween_property(right_panel, "position", right_target_position, animation_duration)

	tween.finished.connect(_on_tween_finished.bind(value))


func snap_open() -> void:
	set_open(true, true)


func snap_closed() -> void:
	set_open(false, true)


func is_open() -> bool:
	return _is_open


func is_closed() -> bool:
	return not _is_open


func is_animating() -> bool:
	return _is_animating


func force_editor_orientation() -> void:
	if not lock_editor_orientation:
		return

	rotation = _root_editor_rotation
	scale = _root_editor_scale

	if left_panel != null and is_instance_valid(left_panel):
		left_panel.rotation = _left_editor_rotation
		left_panel.scale = _left_editor_scale

	if right_panel != null and is_instance_valid(right_panel):
		right_panel.rotation = _right_editor_rotation
		right_panel.scale = _right_editor_scale

	if debug_orientation_lock:
		print("[SlidingHangarDoor] Orientation restaurée : ", get_path())


func _cache_editor_transform_values() -> void:
	_root_editor_rotation = rotation
	_root_editor_scale = scale

	if left_panel != null:
		_left_editor_position = left_panel.position
		_left_editor_rotation = left_panel.rotation
		_left_editor_scale = left_panel.scale

	if right_panel != null:
		_right_editor_position = right_panel.position
		_right_editor_rotation = right_panel.rotation
		_right_editor_scale = right_panel.scale


func _apply_panel_positions(left_target_position: Vector3, right_target_position: Vector3) -> void:
	if left_panel != null:
		left_panel.position = left_target_position

	if right_panel != null:
		right_panel.position = right_target_position

	force_editor_orientation()


func _get_left_target_position(to_opened: bool) -> Vector3:
	var configured_position: Vector3 = left_closed_position
	if to_opened:
		configured_position = left_open_position

	if positions_are_offsets_from_editor_position:
		return _left_editor_position + configured_position

	return configured_position


func _get_right_target_position(to_opened: bool) -> Vector3:
	var configured_position: Vector3 = right_closed_position
	if to_opened:
		configured_position = right_open_position

	if positions_are_offsets_from_editor_position:
		return _right_editor_position + configured_position

	return configured_position


func _on_tween_finished(is_now_open: bool) -> void:
	_is_animating = false
	_active_tween = null
	force_editor_orientation()
	_emit_finished_signal(is_now_open)


func _emit_finished_signal(is_now_open: bool) -> void:
	if is_now_open:
		opened.emit()
	else:
		closed.emit()
