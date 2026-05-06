extends Node3D
class_name VehicleTurretBase

const DEFAULT_VISUAL_BULLET_SCENE := preload("res://scenes/weapons/VisualBullet.tscn")

@export_group("Meta")
@export var turret_id: String = "turret"
@export var turret_label: String = "Tourelle"
@export_range(1, 4, 1) var turret_size: int = 1
@export var turret_price: int = 100

@export_group("Turret")
@export var use_max_rotation: bool = false
@export_range(0.0, 180.0, 1.0) var max_rotation_deg: float = 0.0
@export var fire_cooldown: float = 0.16
@export var damage: int = 10

@export_group("Fire Mode")
@export var automatic_fire: bool = true

@export_group("Ammo")
@export var magazine_ammo: int = 60
@export var magazine_max_ammo: int = 60
@export var reserve_ammo: int = 180
@export var reserve_max_ammo: int = 180
@export var infinite_ammo: bool = false
@export var reload_time: float = 2.0
@export var ammo_per_shot: int = 1

@export_group("Turret")
@export var shot_range: float = 40.0
@export var rotation_speed_deg: float = 180.0
@export var elevation_speed_deg: float = 180.0
@export var min_elevation_deg: float = -10.0
@export var max_elevation_deg: float = 75.0
@export var collision_mask: int = 2
@export var bullet_scene: PackedScene
@export var state_send_interval: float = 0.033
@export var align_to_vehicle_when_idle: bool = false
@export var idle_aim_distance: float = 20.0

@export_group("Paths")
@export var body_path: NodePath = NodePath("Body")
@export var muzzle_path: NodePath = NodePath("TurretMuzzle")
@export var canon_name_prefix: String = "Canon_"

@export_group("Damage")
@export var projectile_damage: int = 10
@export var projectile_penetration: int = 0
@export var projectile_tk: bool = false
@export var projectile_impact_scene: PackedScene
@export var projectile_team: int = VisualBullet.Team.ENEMY


var mount: VehicleTurretMount = null
var vehicle: Vehicle = null

var body_node: Node3D = null
var canon_nodes: Array[Node3D] = []
var canon_muzzles: Array[Marker3D] = []

var target_aim_world: Vector3 = Vector3.ZERO
var replicated_aim_world: Vector3 = Vector3.ZERO

var turret_state_buffer: Array = []
var turret_interpolation_back_time: float = 0.10
var max_turret_state_buffer_size: int = 12

var fire_timer: float = 0.0
var state_timer: float = 0.0
var next_canon_index: int = 0
var trigger_was_pressed: bool = false

var is_reloading: bool = false
var reload_timer: float = 0.0
var pending_reload_amount: int = -1

@onready var fallback_muzzle: Marker3D = get_node_or_null(muzzle_path)


static func inspect_scene(scene: PackedScene) -> Dictionary:
	if scene == null:
		return {}

	var instance := scene.instantiate()
	if instance == null:
		return {}

	var info := {
		"turret_id": "",
		"turret_label": "",
		"turret_size": 0,
		"turret_price": 0,
	}

	if instance is VehicleTurretBase:
		var turret := instance as VehicleTurretBase
		info["turret_id"] = turret.turret_id
		info["turret_label"] = turret.turret_label
		info["turret_size"] = turret.turret_size
		info["turret_price"] = turret.turret_price

	instance.queue_free()
	return info


func setup(owner_mount: VehicleTurretMount, owner_vehicle: Vehicle) -> void:
	mount = owner_mount
	vehicle = owner_vehicle
	set_multiplayer_authority(1)

	_sanitize_ammo_values()
	_scan_turret_nodes()

	var initial_target := _get_idle_aim_world()
	target_aim_world = initial_target
	replicated_aim_world = initial_target
	_apply_aim_target_immediate(initial_target)


func _ready() -> void:
	_sanitize_ammo_values()
	_scan_turret_nodes()


func _physics_process(delta: float) -> void:
	fire_timer = max(fire_timer - delta, 0.0)

	if multiplayer.is_server():
		_update_reload(delta)
		_server_tick(delta)
	else:
		_client_tick(delta)


