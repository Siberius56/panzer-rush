extends CharacterBody3D

class_name NetworkEnemy

signal died(enemy_id: int)

enum EnemyState {
	IDLE,
	CHASE,
	ATTACK,
	INVESTIGATE,
	RETURN
}

@export_group("Meta")
@export var enemy_id: int = 0
@export var team_id: int = 2
@export var allow_friendly_fire: bool = false
@export var debug_logs: bool = true

@export_group("Movement")
@export var move_speed: float = 3.2
@export var gravity_strength: float = 24.0
@export var max_target_distance: float = 50.0
@export var repath_distance: float = 0.8
@export var direct_move_fallback: bool = true
@export var chase_stop_distance: float = 1.2
@export var investigate_reach_distance: float = 1.0
@export var return_reach_distance: float = 0.8

@export_group("Vehicle Impact", "vehicle_impact_")
@export var vehicle_impact_stun_duration: float = 0.25
@export var vehicle_impact_friction: float = 22.0
@export var vehicle_impact_max_horizontal_speed: float = 12.0
@export var vehicle_impact_min_horizontal_speed: float = 0.05
@export var vehicle_impact_rotate_to_push_direction: bool = true
@export var vehicle_impact_clear_target_on_hit: bool = false

@export_group("Health")
@export var max_health: int = 30
@export var armor_rating: int = 0

@export_group("Damage Feedback", "damage_feedback_")
@export var damage_feedback_enabled: bool = true
@export_range(0.02, 0.5, 0.01) var damage_feedback_duration: float = 0.14
@export_range(1.0, 1.4, 0.01) var damage_feedback_scale_up: float = 1.08
@export_range(0.7, 1.0, 0.01) var damage_feedback_scale_down: float = 0.94
@export_range(0.0, 0.5, 0.01) var damage_feedback_recoil_distance: float = 0.08
@export_range(0.0, 0.3, 0.01) var damage_feedback_vertical_bump: float = 0.035
@export_range(0.0, 20.0, 0.1) var damage_feedback_rotation_deg: float = 4.0

@export_group("Detection")
@export var detection_radius: float = 12.0
@export var damage_retarget_max_distance: float = 18.0
@export_flags_3d_physics var line_of_sight_mask: int = 0xFFFFFFFF

@export_group("Performance Scans")
@export_range(1, 120, 1) var scan_interval_frames: int = 20
@export var randomize_scan_frame: bool = true
@export var throttle_path_target_updates: bool = true

@export_group("Enemy Separation", "enemy_separation_")
@export var enemy_separation_enabled: bool = true
@export_range(0.2, 6.0, 0.05) var enemy_separation_radius: float = 1.25
@export_range(0.1, 12.0, 0.1) var enemy_separation_strength: float = 2.8
@export_range(0.1, 8.0, 0.1) var enemy_separation_max_velocity: float = 2.4
@export_range(0.1, 30.0, 0.1) var enemy_separation_decay: float = 12.0
@export_range(0.2, 6.0, 0.1) var enemy_separation_y_tolerance: float = 1.8
@export_range(1.0, 12.0, 0.25) var enemy_grid_cell_size: float = 4.0

@export_group("Attack")
@export var is_melee_attack: bool = false
@export var aim_height: float = 1.1
@export var attack_cooldown: float = 0.8
@export var attack_range: float = 8.0
@export var attack_damage: int = 10
@export var attack_penetration: int = 0
@export var projectile_scene: PackedScene
@export var bullet_spawn_forward_offset: float = 0.35
@export_range(0.0, 45.0, 0.1) var aim_dispersion_deg: float = 0.0
@export var attack_requires_line_of_sight: bool = true
@export var attack_debug_logs: bool = true

@export_group("Networking")
@export var state_send_interval: float = 0.05

@export_group("Loot")
@export_range(0.0, 1.0, 0.01) var loot_drop_chance: float = 0.45
@export_range(0, 100, 1) var money_weight: int = 50
@export_range(0, 100, 1) var pistol_ammo_weight: int = 20
@export_range(0, 100, 1) var rifle_ammo_weight: int = 20
@export_range(0, 100, 1) var smg_ammo_weight: int = 10
@export var money_drop_scene: PackedScene
@export var pistol_ammo_drop_scene: PackedScene
@export var rifle_ammo_drop_scene: PackedScene
@export var smg_ammo_drop_scene: PackedScene
@export var loot_spawn_height: float = 0.4
@export var loot_throw_force: float = 2.5

@export_group("Death Body", "death_body_")
@export var death_body_enabled: bool = true
@export_range(0.2, 8.0, 0.1) var death_body_lifetime: float = 2.6
@export var death_body_center_height: float = 0.95
@export var death_body_impulse_force: float = 4.5
@export var death_body_upward_impulse: float = 1.35
@export var death_body_random_impulse: float = 0.75
@export var death_body_angular_impulse: float = 1.8
@export var death_body_knockdown_angular_impulse: float = 4.0
@export_range(0.0, 1.0, 0.01) var death_body_yaw_spin_factor: float = 0.08
@export_range(0.0, 20.0, 0.1) var death_body_angular_damp: float = 4.0
@export var death_body_lock_yaw_rotation: bool = true
@export_flags_3d_physics var death_body_collision_layer: int = 0
@export_flags_3d_physics var death_body_collision_mask: int = 1

@export_group("Death Weapon", "death_weapon_")
@export var death_weapon_enabled: bool = true
@export_range(0.2, 8.0, 0.1) var death_weapon_lifetime: float = 2.8
@export var death_weapon_impulse_force: float = 3.6
@export var death_weapon_upward_impulse: float = 1.1
@export var death_weapon_random_impulse: float = 0.65
@export var death_weapon_angular_impulse: float = 5.5
@export_range(0.0, 20.0, 0.1) var death_weapon_angular_damp: float = 3.0
@export_flags_3d_physics var death_weapon_collision_layer: int = 0
@export_flags_3d_physics var death_weapon_collision_mask: int = 1

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var detection_area: Area3D = $DetectionArea3D
@onready var detection_shape: CollisionShape3D = $DetectionArea3D/CollisionShape3D
@onready var visual_root: Node3D = $VisualRoot
@onready var weapon_pivot: Node3D = $VisualRoot/WeaponPivot
@onready var muzzle: Node3D = $VisualRoot/WeaponPivot/Muzzle
@onready var stick_mesh: Node3D = $VisualRoot/WeaponPivot/StickMesh
@onready var rifle_mesh: Node3D = $VisualRoot/WeaponPivot/RifleMesh

