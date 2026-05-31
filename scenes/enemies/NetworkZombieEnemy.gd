extends NetworkEnemyBase

class_name NetworkZombieEnemy

@export_group("Zombie Melee")
@export var melee_hit_source_name: String = "zombie"

@export_group("Zombie Horde Performance")
@export var zombie_disable_navigation: bool = false
@export var zombie_disable_detection_area: bool = true
@export var zombie_disable_enemy_separation: bool = false
@export var zombie_use_simplified_server_ai: bool = true
@export var zombie_use_simple_translation: bool = false
@export var zombie_lock_y_to_origin_height: bool = false
@export var zombie_force_direct_move_distance: float = 2.5
@export_range(1, 30, 1) var zombie_procedural_update_interval_frames: int = 1
@export_range(1, 120, 1) var zombie_target_recheck_interval_frames: int = 45
@export_range(1, 120, 1) var zombie_attack_recheck_interval_frames: int = 20

@export_group("Zombie Occasional Navigation")
@export var zombie_use_occasional_navigation: bool = true
@export_range(15, 300, 1) var zombie_nav_sample_interval_frames: int = 30
@export_range(1, 60, 1) var zombie_nav_next_position_interval_frames: int = 6
@export var zombie_nav_direct_distance: float = 4.0
@export var zombie_nav_target_repath_distance: float = 1.0
@export var zombie_nav_waypoint_reach_distance: float = 1.0
@export_range(0.1, 2.0, 0.05) var zombie_nav_waypoint_stop_distance: float = 0.45
@export_range(0.1, 3.0, 0.05) var zombie_nav_tiny_waypoint_distance: float = 0.35
@export_range(6, 240, 1) var zombie_nav_cached_waypoint_max_age_frames: int = 60
@export_range(0.5, 8.0, 0.1) var zombie_nav_long_waypoint_distance: float = 2.5
@export_range(6, 240, 1) var zombie_nav_long_waypoint_min_age_frames: int = 45

@export_group("Zombie Surround Slots")
@export var zombie_use_surround_slots: bool = true
@export_range(0.4, 5.0, 0.05) var zombie_attack_ring_radius: float = 1.45
@export_range(0.4, 8.0, 0.05) var zombie_chase_ring_radius: float = 2.2
@export_range(0.0, 2.0, 0.05) var zombie_surround_ring_spacing: float = 0.55
@export_range(1, 8, 1) var zombie_surround_ring_count: int = 4
@export_range(0.0, 4.0, 0.05) var zombie_vehicle_surround_extra_radius: float = 0.25
@export_range(0.0, 4.0, 0.05) var zombie_vehicle_chase_extra_radius: float = 0.65
@export_range(0.0, 4.0, 0.05) var zombie_vehicle_melee_range_bonus: float = 1.35
@export_range(0.05, 2.0, 0.05) var zombie_surround_slot_stop_distance: float = 0.35
@export_range(1.0, 20.0, 0.5) var zombie_surround_start_distance: float = 10.0

@export_group("Zombie Approach Separation")
@export var zombie_use_approach_spread: bool = true
@export_range(0.0, 8.0, 0.05) var zombie_approach_spread_radius: float = 2.4
@export_range(0.0, 8.0, 0.05) var zombie_approach_vehicle_extra_radius: float = 0.35
@export_range(0.0, 1.0, 0.05) var zombie_approach_ring_spacing_scale: float = 0.85

@export_group("Zombie Light Separation")
@export var zombie_use_light_separation: bool = true
@export_range(1, 120, 1) var zombie_light_separation_interval_frames: int = 4
@export_range(0.2, 4.0, 0.05) var zombie_light_separation_radius: float = 1.65
@export_range(0.0, 8.0, 0.1) var zombie_light_separation_strength: float = 1.1
@export_range(0.0, 6.0, 0.1) var zombie_light_separation_max_velocity: float = 1.0
@export_range(0.0, 30.0, 0.1) var zombie_light_separation_decay: float = 4.5
@export_range(0.0, 1.0, 0.05) var zombie_light_separation_smoothing: float = 0.35
@export_range(0.0, 1.0, 0.05) var zombie_light_separation_forward_cancel: float = 0.25
@export_range(1, 24, 1) var zombie_light_separation_max_neighbors: int = 12