func _server_tick(delta: float) -> void:
	var has_operator := mount != null and mount.get_operator_peer_id() != -1

	if has_operator:
		_step_toward_target(delta)
	else:
		trigger_was_pressed = false

		if align_to_vehicle_when_idle:
			target_aim_world = _get_idle_aim_world()
			_step_toward_target(delta)
		else:
			# Personne n'utilise la tourelle, on garde strictement la pose actuelle.
			# On recalcule juste une cible cohérente pour la réplication client,
			# mais on ne fait pas tourner body / canons.
			target_aim_world = _get_current_aim_target_from_pose()

	state_timer -= delta
	if state_timer <= 0.0:
		state_timer = state_send_interval
		_sync_turret_state.rpc(
			target_aim_world,
			_get_synced_body_yaw(),
			_get_synced_canon_pitches(),
			magazine_ammo,
			magazine_max_ammo,
			reserve_ammo,
			reserve_max_ammo,
			infinite_ammo,
			is_reloading,
			reload_timer
		)


func _client_tick(delta: float) -> void:
	if _is_local_operator():
		_step_toward_target(delta, target_aim_world)
		return

	_client_interpolate_turret_pose(delta)

func _client_interpolate_turret_pose(_delta: float) -> void:
	if turret_state_buffer.size() < 2:
		return

	var render_time := Time.get_ticks_msec() * 0.001 - turret_interpolation_back_time

	while turret_state_buffer.size() >= 2 and turret_state_buffer[1]["time"] <= render_time:
		turret_state_buffer.pop_front()

	if turret_state_buffer.size() < 2:
		return

	var a = turret_state_buffer[0]
	var b = turret_state_buffer[1]

	var span: float = max(b["time"] - a["time"], 0.0001)
	var t: float = clamp((render_time - a["time"]) / span, 0.0, 1.0)

	var body_yaw: float = lerp_angle(
		float(a["body_yaw"]),
		float(b["body_yaw"]),
		t
	)

	if body_node != null:
		body_node.rotation.y = body_yaw

	var a_pitches: Array = a["canon_pitches"]
	var b_pitches: Array = b["canon_pitches"]

	var count: int = mini(
		canon_nodes.size(),
		mini(a_pitches.size(), b_pitches.size())
	)

	for i in count:
		var canon := canon_nodes[i]
		if canon == null:
			continue

		canon.rotation.x = lerp_angle(
			float(a_pitches[i]),
			float(b_pitches[i]),
			t
		)

func preview_local_aim_target(aim_world: Vector3) -> void:
	# Sert uniquement à mettre à jour la cible locale.
	# On ne force plus la rotation instantanément, sinon rotation_speed_deg et
	# elevation_speed_deg sont contournés côté joueur local.
	target_aim_world = _clamp_aim_world(aim_world)


func apply_host_input(peer_id: int, aim_world: Vector3, wants_fire: bool) -> void:
	if not multiplayer.is_server():
		return

	if mount == null or not mount.can_peer_operate(peer_id):
		return

	target_aim_world = _clamp_aim_world(aim_world)

	var should_fire := _should_fire_from_trigger(wants_fire)
	trigger_was_pressed = wants_fire
	
	if should_fire:
		_try_fire(peer_id)
	

func on_vehicle_seat_layout_changed() -> void:
	if mount == null:
		return

	if mount.get_operator_peer_id() == -1:
		trigger_was_pressed = false

		if align_to_vehicle_when_idle:
			var idle_target := _get_idle_aim_world()
			target_aim_world = idle_target
			replicated_aim_world = idle_target
		else:
			var current_target := _get_current_aim_target_from_pose()
			target_aim_world = current_target
			replicated_aim_world = current_target


func get_current_global_yaw() -> float:
	if body_node == null:
		return global_rotation.y

	var base_yaw := mount.global_rotation.y if mount != null else global_rotation.y
	return base_yaw + body_node.rotation.y


func _is_local_operator() -> bool:
	if mount == null:
		return false

	return mount.get_operator_peer_id() == multiplayer.get_unique_id()