var health: int = 0
var attack_timer: float = 0.0
var state_timer: float = 0.0
var current_state: EnemyState = EnemyState.IDLE
var current_target: Node3D = null
var detected_targets: Array[Node3D] = []
var forced_alert: bool = false
var _last_nav_target: Vector3 = Vector3.ZERO
var _has_nav_target: bool = false
var _dying: bool = false
var _last_debug_state: int = -1
var _last_debug_target_id: int = -1
var _origin_position: Vector3 = Vector3.ZERO
var _last_known_target_position: Vector3 = Vector3.ZERO
var _has_last_known_target_position: bool = false
var _damage_feedback_tween: Tween = null
var _visual_root_base_position: Vector3 = Vector3.ZERO
var _visual_root_base_scale: Vector3 = Vector3.ONE
var _visual_root_base_rotation: Vector3 = Vector3.ZERO

static var _enemy_spatial_grid: Dictionary = {}

var _scan_frame_offset: int = 0
var _enemy_grid_cell: Vector2i = Vector2i(2147483647, 2147483647)
var _registered_in_enemy_grid: bool = false
var _enemy_separation_velocity: Vector3 = Vector3.ZERO

var vehicle_impact_timer: float = 0.0
var vehicle_impact_velocity: Vector3 = Vector3.ZERO
var vehicle_impact_source: Node = null

var replicated_position: Vector3 = Vector3.ZERO
var replicated_velocity: Vector3 = Vector3.ZERO
var replicated_yaw: float = 0.0
var replicated_health: int = 0
var replicated_state: int = EnemyState.IDLE


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("enemies")
	_configure_scan_schedule()
	if multiplayer.is_server():
		_update_enemy_grid_registration(true)
	
	health = max_health
	_origin_position = global_position
	_last_known_target_position = global_position
	replicated_position = global_position
	replicated_velocity = velocity
	replicated_yaw = rotation.y
	replicated_health = health
	_cache_visual_root_base_transform()
	_apply_detection_radius()
	_update_weapon_visuals()
	_setup_navigation_agent()
	_connect_detection_signals()
	_debug("ready, melee=%s, range=%.2f, projectile=%s, origin=%s, dispersion=%.2f" % [str(is_melee_attack), attack_range, str(projectile_scene != null), str(_origin_position), aim_dispersion_deg])


func _exit_tree() -> void:
	if _registered_in_enemy_grid:
		_unregister_enemy_from_grid(_enemy_grid_cell)
		_registered_in_enemy_grid = false


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_update(delta)
	else:
		_apply_replicated_state(delta)


func _server_update(delta: float) -> void:
	if _dying:
		return

	if attack_timer > 0.0:
		attack_timer -= delta

	_apply_gravity(delta)

	if _process_vehicle_impact_stun(delta):
		move_and_slide()
		_send_server_state(delta)
		return

	var should_run_scheduled_scan: bool = _should_run_scheduled_scan()
	if should_run_scheduled_scan:
		_run_scheduled_scans()

	_validate_current_target()
	_update_last_known_target_position()

	if current_target == null:
		_acquire_target(should_run_scheduled_scan)

	if current_target == null:
		_handle_no_target_state()
		_last_debug_target_id = -1
	else:
		var combat_target := _get_combat_target(current_target)
		if combat_target == null:
			_debug("combat_target null, switch to last known / return")
			_clear_current_target_preserve_memory()
			_handle_no_target_state()
		else:
			var target_id := combat_target.get_instance_id()
			if target_id != _last_debug_target_id:
				_last_debug_target_id = target_id
				_debug("new combat target: %s" % combat_target.name)
			_handle_combat_state(combat_target)

	_apply_enemy_separation(delta)
	move_and_slide()
	_send_server_state(delta)



func _configure_scan_schedule() -> void:
	var interval: int = max(scan_interval_frames, 1)
	if randomize_scan_frame:
		_scan_frame_offset = randi() % interval
	else:
		_scan_frame_offset = int(get_instance_id()) % interval


func _should_run_scheduled_scan() -> bool:
	var interval: int = max(scan_interval_frames, 1)
	var frame: int = int(Engine.get_physics_frames())
	return frame % interval == _scan_frame_offset % interval


func _run_scheduled_scans() -> void:
	_cleanup_detected_targets()
	_update_enemy_grid_registration(false)
	_scan_enemy_separation()


func _can_refresh_path_target() -> bool:
	if not throttle_path_target_updates:
		return true
	if not _has_nav_target:
		return true
	return _should_run_scheduled_scan()


func _apply_enemy_separation(delta: float) -> void:
	if not enemy_separation_enabled:
		_enemy_separation_velocity = Vector3.ZERO
		return

	if _enemy_separation_velocity.length_squared() <= 0.0001:
		_enemy_separation_velocity = Vector3.ZERO
		return

	velocity.x += _enemy_separation_velocity.x
	velocity.z += _enemy_separation_velocity.z

	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var max_horizontal_speed: float = move_speed + enemy_separation_max_velocity
	if horizontal_velocity.length() > max_horizontal_speed:
		horizontal_velocity = horizontal_velocity.normalized() * max_horizontal_speed
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z

	_enemy_separation_velocity = _enemy_separation_velocity.move_toward(Vector3.ZERO, enemy_separation_decay * delta)


func _add_enemy_separation_velocity(push_velocity: Vector3) -> void:
	if _dying or not enemy_separation_enabled:
		return

	push_velocity.y = 0.0
	if push_velocity.length_squared() <= 0.0001:
		return

	_enemy_separation_velocity += push_velocity
	if _enemy_separation_velocity.length() > enemy_separation_max_velocity:
		_enemy_separation_velocity = _enemy_separation_velocity.normalized() * enemy_separation_max_velocity


func _scan_enemy_separation() -> void:
	if not enemy_separation_enabled or _dying:
		return

	var nearby_enemies: Array = _get_enemy_grid_neighbors(global_position)
	var separation_radius: float = maxf(enemy_separation_radius, 0.05)
	var separation_radius_squared: float = separation_radius * separation_radius

	for item in nearby_enemies:
		if item == self:
			continue
		if item == null or not is_instance_valid(item):
			continue
		if not (item is NetworkEnemy):
			continue

		var other_enemy: NetworkEnemy = item as NetworkEnemy
		if not other_enemy._can_receive_enemy_separation():
			continue

		var offset: Vector3 = global_position - other_enemy.global_position
		if absf(offset.y) > enemy_separation_y_tolerance:
			continue
		offset.y = 0.0

		var distance_squared: float = offset.length_squared()
		if distance_squared >= separation_radius_squared:
			continue

		if distance_squared <= 0.0001:
			offset = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
			if offset.length_squared() <= 0.0001:
				offset = Vector3.RIGHT
			distance_squared = 0.0001

		var distance: float = sqrt(distance_squared)
		var closeness: float = 1.0 - clampf(distance / separation_radius, 0.0, 1.0)
		var push: Vector3 = offset.normalized() * enemy_separation_strength * closeness

		_add_enemy_separation_velocity(push)
		other_enemy._add_enemy_separation_velocity(-push)


