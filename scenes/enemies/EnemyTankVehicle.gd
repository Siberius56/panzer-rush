extends VehicleBody3D
class_name EnemyTankVehicle

signal died(enemy: Node)
signal health_changed(current_health: int, max_health: int)

@export_group("Network")
@export var network_sync_enabled: bool = true
@export_range(0.02, 0.50, 0.01) var network_sync_interval: float = 0.05
@export_range(1.0, 40.0, 0.5) var network_interpolation_speed: float = 14.0
@export var network_snap_distance: float = 4.0
@export var client_freeze_physics: bool = true
@export var spawn_projectile_fx_on_clients: bool = true

@export_group("Team")
@export var team_id: int = 2
@export var can_teamkill: bool = false

@export_group("Health")
@export var max_health: int = 320
@export var armor_rating: int = 5
@export var minimum_damage_after_armor: int = 0
@export var death_effect_scene: PackedScene

@export_group("Detection")
@export var target_groups: PackedStringArray = PackedStringArray(["players", "player", "player_vehicles", "vehicles"])
@export var detection_radius: float = 45.0
@export var attack_range: float = 28.0
@export var target_refresh_interval: float = 0.25
@export_flags_3d_physics var line_of_sight_mask: int = 1
@export_node_path("Area3D") var detection_area_path: NodePath = ^"DetectionArea"

@export_group("Movement")
@export var stop_distance: float = 20.0
@export var reverse_distance: float = 7.0
@export var max_engine_force: float = 1800.0
@export var reverse_engine_force: float = 900.0
@export var max_brake_force: float = 120.0
@export var use_vehicle_body_controls: bool = true
@export var use_wheel_controls: bool = true
@export var use_backup_drive_force: bool = true
@export var backup_drive_force: float = 900.0
@export var backup_force_after_stuck_time: float = 0.45
@export_range(0.0, 45.0, 0.5) var max_steering_angle_deg: float = 28.0
@export_range(1.0, 180.0, 1.0) var steering_speed_deg: float = 95.0
@export var reduce_speed_when_turning: bool = true
@export var invert_steering: bool = true
@export var debug_wheel_contacts: bool = false
@export var debug_ai_state: bool = false

@export_group("Turret")
@export_node_path("Node3D") var turret_yaw_path: NodePath = ^"TurretYaw"
@export_node_path("Node3D") var barrel_pitch_path: NodePath = ^"TurretYaw/BarrelPitch"
@export_node_path("Marker3D") var muzzle_path: NodePath = ^"TurretYaw/BarrelPitch/Muzzle"
@export_range(1.0, 360.0, 1.0) var turret_yaw_speed_deg: float = 130.0
@export_range(1.0, 180.0, 1.0) var barrel_pitch_speed_deg: float = 90.0
@export_range(-45.0, 0.0, 0.5) var min_pitch_deg: float = -8.0
@export_range(0.0, 75.0, 0.5) var max_pitch_deg: float = 25.0
@export_range(0.0, 20.0, 0.25) var fire_angle_tolerance_deg: float = 4.0
@export var invert_turret_yaw: bool = true
@export var invert_barrel_pitch: bool = true

@export_group("Weapon")
@export var projectile_scene: PackedScene
@export var projectile_damage: int = 38
@export var projectile_penetration: int = 1
@export_range(0.1, 10.0, 0.05) var fire_rate: float = 0.65
@export_range(0.0, 15.0, 0.1) var aim_dispersion_deg: float = 2.0
@export var fire_only_with_line_of_sight: bool = true

var current_health: int = 0

var _target: Variant = null
var _candidate_targets: Array = []
var _wheels: Array[VehicleWheel3D] = []
var _fire_cooldown: float = 0.0
var _target_refresh_timer: float = 0.0
var _current_steering: float = 0.0
var _dead: bool = false
var _wheel_debug_timer: float = 0.0
var _ai_debug_timer: float = 0.0
var _stuck_drive_timer: float = 0.0

var _network_sync_timer: float = 0.0
var _last_network_client_state: bool = false
var _client_has_sync: bool = false
var _client_target_transform: Transform3D = Transform3D.IDENTITY
var _client_target_linear_velocity: Vector3 = Vector3.ZERO
var _client_target_angular_velocity: Vector3 = Vector3.ZERO
var _client_target_turret_rotation: Vector3 = Vector3.ZERO
var _client_target_barrel_rotation: Vector3 = Vector3.ZERO
var _death_fx_spawned: bool = false

@onready var _detection_area: Area3D = get_node_or_null(detection_area_path) as Area3D
@onready var _turret_yaw: Node3D = get_node_or_null(turret_yaw_path) as Node3D
@onready var _barrel_pitch: Node3D = get_node_or_null(barrel_pitch_path) as Node3D
@onready var _muzzle: Marker3D = get_node_or_null(muzzle_path) as Marker3D


func _enter_tree() -> void:
	# Le serveur a toujours l'ID 1 dans l'API haut niveau de Godot.
	# Les RPC authority fonctionneront donc depuis le host/serveur.
	set_multiplayer_authority(1)


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("enemies")

	current_health = max_health
	_client_target_transform = global_transform
	_last_network_client_state = _is_network_client()

	_collect_wheels(self)
	_connect_detection_area()
	_update_detection_shape_radius()
	_configure_network_physics()


func _physics_process(delta: float) -> void:
	_update_network_mode_if_needed()

	if _is_network_client():
		_client_interpolate_network_state(delta)
		return

	if _dead:
		return

	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_target_refresh_timer -= delta

	if _target_refresh_timer <= 0.0:
		_target_refresh_timer = target_refresh_interval
		_prune_candidates()
		_scan_targets_from_groups()
		_target = _find_best_target()

	var target_node := _as_valid_node3d(_target)
	if target_node == null:
		_target = null
		_idle(delta)
		_server_sync_network_state(delta)
		return

	var target_distance := _flat_distance_to(target_node)
	var has_los := true
	if fire_only_with_line_of_sight:
		has_los = _has_line_of_sight(target_node)

	var can_attack := target_distance <= attack_range and has_los

	_aim_turret_at(target_node, delta)

	if can_attack:
		_stop_vehicle(delta)
		_try_fire(target_node)
	else:
		_drive_towards(target_node, delta)

	_debug_ai_state(delta, target_node, target_distance, has_los, can_attack)
	_debug_wheel_state(delta)
	_server_sync_network_state(delta)


func _is_multiplayer_active() -> bool:
	return multiplayer.has_multiplayer_peer()


func _is_network_client() -> bool:
	return _is_multiplayer_active() and not multiplayer.is_server()


func _is_server_or_solo() -> bool:
	return not _is_multiplayer_active() or multiplayer.is_server()


func _configure_network_physics() -> void:
	if _is_network_client():
		if client_freeze_physics:
			freeze = true
		return

	freeze = false


func _update_network_mode_if_needed() -> void:
	var now_client := _is_network_client()
	if now_client == _last_network_client_state:
		return

	_last_network_client_state = now_client
	_configure_network_physics()


