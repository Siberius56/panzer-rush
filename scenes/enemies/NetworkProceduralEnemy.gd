extends CharacterBody3D

class_name NetworkProceduralEnemy

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
@export var ally_death_alert_radius: float = 14.0
@export var detection_requires_line_of_sight: bool = true
@export_flags_3d_physics var detection_line_of_sight_mask: int = 8 # Godot physics layer 4, decor.
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

@export_group("Procedural Animation")
@export var remote_animation_velocity_lerp_speed: float = 16.0
@export var remote_animation_move_threshold: float = 0.08
@export_range(0.05, 1.0, 0.01) var remote_animation_fallback_speed_ratio: float = 0.42
@export var turn_speed: float = 14.0
@export var stance_width: float = 0.22
@export var stride_length: float = 0.34
@export var forward_step_reach: float = 0.10
@export var max_stair_step_up: float = 0.0
@export var max_stair_step_down: float = 1.0
@export var step_height: float = 0.16
@export var gait_frequency: float = 11.0
@export var foot_ground_offset: float = 0.035
@export var max_leg_reach: float = 1.0
@export var min_foot_below_hip: float = 0.22
@export var idle_foot_forward_offset: float = 0.03
@export var support_inward: float = 0.05
@export var swing_outward: float = 0.08
@export var strafe_foot_lead: float = 0.10
@export var foot_follow_speed: float = 18.0
@export var airborne_foot_pull: float = 7.0
@export var body_bob_amount: float = 0.045
@export var body_tilt_amount: float = 0.10
@export var landing_squash_strength: float = 0.12
@export var upper_leg_length: float = 0.44
@export var lower_leg_length: float = 0.44
@export var upper_arm_length: float = 0.36
@export var lower_arm_length: float = 0.40
@export var weapon_local_position: Vector3 = Vector3(0.22, 1.18, -0.46)
@export var weapon_follow_speed: float = 14.0
@export var visual_aim_min_target_distance: float = 0.05

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

@onready var navigation_agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
@onready var detection_area: Area3D = get_node_or_null("DetectionArea3D") as Area3D
@onready var detection_shape: CollisionShape3D = get_node_or_null("DetectionArea3D/CollisionShape3D") as CollisionShape3D
@onready var visual_root: Node3D = get_node_or_null("VisualRoot") as Node3D
@onready var weapon_pivot: Node3D = get_node_or_null("VisualRoot/Weapon") as Node3D
@onready var muzzle: Node3D = get_node_or_null("VisualRoot/Weapon/Muzzle") as Node3D
@onready var stick_mesh: Node3D = get_node_or_null("VisualRoot/Weapon/StickMesh") as Node3D
@onready var rifle_mesh: Node3D = get_node_or_null("VisualRoot/Weapon/RifleBody") as Node3D

@onready var left_grip_placeholder: Node3D = get_node_or_null("VisualRoot/Weapon/LeftGrip") as Node3D
@onready var right_grip_placeholder: Node3D = get_node_or_null("VisualRoot/Weapon/RightGrip") as Node3D
@onready var left_hip: Node3D = get_node_or_null("VisualRoot/LeftHip") as Node3D
@onready var right_hip: Node3D = get_node_or_null("VisualRoot/RightHip") as Node3D
@onready var left_shoulder: Node3D = get_node_or_null("VisualRoot/LeftShoulder") as Node3D
@onready var right_shoulder: Node3D = get_node_or_null("VisualRoot/RightShoulder") as Node3D
@onready var foot_probe_root: Node3D = get_node_or_null("FootProbeRoot") as Node3D
@onready var left_probe: RayCast3D = get_node_or_null("FootProbeRoot/LeftFootProbe") as RayCast3D
@onready var right_probe: RayCast3D = get_node_or_null("FootProbeRoot/RightFootProbe") as RayCast3D
@onready var left_foot: Node3D = get_node_or_null("Feet/LeftFoot") as Node3D
@onready var right_foot: Node3D = get_node_or_null("Feet/RightFoot") as Node3D
@onready var limbs_root: Node3D = get_node_or_null("Limbs") as Node3D
@onready var left_upper_leg: Node3D = get_node_or_null("Limbs/LeftUpperLeg") as Node3D
@onready var left_lower_leg: Node3D = get_node_or_null("Limbs/LeftLowerLeg") as Node3D
@onready var right_upper_leg: Node3D = get_node_or_null("Limbs/RightUpperLeg") as Node3D
@onready var right_lower_leg: Node3D = get_node_or_null("Limbs/RightLowerLeg") as Node3D
@onready var left_upper_arm: Node3D = get_node_or_null("Limbs/LeftUpperArm") as Node3D
@onready var left_lower_arm: Node3D = get_node_or_null("Limbs/LeftLowerArm") as Node3D
@onready var right_upper_arm: Node3D = get_node_or_null("Limbs/RightUpperArm") as Node3D
@onready var right_lower_arm: Node3D = get_node_or_null("Limbs/RightLowerArm") as Node3D