func _can_receive_enemy_separation() -> bool:
	return enemy_separation_enabled and not _dying and is_inside_tree()


func _update_enemy_grid_registration(force: bool = false) -> void:
	if not enemy_separation_enabled or _dying:
		return

	var new_cell: Vector2i = _get_enemy_grid_cell(global_position)
	if force or not _registered_in_enemy_grid:
		_enemy_grid_cell = new_cell
		_register_enemy_in_grid(new_cell)
		_registered_in_enemy_grid = true
		return

	if new_cell == _enemy_grid_cell:
		return

	_unregister_enemy_from_grid(_enemy_grid_cell)
	_enemy_grid_cell = new_cell
	_register_enemy_in_grid(new_cell)


func _get_enemy_grid_cell(world_position: Vector3) -> Vector2i:
	var safe_cell_size: float = maxf(enemy_grid_cell_size, 0.1)
	return Vector2i(floori(world_position.x / safe_cell_size), floori(world_position.z / safe_cell_size))


func _register_enemy_in_grid(cell: Vector2i) -> void:
	var cell_enemies: Array = []
	if _enemy_spatial_grid.has(cell):
		cell_enemies = _enemy_spatial_grid[cell]

	if not cell_enemies.has(self):
		cell_enemies.append(self)

	_enemy_spatial_grid[cell] = cell_enemies


func _unregister_enemy_from_grid(cell: Vector2i) -> void:
	if not _enemy_spatial_grid.has(cell):
		return

	var cell_enemies: Array = _enemy_spatial_grid[cell]
	if cell_enemies.has(self):
		cell_enemies.erase(self)

	if cell_enemies.is_empty():
		_enemy_spatial_grid.erase(cell)
	else:
		_enemy_spatial_grid[cell] = cell_enemies


func _get_enemy_grid_neighbors(world_position: Vector3) -> Array:
	var result: Array = []
	var center_cell: Vector2i = _get_enemy_grid_cell(world_position)
	var safe_cell_size: float = maxf(enemy_grid_cell_size, 0.1)
	var cell_range: int = max(1, ceili(enemy_separation_radius / safe_cell_size))

	for x_offset in range(-cell_range, cell_range + 1):
		for z_offset in range(-cell_range, cell_range + 1):
			var cell: Vector2i = Vector2i(center_cell.x + x_offset, center_cell.y + z_offset)
			if not _enemy_spatial_grid.has(cell):
				continue

			var cell_enemies: Array = _enemy_spatial_grid[cell]
			for item in cell_enemies:
				if item == null or not is_instance_valid(item):
					continue
				if not result.has(item):
					result.append(item)

	return result


func apply_vehicle_push(push_velocity: Vector3, source: Node = null) -> void:
	if not multiplayer.is_server() or _dying:
		return

	var horizontal_push = Vector3(push_velocity.x, 0.0, push_velocity.z)
	var horizontal_speed = horizontal_push.length()
	if horizontal_speed <= vehicle_impact_min_horizontal_speed:
		return

	if horizontal_speed > vehicle_impact_max_horizontal_speed:
		horizontal_push = horizontal_push.normalized() * vehicle_impact_max_horizontal_speed

	var current_horizontal = Vector3(vehicle_impact_velocity.x, 0.0, vehicle_impact_velocity.z)
	if horizontal_push.length_squared() >= current_horizontal.length_squared():
		vehicle_impact_velocity.x = horizontal_push.x
		vehicle_impact_velocity.z = horizontal_push.z
	else:
		vehicle_impact_velocity.x = current_horizontal.x
		vehicle_impact_velocity.z = current_horizontal.z

	if push_velocity.y > vehicle_impact_velocity.y:
		vehicle_impact_velocity.y = push_velocity.y

	vehicle_impact_timer = max(vehicle_impact_timer, vehicle_impact_stun_duration)
	vehicle_impact_source = source
	_clear_navigation_target()

	if vehicle_impact_clear_target_on_hit:
		current_target = null
		_has_last_known_target_position = false

	_debug("vehicle push: velocity=%s source=%s" % [str(vehicle_impact_velocity), source.name if source != null else "null"])


func _process_vehicle_impact_stun(delta: float) -> bool:
	var horizontal_impact = Vector3(vehicle_impact_velocity.x, 0.0, vehicle_impact_velocity.z)
	var has_remaining_push = horizontal_impact.length() > vehicle_impact_min_horizontal_speed
	var is_stunned = vehicle_impact_timer > 0.0

	if not is_stunned and not has_remaining_push:
		vehicle_impact_velocity = Vector3.ZERO
		vehicle_impact_source = null
		return false

	vehicle_impact_timer = max(vehicle_impact_timer - delta, 0.0)
	_set_state(EnemyState.IDLE)
	_clear_navigation_target()

	velocity.x = vehicle_impact_velocity.x
	velocity.z = vehicle_impact_velocity.z
	if vehicle_impact_velocity.y > velocity.y:
		velocity.y = vehicle_impact_velocity.y

	if vehicle_impact_rotate_to_push_direction and horizontal_impact.length_squared() > 0.001:
		_face_target(global_position + horizontal_impact)

	horizontal_impact = horizontal_impact.move_toward(Vector3.ZERO, vehicle_impact_friction * delta)
	vehicle_impact_velocity.x = horizontal_impact.x
	vehicle_impact_velocity.z = horizontal_impact.z
	vehicle_impact_velocity.y = move_toward(vehicle_impact_velocity.y, 0.0, gravity_strength * delta)

	return true