func _server_sync_network_state(delta: float) -> void:
	if not network_sync_enabled:
		return
	if not _is_multiplayer_active():
		return
	if not multiplayer.is_server():
		return

	_network_sync_timer -= delta
	if _network_sync_timer > 0.0:
		return

	_network_sync_timer = network_sync_interval

	var turret_rotation := Vector3.ZERO
	var barrel_rotation := Vector3.ZERO

	if _turret_yaw != null:
		turret_rotation = _turret_yaw.rotation
	if _barrel_pitch != null:
		barrel_rotation = _barrel_pitch.rotation

	_rpc_sync_tank_state.rpc(
		global_transform,
		linear_velocity,
		angular_velocity,
		turret_rotation,
		barrel_rotation,
		current_health,
		_dead
	)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _rpc_sync_tank_state(
	synced_transform: Transform3D,
	synced_linear_velocity: Vector3,
	synced_angular_velocity: Vector3,
	synced_turret_rotation: Vector3,
	synced_barrel_rotation: Vector3,
	synced_health: int,
	synced_dead: bool
) -> void:
	if multiplayer.is_server():
		return

	_client_target_transform = synced_transform
	_client_target_linear_velocity = synced_linear_velocity
	_client_target_angular_velocity = synced_angular_velocity
	_client_target_turret_rotation = synced_turret_rotation
	_client_target_barrel_rotation = synced_barrel_rotation

	if not _client_has_sync:
		_client_has_sync = true
		global_transform = synced_transform
		linear_velocity = synced_linear_velocity
		angular_velocity = synced_angular_velocity

	if current_health != synced_health:
		current_health = synced_health
		health_changed.emit(current_health, max_health)

	if synced_dead and not _dead:
		_dead = true
		_spawn_death_effect_once(global_position)
		call_deferred("queue_free")


func _client_interpolate_network_state(delta: float) -> void:
	if not _client_has_sync:
		return

	if global_position.distance_to(_client_target_transform.origin) > network_snap_distance:
		global_transform = _client_target_transform
	else:
		var weight := clampf(network_interpolation_speed * delta, 0.0, 1.0)
		var new_origin := global_position.lerp(_client_target_transform.origin, weight)
		var new_basis := global_transform.basis.slerp(_client_target_transform.basis, weight).orthonormalized()
		global_transform = Transform3D(new_basis, new_origin)

	linear_velocity = _client_target_linear_velocity
	angular_velocity = _client_target_angular_velocity

	var rot_weight := clampf(network_interpolation_speed * delta, 0.0, 1.0)
	if _turret_yaw != null:
		_turret_yaw.rotation = _lerp_rotation(_turret_yaw.rotation, _client_target_turret_rotation, rot_weight)
	if _barrel_pitch != null:
		_barrel_pitch.rotation = _lerp_rotation(_barrel_pitch.rotation, _client_target_barrel_rotation, rot_weight)


func _lerp_rotation(from_rotation: Vector3, to_rotation: Vector3, weight: float) -> Vector3:
	return Vector3(
		lerp_angle(from_rotation.x, to_rotation.x, weight),
		lerp_angle(from_rotation.y, to_rotation.y, weight),
		lerp_angle(from_rotation.z, to_rotation.z, weight)
	)


func _connect_detection_area() -> void:
	if _detection_area == null:
		return
	if not _detection_area.body_entered.is_connected(_on_detection_body_entered):
		_detection_area.body_entered.connect(_on_detection_body_entered)
	if not _detection_area.body_exited.is_connected(_on_detection_body_exited):
		_detection_area.body_exited.connect(_on_detection_body_exited)
	if not _detection_area.area_entered.is_connected(_on_detection_area_entered):
		_detection_area.area_entered.connect(_on_detection_area_entered)
	if not _detection_area.area_exited.is_connected(_on_detection_area_exited):
		_detection_area.area_exited.connect(_on_detection_area_exited)


func _update_detection_shape_radius() -> void:
	if _detection_area == null:
		return
	var shape_node := _detection_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is SphereShape3D:
		(shape_node.shape as SphereShape3D).radius = detection_radius


func _collect_wheels(node: Node) -> void:
	for child in node.get_children():
		if child is VehicleWheel3D:
			_wheels.append(child as VehicleWheel3D)
		_collect_wheels(child)


func _idle(delta: float) -> void:
	_stop_vehicle(delta)


func _drive_towards(target: Node3D, delta: float) -> void:
	if target == null:
		_idle(delta)
		return

	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()

	if distance <= 0.05:
		_stop_vehicle(delta)
		return

	var local_dir := global_transform.basis.inverse() * to_target.normalized()
	var steering_x := -local_dir.x if invert_steering else local_dir.x
	var steering_target := clampf(
		atan2(steering_x, -local_dir.z),
		-deg_to_rad(max_steering_angle_deg),
		deg_to_rad(max_steering_angle_deg)
	)

	_current_steering = _move_toward_angle(_current_steering, steering_target, deg_to_rad(steering_speed_deg) * delta)

	var force := max_engine_force
	var brake_value := 0.0

	if distance <= stop_distance and _has_line_of_sight(target):
		force = 0.0
		brake_value = max_brake_force
	elif distance <= reverse_distance:
		force = -reverse_engine_force
		brake_value = 0.0
	elif reduce_speed_when_turning:
		var turn_ratio := absf(_current_steering) / maxf(0.001, deg_to_rad(max_steering_angle_deg))
		force *= lerpf(1.0, 0.62, turn_ratio)

	_apply_vehicle_controls(force, brake_value, _current_steering, delta)


func _stop_vehicle(delta: float) -> void:
	_current_steering = move_toward(_current_steering, 0.0, deg_to_rad(steering_speed_deg) * delta)
	_stuck_drive_timer = 0.0
	_apply_vehicle_controls(0.0, max_brake_force, _current_steering, delta)


func _apply_vehicle_controls(engine_force_value: float, brake_value: float, steering_value: float, delta: float) -> void:
	if use_vehicle_body_controls:
		engine_force = engine_force_value
		brake = brake_value
		steering = steering_value

	if use_wheel_controls:
		for wheel in _wheels:
			if not is_instance_valid(wheel):
				continue
			if "brake" in wheel:
				wheel.set("brake", brake_value)
			if "engine_force" in wheel:
				wheel.set("engine_force", engine_force_value if wheel.use_as_traction else 0.0)
			if "steering" in wheel and wheel.use_as_steering:
				wheel.set("steering", steering_value)

	_apply_backup_drive_force(engine_force_value, brake_value, delta)


func _apply_backup_drive_force(engine_force_value: float, brake_value: float, delta: float) -> void:
	if not use_backup_drive_force:
		return
	if absf(engine_force_value) <= 0.001 or brake_value > 0.0:
		_stuck_drive_timer = 0.0
		return
	if _count_wheel_contacts() <= 0:
		_stuck_drive_timer = 0.0
		return

	var flat_speed := Vector2(linear_velocity.x, linear_velocity.z).length()
	if flat_speed > 0.25:
		_stuck_drive_timer = 0.0
		return

	_stuck_drive_timer += delta
	if _stuck_drive_timer < backup_force_after_stuck_time:
		return

	var forward := -global_transform.basis.z.normalized()
	apply_central_force(forward * signf(engine_force_value) * backup_drive_force)


func _count_wheel_contacts() -> int:
	var contact_count := 0
	for wheel in _wheels:
		if is_instance_valid(wheel) and wheel.is_in_contact():
			contact_count += 1
	return contact_count


func _debug_ai_state(delta: float, target: Node3D, target_distance: float, has_los: bool, can_attack: bool) -> void:
	if not debug_ai_state:
		return
	_ai_debug_timer -= delta
	if _ai_debug_timer > 0.0:
		return
	_ai_debug_timer = 1.0
	var target_name := "none"
	if is_instance_valid(target):
		target_name = target.name
	print("[EnemyTankVehicle] target=%s | dist=%.2f | los=%s | can_attack=%s | engine=%.1f | brake=%.1f | steering=%.2f" % [target_name, target_distance, str(has_los), str(can_attack), engine_force, brake, steering])


