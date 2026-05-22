extends NetworkRiflemanEnemy

class_name NetworkAntiTankEnemy

@export_group("Rocket Lock")
@export var laser_sight_scene: PackedScene
@export_range(0.1, 3.0, 0.05) var lock_on_duration: float = 1.15
@export_range(0.5, 6.0, 0.1) var lock_break_distance: float = 2.0
@export var keep_laser_visible_while_cooling_down: bool = false
@export_range(0.02, 0.3, 0.01) var laser_sync_interval: float = 0.06


var _laser_sight: Node3D = null
var _laser_visible: bool = false
var _is_locking: bool = false
var _lock_target: Node3D = null
var _lock_time_remaining: float = 0.0
var _lock_target_point: Vector3 = Vector3.ZERO
var _laser_sync_timer: float = 0.0


func _ready() -> void:
	is_melee_attack = false
	attack_requires_line_of_sight = true
	detection_requires_line_of_sight = true
	debug_logs = false
	attack_debug_logs = false
	use_enemy_target_manager = true
	state_send_interval = 0.2
	attack_check_interval_frames = maxi(attack_check_interval_frames, 8)
	super._ready()
	_create_laser_sight_local()


func _exit_tree() -> void:
	_clear_lock(false)
	if _laser_sight != null and is_instance_valid(_laser_sight):
		_laser_sight.queue_free()
	super._exit_tree()


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_update_lock_timer(delta)
	super._physics_process(delta)
	_update_laser_sight()


func _update_lock_timer(delta: float) -> void:
	if not _is_locking:
		return
	if _lock_target == null or not is_instance_valid(_lock_target):
		_clear_lock(true)
		return
	if current_state != EnemyState.ATTACK:
		_clear_lock(true)
		return
	if global_position.distance_squared_to(_lock_target.global_position) > (attack_range + lock_break_distance) * (attack_range + lock_break_distance):
		_clear_lock(true)
		return
	_lock_time_remaining = maxf(_lock_time_remaining - delta, 0.0)
	_lock_target_point = _get_target_aim_point(_lock_target)


func _perform_attack(combat_target: Node3D, target_point: Vector3) -> bool:
	if projectile_scene == null:
		_attack_debug("rocket attack blocked: projectile_scene is null")
		return false
	if combat_target == null or not is_instance_valid(combat_target):
		_clear_lock(true)
		return false

	if not _is_locking or _lock_target != combat_target:
		_start_lock(combat_target, target_point)
		return false

	_lock_target_point = target_point
	if _lock_time_remaining > 0.0:
		return false

	_clear_lock(true)
	return super._perform_attack(combat_target, target_point)


func _start_lock(target: Node3D, target_point: Vector3) -> void:
	_is_locking = true
	_lock_target = target
	_lock_time_remaining = maxf(lock_on_duration, 0.05)
	_lock_target_point = target_point
	_set_laser_visible_local(true)
	_set_laser_visible_remote.rpc(true)


func _clear_lock(sync_remote: bool) -> void:
	_is_locking = false
	_lock_target = null
	_lock_time_remaining = 0.0
	if not keep_laser_visible_while_cooling_down:
		_set_laser_visible_local(false)
		if sync_remote:
			_set_laser_visible_remote.rpc(false)


func _create_laser_sight_local() -> void:
	if laser_sight_scene == null:
		return
	if _laser_sight != null and is_instance_valid(_laser_sight):
		return
	_laser_sight = laser_sight_scene.instantiate() as Node3D
	if _laser_sight == null:
		return
	get_tree().current_scene.add_child(_laser_sight)
	_set_laser_visible_local(false)


func _set_laser_visible_local(active: bool) -> void:
	_laser_visible = active
	if _laser_sight == null or not is_instance_valid(_laser_sight):
		return
	if _laser_sight.has_method("set_laser_visible"):
		_laser_sight.call("set_laser_visible", active)
	else:
		_laser_sight.visible = active


func _update_laser_sight() -> void:
	if not _laser_visible:
		return
	if _laser_sight == null or not is_instance_valid(_laser_sight):
		_create_laser_sight_local()
	if _laser_sight == null or not is_instance_valid(_laser_sight):
		return

	var start_position: Vector3 = muzzle.global_position if muzzle != null else global_position + Vector3.UP * aim_height
	var end_position: Vector3 = aim_target_position
	if multiplayer.is_server() and _lock_target != null and is_instance_valid(_lock_target):
		end_position = _lock_target_point

	if _laser_sight.has_method("set_laser_segment"):
		_laser_sight.call("set_laser_segment", start_position, end_position)

	# Clients do not always have the exact lock target point.
	# Sync the rendered laser segment explicitly so the warning beam is visible in multiplayer.
	if multiplayer.is_server():
		_laser_sync_timer -= get_physics_process_delta_time()
		if _laser_sync_timer <= 0.0:
			_laser_sync_timer = maxf(laser_sync_interval, 0.02)
			_sync_laser_segment_remote.rpc(start_position, end_position)


func _die(damage_source: Node = null) -> void:
	_clear_lock(true)
	super._die(damage_source)


@rpc("authority", "call_remote", "reliable")
func _set_laser_visible_remote(active: bool) -> void:
	if multiplayer.is_server():
		return
	_create_laser_sight_local()
	_set_laser_visible_local(active)


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_laser_segment_remote(start_position: Vector3, end_position: Vector3) -> void:
	if multiplayer.is_server():
		return
	_create_laser_sight_local()
	_set_laser_visible_local(true)
	if _laser_sight != null and is_instance_valid(_laser_sight) and _laser_sight.has_method("set_laser_segment"):
		_laser_sight.call("set_laser_segment", start_position, end_position)