func _scan_turret_nodes() -> void:
	body_node = get_node_or_null(body_path)
	if body_node == null:
		body_node = self

	canon_nodes.clear()
	canon_muzzles.clear()

	for child in body_node.get_children():
		if child is Node3D and String(child.name).begins_with(canon_name_prefix):
			var canon := child as Node3D

			var found_muzzles: Array[Marker3D] = []
			for canon_child in canon.get_children():
				if canon_child is Marker3D and String(canon_child.name).begins_with("TurretMuzzle"):
					found_muzzles.append(canon_child as Marker3D)

			found_muzzles.sort_custom(func(a: Marker3D, b: Marker3D) -> bool:
				return a.name.naturalnocasecmp_to(b.name) < 0
			)

			for muzzle in found_muzzles:
				canon_nodes.append(canon)
				canon_muzzles.append(muzzle)

	if canon_nodes.is_empty():
		if fallback_muzzle != null:
			canon_nodes.append(body_node)
			canon_muzzles.append(fallback_muzzle)

	#print("[TURRET] canons detectés = ", canon_nodes.size(), " | muzzles detectés = ", canon_muzzles.size())
	#for muzzle in canon_muzzles:
		#print("[TURRET] muzzle -> ", muzzle.name)


func _step_toward_target(delta: float, custom_target: Variant = null) -> void:
	var aim_world: Vector3 = target_aim_world if custom_target == null else custom_target
	aim_world = _clamp_aim_world(aim_world)

	if body_node == null:
		return

	var base_yaw := mount.global_rotation.y if mount != null else global_rotation.y
	var target_body_yaw := _compute_target_body_yaw(aim_world)
	var local_target_yaw := wrapf(target_body_yaw - base_yaw, -PI, PI)

	if use_max_rotation:
		var max_radians := deg_to_rad(max_rotation_deg)
		local_target_yaw = clampf(local_target_yaw, -max_radians, max_radians)

	body_node.rotation.y = rotate_toward(
		body_node.rotation.y,
		local_target_yaw,
		deg_to_rad(rotation_speed_deg) * delta
	)
	
	for canon in canon_nodes:
		#var target_pitch := _compute_target_canon_pitch(canon, aim_world)
		#canon.rotation.x = rotate_toward(
			#canon.rotation.x,
			#target_pitch,
			#deg_to_rad(elevation_speed_deg) * delta
		#)
		var target_pitch := _compute_target_canon_pitch(canon, aim_world)
		canon.rotation.x = rotate_toward(
		canon.rotation.x,
		-target_pitch,
		deg_to_rad(elevation_speed_deg) * delta
	)


func _apply_aim_target_immediate(aim_world: Vector3) -> void:
	aim_world = _clamp_aim_world(aim_world)

	if body_node == null:
		return

	var base_yaw := mount.global_rotation.y if mount != null else global_rotation.y
	var target_body_yaw := _compute_target_body_yaw(aim_world)
	var local_target_yaw := wrapf(target_body_yaw - base_yaw, -PI, PI)

	if use_max_rotation:
		var max_radians := deg_to_rad(max_rotation_deg)
		local_target_yaw = clampf(local_target_yaw, -max_radians, max_radians)

	body_node.rotation.y = local_target_yaw

	for canon in canon_nodes:
		#canon.rotation.x = _compute_target_canon_pitch(canon, aim_world)
		canon.rotation.x = -_compute_target_canon_pitch(canon, aim_world)

func _compute_target_body_yaw(aim_world: Vector3) -> float:
	var origin := body_node.global_position if body_node != null else global_position
	var direction := aim_world - origin
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		var forward := _get_vehicle_forward()
		return atan2(forward.x, forward.z)
	direction = direction.normalized()
	return atan2(direction.x, direction.z)


func _compute_target_canon_pitch(canon: Node3D, aim_world: Vector3) -> float:
	var local_target := canon.to_local(aim_world)
	var flat := Vector2(local_target.x, local_target.z).length()
	var pitch := atan2(local_target.y, max(flat, 0.001))
	return clampf(pitch, deg_to_rad(min_elevation_deg), deg_to_rad(max_elevation_deg))


func _get_idle_aim_world() -> Vector3:
	var origin := body_node.global_position if body_node != null else global_position
	var forward := _get_vehicle_forward()
	return origin + forward * idle_aim_distance