var health: int = 0
var attack_timer: float = 0.0
var state_timer: float = 0.0
var current_state: EnemyState = EnemyState.IDLE
var current_target: Node3D = null
var detection_zone_targets: Array[Node3D] = []
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
var replicated_is_grounded: bool = true
var replicated_is_moving: bool = false
var replicated_aim_target_position: Vector3 = Vector3.ZERO

var left_grip: Node3D = null
var right_grip: Node3D = null
var visual_yaw: float = 0.0
var walk_phase: float = 0.0
var landing_squash: float = 0.0
var procedural_nodes_ready: bool = false
var aim_target_position: Vector3 = Vector3.ZERO
var last_valid_aim_target_position: Vector3 = Vector3.ZERO
var procedural_animation_velocity: Vector3 = Vector3.ZERO
var procedural_animation_grounded: bool = true
var procedural_animation_moving: bool = false


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
	visual_yaw = rotation.y
	aim_target_position = global_position + (-global_basis.z.normalized() * 4.0) + Vector3.UP * aim_height
	last_valid_aim_target_position = aim_target_position
	replicated_aim_target_position = aim_target_position
	replicated_is_grounded = is_on_floor()
	replicated_is_moving = false
	procedural_animation_velocity = velocity
	procedural_animation_grounded = replicated_is_grounded
	procedural_animation_moving = false
	procedural_nodes_ready = _validate_procedural_scene_nodes()
	if left_probe != null:
		left_probe.enabled = true
	if right_probe != null:
		right_probe.enabled = true
	_update_weapon_visuals()
	if procedural_nodes_ready:
		_reset_procedural_pose()
		_update_enemy_procedural_animation(0.016)
	_cache_visual_root_base_transform()
	_apply_detection_radius()
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
		_update_enemy_procedural_animation(delta)


func _server_update(delta: float) -> void:
	if _dying:
		return

	if attack_timer > 0.0:
		attack_timer -= delta

	_apply_gravity(delta)

	if _process_vehicle_impact_stun(delta):
		move_and_slide()
		_update_idle_aim_target()
		_update_enemy_procedural_animation(delta)
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
	_update_enemy_procedural_animation(delta)
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
	_cleanup_detection_zone_targets()
	_refresh_visible_detected_targets()
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
		if not (item is Node3D):
			continue
		var other_enemy: Node3D = item as Node3D
		if not other_enemy.has_method("_can_receive_enemy_separation"):
			continue
		if not bool(other_enemy.call("_can_receive_enemy_separation")):
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

func apply_vehicle_impact_damage(amount: int, source: Node = null) -> void:
	apply_damage(amount, source)

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
		_send_state_rpc_now()


func _send_state_rpc_now() -> void:
	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var moving_value: bool = horizontal_velocity.length() > remote_animation_move_threshold
	var grounded_value: bool = is_on_floor()
	_receive_state.rpc(global_position, velocity, rotation.y, health, int(current_state), grounded_value, moving_value, aim_target_position)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y -= gravity_strength * delta


func _handle_no_target_state() -> void:
	if _has_last_known_target_position:
		aim_target_position = _last_known_target_position + Vector3.UP * aim_height
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
	_update_idle_aim_target()
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
	var target_point: Vector3 = _get_target_aim_point(combat_target)
	aim_target_position = target_point
	last_valid_aim_target_position = target_point
	var distance: float = global_position.distance_to(combat_target.global_position)
	var has_los: bool = true
	if attack_requires_line_of_sight:
		has_los = _has_line_of_sight(combat_target, target_point)
	var desired_attack_range: float = attack_range if not is_melee_attack else minf(attack_range, 1.8)

	_face_target(target_point)

	if distance <= desired_attack_range and has_los:
		_set_state(EnemyState.ATTACK)
		velocity.x = 0.0
		velocity.z = 0.0
		_clear_navigation_target()
		_try_attack(combat_target, target_point)
	else:
		var stop_distance: float = maxf(desired_attack_range - chase_stop_distance, 0.2)
		if not has_los:
			stop_distance = maxf(chase_stop_distance, 0.2)
			if distance <= desired_attack_range:
				_attack_debug("attack blocked by line of sight, keep moving toward target=%s distance=%.2f range=%.2f" % [combat_target.name, distance, desired_attack_range])

		_set_state(EnemyState.CHASE)
		_move_towards(combat_target.global_position, stop_distance)


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