var _zombie_visual_delta_accumulator: float = 0.0
var _zombie_visual_frame_offset: int = 0
var _zombie_target_frame_offset: int = 0
var _zombie_attack_frame_offset: int = 0
var _zombie_nav_sample_frame_offset: int = 0
var _zombie_nav_next_frame_offset: int = 0
var _zombie_separation_frame_offset: int = 0
var _zombie_cached_nav_waypoint: Vector3 = Vector3.ZERO
var _zombie_has_cached_nav_waypoint: bool = false
var _zombie_cached_nav_waypoint_frame: int = 0
var _zombie_cached_nav_waypoint_start_distance: float = 0.0
var _zombie_last_nav_target_position: Vector3 = Vector3.ZERO
var _zombie_has_nav_target_position: bool = false
var _zombie_light_separation_velocity: Vector3 = Vector3.ZERO
var _zombie_surround_angle: float = 0.0
var _zombie_surround_ring_index: int = 0
var _zombie_surround_radius_scale: float = 1.0


func _ready() -> void:
	is_melee_attack = true
	projectile_scene = null
	detection_requires_line_of_sight = false
	attack_requires_line_of_sight = false
	death_weapon_enabled = false
	debug_logs = false
	attack_debug_logs = false
	use_enemy_target_manager = true
	use_direct_move_when_close = true
	direct_move_distance = zombie_force_direct_move_distance
	throttle_path_target_updates = true
	state_send_interval = 0.25
	scan_interval_frames = max(scan_interval_frames, 45)
	repath_interval_frames = max(repath_interval_frames, 60)
	attack_check_interval_frames = max(attack_check_interval_frames, 20)

	if zombie_use_occasional_navigation:
		zombie_disable_navigation = false

	if zombie_use_light_separation:
		zombie_disable_enemy_separation = false
		enemy_separation_enabled = true
	else:
		enemy_separation_enabled = false

	if zombie_disable_enemy_separation:
		enemy_separation_enabled = false

	super._ready()

	var instance_offset: int = int(get_instance_id())
	_zombie_visual_frame_offset = instance_offset % max(zombie_procedural_update_interval_frames, 1)
	_zombie_target_frame_offset = instance_offset % max(zombie_target_recheck_interval_frames, 1)
	_zombie_attack_frame_offset = instance_offset % max(zombie_attack_recheck_interval_frames, 1)
	_zombie_nav_sample_frame_offset = instance_offset % max(zombie_nav_sample_interval_frames, 1)
	_zombie_nav_next_frame_offset = instance_offset % max(zombie_nav_next_position_interval_frames, 1)
	_zombie_separation_frame_offset = instance_offset % max(zombie_light_separation_interval_frames, 1)

	_configure_zombie_surround_slot(instance_offset)
	_configure_zombie_horde_performance()
	_configure_zombie_arm_pose()


func _configure_zombie_surround_slot(instance_offset: int) -> void:
	# Golden-angle distribution. Deterministic, stable, and cheap.
	# Avoids all zombies aiming at the exact same center point.
	var golden_angle: float = 2.39996323
	_zombie_surround_angle = fmod(float(instance_offset) * golden_angle, TAU)
	_zombie_surround_ring_index = int(abs(instance_offset)) % max(zombie_surround_ring_count, 1)
	var radius_noise_index: int = int(abs(float(instance_offset) / 17)) % 31
	_zombie_surround_radius_scale = 0.88 + float(radius_noise_index) / 31.0 * 0.24


func _configure_zombie_horde_performance() -> void:
	if zombie_disable_enemy_separation:
		enemy_separation_enabled = false

	if navigation_agent != null:
		# Do not enable NavigationAgent avoidance for hordes.
		# Path sampling is cheap enough when staggered. Avoidance is not.
		navigation_agent.avoidance_enabled = false
		navigation_agent.path_desired_distance = maxf(zombie_nav_waypoint_reach_distance, 0.1)
		navigation_agent.target_desired_distance = maxf(attack_range, 0.1)

	if zombie_disable_detection_area and detection_area != null:
		detection_area.monitoring = false
		detection_area.monitorable = false