func _debug_wheel_state(delta: float) -> void:
	if not debug_wheel_contacts:
		return
	_wheel_debug_timer -= delta
	if _wheel_debug_timer > 0.0:
		return
	_wheel_debug_timer = 1.0
	var contact_count := _count_wheel_contacts()
	print("[EnemyTankVehicle] wheel contacts: %d/%d | speed: %.2f" % [contact_count, _wheels.size(), linear_velocity.length()])


func _aim_turret_at(target: Node3D, delta: float) -> void:
	if _turret_yaw == null or _barrel_pitch == null or target == null:
		return

	var aim_pos := _get_target_aim_position(target)
	var direction := aim_pos - _turret_yaw.global_position
	if direction.length_squared() <= 0.001:
		return
	direction = direction.normalized()

	var yaw_parent := _turret_yaw.get_parent() as Node3D
	var yaw_parent_basis := Basis.IDENTITY
	if yaw_parent != null:
		yaw_parent_basis = yaw_parent.global_transform.basis

	var yaw_local_dir := yaw_parent_basis.inverse() * direction
	var yaw_x := -yaw_local_dir.x if invert_turret_yaw else yaw_local_dir.x
	var desired_yaw := atan2(yaw_x, -yaw_local_dir.z)
	_turret_yaw.rotation.y = _move_toward_angle(
		_turret_yaw.rotation.y,
		desired_yaw,
		deg_to_rad(turret_yaw_speed_deg) * delta
	)

	var pitch_local_dir := _turret_yaw.global_transform.basis.inverse() * direction
	var horizontal := Vector2(pitch_local_dir.x, pitch_local_dir.z).length()
	var desired_pitch := atan2(pitch_local_dir.y, horizontal)
	if not invert_barrel_pitch:
		desired_pitch = -desired_pitch
	desired_pitch = clampf(desired_pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
	_barrel_pitch.rotation.x = _move_toward_angle(
		_barrel_pitch.rotation.x,
		desired_pitch,
		deg_to_rad(barrel_pitch_speed_deg) * delta
	)


func _try_fire(target: Node3D) -> void:
	if projectile_scene == null:
		return
	if _muzzle == null:
		return
	if _fire_cooldown > 0.0:
		return
	if not _is_barrel_aligned(target):
		return

	_fire_cooldown = fire_rate
	_spawn_projectile(target)


func _spawn_projectile(target: Node3D) -> void:
	if target == null or _muzzle == null:
		return

	var origin := _muzzle.global_position
	var direction := (_get_target_aim_position(target) - origin).normalized()
	direction = _apply_dispersion(direction, aim_dispersion_deg)

	_spawn_projectile_instance(origin, direction, false)

	if spawn_projectile_fx_on_clients and _is_multiplayer_active() and multiplayer.is_server():
		_rpc_spawn_projectile_fx.rpc(origin, direction)


@rpc("authority", "call_remote", "reliable", 2)
func _rpc_spawn_projectile_fx(origin: Vector3, direction: Vector3) -> void:
	if multiplayer.is_server():
		return
	_spawn_projectile_instance(origin, direction, true)


func _spawn_projectile_instance(origin: Vector3, direction: Vector3, visual_only: bool) -> void:
	if projectile_scene == null:
		return

	var projectile := projectile_scene.instantiate()
	if projectile == null:
		return

	var parent := get_tree().current_scene
	if parent == null:
		parent = get_parent()
	if parent == null:
		projectile.queue_free()
		return

	parent.add_child(projectile)

	var safe_direction := direction.normalized()
	if safe_direction.length_squared() <= 0.0001:
		safe_direction = -global_transform.basis.z.normalized()

	var source_team := team_id
	var source_damage := projectile_damage
	var source_penetration := projectile_penetration
	var allow_tk := can_teamkill

	if visual_only:
		# Les clients ne doivent afficher que le projectile.
		# Les dégâts restent serveur-autoritaire.
		source_team = 0
		source_damage = 0
		source_penetration = 0
		allow_tk = false

	if projectile is Node3D:
		var projectile_node := projectile as Node3D
		projectile_node.global_position = origin
		projectile_node.look_at(origin + safe_direction, Vector3.UP)

	_safe_set(projectile, "direction", safe_direction)
	_safe_set(projectile, "damage", source_damage)
	_safe_set(projectile, "penetration", source_penetration)
	_safe_set(projectile, "team", source_team)
	_safe_set(projectile, "team_id", source_team)
	_safe_set(projectile, "shooter_team", source_team)
	_safe_set(projectile, "projectile_team", source_team)
	_safe_set(projectile, "can_teamkill", allow_tk)
	_safe_set(projectile, "tk", allow_tk)
	_safe_set(projectile, "shooter", self)
	_safe_set(projectile, "instigator", self)
	_safe_set(projectile, "source", self)

	if projectile.has_method("fire"):
		projectile.fire(
			origin,
			safe_direction,
			source_team,
			source_damage,
			source_penetration,
			allow_tk,
			self,
			null
		)
	elif projectile.has_method("set_direction"):
		projectile.set_direction(safe_direction)
	elif projectile.has_method("setup"):
		projectile.setup(origin, safe_direction)

	if not visual_only and projectile.has_method("setup_from_tank_enemy"):
		projectile.setup_from_tank_enemy(self, safe_direction, projectile_damage, projectile_penetration, team_id, can_teamkill)


func _safe_set(object: Object, property_name: String, value: Variant) -> void:
	if object == null:
		return
	if property_name in object:
		object.set(property_name, value)


func _is_barrel_aligned(target: Node3D) -> bool:
	if _muzzle == null or target == null:
		return false
	var desired_dir := (_get_target_aim_position(target) - _muzzle.global_position).normalized()
	var forward := -_muzzle.global_transform.basis.z.normalized()
	return rad_to_deg(forward.angle_to(desired_dir)) <= fire_angle_tolerance_deg


func _apply_dispersion(direction: Vector3, degrees: float) -> Vector3:
	if degrees <= 0.0:
		return direction.normalized()
	var yaw_offset := deg_to_rad(randf_range(-degrees, degrees))
	var pitch_offset := deg_to_rad(randf_range(-degrees, degrees))
	var right := direction.cross(Vector3.UP)
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	right = right.normalized()
	var up := right.cross(direction).normalized()
	return direction.rotated(up, yaw_offset).rotated(right, pitch_offset).normalized()


func _has_line_of_sight(target: Node3D) -> bool:
	if target == null:
		return false

	var from_pos := global_position + Vector3.UP * 1.1
	if _muzzle != null:
		from_pos = _muzzle.global_position
	var to_pos := _get_target_aim_position(target)

	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.exclude = [self]
	query.collision_mask = line_of_sight_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var space_state := get_world_3d().direct_space_state
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return true

	var collider := hit.get("collider") as Node
	return _is_same_node_or_child(collider, target)


func _get_target_aim_position(target: Node3D) -> Vector3:
	var pos := target.global_position
	if "aim_point" in target and target.aim_point is Node3D:
		pos = target.aim_point.global_position
	elif target.has_node("AimPoint"):
		var aim_node := target.get_node("AimPoint") as Node3D
		if aim_node != null:
			pos = aim_node.global_position
	else:
		pos += Vector3.UP * 1.0
	return pos


func _as_valid_node3d(value: Variant) -> Node3D:
	if value == null:
		return null
	if typeof(value) != TYPE_OBJECT:
		return null
	if not is_instance_valid(value):
		return null
	if value is Node3D:
		return value as Node3D
	return null


func _as_valid_node(value: Variant) -> Node:
	if value == null:
		return null
	if typeof(value) != TYPE_OBJECT:
		return null
	if not is_instance_valid(value):
		return null
	if value is Node:
		return value as Node
	return null


func _scan_targets_from_groups() -> void:
	for group_name in target_groups:
		for node in get_tree().get_nodes_in_group(String(group_name)):
			var target := node as Node3D
			if target == null:
				continue
			if _flat_distance_to(target) <= detection_radius and _is_valid_target(target):
				_register_target(target)


func _find_best_target() -> Node3D:
	var best_target: Node3D = null
	var best_score := INF

	for candidate in _candidate_targets:
		var candidate_node := _as_valid_node3d(candidate)
		if candidate_node == null:
			continue
		if not _is_valid_target(candidate_node):
			continue

		var distance := _flat_distance_to(candidate_node)
		if distance > detection_radius:
			continue

		if distance < best_score:
			best_score = distance
			best_target = candidate_node

	return best_target


func _prune_candidates() -> void:
	for i in range(_candidate_targets.size() - 1, -1, -1):
		var candidate_node := _as_valid_node3d(_candidate_targets[i])

		if candidate_node == null:
			_candidate_targets.remove_at(i)
			continue

		if not _is_valid_target(candidate_node):
			_candidate_targets.remove_at(i)
			continue

		if _flat_distance_to(candidate_node) > detection_radius * 1.15:
			_candidate_targets.remove_at(i)


func _register_target(target: Variant) -> void:
	var target_node := _as_valid_node3d(target)
	if target_node == null:
		return

	if not _candidate_targets.has(target_node):
		_candidate_targets.append(target_node)


func _unregister_target(target: Variant) -> void:
	var target_node := _as_valid_node3d(target)
	if target_node == null:
		return

	_candidate_targets.erase(target_node)

	if _target == target_node:
		_target = null


func _unset_if_outside_detection(target: Variant) -> void:
	var target_node := _as_valid_node3d(target)
	if target_node == null:
		return

	if _flat_distance_to(target_node) > detection_radius:
		_unregister_target(target_node)


func _is_valid_target(target: Variant) -> bool:
	var target_node := _as_valid_node3d(target)
	if target_node == null:
		return false

	if target_node == self:
		return false

	if _is_same_node_or_child(target_node, self):
		return false

	if _is_dead_target(target_node):
		return false

	var other_team := _read_team_id(target_node)
	if other_team != -999999 and other_team == team_id:
		return false

	return true


func _is_dead_target(target: Variant) -> bool:
	var target_node := _as_valid_node(target)
	if target_node == null:
		return true

	if "current_health" in target_node and int(target_node.current_health) <= 0:
		return true

	if "health" in target_node and int(target_node.health) <= 0:
		return true

	if target_node.has_method("is_dead"):
		return bool(target_node.is_dead())

	return false


func _read_team_id(node: Variant) -> int:
	var safe_node := _as_valid_node(node)
	if safe_node == null:
		return -999999

	if "team_id" in safe_node:
		return int(safe_node.team_id)

	if "team" in safe_node and typeof(safe_node.team) == TYPE_INT:
		return int(safe_node.team)

	if "faction_id" in safe_node:
		return int(safe_node.faction_id)

	return -999999


func _on_detection_body_entered(body: Node3D) -> void:
	if not _is_server_or_solo():
		return
	var target := _extract_target_root(body)
	if target != null and _is_valid_target(target):
		_register_target(target)


func _on_detection_body_exited(body: Node3D) -> void:
	if not _is_server_or_solo():
		return
	var target := _extract_target_root(body)
	_unset_if_outside_detection(target)


func _on_detection_area_entered(area: Area3D) -> void:
	if not _is_server_or_solo():
		return
	var target := _extract_target_root(area)
	if target != null and _is_valid_target(target):
		_register_target(target)


func _on_detection_area_exited(area: Area3D) -> void:
	if not _is_server_or_solo():
		return
	var target := _extract_target_root(area)
	_unset_if_outside_detection(target)


func _extract_target_root(node: Node) -> Node3D:
	var current := node
	while current != null and current != self:
		if current is Node3D and _matches_any_target_group(current):
			return current as Node3D
		current = current.get_parent()
	return null


func _matches_any_target_group(node: Node) -> bool:
	for group_name in target_groups:
		if node.is_in_group(String(group_name)):
			return true
	return false


func _is_same_node_or_child(node: Node, possible_parent: Node) -> bool:
	var current := node
	while current != null:
		if current == possible_parent:
			return true
		current = current.get_parent()
	return false


func _flat_distance_to(target: Node3D) -> float:
	var a := global_position
	var b := target.global_position
	a.y = 0.0
	b.y = 0.0
	return a.distance_to(b)


func _move_toward_angle(from: float, to: float, max_delta: float) -> float:
	var diff := wrapf(to - from, -PI, PI)
	if absf(diff) <= max_delta:
		return to
	return from + signf(diff) * max_delta


func apply_projectile_damage(
	amount: int,
	to_projectile_penetration: int = 0,
	_source_team: int = -999999,
	_allow_tk: bool = false,
	_source: Variant = null
) -> void:
	if _is_network_client():
		return

	if _dead:
		return

	if _source_team != -999999 and _source_team == team_id and not _allow_tk:
		if debug_ai_state:
			print("[EnemyTankVehicle] ignored friendly projectile | projectile_team=%d | tank_team=%d" % [_source_team, team_id])
		return

	var effective_armor = max(armor_rating - to_projectile_penetration, 0)
	var final_damage = max(amount - effective_armor, 0)

	if amount > 0 and final_damage <= 0 and minimum_damage_after_armor > 0:
		final_damage = minimum_damage_after_armor

	if debug_ai_state:
		print("[EnemyTankVehicle] hit damage=%d | penetration=%d | armor=%d | final=%d | projectile_team=%d | tank_team=%d" % [
			amount,
			to_projectile_penetration,
			armor_rating,
			final_damage,
			_source_team,
			team_id
		])

	if final_damage <= 0:
		return

	var safe_source := _as_valid_node(_source)
	_apply_damage(final_damage, safe_source, global_position)


func apply_damage(amount: int, attacker: Variant = null, hit_position: Vector3 = Vector3.ZERO) -> void:
	_apply_damage(amount, attacker, hit_position)


func take_damage(amount: int, attacker: Variant = null) -> void:
	_apply_damage(amount, attacker, global_position)


func receive_damage(amount: int, attacker: Variant = null) -> void:
	_apply_damage(amount, attacker, global_position)


func _apply_damage(amount: int, attacker: Variant = null, hit_position: Vector3 = Vector3.ZERO) -> void:
	if _is_network_client():
		return

	if _dead:
		return

	var real_damage := maxi(0, amount)
	if real_damage <= 0:
		return

	current_health = clampi(current_health - real_damage, 0, max_health)
	health_changed.emit(current_health, max_health)

	if _is_multiplayer_active() and multiplayer.is_server():
		_rpc_set_health.rpc(current_health)

	if debug_ai_state:
		print("[EnemyTankVehicle] health=%d/%d after damage=%d" % [current_health, max_health, real_damage])

	if current_health <= 0:
		_die(attacker, hit_position)


@rpc("authority", "call_remote", "reliable", 4)
func _rpc_set_health(synced_health: int) -> void:
	if multiplayer.is_server():
		return

	current_health = clampi(synced_health, 0, max_health)
	health_changed.emit(current_health, max_health)


func _die(_attacker: Variant = null, _hit_position: Vector3 = Vector3.ZERO) -> void:
	if _dead:
		return

	_dead = true
	died.emit(self)
	_spawn_death_effect_once(global_position)

	if _is_multiplayer_active() and multiplayer.is_server():
		_rpc_die.rpc(global_position)

	call_deferred("queue_free")


@rpc("authority", "call_remote", "reliable", 4)
func _rpc_die(effect_position: Vector3) -> void:
	if multiplayer.is_server():
		return

	if _dead:
		return

	_dead = true
	died.emit(self)
	_spawn_death_effect_once(effect_position)
	call_deferred("queue_free")


func _spawn_death_effect_once(effect_position: Vector3) -> void:
	if _death_fx_spawned:
		return
	_death_fx_spawned = true

	if death_effect_scene == null:
		return

	var parent := get_tree().current_scene
	if parent == null:
		parent = get_parent()
	if parent == null:
		return

	var effect := death_effect_scene.instantiate()
	if effect == null:
		return

	parent.add_child(effect)
	if effect is Node3D:
		(effect as Node3D).global_position = effect_position


#extends VehicleBody3D
#class_name EnemyTankVehicle
#
#signal died(enemy: Node)
#signal health_changed(current_health: int, max_health: int)
#
#@export_group("Team")
#@export var team_id: int = 2
#@export var can_teamkill: bool = false
#
#@export_group("Health")
#@export var max_health: int = 320
#@export var armor_rating: int = 5
#@export var death_effect_scene: PackedScene
#
#@export_group("Detection")
#@export var target_groups: PackedStringArray = PackedStringArray(["players", "player", "player_vehicles", "vehicles"])
#@export var detection_radius: float = 45.0
#@export var attack_range: float = 28.0
#@export var target_refresh_interval: float = 0.25
#@export_flags_3d_physics var line_of_sight_mask: int = 1
#@export_node_path("Area3D") var detection_area_path: NodePath = ^"DetectionArea"
#
#@export_group("Movement")
#@export var stop_distance: float = 20.0
#@export var reverse_distance: float = 7.0
#@export var max_engine_force: float = 1800.0
#@export var reverse_engine_force: float = 900.0
#@export var max_brake_force: float = 120.0
#@export var use_vehicle_body_controls: bool = true
#@export var use_wheel_controls: bool = true
#@export var use_backup_drive_force: bool = true
#@export var backup_drive_force: float = 900.0
#@export var backup_force_after_stuck_time: float = 0.45
#@export_range(0.0, 45.0, 0.5) var max_steering_angle_deg: float = 28.0
#@export_range(1.0, 180.0, 1.0) var steering_speed_deg: float = 95.0
#@export var reduce_speed_when_turning: bool = true
#@export var invert_steering: bool = true
#@export var debug_wheel_contacts: bool = false
#@export var debug_ai_state: bool = false
#
#@export_group("Turret")
#@export_node_path("Node3D") var turret_yaw_path: NodePath = ^"TurretYaw"
#@export_node_path("Node3D") var barrel_pitch_path: NodePath = ^"TurretYaw/BarrelPitch"
#@export_node_path("Marker3D") var muzzle_path: NodePath = ^"TurretYaw/BarrelPitch/Muzzle"
#@export_range(1.0, 360.0, 1.0) var turret_yaw_speed_deg: float = 130.0
#@export_range(1.0, 180.0, 1.0) var barrel_pitch_speed_deg: float = 90.0
#@export_range(-45.0, 0.0, 0.5) var min_pitch_deg: float = -8.0
#@export_range(0.0, 75.0, 0.5) var max_pitch_deg: float = 25.0
#@export_range(0.0, 20.0, 0.25) var fire_angle_tolerance_deg: float = 4.0
#@export var invert_turret_yaw: bool = true
#@export var invert_barrel_pitch: bool = true
#
#@export_group("Weapon")
#@export var projectile_scene: PackedScene
#@export var projectile_damage: int = 38
#@export var projectile_penetration: int = 1
##@export var projectile_speed: float = 46.0
##@export var projectile_lifetime: float = 4.0
#@export_range(0.1, 10.0, 0.05) var fire_rate: float = 0.65
#@export_range(0.0, 15.0, 0.1) var aim_dispersion_deg: float = 2.0
#@export var fire_only_with_line_of_sight: bool = true
#
#var current_health: int = 0
#
#var _target: Variant = null
#var _candidate_targets: Array = []
#var _wheels: Array[VehicleWheel3D] = []
#var _fire_cooldown: float = 0.0
#var _target_refresh_timer: float = 0.0
#var _current_steering: float = 0.0
#var _dead: bool = false
#var _wheel_debug_timer: float = 0.0
#var _ai_debug_timer: float = 0.0
#var _stuck_drive_timer: float = 0.0
#
#@onready var _detection_area: Area3D = get_node_or_null(detection_area_path) as Area3D
#@onready var _turret_yaw: Node3D = get_node_or_null(turret_yaw_path) as Node3D
#@onready var _barrel_pitch: Node3D = get_node_or_null(barrel_pitch_path) as Node3D
#@onready var _muzzle: Marker3D = get_node_or_null(muzzle_path) as Marker3D
#
#func _ready() -> void:
	#add_to_group("enemy")
	#add_to_group("enemies")
	#
	#current_health = max_health
	#_collect_wheels(self)
	#_connect_detection_area()
	#_update_detection_shape_radius()
#
#func _physics_process(delta: float) -> void:
	#if _dead:
		#return
	#if not _should_run_ai():
		#return
#
	#_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	#_target_refresh_timer -= delta
#
	#if _target_refresh_timer <= 0.0:
		#_target_refresh_timer = target_refresh_interval
		#_prune_candidates()
		#_scan_targets_from_groups()
		#_target = _find_best_target()
#
	#var target_node := _as_valid_node3d(_target)
	#if target_node == null:
		#_target = null
		#_idle(delta)
		#return
#
	#var target_distance := _flat_distance_to(target_node)
	#var has_los := true
	#if fire_only_with_line_of_sight:
		#has_los = _has_line_of_sight(target_node)
#
	#var can_attack := target_distance <= attack_range and has_los
#
	#_aim_turret_at(target_node, delta)
#
	#if can_attack:
		#_stop_vehicle(delta)
		#_try_fire(target_node)
	#else:
		#_drive_towards(target_node, delta)
#
	#_debug_ai_state(delta, target_node, target_distance, has_los, can_attack)
	#_debug_wheel_state(delta)
#
#func _should_run_ai() -> bool:
	#if multiplayer.has_multiplayer_peer():
		#return multiplayer.is_server()
	#return true
#
#func _connect_detection_area() -> void:
	#if _detection_area == null:
		#return
	#if not _detection_area.body_entered.is_connected(_on_detection_body_entered):
		#_detection_area.body_entered.connect(_on_detection_body_entered)
	#if not _detection_area.body_exited.is_connected(_on_detection_body_exited):
		#_detection_area.body_exited.connect(_on_detection_body_exited)
	#if not _detection_area.area_entered.is_connected(_on_detection_area_entered):
		#_detection_area.area_entered.connect(_on_detection_area_entered)
	#if not _detection_area.area_exited.is_connected(_on_detection_area_exited):
		#_detection_area.area_exited.connect(_on_detection_area_exited)
#
#func _update_detection_shape_radius() -> void:
	#if _detection_area == null:
		#return
	#var shape_node := _detection_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	#if shape_node != null and shape_node.shape is SphereShape3D:
		#(shape_node.shape as SphereShape3D).radius = detection_radius
#
#func _collect_wheels(node: Node) -> void:
	#for child in node.get_children():
		#if child is VehicleWheel3D:
			#_wheels.append(child as VehicleWheel3D)
		#_collect_wheels(child)
#
#func _idle(delta: float) -> void:
	#_stop_vehicle(delta)
#
#func _drive_towards(target: Node3D, delta: float) -> void:
	#if target == null:
		#_idle(delta)
		#return
#
	#var to_target := target.global_position - global_position
	#to_target.y = 0.0
	#var distance := to_target.length()
#
	#if distance <= 0.05:
		#_stop_vehicle(delta)
		#return
#
	#var local_dir := global_transform.basis.inverse() * to_target.normalized()
	#var steering_x := -local_dir.x if invert_steering else local_dir.x
	#var steering_target := clampf(
		#atan2(steering_x, -local_dir.z),
		#-deg_to_rad(max_steering_angle_deg),
		#deg_to_rad(max_steering_angle_deg)
	#)
#
	#_current_steering = _move_toward_angle(_current_steering, steering_target, deg_to_rad(steering_speed_deg) * delta)
#
	#var force := max_engine_force
	#var brake_value := 0.0
#
	## Sécurité. La logique principale arrête déjà le tank dans _physics_process()
	## quand il est à portée et qu'il a une ligne de vue.
	#if distance <= stop_distance and _has_line_of_sight(target):
		#force = 0.0
		#brake_value = max_brake_force
	#elif distance <= reverse_distance:
		#force = -reverse_engine_force
		#brake_value = 0.0
	#elif reduce_speed_when_turning:
		#var turn_ratio := absf(_current_steering) / maxf(0.001, deg_to_rad(max_steering_angle_deg))
		#force *= lerpf(1.0, 0.62, turn_ratio)
#
	#_apply_vehicle_controls(force, brake_value, _current_steering, delta)
#
#func _stop_vehicle(delta: float) -> void:
	#_current_steering = move_toward(_current_steering, 0.0, deg_to_rad(steering_speed_deg) * delta)
	#_stuck_drive_timer = 0.0
	#_apply_vehicle_controls(0.0, max_brake_force, _current_steering, delta)
#
#func _apply_vehicle_controls(engine_force_value: float, brake_value: float, steering_value: float, delta: float) -> void:
	## Contrôle principal de VehicleBody3D.
	## C'est ce point qui manquait dans la v2 sur certains projets.
	#if use_vehicle_body_controls:
		#engine_force = engine_force_value
		#brake = brake_value
		#steering = steering_value
#
	## Compatibilité avec les projets qui pilotent aussi certaines valeurs par roue.
	#if use_wheel_controls:
		#for wheel in _wheels:
			#if not is_instance_valid(wheel):
				#continue
			#if "brake" in wheel:
				#wheel.set("brake", brake_value)
			#if "engine_force" in wheel:
				#wheel.set("engine_force", engine_force_value if wheel.use_as_traction else 0.0)
			#if "steering" in wheel and wheel.use_as_steering:
				#wheel.set("steering", steering_value)
#
	#_apply_backup_drive_force(engine_force_value, brake_value, delta)
#
#func _apply_backup_drive_force(engine_force_value: float, brake_value: float, delta: float) -> void:
	#if not use_backup_drive_force:
		#return
	#if absf(engine_force_value) <= 0.001 or brake_value > 0.0:
		#_stuck_drive_timer = 0.0
		#return
	#if _count_wheel_contacts() <= 0:
		#_stuck_drive_timer = 0.0
		#return
#
	#var flat_speed := Vector2(linear_velocity.x, linear_velocity.z).length()
	#if flat_speed > 0.25:
		#_stuck_drive_timer = 0.0
		#return
#
	#_stuck_drive_timer += delta
	#if _stuck_drive_timer < backup_force_after_stuck_time:
		#return
#
	#var forward := -global_transform.basis.z.normalized()
	#apply_central_force(forward * signf(engine_force_value) * backup_drive_force)
#
#func _count_wheel_contacts() -> int:
	#var contact_count := 0
	#for wheel in _wheels:
		#if is_instance_valid(wheel) and wheel.is_in_contact():
			#contact_count += 1
	#return contact_count
#
#func _debug_ai_state(delta: float, target: Node3D, target_distance: float, has_los: bool, can_attack: bool) -> void:
	#if not debug_ai_state:
		#return
	#_ai_debug_timer -= delta
	#if _ai_debug_timer > 0.0:
		#return
	#_ai_debug_timer = 1.0
	#var target_name := "none"
	#if is_instance_valid(target):
		#target_name = target.name
	#print("[EnemyTankVehicle] target=%s | dist=%.2f | los=%s | can_attack=%s | engine=%.1f | brake=%.1f | steering=%.2f" % [target_name, target_distance, str(has_los), str(can_attack), engine_force, brake, steering])
#
#func _debug_wheel_state(delta: float) -> void:
	#if not debug_wheel_contacts:
		#return
	#_wheel_debug_timer -= delta
	#if _wheel_debug_timer > 0.0:
		#return
	#_wheel_debug_timer = 1.0
	#var contact_count := _count_wheel_contacts()
	#print("[EnemyTankVehicle] wheel contacts: %d/%d | speed: %.2f" % [contact_count, _wheels.size(), linear_velocity.length()])
#
#func _aim_turret_at(target: Node3D, delta: float) -> void:
	#if _turret_yaw == null or _barrel_pitch == null or target == null:
		#return
#
	#var aim_pos := _get_target_aim_position(target)
	#var direction := aim_pos - _turret_yaw.global_position
	#if direction.length_squared() <= 0.001:
		#return
	#direction = direction.normalized()
#
	#var yaw_parent := _turret_yaw.get_parent() as Node3D
	#var yaw_parent_basis := Basis.IDENTITY
	#if yaw_parent != null:
		#yaw_parent_basis = yaw_parent.global_transform.basis
#
	#var yaw_local_dir := yaw_parent_basis.inverse() * direction
	#var yaw_x := -yaw_local_dir.x if invert_turret_yaw else yaw_local_dir.x
	#var desired_yaw := atan2(yaw_x, -yaw_local_dir.z)
	#_turret_yaw.rotation.y = _move_toward_angle(
		#_turret_yaw.rotation.y,
		#desired_yaw,
		#deg_to_rad(turret_yaw_speed_deg) * delta
	#)
#
	#var pitch_local_dir := _turret_yaw.global_transform.basis.inverse() * direction
	#var horizontal := Vector2(pitch_local_dir.x, pitch_local_dir.z).length()
	#var desired_pitch := atan2(pitch_local_dir.y, horizontal)
	#if not invert_barrel_pitch:
		#desired_pitch = -desired_pitch
	#desired_pitch = clampf(desired_pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
	#_barrel_pitch.rotation.x = _move_toward_angle(
		#_barrel_pitch.rotation.x,
		#desired_pitch,
		#deg_to_rad(barrel_pitch_speed_deg) * delta
	#)
#
#func _try_fire(target: Node3D) -> void:
	#if projectile_scene == null:
		#return
	#if _muzzle == null:
		#return
	#if _fire_cooldown > 0.0:
		#return
	#if not _is_barrel_aligned(target):
		#return
#
	#_fire_cooldown = fire_rate
	#_spawn_projectile(target)
#
#func _spawn_projectile(target: Node3D) -> void:
	#var projectile := projectile_scene.instantiate()
	#var parent := get_tree().current_scene
	#if parent == null:
		#parent = get_parent()
	#parent.add_child(projectile)
#
	#var origin := _muzzle.global_position
	#var direction := (_get_target_aim_position(target) - origin).normalized()
	#direction = _apply_dispersion(direction, aim_dispersion_deg)
#
	#if projectile is Node3D:
		#var projectile_node := projectile as Node3D
		#projectile_node.global_position = origin
		#projectile_node.look_at(origin + direction, Vector3.UP)
#
	#_safe_set(projectile, "direction", direction)
	##_safe_set(projectile, "speed", projectile_speed)
	#_safe_set(projectile, "damage", projectile_damage)
	#_safe_set(projectile, "penetration", projectile_penetration)
	#_safe_set(projectile, "team_id", team_id)
	#_safe_set(projectile, "shooter_team", team_id)
	#_safe_set(projectile, "projectile_team", team_id)
	#_safe_set(projectile, "can_teamkill", can_teamkill)
	#_safe_set(projectile, "tk", can_teamkill)
	##_safe_set(projectile, "lifetime", projectile_lifetime)
	#_safe_set(projectile, "shooter", self)
	#_safe_set(projectile, "instigator", self)
	#_safe_set(projectile, "source", self)
#
	#if projectile.has_method("setup_from_tank_enemy"):
		#projectile.setup_from_tank_enemy(self, direction, projectile_damage, projectile_penetration, team_id, can_teamkill)
#
#func _safe_set(object: Object, property_name: String, value: Variant) -> void:
	#if object == null:
		#return
	#if property_name in object:
		#object.set(property_name, value)
#
#func _is_barrel_aligned(target: Node3D) -> bool:
	#if _muzzle == null or target == null:
		#return false
	#var desired_dir := (_get_target_aim_position(target) - _muzzle.global_position).normalized()
	#var forward := -_muzzle.global_transform.basis.z.normalized()
	#return rad_to_deg(forward.angle_to(desired_dir)) <= fire_angle_tolerance_deg
#
#func _apply_dispersion(direction: Vector3, degrees: float) -> Vector3:
	#if degrees <= 0.0:
		#return direction.normalized()
	#var yaw_offset := deg_to_rad(randf_range(-degrees, degrees))
	#var pitch_offset := deg_to_rad(randf_range(-degrees, degrees))
	#var right := direction.cross(Vector3.UP)
	#if right.length_squared() < 0.001:
		#right = Vector3.RIGHT
	#right = right.normalized()
	#var up := right.cross(direction).normalized()
	#return direction.rotated(up, yaw_offset).rotated(right, pitch_offset).normalized()
#
#func _has_line_of_sight(target: Node3D) -> bool:
	#if target == null:
		#return false
#
	#var from_pos := global_position + Vector3.UP * 1.1
	#if _muzzle != null:
		#from_pos = _muzzle.global_position
	#var to_pos := _get_target_aim_position(target)
#
	#var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	#query.exclude = [self]
	#query.collision_mask = line_of_sight_mask
	#query.collide_with_areas = true
	#query.collide_with_bodies = true
#
	#var space_state := get_world_3d().direct_space_state
	#var hit := space_state.intersect_ray(query)
	#if hit.is_empty():
		#return true
#
	#var collider := hit.get("collider") as Node
	#return _is_same_node_or_child(collider, target)
#
#func _get_target_aim_position(target: Node3D) -> Vector3:
	#var pos := target.global_position
	#if "aim_point" in target and target.aim_point is Node3D:
		#pos = target.aim_point.global_position
	#elif target.has_node("AimPoint"):
		#var aim_node := target.get_node("AimPoint") as Node3D
		#if aim_node != null:
			#pos = aim_node.global_position
	#else:
		#pos += Vector3.UP * 1.0
	#return pos
#
#func _as_valid_node3d(value: Variant) -> Node3D:
	#if value == null:
		#return null
	#if typeof(value) != TYPE_OBJECT:
		#return null
	#if not is_instance_valid(value):
		#return null
	#if value is Node3D:
		#return value as Node3D
	#return null
#
#
#func _as_valid_node(value: Variant) -> Node:
	#if value == null:
		#return null
	#if typeof(value) != TYPE_OBJECT:
		#return null
	#if not is_instance_valid(value):
		#return null
	#if value is Node:
		#return value as Node
	#return null
#
#func _scan_targets_from_groups() -> void:
	#for group_name in target_groups:
		#for node in get_tree().get_nodes_in_group(String(group_name)):
			#var target := node as Node3D
			#if target == null:
				#continue
			#if _flat_distance_to(target) <= detection_radius and _is_valid_target(target):
				#_register_target(target)
#
#func _find_best_target() -> Node3D:
	#var best_target: Node3D = null
	#var best_score := INF
#
	#for candidate in _candidate_targets:
		#var candidate_node := _as_valid_node3d(candidate)
		#if candidate_node == null:
			#continue
		#if not _is_valid_target(candidate_node):
			#continue
#
		#var distance := _flat_distance_to(candidate_node)
		#if distance > detection_radius:
			#continue
#
		#if distance < best_score:
			#best_score = distance
			#best_target = candidate_node
#
	#return best_target
#
#
#func _prune_candidates() -> void:
	#for i in range(_candidate_targets.size() - 1, -1, -1):
		#var candidate_node := _as_valid_node3d(_candidate_targets[i])
#
		#if candidate_node == null:
			#_candidate_targets.remove_at(i)
			#continue
#
		#if not _is_valid_target(candidate_node):
			#_candidate_targets.remove_at(i)
			#continue
#
		#if _flat_distance_to(candidate_node) > detection_radius * 1.15:
			#_candidate_targets.remove_at(i)
#
#
#func _register_target(target: Variant) -> void:
	#var target_node := _as_valid_node3d(target)
	#if target_node == null:
		#return
#
	#if not _candidate_targets.has(target_node):
		#_candidate_targets.append(target_node)
#
#
#func _unregister_target(target: Variant) -> void:
	#var target_node := _as_valid_node3d(target)
	#if target_node == null:
		#return
#
	#_candidate_targets.erase(target_node)
#
	#if _target == target_node:
		#_target = null
#
#
#func _unset_if_outside_detection(target: Variant) -> void:
	#var target_node := _as_valid_node3d(target)
	#if target_node == null:
		#return
#
	#if _flat_distance_to(target_node) > detection_radius:
		#_unregister_target(target_node)
#
#
#func _is_valid_target(target: Variant) -> bool:
	#var target_node := _as_valid_node3d(target)
	#if target_node == null:
		#return false
#
	#if target_node == self:
		#return false
#
	#if _is_same_node_or_child(target_node, self):
		#return false
#
	#if _is_dead_target(target_node):
		#return false
#
	#var other_team := _read_team_id(target_node)
	#if other_team != -999999 and other_team == team_id:
		#return false
#
	#return true
#
#
#func _is_dead_target(target: Variant) -> bool:
	#var target_node := _as_valid_node(target)
	#if target_node == null:
		#return true
#
	#if "current_health" in target_node and int(target_node.current_health) <= 0:
		#return true
#
	#if "health" in target_node and int(target_node.health) <= 0:
		#return true
#
	#if target_node.has_method("is_dead"):
		#return bool(target_node.is_dead())
#
	#return false
#
#
#func _read_team_id(node: Variant) -> int:
	#var safe_node := _as_valid_node(node)
	#if safe_node == null:
		#return -999999
#
	#if "team_id" in safe_node:
		#return int(safe_node.team_id)
#
	#if "team" in safe_node and typeof(safe_node.team) == TYPE_INT:
		#return int(safe_node.team)
#
	#if "faction_id" in safe_node:
		#return int(safe_node.faction_id)
#
	#return -999999
	##if target == null:
		##return
	##_candidate_targets.erase(target)
	##if _target == target:
		##_target = null
#
#func _on_detection_body_entered(body: Node3D) -> void:
	#var target := _extract_target_root(body)
	#if target != null and _is_valid_target(target):
		#_register_target(target)
#
#func _on_detection_body_exited(body: Node3D) -> void:
	#var target := _extract_target_root(body)
	#_unset_if_outside_detection(target)
#
#func _on_detection_area_entered(area: Area3D) -> void:
	#var target := _extract_target_root(area)
	#if target != null and _is_valid_target(target):
		#_register_target(target)
#
#func _on_detection_area_exited(area: Area3D) -> void:
	#var target := _extract_target_root(area)
	#_unset_if_outside_detection(target)
#
##func _unset_if_outside_detection(target: Node3D) -> void:
	##if target == null:
		##return
	##if _flat_distance_to(target) > detection_radius:
		##_unregister_target(target)
#
#func _extract_target_root(node: Node) -> Node3D:
	#var current := node
	#while current != null and current != self:
		#if current is Node3D and _matches_any_target_group(current):
			#return current as Node3D
		#current = current.get_parent()
	#return null
#
#func _matches_any_target_group(node: Node) -> bool:
	#for group_name in target_groups:
		#if node.is_in_group(String(group_name)):
			#return true
	#return false
#
##func _is_valid_target(target: Node) -> bool:
	##if target == null:
		##return false
	##if target == self:
		##return false
	##if not is_instance_valid(target):
		##return false
	##if not target is Node3D:
		##return false
	##if _is_same_node_or_child(target, self):
		##return false
	##if _is_dead_target(target):
		##return false
	##var other_team := _read_team_id(target)
	##if other_team != -999999 and other_team == team_id:
		##return false
	##return true
#
##func _is_dead_target(target: Node) -> bool:
	##if target == null:
		##return true
	##if "current_health" in target and int(target.current_health) <= 0:
		##return true
	##if "health" in target and int(target.health) <= 0:
		##return true
	##if target.has_method("is_dead"):
		##return bool(target.is_dead())
	##return false
#
##func _read_team_id(node: Node) -> int:
	##if node == null:
		##return -999999
	##if "team_id" in node:
		##return int(node.team_id)
	##if "team" in node and typeof(node.team) == TYPE_INT:
		##return int(node.team)
	##if "faction_id" in node:
		##return int(node.faction_id)
	##return -999999
#
#func _is_same_node_or_child(node: Node, possible_parent: Node) -> bool:
	#var current := node
	#while current != null:
		#if current == possible_parent:
			#return true
		#current = current.get_parent()
	#return false
#
#func _flat_distance_to(target: Node3D) -> float:
	#var a := global_position
	#var b := target.global_position
	#a.y = 0.0
	#b.y = 0.0
	#return a.distance_to(b)
#
#func _move_toward_angle(from: float, to: float, max_delta: float) -> float:
	#var diff := wrapf(to - from, -PI, PI)
	#if absf(diff) <= max_delta:
		#return to
	#return from + signf(diff) * max_delta
#
##func apply_projectile_damage(amount: int, penetration: int = 0, hit_position: Vector3 = Vector3.ZERO, attacker: Node = null, projectile_team_id: int = -999999, projectile_can_teamkill: bool = false) -> void:
	##if _dead:
		##return
	##if projectile_team_id != -999999 and projectile_team_id == team_id and not projectile_can_teamkill:
		##return
	##_apply_damage(amount, attacker, hit_position)
#
#func apply_projectile_damage(
	#amount: int,
	#to_projectile_penetration: int = 0,
	#arg3: Variant = -999999,
	#arg4: Variant = false,
	#arg5: Variant = null,
	#arg6: Variant = null
#) -> void:
	#if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		#return
#
	#if _dead:
		#return
#
	#var projectile_team_id := -999999
	#var projectile_can_teamkill := false
	#var source: Variant = null
	#var hit_position := global_position
#
	## Signature possible :
	## apply_projectile_damage(damage, penetration, team_id, can_teamkill, source)
	#if typeof(arg3) == TYPE_INT:
		#projectile_team_id = int(arg3)
		#projectile_can_teamkill = bool(arg4)
		#source = arg5
#
	## Signature possible :
	## apply_projectile_damage(damage, penetration, hit_position, source, team_id, can_teamkill)
	#elif typeof(arg3) == TYPE_VECTOR3:
		#hit_position = arg3
		#source = arg4
#
		#if typeof(arg5) == TYPE_INT:
			#projectile_team_id = int(arg5)
#
		#if typeof(arg6) == TYPE_BOOL:
			#projectile_can_teamkill = bool(arg6)
#
	## Signature possible :
	## apply_projectile_damage(damage, penetration, source)
	#else:
		#source = arg3
#
	#if projectile_team_id != -999999 and projectile_team_id == team_id and not projectile_can_teamkill:
		#if debug_ai_state:
			#print("[EnemyTankVehicle] ignored friendly projectile")
		#return
	#
	#var effective_armor = max(armor_rating - to_projectile_penetration, 0)
	#var final_damage = max(amount - effective_armor, 1)
	#
	#if debug_ai_state:
		#print("[EnemyTankVehicle] hit damage=%d | penetration=%d | armor=%d | final=%d | projectile_team=%d" % [
			#amount,
			#to_projectile_penetration,
			#armor_rating,
			#final_damage,
			#projectile_team_id
		#])
#
	#if final_damage <= 0:
		#return
#
	#var safe_source := _as_valid_node(source)
	#_apply_damage(final_damage, safe_source, hit_position)
#
#func apply_damage(amount: int, attacker: Variant = null, hit_position: Vector3 = Vector3.ZERO) -> void:
	#_apply_damage(amount, attacker, hit_position)
#
#
#func take_damage(amount: int, attacker: Variant = null) -> void:
	#_apply_damage(amount, attacker, global_position)
#
#
#func receive_damage(amount: int, attacker: Variant = null) -> void:
	#_apply_damage(amount, attacker, global_position)
#
#
#func _apply_damage(amount: int, attacker: Variant = null, hit_position: Vector3 = Vector3.ZERO) -> void:
	#if _dead:
		#return
	#
	#current_health = clampi(current_health - maxi(0, amount), 0, max_health)
	#health_changed.emit(current_health, max_health)
	#if current_health <= 0:
		#_die(attacker, hit_position)
#
#func _die(attacker: Variant = null, hit_position: Vector3 = Vector3.ZERO) -> void:
	#if _dead:
		#return
	#_dead = true
	#died.emit(self)
#
	#if death_effect_scene != null:
		#var effect := death_effect_scene.instantiate()
		#get_tree().current_scene.add_child(effect)
		#if effect is Node3D:
			#(effect as Node3D).global_position = global_position
#
	#queue_free()