func _cleanup_detection_zone_targets() -> void:
	var cleaned: Array[Node3D] = []
	for target in detection_zone_targets:
		if not _is_valid_target(target):
			continue
		if cleaned.has(target):
			continue
		cleaned.append(target)
	detection_zone_targets = cleaned


func _refresh_visible_detected_targets() -> void:
	var visible_targets: Array[Node3D] = []
	for target in detection_zone_targets:
		if not _can_detect_target(target):
			continue
		visible_targets.append(target)
	detected_targets = visible_targets

	if current_target != null and not forced_alert and not detected_targets.has(current_target):
		if _is_valid_target(current_target):
			_last_known_target_position = current_target.global_position
			_has_last_known_target_position = true
			_debug("current target lost detection line of sight, last known=%s" % str(_last_known_target_position))
		current_target = null
		_clear_navigation_target()


func _cleanup_detected_targets() -> void:
	_cleanup_detection_zone_targets()
	_refresh_visible_detected_targets()


func _can_detect_target(target: Node3D) -> bool:
	if not _is_valid_target(target):
		return false
	if detection_requires_line_of_sight and not _has_detection_line_of_sight(target):
		return false
	return true


func _has_detection_line_of_sight(target_body: Node3D) -> bool:
	var origin: Vector3 = global_position + Vector3.UP * aim_height
	var target_point: Vector3 = _get_target_aim_point(target_body)
	var hit: Dictionary = _raycast_with_mask(origin, target_point, detection_line_of_sight_mask, [self, detection_area])
	if hit.is_empty():
		return true

	var collider: Node = hit.get("collider") as Node
	var result: bool = _belongs_to_node(collider, target_body)
	if not result:
		_debug("detection line of sight blocked by: %s" % [collider.name if collider != null else "null"])
	return result


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
	return _raycast_with_mask(from, to, line_of_sight_mask, exclude)


func _raycast_with_mask(from: Vector3, to: Vector3, collision_mask: int, exclude: Array) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
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

	health = max(health - amount, 0)
	_debug("apply_damage: %d -> health=%d" % [amount, health])
	if health <= 0:
		_die(damage_source)
		return

	if current_state == EnemyState.IDLE:
		_try_retarget_from_damage_source(damage_source)

	var hit_direction: Vector3 = _get_damage_push_direction(damage_source)
	_play_damage_feedback_local(hit_direction)
	_play_damage_feedback_remote.rpc(hit_direction)
	_send_state_rpc_now()


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

	apply_damage(final_damage, _source)


func _try_retarget_from_damage_source(source: Node) -> void:
	var attacker: Node3D = _extract_target_from_damage_source(source)
	if not _is_valid_target(attacker):
		return

	if global_position.distance_to(attacker.global_position) > damage_retarget_max_distance:
		return

	_force_alert_target(attacker)
	_debug("retarget from damage source: %s" % attacker.name)


func _force_alert_target(target: Node3D) -> void:
	if not _is_valid_target(target):
		return

	current_target = target
	forced_alert = true
	_last_known_target_position = target.global_position
	_has_last_known_target_position = true
	_clear_navigation_target()
	_set_state(EnemyState.CHASE)


func _extract_target_from_damage_source(source: Node) -> Node3D:
	if source == null or not is_instance_valid(source):
		return null

	var direct_target: Node3D = _resolve_target_candidate(source)
	if direct_target != null:
		return direct_target

	for method_name in ["get_attacker", "get_shooter", "get_owner", "get_source", "get_damage_source", "get_driver"]:
		if source.has_method(method_name):
			var method_value = source.call(method_name)
			var method_target: Node3D = _resolve_target_candidate(method_value)
			if method_target != null:
				return method_target

	for property_name in ["attacker", "shooter", "source", "damage_source", "owner_player", "player_owner", "controlling_player", "driver", "owner", "instigator"]:
		var property_value = _safe_get_property(source, property_name)
		var property_target: Node3D = _resolve_target_candidate(property_value)
		if property_target != null:
			return property_target

	return null


func _resolve_target_candidate(candidate: Variant) -> Node3D:
	if candidate == null:
		return null
	if not (candidate is Node):
		return null

	var candidate_node: Node = candidate as Node
	if not is_instance_valid(candidate_node):
		return null
	if _is_valid_target(candidate_node):
		return candidate_node as Node3D

	var vehicle: Node = _get_vehicle_from_player(candidate_node)
	if vehicle != null and vehicle is Node3D:
		var vehicle_node: Node3D = vehicle as Node3D
		if _is_valid_target(vehicle_node):
			return vehicle_node

	return null