func _server_update(delta: float) -> void:
	if not zombie_use_simplified_server_ai:
		super._server_update(delta)
		return

	if _dying:
		return

	if attack_timer > 0.0:
		attack_timer -= delta

	if _process_transport_spawn_deployment(delta):
		move_and_slide()
		_update_enemy_procedural_animation(delta)
		_send_server_state(delta)
		return

	if _process_vehicle_impact_stun(delta):
		move_and_slide()
		_update_enemy_procedural_animation(delta)
		_send_server_state(delta)
		return

	_simplified_zombie_targeting()
	_simplified_zombie_combat()
	_update_zombie_light_separation(delta)
	_simplified_zombie_move(delta)
	_send_server_state(delta)
	_update_enemy_procedural_animation(delta)


func _simplified_zombie_targeting() -> void:
	# Hot path fix.
	# The previous version validated the current target every physics frame.
	# That called _is_valid_target -> _is_target_dead -> _safe_get_property for every zombie.
	# With 80 zombies, this dominated the profiler. We now validate only on a staggered interval.
	var frame: int = int(Engine.get_physics_frames())
	var interval: int = max(zombie_target_recheck_interval_frames, 1)
	var should_recheck: bool = current_target == null or frame % interval == _zombie_target_frame_offset

	if not should_recheck:
		if current_target != null and is_instance_valid(current_target):
			_has_last_known_target_position = true
			_last_known_target_position = current_target.global_position
		return

	if current_target != null:
		if not _is_zombie_target_valid_fast(current_target):
			current_target = null
		elif _should_validate_target_distance() and global_position.distance_squared_to(current_target.global_position) > max_target_distance * max_target_distance:
			current_target = null

	if current_target == null:
		current_target = _find_nearest_target(_get_target_search_distance())

	if current_target != null:
		_has_last_known_target_position = true
		_last_known_target_position = current_target.global_position


func _simplified_zombie_combat() -> void:
	if current_target == null or not is_instance_valid(current_target):
		current_target = null
		_set_state(EnemyState.IDLE)
		velocity.x = 0.0
		velocity.z = 0.0
		_update_idle_aim_target()
		return

	# Zombie targets come from EnemyTargetManager. Do not call _get_combat_target() here.
	# _get_combat_target() searches player vehicle properties and is too expensive for hordes.
	var combat_target: Node3D = current_target
	var target_position: Vector3 = combat_target.global_position
	var target_point: Vector3 = target_position + Vector3.UP * aim_height
	aim_target_position = target_point
	last_valid_aim_target_position = target_point
	_face_target(target_point)

	var effective_attack_range: float = _get_zombie_effective_attack_range(combat_target)
	var attack_range_squared: float = effective_attack_range * effective_attack_range
	var distance_squared: float = global_position.distance_squared_to(target_position)
	var desired_move_position: Vector3 = _get_zombie_surround_position(combat_target, distance_squared)
	var slot_stop_distance: float = maxf(zombie_surround_slot_stop_distance, 0.05)
	var slot_distance_squared: float = global_position.distance_squared_to(desired_move_position)
	var slot_stop_distance_squared: float = slot_stop_distance * slot_stop_distance

	if distance_squared <= attack_range_squared:
		_set_state(EnemyState.ATTACK)

		# Do not freeze every zombie at the exact same target center.
		# They can still attack while adjusting toward their personal ring slot.
		if zombie_use_surround_slots and slot_distance_squared > slot_stop_distance_squared:
			_move_zombie_towards_target(desired_move_position, slot_stop_distance)
		else:
			velocity.x = 0.0
			velocity.z = 0.0

		var frame: int = int(Engine.get_physics_frames())
		var can_check_attack: bool = frame % max(zombie_attack_recheck_interval_frames, 1) == _zombie_attack_frame_offset
		if can_check_attack:
			_try_attack(combat_target, target_point)
		return

	_set_state(EnemyState.CHASE)
	_move_zombie_towards_target(desired_move_position, slot_stop_distance)