func _send_server_state(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		state_timer = state_send_interval
		_receive_state.rpc(global_position, velocity, rotation.y, health, int(current_state))


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y -= gravity_strength * delta


func _handle_no_target_state() -> void:
	if _has_last_known_target_position:
		var investigate_pos := _last_known_target_position
		var planar_distance := _planar_distance_to(investigate_pos)
		if planar_distance <= investigate_reach_distance:
			_debug("reached last known target position, no target found")
			_has_last_known_target_position = false
			_clear_navigation_target()
			_handle_return_to_origin_or_idle()
			return

		_set_state(EnemyState.INVESTIGATE)
		_move_towards(investigate_pos, investigate_reach_distance)
		return

	_handle_return_to_origin_or_idle()


func _handle_return_to_origin_or_idle() -> void:
	var origin_distance := _planar_distance_to(_origin_position)
	if origin_distance > return_reach_distance:
		_set_state(EnemyState.RETURN)
		_move_towards(_origin_position, return_reach_distance)
	else:
		_set_state(EnemyState.IDLE)
		velocity.x = 0.0
		velocity.z = 0.0
		_clear_navigation_target()


func _handle_combat_state(combat_target: Node3D) -> void:
	var target_point := _get_target_aim_point(combat_target)
	var distance := global_position.distance_to(combat_target.global_position)
	var has_los := true
	if attack_requires_line_of_sight:
		has_los = _has_line_of_sight(combat_target, target_point)
	var desired_attack_range := attack_range if not is_melee_attack else minf(attack_range, 1.8)

	_face_target(target_point)

	if distance <= desired_attack_range and has_los:
		_set_state(EnemyState.ATTACK)
		velocity.x = 0.0
		velocity.z = 0.0
		_clear_navigation_target()
		_try_attack(combat_target, target_point)
	else:
		if not has_los and distance <= desired_attack_range:
			_attack_debug("attack blocked by line of sight, moving toward target=%s distance=%.2f range=%.2f" % [combat_target.name, distance, desired_attack_range])
		_set_state(EnemyState.CHASE)
		_move_towards(combat_target.global_position, maxf(desired_attack_range - chase_stop_distance, 0.2))


func _move_towards(target_position: Vector3, stop_distance: float = 0.0) -> void:
	var to_target := target_position - global_position
	var planar_to_target := Vector3(to_target.x, 0.0, to_target.z)
	var planar_distance := planar_to_target.length()
	if planar_distance <= maxf(stop_distance, 0.05):
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var flat_target := target_position
	flat_target.y = global_position.y

	if navigation_agent == null:
		_debug("no NavigationAgent3D, fallback direct move")
		_move_towards_direct(flat_target)
		return

	var needs_new_path: bool = not _has_nav_target or _last_nav_target.distance_to(flat_target) > repath_distance
	if needs_new_path and _can_refresh_path_target():
		navigation_agent.target_position = flat_target
		_last_nav_target = flat_target
		_has_nav_target = true
		_debug("set nav target: %s" % str(flat_target))

	var next_position := navigation_agent.get_next_path_position()
	var direction := next_position - global_position
	direction.y = 0.0

	if direction.length_squared() <= 0.001:
		if direct_move_fallback:
			_debug("nav next position too close, fallback direct move. next=%s current=%s finished=%s" % [str(next_position), str(global_position), str(navigation_agent.is_navigation_finished())])
			_move_towards_direct(flat_target)
			return
		velocity.x = 0.0
		velocity.z = 0.0
		return

	direction = direction.normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	_face_target(global_position + direction)
	_debug_move("nav move dir=%s vel=(%.2f,%.2f,%.2f) floor=%s" % [str(direction), velocity.x, velocity.y, velocity.z, str(is_on_floor())])


func _move_towards_direct(target_position: Vector3) -> void:
	var direction := target_position - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	direction = direction.normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	_face_target(global_position + direction)
	_debug_move("direct move dir=%s vel=(%.2f,%.2f,%.2f) floor=%s" % [str(direction), velocity.x, velocity.y, velocity.z, str(is_on_floor())])


func _try_attack(combat_target: Node3D, target_point: Vector3) -> void:
	if attack_timer > 0.0:
		return

	if projectile_scene == null:
		_attack_debug("attack blocked: projectile_scene is null. Check NetworkEnemy.tscn > projectile_scene")
		return

	var spawn_position := muzzle.global_position if muzzle != null else global_position + Vector3.UP * aim_height
	var direction := target_point - spawn_position

	if is_melee_attack:
		spawn_position = target_point
		direction = target_point - global_position
	else:
		var forward := (target_point - spawn_position).normalized()
		if forward.length_squared() > 0.0001:
			spawn_position += forward * bullet_spawn_forward_offset
			direction = forward
		direction = _apply_aim_dispersion(direction)

	if direction.length_squared() <= 0.0001:
		direction = combat_target.global_position - global_position
	if direction.length_squared() <= 0.0001:
		direction = -global_basis.z
	direction = direction.normalized()

	_attack_debug("attack, melee=%s, spawn=%s, dir=%s, target=%s" % [str(is_melee_attack), str(spawn_position), str(direction), combat_target.name])
	_spawn_attack_projectile_local(spawn_position, direction)
	_spawn_attack_projectile_remote.rpc(spawn_position, direction)
	attack_timer = attack_cooldown


func _spawn_attack_projectile_local(spawn_position: Vector3, direction: Vector3) -> void:
	if projectile_scene == null:
		return

	var projectile = projectile_scene.instantiate()
	if projectile == null:
		_attack_debug("projectile instantiate failed")
		return

	get_tree().current_scene.add_child(projectile)
	if projectile.has_method("fire"):
		projectile.fire(
			spawn_position,
			direction,
			team_id,
			attack_damage,
			attack_penetration,
			allow_friendly_fire,
			self,
			null
		)
		_attack_debug("projectile fired with fire() projectile=%s" % projectile.name)
	elif projectile is Node3D:
		var node := projectile as Node3D
		node.global_position = spawn_position
		node.look_at(spawn_position + direction, Vector3.UP)
		_attack_debug("projectile spawned as Node3D without fire()")
	else:
		_attack_debug("projectile has no fire() and is not Node3D")


func _acquire_target(allow_global_scan: bool = true) -> void:
	var best_target: Node3D = null
	var best_distance := INF

	for target in detected_targets:
		if not _is_valid_target(target):
			continue

		var dist := global_position.distance_squared_to(target.global_position)
		if dist < best_distance:
			best_distance = dist
			best_target = target

	if best_target == null and forced_alert and allow_global_scan:
		best_target = _find_nearest_target(max_target_distance)

	current_target = best_target
	if current_target != null:
		_debug("detected target: %s" % current_target.name)


func _find_nearest_target(max_distance: float = INF) -> Node3D:
	var best_target: Node3D = null
	var best_distance := max_distance * max_distance
	var candidates: Array[Node3D] = []

	for node in get_tree().get_nodes_in_group("player"):
		if node is Node3D:
			candidates.append(node)

	for node in get_tree().get_nodes_in_group("vehicle"):
		if node is Node3D and not candidates.has(node):
			candidates.append(node)

	for node in get_tree().get_nodes_in_group("vehicles"):
		if node is Node3D and not candidates.has(node):
			candidates.append(node)

	for target in candidates:
		if not _is_valid_target(target):
			continue

		var dist := global_position.distance_squared_to(target.global_position)
		if dist < best_distance:
			best_distance = dist
			best_target = target

	return best_target


func _validate_current_target() -> void:
	if not _is_valid_target(current_target):
		current_target = null
		return

	var distance := global_position.distance_to(current_target.global_position)
	if distance > max_target_distance:
		_debug("target too far, reset")
		current_target = null


func _cleanup_detected_targets() -> void:
	var cleaned: Array[Node3D] = []
	for target in detected_targets:
		if _is_valid_target(target):
			cleaned.append(target)
	detected_targets = cleaned


func _resolve_detected_target(node: Node) -> Node3D:
	var current := node
	while current != null:
		if current is Node3D:
			var current_node := current as Node3D
			if current_node.is_in_group("player"):
				return current_node
			if current_node.is_in_group("vehicle") or current_node.is_in_group("vehicles"):
				return current_node
		current = current.get_parent()
	return null


func _update_last_known_target_position() -> void:
	if current_target == null:
		return
	if not detected_targets.has(current_target):
		return
	_last_known_target_position = current_target.global_position
	_has_last_known_target_position = true


func _clear_current_target_preserve_memory() -> void:
	if _is_valid_target(current_target):
		_last_known_target_position = current_target.global_position
		_has_last_known_target_position = true
	current_target = null


func _clear_navigation_target() -> void:
	_has_nav_target = false
	_last_nav_target = Vector3.ZERO
	if navigation_agent != null:
		navigation_agent.target_position = global_position


func _planar_distance_to(world_pos: Vector3) -> float:
	var delta := world_pos - global_position
	delta.y = 0.0
	return delta.length()


func _is_valid_target(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not (node is Node3D):
		return false
	if _is_target_dead(node):
		return false

	if node.is_in_group("player"):
		return true

	if node.is_in_group("vehicle") or node.is_in_group("vehicles"):
		return true

	return false


func _is_target_dead(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return true

	if node.has_method("is_alive") and not node.is_alive():
		return true

	var dead_value: Variant = _safe_get_property(node, "is_dead")
	if dead_value is bool:
		return dead_value

	return false


func _face_target(world_point: Vector3) -> void:
	var flat_point := world_point
	flat_point.y = global_position.y
	if flat_point.distance_squared_to(global_position) > 0.001:
		look_at(flat_point, Vector3.UP)


func _get_target_aim_point(target_body: Node3D) -> Vector3:
	if target_body == null:
		return global_position
	return target_body.global_position + Vector3.UP * aim_height


func _apply_aim_dispersion(direction: Vector3) -> Vector3:
	var dir := direction.normalized()
	if aim_dispersion_deg <= 0.0:
		return dir

	var yaw_offset := deg_to_rad(randf_range(-aim_dispersion_deg, aim_dispersion_deg))
	var pitch_offset := deg_to_rad(randf_range(-aim_dispersion_deg, aim_dispersion_deg))

	var right := dir.cross(Vector3.UP).normalized()
	if right.length_squared() <= 0.0001:
		right = Vector3.RIGHT

	dir = dir.rotated(Vector3.UP, yaw_offset)
	dir = dir.rotated(right, pitch_offset)
	return dir.normalized()


func _has_line_of_sight(target_body: Node3D, target_point: Vector3) -> bool:
	var origin := muzzle.global_position if muzzle != null else global_position + Vector3.UP * aim_height
	var hit := _raycast(origin, target_point, [self, detection_area])
	if hit.is_empty():
		return true

	var collider := hit.get("collider") as Node
	var result := _belongs_to_node(collider, target_body)
	if not result:
		_debug("line of sight blocked by: %s" % [collider.name if collider != null else "null"])
	return result


func _raycast(from: Vector3, to: Vector3, exclude: Array) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, line_of_sight_mask)
	var exclude_rids: Array = []
	for item in exclude:
		_collect_collision_rids(item, exclude_rids)
	query.exclude = exclude_rids
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_3d().direct_space_state.intersect_ray(query)


func _collect_collision_rids(node: Node, output: Array) -> void:
	if node == null or not is_instance_valid(node):
		return

	if node is CollisionObject3D:
		var rid := (node as CollisionObject3D).get_rid()
		if not output.has(rid):
			output.append(rid)

	for child in node.get_children():
		_collect_collision_rids(child, output)


func _belongs_to_node(candidate: Node, root_target: Node) -> bool:
	var current := candidate
	while current != null:
		if current == root_target:
			return true
		current = current.get_parent()
	return false


func _get_combat_target(target: Node3D) -> Node3D:
	if target == null or not _is_valid_target(target):
		return null

	if target.is_in_group("vehicle") or target.is_in_group("vehicles"):
		return target

	var vehicle := _get_vehicle_from_player(target)
	if vehicle != null and vehicle is Node3D and is_instance_valid(vehicle):
		var vehicle_node: Node3D = vehicle as Node3D
		if _is_valid_target(vehicle_node):
			return vehicle_node

	return target


func _get_vehicle_from_player(player_target: Node) -> Node:
	if player_target == null:
		return null

	if player_target.has_method("get_current_vehicle"):
		var vehicle = player_target.get_current_vehicle()
		if vehicle != null and is_instance_valid(vehicle):
			return vehicle

	var vehicle_interactor = _safe_get_property(player_target, "vehicle_interactor")
	if vehicle_interactor != null:
		if vehicle_interactor.has_method("get_current_vehicle"):
			var interactor_vehicle = vehicle_interactor.get_current_vehicle()
			if interactor_vehicle != null and is_instance_valid(interactor_vehicle):
				return interactor_vehicle

		for property_name in ["current_vehicle", "vehicle", "controlled_vehicle"]:
			var interactor_value = _safe_get_property(vehicle_interactor, property_name)
			if interactor_value != null and interactor_value is Node and is_instance_valid(interactor_value):
				return interactor_value

	for property_name in ["current_vehicle", "vehicle", "controlled_vehicle"]:
		var value = _safe_get_property(player_target, property_name)
		if value != null and value is Node and is_instance_valid(value):
			return value

	return null


func _safe_get_property(object: Object, property_name: String) -> Variant:
	if object == null:
		return null

	for property_data in object.get_property_list():
		if String(property_data.name) == property_name:
			return object.get(property_name)

	return null


func apply_damage(amount: int, damage_source: Node = null) -> void:
	if not multiplayer.is_server() or _dying:
		return
	
	print("take a damage ?!")
	
	health = max(health - amount, 0)
	_debug("apply_damage: %d -> health=%d" % [amount, health])
	if health <= 0:
		_die(damage_source)
		return

	var hit_direction := _get_damage_push_direction(damage_source)
	_play_damage_feedback_local(hit_direction)
	_play_damage_feedback_remote.rpc(hit_direction)
	_receive_state.rpc(global_position, velocity, rotation.y, health, int(current_state))


func apply_projectile_damage(
	amount: int,
	to_projectile_penetration: int = 0,
	_source_team: int = 0,
	_allow_tk: bool = false,
	_source: Node = null
) -> void:
	if not multiplayer.is_server() or _dying:
		return

	var effective_armor = max(armor_rating - to_projectile_penetration, 0)
	var final_damage = max(amount - effective_armor, 1)
	if final_damage <= 0:
		return

	_try_retarget_from_damage_source(_source)
	
	print("here ?!")
	apply_damage(final_damage, _source)


func _try_retarget_from_damage_source(source: Node) -> void:
	var target_player := _extract_player_from_source(source)
	if not _is_valid_target(target_player):
		return

	if global_position.distance_to(target_player.global_position) > damage_retarget_max_distance:
		return

	current_target = target_player
	forced_alert = true
	_last_known_target_position = target_player.global_position
	_has_last_known_target_position = true
	_debug("retarget from damage source: %s" % target_player.name)


func _extract_player_from_source(source: Node) -> Node3D:
	if source == null or not is_instance_valid(source):
		return null

	if source.is_in_group("player"):
		return source as Node3D

	if source.has_method("get_driver"):
		var driver = source.get_driver()
		if driver != null and driver is Node3D and driver.is_in_group("player"):
			return driver

	for property_name in ["driver", "owner_player", "player_owner", "controlling_player"]:
		var value = _safe_get_property(source, property_name)
		if value != null and value is Node3D and value.is_in_group("player"):
			return value

	return null



func _cache_visual_root_base_transform() -> void:
	if visual_root == null:
		return
	_visual_root_base_position = visual_root.position
	_visual_root_base_scale = visual_root.scale
	_visual_root_base_rotation = visual_root.rotation


func _play_damage_feedback_local(hit_direction: Vector3 = Vector3.ZERO) -> void:
	if not damage_feedback_enabled:
		return
	if visual_root == null or not is_instance_valid(visual_root):
		return
	if _dying:
		return

	if _damage_feedback_tween != null:
		_damage_feedback_tween.kill()
		_damage_feedback_tween = null

	visual_root.position = _visual_root_base_position
	visual_root.scale = _visual_root_base_scale
	visual_root.rotation = _visual_root_base_rotation

	var direction := hit_direction
	if direction.length_squared() <= 0.001:
		direction = -global_basis.z
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		direction = Vector3.FORWARD
	direction = direction.normalized()

	var local_direction := global_basis.inverse() * direction
	local_direction.y = 0.0
	if local_direction.length_squared() > 0.001:
		local_direction = local_direction.normalized()

	var recoil_offset := local_direction * damage_feedback_recoil_distance
	recoil_offset.y += damage_feedback_vertical_bump

	var rotation_amount := deg_to_rad(damage_feedback_rotation_deg)
	var recoil_rotation := Vector3(
		-local_direction.z * rotation_amount,
		0.0,
		local_direction.x * rotation_amount
	)

	var first_step := damage_feedback_duration * 0.32
	var second_step := damage_feedback_duration * 0.28
	var third_step := maxf(damage_feedback_duration - first_step - second_step, 0.01)

	_damage_feedback_tween = create_tween()
	_damage_feedback_tween.set_parallel(true)
	_damage_feedback_tween.tween_property(visual_root, "scale", _visual_root_base_scale * damage_feedback_scale_up, first_step).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_damage_feedback_tween.tween_property(visual_root, "position", _visual_root_base_position + recoil_offset, first_step).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_damage_feedback_tween.tween_property(visual_root, "rotation", _visual_root_base_rotation + recoil_rotation, first_step).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_damage_feedback_tween.chain().set_parallel(true)
	_damage_feedback_tween.tween_property(visual_root, "scale", _visual_root_base_scale * damage_feedback_scale_down, second_step).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_damage_feedback_tween.tween_property(visual_root, "position", _visual_root_base_position - recoil_offset * 0.25, second_step).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_damage_feedback_tween.tween_property(visual_root, "rotation", _visual_root_base_rotation - recoil_rotation * 0.35, second_step).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	_damage_feedback_tween.chain().set_parallel(true)
	_damage_feedback_tween.tween_property(visual_root, "scale", _visual_root_base_scale, third_step).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_damage_feedback_tween.tween_property(visual_root, "position", _visual_root_base_position, third_step).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_damage_feedback_tween.tween_property(visual_root, "rotation", _visual_root_base_rotation, third_step).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_damage_feedback_tween.finished.connect(func() -> void:
		if visual_root != null and is_instance_valid(visual_root):
			visual_root.position = _visual_root_base_position
			visual_root.scale = _visual_root_base_scale
			visual_root.rotation = _visual_root_base_rotation
		_damage_feedback_tween = null
	)


func set_alert_mode(enabled: bool = true) -> void:
	forced_alert = enabled
	if not multiplayer.is_server():
		return

	if enabled:
		current_target = _find_nearest_target(max_target_distance)
		if current_target != null:
			_last_known_target_position = current_target.global_position
			_has_last_known_target_position = true
			_set_state(EnemyState.CHASE)
	else:
		current_target = null
		_set_state(EnemyState.IDLE)


func alert_nearest_player() -> void:
	set_alert_mode(true)


func _die(damage_source: Node = null) -> void:
	if _dying:
		return
	_dying = true

	var death_direction := _get_death_direction(damage_source)
	var death_impulse := _build_death_body_impulse(death_direction)
	var weapon_impulse := _build_death_weapon_impulse(death_direction)
	var death_body_transform := global_transform
	death_body_transform.origin += Vector3.UP * death_body_center_height
	_spawn_death_body_local(death_body_transform, velocity, death_impulse, death_direction)
	_spawn_death_body_remote.rpc(death_body_transform, velocity, death_impulse, death_direction)
	_spawn_death_weapon_local(weapon_impulse)
	_spawn_death_weapon_remote.rpc(weapon_impulse)

	_drop_loot()
	emit_signal("died", enemy_id)
	_remote_die.rpc()
	queue_free()



func _spawn_death_body_local(body_transform: Transform3D, inherited_velocity: Vector3, impulse: Vector3, fall_direction: Vector3) -> void:
	if not death_body_enabled:
		return
	if get_tree() == null or get_tree().current_scene == null:
		return

	var corpse := RigidBody3D.new()
	corpse.name = "%s_DeathBody" % name
	corpse.collision_layer = death_body_collision_layer
	corpse.collision_mask = death_body_collision_mask
	corpse.mass = 1.0
	corpse.gravity_scale = 1.0
	corpse.angular_damp = death_body_angular_damp
	corpse.axis_lock_angular_y = death_body_lock_yaw_rotation
	corpse.global_transform = body_transform

	var source_collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	var corpse_collision := CollisionShape3D.new()
	if source_collision != null and source_collision.shape != null:
		corpse_collision.shape = source_collision.shape.duplicate(true)
		corpse_collision.transform = source_collision.transform
	else:
		var fallback_shape := CapsuleShape3D.new()
		fallback_shape.radius = 0.45
		fallback_shape.height = 1.9
		corpse_collision.shape = fallback_shape
		corpse_collision.position = Vector3.UP * death_body_center_height
	corpse_collision.position -= Vector3.UP * death_body_center_height
	corpse.add_child(corpse_collision)

	var source_visual := get_node_or_null("VisualRoot") as Node3D
	if source_visual != null:
		var corpse_visual := source_visual.duplicate() as Node3D
		corpse_visual.position -= Vector3.UP * death_body_center_height
		if death_weapon_enabled:
			_strip_weapon_from_corpse_visual(corpse_visual)
		corpse.add_child(corpse_visual)

	get_tree().current_scene.add_child(corpse)
	corpse.global_transform = body_transform
	corpse.linear_velocity = inherited_velocity
	corpse.apply_central_impulse(impulse)

	var knockdown_axis := fall_direction.cross(Vector3.UP)
	if knockdown_axis.length_squared() <= 0.001:
		knockdown_axis = body_transform.basis.x
	if knockdown_axis.length_squared() > 0.001:
		corpse.apply_torque_impulse(knockdown_axis.normalized() * death_body_knockdown_angular_impulse)

	var torque := Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	)
	if torque.length_squared() > 0.001:
		torque = torque.normalized()
		torque.y *= death_body_yaw_spin_factor
		corpse.apply_torque_impulse(torque * death_body_angular_impulse)

	var timer := get_tree().create_timer(death_body_lifetime)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(corpse):
			corpse.queue_free()
	)