func _extract_player_from_source(source: Node) -> Node3D:
	return _extract_target_from_damage_source(source)



func _notify_nearby_allies_about_death(damage_source: Node = null) -> void:
	if not multiplayer.is_server():
		return

	var attacker: Node3D = _extract_target_from_damage_source(damage_source)
	if not _is_valid_target(attacker):
		return

	for node in get_tree().get_nodes_in_group("enemy"):
		if node == self:
			continue
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_method("_on_ally_death_reported"):
			continue

		node.call("_on_ally_death_reported", self, attacker)


func _on_ally_death_reported(dead_ally: Node, attacker: Node3D) -> void:
	if not multiplayer.is_server() or _dying:
		return
	if current_state != EnemyState.IDLE:
		return
	if dead_ally == null or not is_instance_valid(dead_ally):
		return
	var dead_ally_team_id: Variant = dead_ally.get("team_id")
	if dead_ally_team_id is int and int(dead_ally_team_id) != team_id:
		return
	if not _is_valid_target(attacker):
		return

	var max_alert_distance: float = maxf(ally_death_alert_radius, 0.0)
	if max_alert_distance > 0.0 and global_position.distance_to(dead_ally.global_position) > max_alert_distance:
		return

	_force_alert_target(attacker)
	_debug("ally killed, alert target: %s" % attacker.name)


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

	_notify_nearby_allies_about_death(damage_source)
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
	_free_child_if_exists(corpse_visual, "Weapon")
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
	if weapon_pivot != null:
		weapon_pivot.visible = true
	if stick_mesh != null:
		stick_mesh.visible = is_melee_attack
	if rifle_mesh != null:
		rifle_mesh.visible = not is_melee_attack
	_refresh_procedural_hand_grips()


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

	if not detection_zone_targets.has(target):
		detection_zone_targets.append(target)

	if not _can_detect_target(target):
		_debug("target entered detection zone but is not visible: %s from body=%s" % [target.name, body.name if body != null else "null"])
		return

	if not detected_targets.has(target):
		detected_targets.append(target)
		_debug("detected visible target entered: %s from body=%s" % [target.name, body.name if body != null else "null"])

	_last_known_target_position = target.global_position
	_has_last_known_target_position = true

	if current_target == null:
		current_target = target
		_debug("current target from visible detection: %s" % target.name)


func _on_detection_body_exited(body: Node) -> void:
	var target := _resolve_detected_target(body)
	if target == null:
		return

	if detection_zone_targets.has(target):
		detection_zone_targets.erase(target)

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

	var aim_lerp_weight: float = min(delta * 16.0, 1.0)
	aim_target_position = aim_target_position.lerp(replicated_aim_target_position, aim_lerp_weight)
	last_valid_aim_target_position = aim_target_position
	visual_yaw = lerp_angle(visual_yaw, replicated_yaw, aim_lerp_weight)

	health = replicated_health
	current_state = replicated_state


func _validate_procedural_scene_nodes() -> bool:
	var missing_nodes: Array[String] = []
	var required_nodes: Dictionary = {
		"VisualRoot": visual_root,
		"VisualRoot/Weapon": weapon_pivot,
		"VisualRoot/Weapon/LeftGrip": left_grip_placeholder,
		"VisualRoot/Weapon/RightGrip": right_grip_placeholder,
		"VisualRoot/LeftHip": left_hip,
		"VisualRoot/RightHip": right_hip,
		"VisualRoot/LeftShoulder": left_shoulder,
		"VisualRoot/RightShoulder": right_shoulder,
		"FootProbeRoot": foot_probe_root,
		"FootProbeRoot/LeftFootProbe": left_probe,
		"FootProbeRoot/RightFootProbe": right_probe,
		"Feet/LeftFoot": left_foot,
		"Feet/RightFoot": right_foot,
	}

	for node_path: String in required_nodes.keys():
		if required_nodes[node_path] == null:
			missing_nodes.append(node_path)

	if not missing_nodes.is_empty():
		push_error("NetworkProceduralEnemy: nodes obligatoires manquants: " + ", ".join(missing_nodes))
		return false

	var missing_limb_nodes: Array[String] = []
	var limb_nodes: Dictionary = {
		"Limbs/LeftUpperLeg": left_upper_leg,
		"Limbs/LeftLowerLeg": left_lower_leg,
		"Limbs/RightUpperLeg": right_upper_leg,
		"Limbs/RightLowerLeg": right_lower_leg,
		"Limbs/LeftUpperArm": left_upper_arm,
		"Limbs/LeftLowerArm": left_lower_arm,
		"Limbs/RightUpperArm": right_upper_arm,
		"Limbs/RightLowerArm": right_lower_arm,
	}

	for limb_path: String in limb_nodes.keys():
		if limb_nodes[limb_path] == null:
			missing_limb_nodes.append(limb_path)

	if not missing_limb_nodes.is_empty():
		push_warning("NetworkProceduralEnemy: membres manquants, ils seront ignorés: " + ", ".join(missing_limb_nodes))

	return true