func _get_zombie_surround_position(target: Node3D, distance_squared_to_target: float) -> Vector3:
	if not zombie_use_surround_slots or target == null or not is_instance_valid(target):
		return target.global_position if target != null else global_position

	var target_position: Vector3 = target.global_position
	var start_distance: float = maxf(zombie_surround_start_distance, 0.1)
	if distance_squared_to_target > start_distance * start_distance:
		return _get_zombie_approach_spread_position(target)

	var base_radius: float = zombie_chase_ring_radius
	var effective_attack_range: float = _get_zombie_effective_attack_range(target)
	var is_near_attack_distance: bool = distance_squared_to_target <= effective_attack_range * effective_attack_range * 4.0
	if is_near_attack_distance:
		base_radius = zombie_attack_ring_radius

	if _is_zombie_vehicle_target(target):
		# Vehicles usually have their origin near the center of the body.
		# A large extra ring prevents melee from ever reaching the effective attack distance.
		# Keep a wider approach/chase radius, but a tight attack radius.
		if is_near_attack_distance:
			base_radius += zombie_vehicle_surround_extra_radius
		else:
			base_radius += zombie_vehicle_chase_extra_radius

	var ring_count: int = max(zombie_surround_ring_count, 1)
	var ring_index: int = clampi(_zombie_surround_ring_index, 0, ring_count - 1)
	var radius: float = (base_radius + float(ring_index) * zombie_surround_ring_spacing) * _zombie_surround_radius_scale
	var offset: Vector3 = Vector3(cos(_zombie_surround_angle), 0.0, sin(_zombie_surround_angle)) * radius
	return target_position + offset


func _get_zombie_approach_spread_position(target: Node3D) -> Vector3:
	if not zombie_use_approach_spread or target == null or not is_instance_valid(target):
		return target.global_position if target != null else global_position

	var base_radius: float = zombie_approach_spread_radius
	if _is_zombie_vehicle_target(target):
		base_radius += zombie_approach_vehicle_extra_radius

	var ring_spacing: float = zombie_surround_ring_spacing * zombie_approach_ring_spacing_scale
	var ring_index: int = clampi(_zombie_surround_ring_index, 0, max(zombie_surround_ring_count, 1) - 1)
	var radius: float = (base_radius + float(ring_index) * ring_spacing) * _zombie_surround_radius_scale
	var offset: Vector3 = Vector3(cos(_zombie_surround_angle), 0.0, sin(_zombie_surround_angle)) * radius
	return target.global_position + offset


func _move_towards_direct_flat(target_position: Vector3, stop_distance: float = 0.0) -> void:
	var to_target: Vector3 = target_position - global_position
	to_target.y = 0.0

	var stop_distance_squared: float = stop_distance * stop_distance
	if to_target.length_squared() <= stop_distance_squared:
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var direction: Vector3 = to_target.normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed


func _move_zombie_towards_target(target_position: Vector3, stop_distance: float = 0.0) -> void:
	if not zombie_use_occasional_navigation or zombie_disable_navigation or navigation_agent == null:
		_move_towards_direct_flat(target_position, stop_distance)
		return

	var flat_target: Vector3 = target_position
	flat_target.y = global_position.y

	var to_target: Vector3 = flat_target - global_position
	to_target.y = 0.0
	var distance_squared: float = to_target.length_squared()
	var stop_distance_squared: float = stop_distance * stop_distance
	if distance_squared <= stop_distance_squared:
		velocity.x = 0.0
		velocity.z = 0.0
		_clear_zombie_cached_navigation()
		return

	# Close range should stay direct. This prevents the agent from orbiting tiny
	# path points around the target or around its personal surround slot.
	var direct_distance: float = maxf(zombie_nav_direct_distance, stop_distance + 0.1)
	if distance_squared <= direct_distance * direct_distance:
		_clear_zombie_cached_navigation()
		_move_towards_direct_flat(flat_target, stop_distance)
		return

	var frame: int = int(Engine.get_physics_frames())
	var sample_interval: int = max(zombie_nav_sample_interval_frames, 1)
	var repath_distance: float = maxf(zombie_nav_target_repath_distance, 0.1)
	var target_moved_enough: bool = not _zombie_has_nav_target_position or _zombie_last_nav_target_position.distance_squared_to(flat_target) >= repath_distance * repath_distance
	var must_sample_path: bool = target_moved_enough or not _zombie_has_cached_nav_waypoint or frame % sample_interval == _zombie_nav_sample_frame_offset
	var must_sample_next: bool = not _zombie_has_cached_nav_waypoint

	var reach_distance: float = maxf(zombie_nav_waypoint_reach_distance, 0.1)
	var waypoint_age_frames: int = frame - _zombie_cached_nav_waypoint_frame
	var waypoint_max_age_frames: int = max(zombie_nav_cached_waypoint_max_age_frames, 1)
	var long_waypoint_distance: float = maxf(zombie_nav_long_waypoint_distance, 0.1)
	var long_waypoint_min_age_frames: int = max(zombie_nav_long_waypoint_min_age_frames, 1)
	var is_long_waypoint: bool = _zombie_cached_nav_waypoint_start_distance >= long_waypoint_distance
	var can_refresh_cached_waypoint: bool = waypoint_age_frames >= waypoint_max_age_frames
	if is_long_waypoint:
		can_refresh_cached_waypoint = waypoint_age_frames >= long_waypoint_min_age_frames

	var cached_waypoint_was_reached: bool = false
	if _zombie_has_cached_nav_waypoint:
		var waypoint_offset: Vector3 = _zombie_cached_nav_waypoint - global_position
		waypoint_offset.y = 0.0
		if waypoint_offset.length_squared() <= reach_distance * reach_distance:
			cached_waypoint_was_reached = true
			must_sample_next = true
		elif must_sample_path and can_refresh_cached_waypoint:
			must_sample_next = true

	if must_sample_path:
		navigation_agent.target_position = flat_target
		_zombie_last_nav_target_position = flat_target
		_zombie_has_nav_target_position = true

	if navigation_agent.is_navigation_finished():
		_clear_zombie_cached_navigation()
		_move_towards_direct_flat(flat_target, stop_distance)
		return

	if must_sample_next:
		var next_position: Vector3 = navigation_agent.get_next_path_position()
		next_position.y = global_position.y

		var next_offset: Vector3 = next_position - global_position
		next_offset.y = 0.0
		var tiny_distance: float = maxf(zombie_nav_tiny_waypoint_distance, 0.05)

		# If Godot gives a point nearly under the enemy, do not chase that point.
		# On a NavigationLink3D, do not clear the current path and rush directly to the target,
		# because that can make the enemy bounce between the link start and the link end.
		if next_offset.length_squared() <= tiny_distance * tiny_distance:
			if _zombie_has_cached_nav_waypoint and not cached_waypoint_was_reached:
				_move_towards_direct_flat(_zombie_cached_nav_waypoint, maxf(zombie_nav_waypoint_stop_distance, 0.1))
			else:
				_move_towards_direct_flat(flat_target, stop_distance)
			return

		_zombie_cached_nav_waypoint = next_position
		_zombie_has_cached_nav_waypoint = true
		_zombie_cached_nav_waypoint_frame = frame
		_zombie_cached_nav_waypoint_start_distance = sqrt(next_offset.length_squared())

	if _zombie_has_cached_nav_waypoint:
		var cached_offset: Vector3 = _zombie_cached_nav_waypoint - global_position
		cached_offset.y = 0.0
		var waypoint_stop_distance: float = maxf(zombie_nav_waypoint_stop_distance, 0.1)

		if cached_offset.length_squared() > waypoint_stop_distance * waypoint_stop_distance:
			_move_towards_direct_flat(_zombie_cached_nav_waypoint, waypoint_stop_distance)
		else:
			_zombie_has_cached_nav_waypoint = false
			_move_towards_direct_flat(flat_target, stop_distance)
	else:
		_move_towards_direct_flat(flat_target, stop_distance)


func _clear_zombie_cached_navigation() -> void:
	_zombie_has_cached_nav_waypoint = false
	_zombie_cached_nav_waypoint_frame = 0
	_zombie_cached_nav_waypoint_start_distance = 0.0
	_zombie_has_nav_target_position = false