func _spawn_death_weapon_local(impulse: Vector3) -> void:
	if not death_weapon_enabled:
		return
	if weapon_pivot == null or not is_instance_valid(weapon_pivot):
		return
	if get_tree() == null or get_tree().current_scene == null:
		return

	var active_weapon := _get_active_weapon_visual_source()
	if active_weapon == null or not is_instance_valid(active_weapon):
		return

	var weapon_body := RigidBody3D.new()
	weapon_body.name = "%s_DeathWeapon" % name
	weapon_body.collision_layer = death_weapon_collision_layer
	weapon_body.collision_mask = death_weapon_collision_mask
	weapon_body.mass = 0.35
	weapon_body.gravity_scale = 1.0
	weapon_body.angular_damp = death_weapon_angular_damp
	weapon_body.global_transform = weapon_pivot.global_transform

	var weapon_collision := _create_death_weapon_collision(active_weapon)
	weapon_body.add_child(weapon_collision)

	var weapon_visual := weapon_pivot.duplicate() as Node3D
	weapon_visual.transform = Transform3D.IDENTITY
	_prepare_detached_weapon_visual(weapon_visual)
	weapon_body.add_child(weapon_visual)

	get_tree().current_scene.add_child(weapon_body)
	weapon_body.global_transform = weapon_pivot.global_transform
	weapon_body.linear_velocity = velocity
	weapon_body.apply_central_impulse(impulse)

	var torque := Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	)
	if torque.length_squared() > 0.001:
		weapon_body.apply_torque_impulse(torque.normalized() * death_weapon_angular_impulse)

	var timer := get_tree().create_timer(death_weapon_lifetime)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(weapon_body):
			weapon_body.queue_free()
	)


