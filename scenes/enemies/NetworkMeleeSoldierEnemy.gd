extends NetworkZombieEnemy

class_name NetworkMeleeSoldierEnemy

enum MeleeStyle {
	TONFA,
	SHIELD,
	HAMMER
}

@export_group("Melee Soldier")
@export var melee_style: int = MeleeStyle.TONFA
@export_range(0.05, 0.8, 0.01) var melee_swing_duration: float = 0.22
@export_range(0.0, 1.5, 0.01) var melee_swing_strength: float = 1.0
@export_range(0.0, 1.0, 0.01) var shield_front_damage_multiplier: float = 0.35
@export_range(-1.0, 1.0, 0.01) var shield_front_dot: float = 0.25
@export var shield_blocks_projectiles: bool = true
@export_group("Visual Size")
@export_range(0.6, 1.8, 0.01) var visual_size_scale: float = 1.0


@export_group("Melee Placement")
@export_range(0.25, 3.0, 0.05) var melee_attack_ring_radius: float = 0.82
@export_range(0.25, 4.0, 0.05) var melee_chase_ring_radius: float = 1.10
@export_range(0.75, 5.0, 0.05) var melee_vehicle_attack_ring_radius: float = 2.20
@export_range(1.0, 6.0, 0.05) var melee_vehicle_chase_ring_radius: float = 2.65
@export_range(0.0, 0.8, 0.01) var melee_ring_spacing: float = 0.14
@export_range(1, 4, 1) var melee_ring_count: int = 2
@export_range(0.0, 1.5, 0.05) var melee_attack_range_padding: float = 0.35
@export_range(0.0, 2.5, 0.05) var melee_vehicle_attack_range_padding: float = 0.45
@export_range(0.02, 0.8, 0.01) var melee_slot_stop_distance: float = 0.12
@export var melee_force_slot_inside_attack_range: bool = true

@export_group("Melee Weapon Pose")
@export_range(-120.0, 120.0, 1.0) var weapon_guard_roll_deg: float = -18.0
@export_range(-90.0, 90.0, 1.0) var weapon_guard_pitch_deg: float = -8.0
@export_range(0.0, 140.0, 1.0) var weapon_swing_arc_deg: float = 95.0
@export_range(0.0, 70.0, 1.0) var weapon_swing_pitch_deg: float = 18.0
@export_range(0.0, 0.5, 0.01) var weapon_swing_forward_offset: float = 0.10
@export_range(0.0, 0.35, 0.01) var weapon_swing_side_offset: float = 0.06

var _melee_swing_timer: float = 0.0

@onready var tonfa_mesh: Node3D = get_node_or_null("VisualRoot/Weapon/StickMesh") as Node3D
@onready var shield_mesh: Node3D = get_node_or_null("VisualRoot/Weapon/ShieldMesh") as Node3D
@onready var hammer_handle_mesh: Node3D = get_node_or_null("VisualRoot/Weapon/HammerHandle") as Node3D
@onready var hammer_head_mesh: Node3D = get_node_or_null("VisualRoot/Weapon/HammerHead") as Node3D


func _ready() -> void:
	# Reuse the optimized horde/melee path from NetworkZombieEnemy.
	# These units are soldiers visually, but their AI profile is close to a horde melee enemy.
	is_melee_attack = true
	projectile_scene = null
	detection_requires_line_of_sight = false
	attack_requires_line_of_sight = false
	death_weapon_enabled = true
	debug_logs = false
	attack_debug_logs = false
	use_enemy_target_manager = true
	use_direct_move_when_close = true
	direct_move_distance = maxf(direct_move_distance, 2.5)
	state_send_interval = 0.25
	scan_interval_frames = maxi(scan_interval_frames, 35)
	repath_interval_frames = maxi(repath_interval_frames, 45)
	attack_check_interval_frames = maxi(attack_check_interval_frames, 10)

	# Tighten the horde slots for melee soldiers.
	# The previous zombie-style ring could place them outside their real hit range.
	zombie_attack_ring_radius = melee_attack_ring_radius
	zombie_chase_ring_radius = melee_chase_ring_radius
	zombie_surround_ring_spacing = melee_ring_spacing
	zombie_surround_ring_count = melee_ring_count
	zombie_surround_slot_stop_distance = melee_slot_stop_distance

	super._ready()
	death_weapon_enabled = true
	direct_move_distance = zombie_force_direct_move_distance
	_configure_melee_arm_pose()
	_update_weapon_visuals()


func _physics_process(delta: float) -> void:
	if _melee_swing_timer > 0.0:
		_melee_swing_timer = maxf(_melee_swing_timer - delta, 0.0)
	super._physics_process(delta)


func _update_weapon_visuals() -> void:
	if weapon_pivot != null:
		weapon_pivot.visible = true
	if tonfa_mesh != null:
		tonfa_mesh.visible = melee_style == MeleeStyle.TONFA or melee_style == MeleeStyle.SHIELD
	if shield_mesh != null:
		shield_mesh.visible = melee_style == MeleeStyle.SHIELD
	if hammer_handle_mesh != null:
		hammer_handle_mesh.visible = melee_style == MeleeStyle.HAMMER
	if hammer_head_mesh != null:
		hammer_head_mesh.visible = melee_style == MeleeStyle.HAMMER
	if rifle_mesh != null:
		rifle_mesh.visible = false
	_refresh_procedural_hand_grips()