func _update_zombie_light_separation(delta: float) -> void:
	if not zombie_use_light_separation or not enemy_separation_enabled or _dying:
		_zombie_light_separation_velocity = Vector3.ZERO
		return

	var frame: int = int(Engine.get_physics_frames())
	var interval: int = max(zombie_light_separation_interval_frames, 1)
	if frame % interval == _zombie_separation_frame_offset:
		_update_enemy_grid_registration(false)
		var desired_push: Vector3 = _compute_zombie_light_separation_velocity()
		var smoothing: float = clampf(zombie_light_separation_smoothing, 0.0, 1.0)
		_zombie_light_separation_velocity = _zombie_light_separation_velocity.lerp(desired_push, smoothing)
	else:
		_zombie_light_separation_velocity = _zombie_light_separation_velocity.move_toward(Vector3.ZERO, zombie_light_separation_decay * delta)

	if _zombie_light_separation_velocity.length_squared() <= 0.0001:
		return

	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var desired_direction: Vector3 = horizontal_velocity
	if desired_direction.length_squared() > 0.0001:
		desired_direction = desired_direction.normalized()
		# Keep a part of the separation lateral, but do not remove it entirely.
		# During long straight chases, zombies also need forward/back spacing.
		var forward_component: float = _zombie_light_separation_velocity.dot(desired_direction)
		var forward_cancel: float = clampf(zombie_light_separation_forward_cancel, 0.0, 1.0)
		_zombie_light_separation_velocity -= desired_direction * forward_component * forward_cancel

	velocity.x += _zombie_light_separation_velocity.x
	velocity.z += _zombie_light_separation_velocity.z

	var max_speed: float = move_speed + zombie_light_separation_max_velocity
	horizontal_velocity = Vector3(velocity.x, 0.0, velocity.z)
	if horizontal_velocity.length_squared() > max_speed * max_speed:
		horizontal_velocity = horizontal_velocity.normalized() * max_speed
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z


func _compute_zombie_light_separation_velocity() -> Vector3:
	var separation_radius: float = maxf(zombie_light_separation_radius, 0.05)
	var separation_radius_squared: float = separation_radius * separation_radius
	var push: Vector3 = Vector3.ZERO
	var checked_neighbors: int = 0
	var max_neighbors: int = max(zombie_light_separation_max_neighbors, 1)
	var nearby_enemies: Array = _get_enemy_grid_neighbors(global_position)

	for item in nearby_enemies:
		if checked_neighbors >= max_neighbors:
			break
		if item == self:
			continue
		if item == null or not is_instance_valid(item):
			continue
		if not (item is Node3D):
			continue

		var other_enemy: Node3D = item as Node3D
		var offset: Vector3 = global_position - other_enemy.global_position
		offset.y = 0.0
		var distance_squared: float = offset.length_squared()
		if distance_squared >= separation_radius_squared:
			continue

		if distance_squared <= 0.0001:
			var fallback_angle: float = _zombie_surround_angle + float(other_enemy.get_instance_id() % 997) * 0.017
			offset = Vector3(cos(fallback_angle), 0.0, sin(fallback_angle))
			distance_squared = 0.0001

		var distance: float = sqrt(distance_squared)
		var closeness: float = 1.0 - clampf(distance / separation_radius, 0.0, 1.0)
		var softened_closeness: float = closeness * closeness
		push += offset / distance * zombie_light_separation_strength * softened_closeness
		checked_neighbors += 1

	if push.length_squared() > zombie_light_separation_max_velocity * zombie_light_separation_max_velocity:
		push = push.normalized() * zombie_light_separation_max_velocity

	return push


func _simplified_zombie_move(delta: float) -> void:
	if zombie_use_simple_translation:
		var horizontal_motion: Vector3 = Vector3(velocity.x, 0.0, velocity.z) * delta
		global_position += horizontal_motion
		velocity.y = 0.0
		if zombie_lock_y_to_origin_height:
			global_position.y = _origin_position.y
		return

	_apply_gravity(delta)
	move_and_slide()