func _get_active_weapon_visual_source() -> Node3D:
	if is_melee_attack:
		if stick_mesh != null and is_instance_valid(stick_mesh):
			return stick_mesh
	else:
		if rifle_mesh != null and is_instance_valid(rifle_mesh):
			return rifle_mesh

	if weapon_pivot != null and is_instance_valid(weapon_pivot):
		return weapon_pivot
	return null


func _create_death_weapon_collision(active_weapon: Node3D) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.18, 0.18, 0.95)
	collision.transform = active_weapon.transform

	if active_weapon is MeshInstance3D:
		var mesh_instance := active_weapon as MeshInstance3D
		if mesh_instance.mesh != null:
			var aabb := mesh_instance.mesh.get_aabb()
			box.size = Vector3(
				maxf(absf(aabb.size.x), 0.05),
				maxf(absf(aabb.size.y), 0.05),
				maxf(absf(aabb.size.z), 0.05)
			)
			var local_center := aabb.position + aabb.size * 0.5
			collision.position += active_weapon.basis * local_center

	collision.shape = box
	return collision


func _prepare_detached_weapon_visual(weapon_visual: Node3D) -> void:
	if is_melee_attack:
		_free_child_if_exists(weapon_visual, "RifleMesh")
	else:
		_free_child_if_exists(weapon_visual, "StickMesh")
	_free_child_if_exists(weapon_visual, "Muzzle")