func _reset_procedural_pose() -> void:
	if not procedural_nodes_ready:
		return

	visual_yaw = rotation.y
	if foot_probe_root != null:
		foot_probe_root.rotation.y = 0.0

	_refresh_procedural_hand_grips()
	left_foot.global_position = _sample_grounded_foot_position(-1.0, Vector3.ZERO, 0.0, true)
	right_foot.global_position = _sample_grounded_foot_position(1.0, Vector3.ZERO, PI, true)
	_update_idle_aim_target()
	last_valid_aim_target_position = aim_target_position


func _update_idle_aim_target() -> void:
	var forward_direction: Vector3 = -global_basis.z.normalized()
	if forward_direction.length_squared() <= 0.001:
		forward_direction = Vector3.FORWARD
	aim_target_position = global_position + forward_direction * 4.0 + Vector3.UP * aim_height
	last_valid_aim_target_position = aim_target_position


func _update_enemy_procedural_animation(delta: float) -> void:
	if not procedural_nodes_ready:
		return
	if _dying:
		return

	_update_procedural_animation_state(delta)
	_update_feet(delta)
	_update_visuals(delta)


func _update_procedural_animation_state(delta: float) -> void:
	if multiplayer.is_server():
		procedural_animation_velocity = velocity
		procedural_animation_grounded = is_on_floor()
		procedural_animation_moving = Vector3(velocity.x, 0.0, velocity.z).length() > remote_animation_move_threshold
		return

	var target_velocity: Vector3 = replicated_velocity
	if not replicated_is_moving:
		target_velocity.x = 0.0
		target_velocity.z = 0.0

	var velocity_lerp_weight: float = min(delta * remote_animation_velocity_lerp_speed, 1.0)
	procedural_animation_velocity = procedural_animation_velocity.lerp(target_velocity, velocity_lerp_weight)
	procedural_animation_grounded = replicated_is_grounded
	procedural_animation_moving = replicated_is_moving


func _get_procedural_horizontal_velocity() -> Vector3:
	var source_velocity: Vector3 = velocity if multiplayer.is_server() else procedural_animation_velocity
	var horizontal_velocity: Vector3 = Vector3(source_velocity.x, 0.0, source_velocity.z)

	if not multiplayer.is_server() and procedural_animation_moving:
		if horizontal_velocity.length() <= remote_animation_move_threshold:
			var yaw_basis: Basis = Basis(Vector3.UP, visual_yaw)
			var fallback_forward: Vector3 = -yaw_basis.z.normalized()
			horizontal_velocity = fallback_forward * move_speed * remote_animation_fallback_speed_ratio

	return horizontal_velocity


func _is_procedural_grounded() -> bool:
	if multiplayer.is_server():
		return is_on_floor()
	return procedural_animation_grounded


func _refresh_procedural_hand_grips() -> void:
	left_grip = left_grip_placeholder
	right_grip = right_grip_placeholder

	var current_visual_weapon: Node3D = _get_current_held_visual_weapon()
	if current_visual_weapon == null:
		return

	var found_left: Node = current_visual_weapon.find_child("LeftGrip", true, false)
	var found_right: Node = current_visual_weapon.find_child("RightGrip", true, false)

	if found_left is Node3D:
		left_grip = found_left as Node3D
	if found_right is Node3D:
		right_grip = found_right as Node3D


func _get_current_held_visual_weapon() -> Node3D:
	if weapon_pivot != null and is_instance_valid(weapon_pivot):
		return weapon_pivot
	return null