func _get_vehicle_forward() -> Vector3:
	if vehicle != null:
		return (vehicle.global_basis * Vector3.MODEL_FRONT).normalized()
	if mount != null:
		return mount.global_basis.z.normalized()
	return global_basis.z.normalized()


func _get_current_aim_target_from_pose() -> Vector3:
	var muzzle := _get_current_fire_muzzle()
	if muzzle == null:
		return _get_idle_aim_world()

	var direction := muzzle.global_basis.z.normalized()
	return muzzle.global_position + direction * shot_range


func _clamp_aim_world(raw_aim_world: Vector3) -> Vector3:
	if body_node == null:
		return raw_aim_world

	var origin := body_node.global_position
	if raw_aim_world.distance_to(origin) < 0.25:
		return origin + _get_vehicle_forward() * 1.0

	if use_max_rotation and vehicle != null:
		var base_yaw := vehicle.global_rotation.y
		var desired_dir := raw_aim_world - origin
		desired_dir.y = 0.0
		if desired_dir.length_squared() > 0.0001:
			var raw_yaw := atan2(desired_dir.x, desired_dir.z)
			var local_yaw := wrapf(raw_yaw - base_yaw, -PI, PI)
			local_yaw = clampf(local_yaw, -deg_to_rad(max_rotation_deg), deg_to_rad(max_rotation_deg))
			var clamped_yaw := base_yaw + local_yaw
			var horizontal_distance := Vector2(desired_dir.x, desired_dir.z).length()
			raw_aim_world.x = origin.x + sin(clamped_yaw) * horizontal_distance
			raw_aim_world.z = origin.z + cos(clamped_yaw) * horizontal_distance

	return raw_aim_world


func _should_fire_from_trigger(wants_fire: bool) -> bool:
	if not wants_fire:
		return false

	if automatic_fire:
		return true

	return not trigger_was_pressed


func set_automatic_fire(value: bool) -> void:
	automatic_fire = value
	trigger_was_pressed = false


func is_automatic_fire_enabled() -> bool:
	return automatic_fire


func _try_fire(peer_id: int) -> void:
	if not _can_fire():
		return

	var muzzle := _get_next_fire_muzzle()
	if muzzle == null:
		return
	
	_consume_ammo(ammo_per_shot)
	fire_timer = fire_cooldown

	var shot_origin := muzzle.global_position
	var shot_direction := _get_shot_direction(muzzle)

	_spawn_bullet_fx(shot_origin, shot_direction)
	_spawn_bullet_fx.rpc(shot_origin, shot_direction)

	#_process_shot(peer_id, shot_origin, shot_direction)


func _sanitize_ammo_values() -> void:
	magazine_max_ammo = maxi(magazine_max_ammo, 1)
	magazine_ammo = clampi(magazine_ammo, 0, magazine_max_ammo)
	reserve_max_ammo = maxi(reserve_max_ammo, 0)
	reserve_ammo = clampi(reserve_ammo, 0, reserve_max_ammo)
	reload_time = maxf(reload_time, 0.0)
	ammo_per_shot = maxi(ammo_per_shot, 1)
	reload_timer = maxf(reload_timer, 0.0)


func _can_fire() -> bool:
	if fire_timer > 0.0:
		return false

	if is_reloading:
		return false

	if magazine_ammo < ammo_per_shot:
		if reserve_ammo > 0:
			reload_turret()
		return false

	return true


func _consume_ammo(amount: int) -> void:
	magazine_ammo = max(magazine_ammo - amount, 0)


func can_reload() -> bool:
	if is_reloading:
		return false

	if magazine_ammo >= magazine_max_ammo:
		return false

	if not infinite_ammo and reserve_ammo <= 0:
		return false

	return true


func reload_turret(amount: int = -1) -> bool:
	if not multiplayer.is_server():
		return false

	_sanitize_ammo_values()

	if not can_reload():
		return false

	pending_reload_amount = amount

	if reload_time <= 0.0:
		_finish_reload()
		return true

	is_reloading = true
	reload_timer = reload_time
	return true


func cancel_reload() -> void:
	if not multiplayer.is_server():
		return

	is_reloading = false
	reload_timer = 0.0
	pending_reload_amount = -1