func _strip_weapon_from_corpse_visual(corpse_visual: Node3D) -> void:
	_free_child_if_exists(corpse_visual, "WeaponPivot")


func _free_child_if_exists(root: Node, child_path: String) -> void:
	if root == null:
		return
	var child := root.get_node_or_null(NodePath(child_path))
	if child == null:
		return
	var parent := child.get_parent()
	if parent != null:
		parent.remove_child(child)
	child.free()


func _get_death_direction(damage_source: Node = null) -> Vector3:
	var direction := _get_damage_push_direction(damage_source)

	if direction.length_squared() <= 0.001:
		direction = -global_basis.z
		direction.y = 0.0

	if direction.length_squared() <= 0.001:
		direction = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))

	var random_direction := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	if random_direction.length_squared() > 0.001:
		direction += random_direction.normalized() * death_body_random_impulse

	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return Vector3.FORWARD
	return direction.normalized()


func _build_death_body_impulse(death_direction: Vector3) -> Vector3:
	var direction := death_direction
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		direction = Vector3.FORWARD
	else:
		direction = direction.normalized()
	return direction * death_body_impulse_force + Vector3.UP * death_body_upward_impulse


func _build_death_weapon_impulse(death_direction: Vector3) -> Vector3:
	var direction := death_direction
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		direction = Vector3.FORWARD

	var random_direction := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	if random_direction.length_squared() > 0.001:
		direction += random_direction.normalized() * death_weapon_random_impulse

	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		direction = Vector3.FORWARD
	else:
		direction = direction.normalized()

	return direction * death_weapon_impulse_force + Vector3.UP * death_weapon_upward_impulse


func _get_damage_push_direction(damage_source: Node = null) -> Vector3:
	if damage_source != null and is_instance_valid(damage_source):
		var source_velocity := _get_vector3_from_source(damage_source, ["damage_direction", "hit_direction", "direction", "velocity", "linear_velocity", "projectile_velocity"])
		if source_velocity.length_squared() > 0.001:
			return source_velocity.normalized()

		var source_position = _get_world_position_from_source(damage_source)
		if source_position is Vector3:
			var source_position_3d := source_position as Vector3
			var from_source := global_position - source_position_3d
			from_source.y = 0.0
			if from_source.length_squared() > 0.001:
				return from_source.normalized()

	var vehicle_horizontal := Vector3(vehicle_impact_velocity.x, 0.0, vehicle_impact_velocity.z)
	if vehicle_horizontal.length_squared() > 0.001:
		return vehicle_horizontal.normalized()

	return Vector3.ZERO


func _get_vector3_from_source(source: Node, property_names: Array[String]) -> Vector3:
	for property_name in property_names:
		var value = _safe_get_property(source, property_name)
		if value is Vector3:
			return value as Vector3

	for method_name in ["get_damage_direction", "get_hit_direction", "get_direction", "get_velocity", "get_linear_velocity"]:
		if source.has_method(method_name):
			var method_value = source.call(method_name)
			if method_value is Vector3:
				return method_value as Vector3

	return Vector3.ZERO