func _update_feet(delta: float) -> void:
	var horizontal_velocity: Vector3 = _get_procedural_horizontal_velocity()
	var speed_ratio: float = clamp(horizontal_velocity.length() / move_speed, 0.0, 1.0)
	var grounded: bool = _is_procedural_grounded()

	if grounded and speed_ratio > 0.03:
		walk_phase += delta * lerp(3.0, gait_frequency, speed_ratio)

	if foot_probe_root != null:
		foot_probe_root.rotation.y = _get_visual_local_yaw()

	if grounded:
		var left_target: Vector3 = _sample_grounded_foot_position(-1.0, horizontal_velocity, 0.0)
		var right_target: Vector3 = _sample_grounded_foot_position(1.0, horizontal_velocity, PI)
		var follow_speed: float = foot_follow_speed + speed_ratio * 8.0
		left_foot.global_position = left_foot.global_position.lerp(left_target, delta * follow_speed)
		right_foot.global_position = right_foot.global_position.lerp(right_target, delta * follow_speed)
		left_foot.global_position = _clamp_foot_target(-1.0, left_foot.global_position)
		right_foot.global_position = _clamp_foot_target(1.0, right_foot.global_position)
	else:
		_update_air_feet(delta)


func _sample_grounded_foot_position(side_sign: float, horizontal_velocity: Vector3, phase_offset: float, instant: bool = false) -> Vector3:
	var speed_ratio: float = clamp(horizontal_velocity.length() / move_speed, 0.0, 1.0)
	var local_velocity: Vector3 = _world_to_visual_local(horizontal_velocity)
	var move_direction: Vector3 = Vector3.ZERO
	if local_velocity.length_squared() > 0.001:
		move_direction = local_velocity.normalized()

	var foot_data: Dictionary = _get_foot_cycle_data(side_sign, move_direction, speed_ratio, walk_phase + phase_offset)
	var local_x: float = float(foot_data.get("local_x", 0.0))
	var local_z: float = float(foot_data.get("local_z", 0.0))
	var lift: float = float(foot_data.get("lift", 0.0))

	if instant or speed_ratio < 0.03:
		local_x = side_sign * stance_width
		local_z = idle_foot_forward_offset
		lift = 0.0

	var probe: RayCast3D = left_probe if side_sign < 0.0 else right_probe
	probe.position.x = local_x
	probe.position.z = local_z
	var grounded_position: Vector3 = _get_probe_ground_position(probe, side_sign)
	grounded_position.y += lift
	return _clamp_foot_target(side_sign, grounded_position)


func _get_foot_cycle_data(side_sign: float, move_direction: Vector3, speed_ratio: float, phase_value: float) -> Dictionary:
	var cycle: float = sin(phase_value)
	var opposite_cycle: float = sin(phase_value + PI)
	var swing_factor: float = max(cycle, 0.0)
	var support_factor: float = max(-cycle, 0.0)
	var lift_phase: float = max(opposite_cycle, 0.0)
	var forward_blend: float = abs(move_direction.z)
	var strafe_blend: float = abs(move_direction.x)

	var base_x: float = side_sign * stance_width
	var base_z: float = idle_foot_forward_offset
	var stride_offset: Vector3 = move_direction * (cycle * stride_length * speed_ratio)
	stride_offset += move_direction * (swing_factor * forward_step_reach * speed_ratio)

	var local_x: float = base_x + stride_offset.x
	local_x += -side_sign * support_inward * support_factor * forward_blend * speed_ratio
	local_x += side_sign * swing_outward * swing_factor * forward_blend * speed_ratio

	var local_z: float = base_z + stride_offset.z
	local_z += -side_sign * move_direction.x * strafe_foot_lead * strafe_blend * speed_ratio

	var lift_amount: float = step_height * lift_phase * speed_ratio

	return {
		"local_x": local_x,
		"local_z": local_z,
		"lift": lift_amount
	}


func _update_air_feet(delta: float) -> void:
	var left_air_local: Vector3 = Vector3(-stance_width * 0.85, 0.30, 0.10)
	var right_air_local: Vector3 = Vector3(stance_width * 0.85, 0.30, 0.10)
	var left_air_world: Vector3 = _clamp_foot_target(-1.0, foot_probe_root.to_global(left_air_local))
	var right_air_world: Vector3 = _clamp_foot_target(1.0, foot_probe_root.to_global(right_air_local))
	left_foot.global_position = left_foot.global_position.lerp(left_air_world, delta * airborne_foot_pull)
	right_foot.global_position = right_foot.global_position.lerp(right_air_world, delta * airborne_foot_pull)
	left_foot.global_position = _clamp_foot_target(-1.0, left_foot.global_position)
	right_foot.global_position = _clamp_foot_target(1.0, right_foot.global_position)