func _configure_zombie_arm_pose() -> void:
	_configure_melee_arm_pose()


func _configure_melee_arm_pose() -> void:
	if weapon_pivot == null:
		return

	_configure_weapon_mesh_orientation()

	match melee_style:
		MeleeStyle.SHIELD:
			weapon_local_position = Vector3(0.08, 1.18, -0.56)
			weapon_guard_roll_deg = -10.0
			weapon_guard_pitch_deg = -3.0
			weapon_swing_arc_deg = 55.0
			weapon_swing_pitch_deg = 8.0
			weapon_swing_forward_offset = 0.05
			weapon_swing_side_offset = 0.03
			if left_grip_placeholder != null:
				left_grip_placeholder.position = Vector3(-0.20, -0.02, -0.24)
			if right_grip_placeholder != null:
				right_grip_placeholder.position = Vector3(0.13, -0.22, -0.03)
		MeleeStyle.HAMMER:
			weapon_local_position = Vector3(0.08, 1.28, -0.54)
			weapon_guard_roll_deg = -44.0
			weapon_guard_pitch_deg = -18.0
			weapon_swing_arc_deg = 115.0
			weapon_swing_pitch_deg = 48.0
			weapon_swing_forward_offset = 0.16
			weapon_swing_side_offset = 0.09
			if left_grip_placeholder != null:
				left_grip_placeholder.position = Vector3(-0.08, 0.10, 0.0)
			if right_grip_placeholder != null:
				right_grip_placeholder.position = Vector3(0.10, -0.20, 0.0)
		_:
			weapon_local_position = Vector3(0.18, 1.20, -0.54)
			weapon_guard_roll_deg = -28.0
			weapon_guard_pitch_deg = -8.0
			weapon_swing_arc_deg = 95.0
			weapon_swing_pitch_deg = 20.0
			weapon_swing_forward_offset = 0.11
			weapon_swing_side_offset = 0.06
			if left_grip_placeholder != null:
				left_grip_placeholder.position = Vector3(-0.08, 0.10, 0.0)
			if right_grip_placeholder != null:
				right_grip_placeholder.position = Vector3(0.10, -0.18, 0.0)

	weapon_pivot.position = weapon_local_position
	_refresh_procedural_hand_grips()


func _configure_weapon_mesh_orientation() -> void:
	# Meshes are kept vertical inside the weapon pivot.
	# The pivot still looks at the target, but the weapon is now held like a sword/hammer,
	# instead of being pushed forward like a spear.
	if tonfa_mesh != null:
		tonfa_mesh.position = Vector3(0.02, -0.02, 0.0)
		tonfa_mesh.rotation = Vector3.ZERO
	if hammer_handle_mesh != null:
		hammer_handle_mesh.position = Vector3(0.0, 0.0, 0.0)
		hammer_handle_mesh.rotation = Vector3.ZERO
	if hammer_head_mesh != null:
		hammer_head_mesh.position = Vector3(0.0, 0.48, 0.0)
		hammer_head_mesh.rotation = Vector3.ZERO
	if shield_mesh != null:
		shield_mesh.position = Vector3(-0.12, 0.00, -0.22)
		shield_mesh.rotation = Vector3.ZERO


func _update_body_motion(delta: float) -> void:
	super._update_body_motion(delta)
	if visual_root != null and absf(visual_size_scale - 1.0) > 0.001:
		visual_root.scale *= visual_size_scale


func _get_zombie_effective_attack_range(target: Node) -> float:
	var effective_range: float = attack_range + melee_attack_range_padding
	if _is_zombie_vehicle_target(target):
		effective_range += zombie_vehicle_melee_range_bonus + melee_vehicle_attack_range_padding
	return effective_range


func _get_zombie_surround_position(target: Node3D, distance_squared_to_target: float) -> Vector3:
	if not zombie_use_surround_slots or target == null or not is_instance_valid(target):
		return target.global_position if target != null else global_position

	var target_position: Vector3 = target.global_position
	var start_distance: float = maxf(zombie_surround_start_distance, 0.1)
	if distance_squared_to_target > start_distance * start_distance:
		return _get_zombie_approach_spread_position(target)

	var is_vehicle: bool = _is_zombie_vehicle_target(target)
	var effective_attack_range: float = _get_zombie_effective_attack_range(target)
	var near_attack_distance: bool = distance_squared_to_target <= effective_attack_range * effective_attack_range * 4.0
	var base_radius: float = melee_attack_ring_radius if near_attack_distance else melee_chase_ring_radius

	if is_vehicle:
		base_radius = melee_vehicle_attack_ring_radius if near_attack_distance else melee_vehicle_chase_ring_radius

	var ring_count: int = max(melee_ring_count, 1)
	var ring_index: int = clampi(_zombie_surround_ring_index, 0, ring_count - 1)
	var radius: float = (base_radius + float(ring_index) * melee_ring_spacing) * _zombie_surround_radius_scale

	if melee_force_slot_inside_attack_range and near_attack_distance:
		var safe_max_radius: float = maxf(0.2, effective_attack_range - melee_slot_stop_distance - 0.08)
		radius = minf(radius, safe_max_radius)

	var offset: Vector3 = Vector3(cos(_zombie_surround_angle), 0.0, sin(_zombie_surround_angle)) * radius
	return target_position + offset