func _get_world_position_from_source(source: Node) -> Variant:
	if source is Node3D:
		return (source as Node3D).global_position

	for property_name in ["global_position", "position", "origin"]:
		var value = _safe_get_property(source, property_name)
		if value is Vector3:
			return value

	for method_name in ["get_global_position", "get_position", "get_origin"]:
		if source.has_method(method_name):
			var method_value = source.call(method_name)
			if method_value is Vector3:
				return method_value

	return null

func _drop_loot() -> void:
	if randf() > loot_drop_chance:
		return

	var total_weight := money_weight + pistol_ammo_weight + rifle_ammo_weight + smg_ammo_weight
	if total_weight <= 0:
		return

	var roll := randi() % total_weight
	var selected_scene: PackedScene = null

	if roll < money_weight:
		selected_scene = money_drop_scene
	elif roll < money_weight + pistol_ammo_weight:
		selected_scene = pistol_ammo_drop_scene
	elif roll < money_weight + pistol_ammo_weight + rifle_ammo_weight:
		selected_scene = rifle_ammo_drop_scene
	else:
		selected_scene = smg_ammo_drop_scene

	if selected_scene == null:
		return

	var loot = selected_scene.instantiate()
	if loot == null:
		return

	get_tree().current_scene.add_child(loot)
	if loot is Node3D:
		var loot_node := loot as Node3D
		loot_node.global_position = global_position + Vector3.UP * loot_spawn_height
		if loot.has_method("apply_spawn_impulse"):
			var random_dir := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
			loot.apply_spawn_impulse(random_dir * loot_throw_force)


func _apply_detection_radius() -> void:
	if detection_shape == null:
		return

	var shape := detection_shape.shape
	if shape is SphereShape3D:
		(shape as SphereShape3D).radius = detection_radius
	elif shape is CylinderShape3D:
		(shape as CylinderShape3D).radius = detection_radius


func _update_weapon_visuals() -> void:
	if stick_mesh != null:
		stick_mesh.visible = is_melee_attack
	if rifle_mesh != null:
		rifle_mesh.visible = not is_melee_attack


func _setup_navigation_agent() -> void:
	if navigation_agent == null:
		return
	navigation_agent.avoidance_enabled = false
	navigation_agent.path_desired_distance = 0.6
	navigation_agent.target_desired_distance = maxf(chase_stop_distance, 0.6)


func _connect_detection_signals() -> void:
	if detection_area == null:
		return
	if not detection_area.body_entered.is_connected(_on_detection_body_entered):
		detection_area.body_entered.connect(_on_detection_body_entered)
	if not detection_area.body_exited.is_connected(_on_detection_body_exited):
		detection_area.body_exited.connect(_on_detection_body_exited)


func _on_detection_body_entered(body: Node) -> void:
	var target := _resolve_detected_target(body)
	if not _is_valid_target(target):
		return

	if not detected_targets.has(target):
		detected_targets.append(target)
		_debug("detected target entered: %s from body=%s" % [target.name, body.name if body != null else "null"])

	_last_known_target_position = target.global_position
	_has_last_known_target_position = true

	if current_target == null:
		current_target = target
		_debug("current target from detection: %s" % target.name)


func _on_detection_body_exited(body: Node) -> void:
	var target := _resolve_detected_target(body)
	if target == null:
		return

	if detected_targets.has(target):
		detected_targets.erase(target)
		_debug("detected target exited: %s from body=%s" % [target.name, body.name if body != null else "null"])

	if target == current_target and not forced_alert:
		_last_known_target_position = target.global_position
		_has_last_known_target_position = true
		_debug("current target exited detection, last known=%s" % str(_last_known_target_position))
		current_target = null
		_clear_navigation_target()


func _set_state(new_state: EnemyState) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	if int(new_state) != _last_debug_state:
		_last_debug_state = int(new_state)
		match new_state:
			EnemyState.IDLE:
				_debug("state -> IDLE")
			EnemyState.CHASE:
				_debug("state -> CHASE")
			EnemyState.ATTACK:
				_debug("state -> ATTACK")
			EnemyState.INVESTIGATE:
				_debug("state -> INVESTIGATE")
			EnemyState.RETURN:
				_debug("state -> RETURN")


func _apply_replicated_state(delta: float) -> void:
	global_position = global_position.lerp(replicated_position, min(delta * 12.0, 1.0))
	velocity = velocity.lerp(replicated_velocity, min(delta * 10.0, 1.0))
	rotation.y = lerp_angle(rotation.y, replicated_yaw, min(delta * 14.0, 1.0))
	
	health = replicated_health
	current_state = replicated_state


func _attack_debug(message: String) -> void:
	if not attack_debug_logs:
		return
	print("[NetworkEnemyAttack:%s] %s" % [name, message])


func _debug(_message: String) -> void:
	return
	
	#if not debug_logs:
		#return
	#print("[NetworkEnemy:%s] %s" % [name, message])


func _debug_move(_message: String) -> void:
	return
	
	#if not debug_logs:
		#return
	#if Engine.get_physics_frames() % 20 != 0:
		#return
	#print("[NetworkEnemy:%s] %s" % [name, message])


@rpc("authority", "call_remote", "unreliable_ordered")
func _receive_state(position_value: Vector3, velocity_value: Vector3, yaw_value: float, health_value: int, state_value: int) -> void:
	if multiplayer.is_server():
		return
	replicated_position = position_value
	replicated_velocity = velocity_value
	replicated_yaw = yaw_value
	replicated_health = health_value
	replicated_state = state_value



@rpc("authority", "call_remote", "unreliable")
func _play_damage_feedback_remote(hit_direction: Vector3 = Vector3.ZERO) -> void:
	if multiplayer.is_server():
		return
	_play_damage_feedback_local(hit_direction)


@rpc("authority", "call_remote", "reliable")
func _spawn_death_body_remote(body_transform: Transform3D, inherited_velocity: Vector3, impulse: Vector3, fall_direction: Vector3) -> void:
	if multiplayer.is_server():
		return
	_spawn_death_body_local(body_transform, inherited_velocity, impulse, fall_direction)


@rpc("authority", "call_remote", "reliable")
func _spawn_death_weapon_remote(impulse: Vector3) -> void:
	if multiplayer.is_server():
		return
	_spawn_death_weapon_local(impulse)


@rpc("authority", "call_remote", "reliable")
func _remote_die() -> void:
	if multiplayer.is_server():
		return
	queue_free()


@rpc("authority", "call_remote", "reliable")
func _spawn_attack_projectile_remote(spawn_position: Vector3, direction: Vector3) -> void:
	if multiplayer.is_server():
		return
	_spawn_attack_projectile_local(spawn_position, direction)