func _get_probe_ground_position(probe: RayCast3D, side_sign: float) -> Vector3:
	var hip_world_position: Vector3 = _get_hip_position(side_sign)
	var nominal_foot_y: float = hip_world_position.y - max_leg_reach * 0.82
	var highest_ground_y: float = min(hip_world_position.y - min_foot_below_hip, nominal_foot_y + max_stair_step_up)
	var lowest_ground_y: float = nominal_foot_y - max_stair_step_down

	if probe.is_colliding():
		var hit_world_position: Vector3 = probe.get_collision_point() + Vector3.UP * foot_ground_offset
		hit_world_position.y = clamp(hit_world_position.y, lowest_ground_y, highest_ground_y)
		return _clamp_foot_target(side_sign, hit_world_position)

	var suspended_world_position: Vector3 = probe.global_position
	suspended_world_position.y = nominal_foot_y
	return _clamp_foot_target(side_sign, suspended_world_position)


func _get_hip_position(side_sign: float) -> Vector3:
	if side_sign < 0.0:
		return left_hip.global_position
	return right_hip.global_position


func _clamp_foot_target(side_sign: float, target_position: Vector3) -> Vector3:
	var hip_world_position: Vector3 = _get_hip_position(side_sign)
	var highest_allowed_y: float = hip_world_position.y - min_foot_below_hip
	var lowest_allowed_y: float = hip_world_position.y - max_leg_reach
	target_position.y = clamp(target_position.y, lowest_allowed_y, highest_allowed_y)

	var hip_to_target: Vector3 = target_position - hip_world_position
	var target_distance: float = hip_to_target.length()
	if target_distance > max_leg_reach:
		var clamped_direction: Vector3 = hip_to_target.normalized()
		target_position = hip_world_position + clamped_direction * max_leg_reach
		target_position.y = clamp(target_position.y, lowest_allowed_y, highest_allowed_y)

	return target_position


func _update_visuals(delta: float) -> void:
	_update_body_rotation(delta)
	_update_body_motion(delta)
	_update_weapon_pose(delta)
	_update_limbs()


func _update_body_rotation(delta: float) -> void:
	var aim_direction: Vector3 = aim_target_position - global_position
	aim_direction.y = 0.0
	if aim_direction.length_squared() <= 0.001:
		return

	var target_yaw: float = atan2(-aim_direction.x, -aim_direction.z)
	visual_yaw = lerp_angle(visual_yaw, target_yaw, delta * turn_speed)


func _update_body_motion(delta: float) -> void:
	var horizontal_velocity: Vector3 = _get_procedural_horizontal_velocity()
	var speed_ratio: float = clamp(horizontal_velocity.length() / move_speed, 0.0, 1.0)

	var bob: float = sin(walk_phase * 2.0) * body_bob_amount * speed_ratio
	var local_velocity: Vector3 = _world_to_visual_local(horizontal_velocity)
	var pitch: float = clamp(local_velocity.z / move_speed, -1.0, 1.0) * body_tilt_amount
	var roll: float = clamp(-local_velocity.x / move_speed, -1.0, 1.0) * body_tilt_amount

	landing_squash = move_toward(landing_squash, 0.0, delta * 5.5)
	var squash: float = landing_squash * landing_squash_strength
	if landing_squash < 0.0:
		squash = landing_squash * landing_squash_strength * 0.5

	visual_root.position.y = lerp(visual_root.position.y, bob, delta * 12.0)
	visual_root.rotation = Vector3(pitch, _get_visual_local_yaw(), roll)
	visual_root.scale = Vector3(1.0 + abs(squash) * 0.45, 1.0 - squash, 1.0 + abs(squash) * 0.25)


func _get_visual_local_yaw() -> float:
	return wrapf(visual_yaw - rotation.y, -PI, PI)


func _update_weapon_pose(delta: float) -> void:
	var current_visual_weapon: Node3D = _get_current_held_visual_weapon()
	if current_visual_weapon == null:
		_refresh_procedural_hand_grips()
		return

	current_visual_weapon.position = current_visual_weapon.position.lerp(weapon_local_position, min(delta * weapon_follow_speed, 1.0))

	var weapon_to_target: Vector3 = aim_target_position - current_visual_weapon.global_position
	var flat_weapon_to_target: Vector3 = weapon_to_target
	flat_weapon_to_target.y = 0.0
	if flat_weapon_to_target.length() < visual_aim_min_target_distance:
		_refresh_procedural_hand_grips()
		return

	if weapon_to_target.length_squared() > 0.001:
		current_visual_weapon.look_at(aim_target_position, Vector3.UP)
		current_visual_weapon.rotation.z = 0.0

	_refresh_procedural_hand_grips()


func _world_to_visual_local(world_vector: Vector3) -> Vector3:
	var yaw_transform_basis: Basis = Basis(Vector3.UP, visual_yaw)
	return yaw_transform_basis.inverse() * world_vector