func refill_turret_instant(amount: int = -1) -> bool:
	if not multiplayer.is_server():
		return false

	_sanitize_ammo_values()

	if not can_reload():
		return false

	pending_reload_amount = amount
	_finish_reload()
	return true


func _update_reload(delta: float) -> void:
	if not is_reloading:
		return

	reload_timer -= delta

	if reload_timer <= 0.0:
		_finish_reload()


func _finish_reload() -> void:
	is_reloading = false
	reload_timer = 0.0

	var missing_ammo := magazine_max_ammo - magazine_ammo
	if missing_ammo <= 0:
		pending_reload_amount = -1
		return

	var wanted_reload_amount := missing_ammo
	if pending_reload_amount > 0:
		wanted_reload_amount = mini(pending_reload_amount, missing_ammo)

	if infinite_ammo:
		magazine_ammo = clampi(
			magazine_ammo + wanted_reload_amount,
			0,
			magazine_max_ammo
		)
	else:
		var loaded_ammo := mini(wanted_reload_amount, reserve_ammo)
		reserve_ammo = maxi(reserve_ammo - loaded_ammo, 0)
		magazine_ammo = clampi(
			magazine_ammo + loaded_ammo,
			0,
			magazine_max_ammo
		)

	pending_reload_amount = -1


func get_magazine_ammo() -> int:
	return magazine_ammo


func get_magazine_max_ammo() -> int:
	return magazine_max_ammo


func get_reserve_ammo() -> int:
	return reserve_ammo


func get_reserve_max_ammo() -> int:
	return reserve_max_ammo


func has_infinite_ammo() -> bool:
	return infinite_ammo


func get_total_available_ammo() -> int:
	if infinite_ammo:
		return -1

	return magazine_ammo + reserve_ammo


func add_reserve_ammo(amount: int) -> int:
	if not multiplayer.is_server():
		return 0

	if infinite_ammo:
		return 0

	_sanitize_ammo_values()

	if amount <= 0:
		return 0

	var previous_reserve := reserve_ammo
	reserve_ammo = clampi(reserve_ammo + amount, 0, reserve_max_ammo)
	return reserve_ammo - previous_reserve


func refill_reserve_instant(amount: int = -1) -> int:
	if not multiplayer.is_server():
		return 0

	if infinite_ammo:
		return 0

	_sanitize_ammo_values()

	var previous_reserve := reserve_ammo
	if amount <= 0:
		reserve_ammo = reserve_max_ammo
	else:
		reserve_ammo = clampi(reserve_ammo + amount, 0, reserve_max_ammo)

	return reserve_ammo - previous_reserve


func set_infinite_ammo(value: bool) -> void:
	if not multiplayer.is_server():
		return

	infinite_ammo = value
	_sanitize_ammo_values()


func get_reload_progress() -> float:
	if not is_reloading:
		return 1.0

	if reload_time <= 0.0:
		return 1.0

	return 1.0 - clampf(reload_timer / reload_time, 0.0, 1.0)


func _get_next_fire_muzzle() -> Marker3D:
	if canon_muzzles.is_empty():
		return fallback_muzzle

	var muzzle := canon_muzzles[next_canon_index % canon_muzzles.size()]
	next_canon_index = (next_canon_index + 1) % canon_muzzles.size()
	return muzzle


func _get_current_fire_muzzle() -> Marker3D:
	if canon_muzzles.is_empty():
		return fallback_muzzle
	return canon_muzzles[(next_canon_index - 1 + canon_muzzles.size()) % canon_muzzles.size()]


func _get_shot_direction(muzzle_node: Marker3D) -> Vector3:
	# Le projectile part dans l'axe réel du canon, pas vers la position de la souris.
	# La souris sert seulement à orienter la tourelle progressivement.
	if muzzle_node == null:
		return global_basis.z.normalized()

	return muzzle_node.global_basis.z.normalized()