func _is_zombie_target_valid_fast(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not target.is_inside_tree():
		return false

	var target_manager: Node = _get_target_manager()
	if target_manager != null and target_manager.has_method("is_target_valid"):
		return bool(target_manager.call("is_target_valid", target))

	var dead_value: Variant = target.get("is_dead")
	if dead_value is bool:
		return not bool(dead_value)

	if target.has_method("is_alive"):
		return bool(target.call("is_alive"))

	return true


func _is_zombie_vehicle_target(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	return target.is_in_group("vehicle") or target.is_in_group("vehicles")


func _get_zombie_effective_attack_range(target: Node) -> float:
	var effective_range: float = attack_range
	if _is_zombie_vehicle_target(target):
		# The tank origin is near the center, not at the hull edge.
		# This bonus lets zombies damage it while standing close to the body
		# instead of needing to reach the origin point.
		effective_range += zombie_vehicle_melee_range_bonus
	return effective_range


func _get_attack_range() -> float:
	return attack_range


func _should_use_attack_line_of_sight() -> bool:
	return false


func _should_use_detection_line_of_sight() -> bool:
	return false


func _get_combat_target(target: Node3D) -> Node3D:
	# Zombies must not inspect player vehicle_interactor/current_vehicle every frame.
	# EnemyTargetManager already gives them a direct target.
	return target


func _acquire_target(_allow_global_scan: bool = true) -> void:
	current_target = _find_nearest_target(_get_target_search_distance())
	if current_target != null:
		_has_last_known_target_position = true
		_last_known_target_position = current_target.global_position


func _refresh_visible_detected_targets() -> void:
	detection_zone_targets.clear()
	detected_targets.clear()


func _move_towards(target_position: Vector3, stop_distance: float = 0.0) -> void:
	if not zombie_disable_navigation:
		super._move_towards(target_position, stop_distance)
		return

	_move_towards_direct_flat(target_position, stop_distance)


func _update_enemy_procedural_animation(delta: float) -> void:
	var interval: int = max(zombie_procedural_update_interval_frames, 1)
	if interval <= 1:
		super._update_enemy_procedural_animation(delta)
		return

	_zombie_visual_delta_accumulator += delta
	var frame: int = int(Engine.get_physics_frames())
	if frame % interval != _zombie_visual_frame_offset:
		return

	super._update_enemy_procedural_animation(_zombie_visual_delta_accumulator)
	_zombie_visual_delta_accumulator = 0.0


func _update_weapon_visuals() -> void:
	if weapon_pivot != null:
		weapon_pivot.visible = true
	if stick_mesh != null:
		stick_mesh.visible = false
	if rifle_mesh != null:
		rifle_mesh.visible = false
	_refresh_procedural_hand_grips()


func _configure_zombie_arm_pose() -> void:
	if weapon_pivot != null:
		weapon_pivot.position = weapon_local_position
	if left_grip_placeholder != null:
		left_grip_placeholder.position = Vector3(-0.28, -0.03, -0.34)
	if right_grip_placeholder != null:
		right_grip_placeholder.position = Vector3(0.28, -0.03, -0.34)
	_refresh_procedural_hand_grips()


func _perform_attack(combat_target: Node3D, _target_point: Vector3) -> bool:
	if combat_target == null or not is_instance_valid(combat_target):
		return false

	var effective_attack_range: float = _get_zombie_effective_attack_range(combat_target)
	var attack_range_squared: float = effective_attack_range * effective_attack_range
	if global_position.distance_squared_to(combat_target.global_position) > attack_range_squared:
		return false

	return _apply_melee_damage_to_target(combat_target)


func _apply_melee_damage_to_target(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	# Fast project path. Avoid get_method_list() during melee attacks.
	if target.has_method("apply_damage"):
		if target.is_in_group("vehicle") or target.is_in_group("vehicles"):
			target.call("apply_damage", attack_damage)
		else:
			target.call("apply_damage", attack_damage, self)
		return true

	if target.has_method("take_damage"):
		target.call("take_damage", attack_damage)
		return true

	if target.has_method("receive_damage"):
		target.call("receive_damage", attack_damage)
		return true

	return false