func _update_limbs() -> void:
	if left_grip == null or right_grip == null:
		_refresh_procedural_hand_grips()
	if left_grip == null or right_grip == null:
		return

	left_foot.global_position = _clamp_foot_target(-1.0, left_foot.global_position)
	right_foot.global_position = _clamp_foot_target(1.0, right_foot.global_position)

	var body_forward: Vector3 = -visual_root.global_transform.basis.z
	var body_right: Vector3 = visual_root.global_transform.basis.x

	var left_knee: Vector3 = _solve_two_bone_joint(left_hip.global_position, left_foot.global_position, (body_forward + body_right * -0.25).normalized(), upper_leg_length, lower_leg_length)
	var right_knee: Vector3 = _solve_two_bone_joint(right_hip.global_position, right_foot.global_position, (body_forward + body_right * 0.25).normalized(), upper_leg_length, lower_leg_length)

	_place_segment_between_points(left_upper_leg, left_hip.global_position, left_knee)
	_place_segment_between_points(left_lower_leg, left_knee, left_foot.global_position)
	_place_segment_between_points(right_upper_leg, right_hip.global_position, right_knee)
	_place_segment_between_points(right_lower_leg, right_knee, right_foot.global_position)

	var left_elbow: Vector3 = _solve_two_bone_joint(left_shoulder.global_position, left_grip.global_position, (-body_forward + body_right * -1.00).normalized(), upper_arm_length, lower_arm_length)
	var right_elbow: Vector3 = _solve_two_bone_joint(right_shoulder.global_position, right_grip.global_position, (-body_forward + body_right * 0.70).normalized(), upper_arm_length, lower_arm_length)

	_place_segment_between_points(left_upper_arm, left_shoulder.global_position, left_elbow)
	_place_segment_between_points(left_lower_arm, left_elbow, left_grip.global_position)
	_place_segment_between_points(right_upper_arm, right_shoulder.global_position, right_elbow)
	_place_segment_between_points(right_lower_arm, right_elbow, right_grip.global_position)


func _solve_two_bone_joint(root_position: Vector3, target_position: Vector3, bend_direction: Vector3, upper_length: float, lower_length: float) -> Vector3:
	var to_target: Vector3 = target_position - root_position
	var distance_to_target: float = to_target.length()
	if distance_to_target <= 0.0001:
		return root_position + bend_direction.normalized() * upper_length

	var target_direction: Vector3 = to_target / distance_to_target
	var clamped_distance: float = clamp(distance_to_target, 0.001, upper_length + lower_length - 0.001)
	var bend_axis: Vector3 = bend_direction - target_direction * bend_direction.dot(target_direction)
	if bend_axis.length_squared() <= 0.0001:
		bend_axis = target_direction.cross(Vector3.UP)
		if bend_axis.length_squared() <= 0.0001:
			bend_axis = target_direction.cross(Vector3.RIGHT)

	bend_axis = bend_axis.normalized()
	var along_distance: float = (upper_length * upper_length - lower_length * lower_length + clamped_distance * clamped_distance) / (2.0 * clamped_distance)
	var height_squared: float = max(upper_length * upper_length - along_distance * along_distance, 0.0)
	var bend_height: float = sqrt(height_squared)
	return root_position + target_direction * along_distance + bend_axis * bend_height


func _place_segment_between_points(segment: Node3D, start_position: Vector3, end_position: Vector3) -> void:
	if segment == null:
		return

	var segment_direction: Vector3 = end_position - start_position
	var segment_length: float = segment_direction.length()
	if segment_length <= 0.001:
		return

	var midpoint: Vector3 = start_position + segment_direction * 0.5
	var y_axis: Vector3 = segment_direction.normalized()
	var x_axis: Vector3 = y_axis.cross(Vector3.FORWARD)
	if x_axis.length_squared() <= 0.001:
		x_axis = y_axis.cross(Vector3.RIGHT)

	x_axis = x_axis.normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	var segment_basis: Basis = Basis(x_axis, y_axis, z_axis).orthonormalized()
	segment.global_transform = Transform3D(segment_basis, midpoint)
	segment.scale = Vector3(1.0, segment_length, 1.0)


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
func _receive_state(
	position_value: Vector3,
	velocity_value: Vector3,
	yaw_value: float,
	health_value: int,
	state_value: int,
	grounded_value: bool,
	moving_value: bool,
	aim_target_value: Vector3
) -> void:
	if multiplayer.is_server():
		return
	replicated_position = position_value
	replicated_velocity = velocity_value
	replicated_yaw = yaw_value
	replicated_health = health_value
	replicated_state = state_value
	replicated_is_grounded = grounded_value
	replicated_is_moving = moving_value
	replicated_aim_target_position = aim_target_value



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