func _process_shot(peer_id: int, shot_origin: Vector3, shot_direction: Vector3) -> void:
	var query := PhysicsRayQueryParameters3D.create(
		shot_origin,
		shot_origin + shot_direction * shot_range
	)

	var excludes: Array[RID] = []
	if vehicle != null:
		excludes.append(vehicle.get_rid())

	var shooter := vehicle.get_player_node_by_peer_id(peer_id) if vehicle != null else null
	if shooter != null and shooter is CollisionObject3D:
		excludes.append((shooter as CollisionObject3D).get_rid())

	query.exclude = excludes
	query.collision_mask = collision_mask

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return

	var collider = result.get("collider")
	if collider != null:
		if collider.has_method("take_damage"):
			print("process applied 1")
			collider.take_damage(damage)
		elif collider.has_method("apply_damage"):
			print("process applied 2")
			collider.apply_damage(damage)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _sync_turret_state(
	aim_world: Vector3,
	synced_body_yaw: float,
	synced_canon_pitches: Array,
	synced_magazine_ammo: int,
	synced_magazine_max_ammo: int,
	synced_reserve_ammo: int,
	synced_reserve_max_ammo: int,
	synced_infinite_ammo: bool,
	synced_is_reloading: bool,
	synced_reload_timer: float
) -> void:
	if multiplayer.is_server():
		return

	replicated_aim_world = aim_world

	turret_state_buffer.append({
		"time": Time.get_ticks_msec() * 0.001,
		"body_yaw": synced_body_yaw,
		"canon_pitches": synced_canon_pitches
	})

	while turret_state_buffer.size() > max_turret_state_buffer_size:
		turret_state_buffer.pop_front()

	magazine_ammo = synced_magazine_ammo
	magazine_max_ammo = synced_magazine_max_ammo
	reserve_ammo = synced_reserve_ammo
	reserve_max_ammo = synced_reserve_max_ammo
	infinite_ammo = synced_infinite_ammo
	is_reloading = synced_is_reloading
	reload_timer = synced_reload_timer


func _get_synced_body_yaw() -> float:
	if body_node == null:
		return 0.0

	return body_node.rotation.y


func _get_synced_canon_pitches() -> Array:
	var pitches: Array = []

	for canon in canon_nodes:
		if canon == null:
			pitches.append(0.0)
		else:
			pitches.append(canon.rotation.x)

	return pitches


func _apply_synced_turret_pose(body_yaw: float, canon_pitches: Array) -> void:
	if body_node != null:
		body_node.rotation.y = body_yaw

	var count: int = mini(canon_nodes.size(), canon_pitches.size())

	for i in count:
		var canon := canon_nodes[i]
		if canon == null:
			continue

		canon.rotation.x = float(canon_pitches[i])

#@rpc("authority", "call_remote", "reliable", 2)
#func _spawn_bullet_fx(start_pos: Vector3, direction: Vector3) -> void:
	#var scene := bullet_scene if bullet_scene != null else DEFAULT_VISUAL_BULLET_SCENE
	#if scene == null:
		#return
#
	#var bullet = scene.instantiate()
	#if bullet == null:
		#return
#
	#if bullet is Node3D:
		#(bullet as Node3D).global_position = start_pos
#
	#if bullet.has_method("setup"):
		#bullet.setup(start_pos, direction)
	#elif bullet.has_method("set_direction"):
		#bullet.set_direction(direction)
#
	#get_tree().current_scene.add_child(bullet)


@rpc("authority", "call_remote", "reliable", 2)
func _spawn_bullet_fx(start_pos: Vector3, direction: Vector3) -> void:
	var scene := bullet_scene if bullet_scene != null else DEFAULT_VISUAL_BULLET_SCENE

	spawn_projectile(
		scene,
		start_pos,
		direction,
		projectile_team,
		projectile_damage,
		projectile_penetration,
		projectile_tk,
		self,
		projectile_impact_scene
	)


func spawn_projectile(
	scene: PackedScene,
	start_pos: Vector3,
	direction: Vector3,
	source_team: int,
	source_damage: int,
	source_penetration: int = 0,
	allow_tk: bool = false,
	source_node: Node = null,
	impact_scene: PackedScene = null
) -> void:
	if scene == null:
		return

	var bullet = scene.instantiate()
	if bullet == null:
		return

	get_tree().current_scene.add_child(bullet)

	if bullet.has_method("fire"):
		bullet.fire(
			start_pos,
			direction.normalized(),
			source_team,
			source_damage,
			source_penetration,
			allow_tk,
			source_node,
			impact_scene
		)