func _get_planar_distance_squared_to_node(target: Node3D) -> float:
	var offset: Vector3 = target.global_position - global_position
	offset.y = 0.0
	return offset.length_squared()


func _perform_attack(combat_target: Node3D, _target_point: Vector3) -> bool:
	if combat_target == null or not is_instance_valid(combat_target):
		return false

	var effective_attack_range: float = _get_zombie_effective_attack_range(combat_target)
	var attack_range_squared: float = effective_attack_range * effective_attack_range
	if _get_planar_distance_squared_to_node(combat_target) > attack_range_squared:
		return false

	_start_melee_swing()
	return _apply_melee_damage_to_target(combat_target)


func _start_melee_swing(sync_remote: bool = true) -> void:
	_melee_swing_timer = maxf(melee_swing_duration, 0.05)
	if sync_remote and multiplayer.is_server():
		_start_melee_swing_remote.rpc()


func _update_weapon_pose(delta: float) -> void:
	super._update_weapon_pose(delta)

	if weapon_pivot == null:
		return

	var duration: float = maxf(melee_swing_duration, 0.05)
	var progress: float = 0.0
	if _melee_swing_timer > 0.0:
		progress = 1.0 - clampf(_melee_swing_timer / duration, 0.0, 1.0)

	var windup_progress: float = clampf(progress / 0.28, 0.0, 1.0)
	var strike_progress: float = clampf((progress - 0.18) / 0.48, 0.0, 1.0)
	var recovery_progress: float = clampf((progress - 0.68) / 0.32, 0.0, 1.0)
	var windup: float = _smoothstep(windup_progress)
	var strike: float = _smoothstep(strike_progress)
	var recovery: float = _smoothstep(recovery_progress)

	var base_roll: float = deg_to_rad(weapon_guard_roll_deg)
	var base_pitch: float = deg_to_rad(weapon_guard_pitch_deg)
	var swing_arc: float = deg_to_rad(weapon_swing_arc_deg) * melee_swing_strength
	var swing_pitch: float = deg_to_rad(weapon_swing_pitch_deg) * melee_swing_strength

	var attack_roll: float = base_roll
	var attack_pitch: float = base_pitch
	var active_swing: float = 0.0
	if _melee_swing_timer > 0.0:
		# Side swing: weapon starts pulled back, crosses the body, then returns to guard.
		attack_roll += lerpf(-swing_arc * 0.45, swing_arc * 0.55, strike)
		attack_roll = lerpf(attack_roll, base_roll, recovery)
		attack_pitch += sin(strike * PI) * swing_pitch
		active_swing = sin(strike * PI)
		weapon_pivot.position += Vector3(
			weapon_swing_side_offset * (strike - 0.5) * 2.0,
			0.06 * windup,
			-weapon_swing_forward_offset * active_swing
		)

	weapon_pivot.rotation.x += attack_pitch
	weapon_pivot.rotation.z += attack_roll
	_refresh_procedural_hand_grips()


func _smoothstep(value: float) -> float:
	var x: float = clampf(value, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func apply_projectile_damage(
	amount: int,
	to_projectile_penetration: int = 0,
	_source_team: int = 0,
	_allow_tk: bool = false,
	_source: Node = null
) -> void:
	if melee_style != MeleeStyle.SHIELD or not shield_blocks_projectiles:
		super.apply_projectile_damage(amount, to_projectile_penetration, _source_team, _allow_tk, _source)
		return

	var final_amount: int = amount
	if _is_damage_source_in_front(_source):
		final_amount = max(1, int(round(float(amount) * shield_front_damage_multiplier)))

	super.apply_projectile_damage(final_amount, to_projectile_penetration, _source_team, _allow_tk, _source)


func _is_damage_source_in_front(source: Node) -> bool:
	if source == null or not is_instance_valid(source):
		return false

	var source_position: Vector3 = global_position
	if source is Node3D:
		source_position = (source as Node3D).global_position
	else:
		var resolved_position: Variant = _get_world_position_from_source(source)
		if resolved_position is Vector3:
			source_position = resolved_position
		else:
			return false

	var to_source: Vector3 = source_position - global_position
	to_source.y = 0.0
	if to_source.length_squared() <= 0.001:
		return false

	var forward: Vector3 = -global_basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		return false

	return forward.normalized().dot(to_source.normalized()) >= shield_front_dot


@rpc("authority", "call_remote", "unreliable")
func _start_melee_swing_remote() -> void:
	if multiplayer.is_server():
		return
	_start_melee_swing(false)
