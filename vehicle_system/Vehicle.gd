extends VehicleBody3D
class_name Vehicle

signal loadout_state_changed
signal seat_layout_changed

const TURRET_SCAN_ROOT := "res://vehicle_system/turrets/"
const CHASSIS_SCAN_ROOT := "res://vehicle_system/chassis/"

var state_buffer: Array = []
var interpolation_back_time: float = 0.15
var max_state_buffer_size: int = 12
var client_has_target_transform: bool = false
var client_target_transform: Transform3D = Transform3D.IDENTITY

var available_shop_turrets: Array[Dictionary] = []
var available_chassis_entries: Array[Dictionary] = []

@export_group("Identity")
@export var vehicle_display_name: String = "Tank"
@export var chassis_id: String = "medium_tank"
@export var chassis_price: int = 2000
@export var chassis_trade_in_value: int = 1500

@export_group("Seats")
@export_range(1, 8, 1) var seat_count: int = 4

@export_group("Drive")
@export var engine_force_forward: float = 6000.0
@export var engine_force_reverse: float = 550.0
@export var brake_force: float = 500.0
@export var idle_brake_force: float = 40.0
@export var max_steering_deg: float = 50.0
@export var steering_speed: float = 4.8
@export var downforce_strength: float = 20.0
@export var invert_steering: bool = true

@export_group("Shop")
@export var shop_money: int = 2000

@export_group("UI")
@export var loadout_menu_scene: PackedScene = preload("res://vehicle_system/VehicleLoadoutMenu.tscn")

@export_group("Replication")
@export var state_send_interval: float = 0.033

@onready var body_visual_root: Node3D = $BodyVisualRoot
@onready var seats_root: Node = $BodyVisualRoot/Seats
@onready var exit_point: Marker3D = $ExitPoint
@onready var use_area: Area3D = $UseArea

var seat_markers: Array[Marker3D] = []
var seat_occupants: Array[int] = []
var turret_mounts: Array[VehicleTurretMount] = []

var steer_input: float = 0.0
var drive_input: float = 0.0
var current_steering: float = 0.0
var state_timer: float = 0.0

var replicated_position: Vector3 = Vector3.ZERO
var replicated_rotation: Quaternion = Quaternion.IDENTITY
var replicated_steering: float = 0.0
var replicated_engine_force: float = 0.0
var replicated_brake: float = 0.0


@export var max_health: int = 600
@export var armor_rating: int = 0
var health := 0
var is_dead := false

@export_group("Impact Damage")
@export var impact_damage_enabled: bool = true
@export var impact_min_speed: float = 1.0
@export var impact_damage_at_min_speed: int = 5
@export var impact_damage_per_speed: float = 2.0
@export var impact_max_damage: int = 40
@export var impact_damage_cooldown: float = 0.35
@export var impact_damage_other_vehicles: bool = false
@export var impact_target_groups: Array[StringName] = [
	&"enemy",
	&"enemies",
	&"prop",
	&"props",
	&"damageable",
]
@export var impact_damage_debug: bool = false
@export_range(0, 6, 1) var impact_disable_player_damage_after_exit_frames: int = 2
@export var impact_player_groups: Array[StringName] = [
	&"player",
	&"players",
]

@export_group("Enemy Soft Collision")
@export var enemy_soft_collision_enabled: bool = true
@export var enemy_soft_impact_area_path: NodePath = ^"EnemySoftImpactArea"
@export var enemy_soft_collision_groups: Array[StringName] = [
	&"enemy",
	&"enemies",
]
@export var enemy_soft_push_velocity: float = 18.0 # 8
@export var enemy_soft_push_upward_velocity: float = 1.75 # .75
@export var enemy_soft_position_nudge: float = 0.18
@export var enemy_soft_push_rigidbody_impulse_multiplier: float = 2.0

var _impact_last_hit_time: Dictionary = {}
var _impact_disable_player_damage_until_frame: int = -1
var _enemy_soft_impact_area: Area3D = null


static func inspect_chassis_scene(scene: PackedScene) -> Dictionary:
	if scene == null:
		return {}

	var instance := scene.instantiate()
	if instance == null:
		return {}

	var info := {}
	if instance is Vehicle:
		var vehicle := instance as Vehicle
		info = {
			"chassis_id": vehicle.chassis_id,
			"vehicle_display_name": vehicle.vehicle_display_name,
			"chassis_price": vehicle.chassis_price,
			"chassis_trade_in_value": vehicle.get_chassis_trade_in_value(),
			"scene": scene,
		}

	instance.queue_free()
	return info

func _ready() -> void:
	#VehicleState.register_vehicle(self)
	add_to_group("vehicle")
	add_to_group("vehicles")
	
	set_multiplayer_authority(1)
	health = max_health
	
	if multiplayer.is_server():
		can_sleep = false
		contact_monitor = true
		max_contacts_reported = max(max_contacts_reported, 16)
		if not body_entered.is_connected(_on_vehicle_body_entered):
			body_entered.connect(_on_vehicle_body_entered)
		_setup_enemy_soft_impact_area()
		freeze = false
		custom_integrator = false
	else:
		can_sleep = false
		contact_monitor = false
		freeze = false
		custom_integrator = true
		sleeping = false
	
	replicated_position = global_position
	replicated_rotation = global_basis.get_rotation_quaternion()
	replicated_steering = steering
	replicated_engine_force = engine_force
	replicated_brake = brake
	
	_scan_seat_markers()
	_ensure_seat_occupants()
	_scan_turret_mounts()
	_scan_available_shop_turrets()
	_scan_available_chassis_entries()
	
	if use_area != null:
		if not use_area.body_entered.is_connected(_on_use_area_body_entered):
			use_area.body_entered.connect(_on_use_area_body_entered)
	
		if not use_area.body_exited.is_connected(_on_use_area_body_exited):
			use_area.body_exited.connect(_on_use_area_body_exited)
	
		set_use_area_enabled(not bool(get_meta("upgrade_station_locked", false)))
	
	if multiplayer.is_server():
		_broadcast_seat_layout()
		_broadcast_loadout_state()

func build_session_state() -> Dictionary:
	var config: Array[Dictionary] = []
	for mount in turret_mounts:
		config.append({
			"seat_index": mount.seat_index,
			"turret_scene_path": mount.get_turret_scene_path()
		})

	return {
		"scene_path": _get_session_scene_path(),
		"vehicle_display_name": vehicle_display_name,
		"chassis_id": chassis_id,
		"max_health": max_health,
		"health": health,
		"is_dead": is_dead,
		"shop_money": shop_money,
		"turret_config": config
	}


func apply_session_state(state: Dictionary) -> void:
	vehicle_display_name = String(state.get("vehicle_display_name", vehicle_display_name))
	chassis_id = String(state.get("chassis_id", chassis_id))
	max_health = int(state.get("max_health", max_health))
	shop_money = int(state.get("shop_money", shop_money))

	var restored_health: int = int(state.get("health", max_health))
	health = clampi(restored_health, 0, max_health)
	is_dead = bool(state.get("is_dead", false)) or health <= 0

	var turret_config = state.get("turret_config", [])
	if turret_config is Array:
		_sync_loadout_state(shop_money, turret_config)

	if is_dead:
		_sync_vehicle_destroyed()
	else:
		freeze = false
		sleeping = false
		set_use_area_enabled(not bool(get_meta("upgrade_station_locked", false)))
		_sync_vehicle_health(health)


func _get_session_scene_path() -> String:
	if not scene_file_path.is_empty():
		return scene_file_path
	return ""


func set_use_area_enabled(enabled: bool) -> void:
	if use_area == null:
		print("[VEHICLE] set_use_area_enabled FAIL: no UseArea on ", name)
		return

	#use_area.monitoring = enabled
	#use_area.monitorable = enabled
	use_area.set_deferred("monitoring", enabled)
	use_area.set_deferred("monitorable", enabled)

	print("[VEHICLE] UseArea -> monitoring=", use_area.monitoring, " monitorable=", use_area.monitorable, " enabled=", enabled)

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_physics(delta)
	else:
		_client_physics(delta)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if multiplayer.is_server():
		return

	if not client_has_target_transform:
		return

	state.transform = client_target_transform
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO


func _server_physics(delta: float) -> void:
	if is_dead:
		steer_input = 0.0
		drive_input = 0.0
		engine_force = 0.0
		brake = brake_force
		return

	_update_drive_controls(delta)
	_process_enemy_soft_impacts(delta)

	state_timer -= delta
	if state_timer <= 0.0:
		state_timer = state_send_interval

		_sync_vehicle_state.rpc(
			global_transform,
			linear_velocity,
			angular_velocity,
			steering,
			engine_force,
			brake
		)


func _client_physics(_delta: float) -> void:
	if state_buffer.size() < 2:
		return

	var render_time := Time.get_ticks_msec() * 0.001 - interpolation_back_time

	while state_buffer.size() >= 2 and state_buffer[1]["time"] <= render_time:
		state_buffer.pop_front()

	if state_buffer.size() < 2:
		return

	var a = state_buffer[0]
	var b = state_buffer[1]

	var span: float = max(b["time"] - a["time"], 0.0001)
	var t: float = clamp((render_time - a["time"]) / span, 0.0, 1.0)

	var target_position: Vector3 = a["transform"].origin.lerp(
		b["transform"].origin,
		t
	)

	var qa: Quaternion = a["transform"].basis.get_rotation_quaternion()
	var qb: Quaternion = b["transform"].basis.get_rotation_quaternion()
	var target_basis := Basis(qa.slerp(qb, t))

	client_target_transform = Transform3D(target_basis, target_position)
	client_has_target_transform = true

	engine_force = 0.0
	brake = 0.0
	steering = 0.0


func get_hud_data_for_player(player: Node) -> Dictionary:
	var out := {
		"vehicle_name": vehicle_display_name,
		"health": health,
		"max_health": max_health,
		"current_seat_name": "",
		"turret_name": "",
		"turret_ammo": {},
		"seats": []
	}

	var local_peer_id := -1
	if player != null and "player_id" in player:
		local_peer_id = int(player.player_id)

	for seat_index in range(1, seat_count + 1):
		var mount := get_mount_for_seat(seat_index)
		var occupant_peer_id := get_seat_occupant(seat_index)

		var seat_name := "Siège %d" % seat_index
		var turret_name := ""

		if mount != null:
			seat_name = mount.seat_label
			turret_name = mount.get_turret_label()

		var occupant_name := "Libre"
		if occupant_peer_id != -1:
			var occupant_player := _find_player_by_peer_id(occupant_peer_id)
			if occupant_player != null and "player_name" in occupant_player:
				occupant_name = str(occupant_player.player_name)
			else:
				occupant_name = "Joueur %d" % occupant_peer_id

		var is_self := occupant_peer_id == local_peer_id

		out["seats"].append({
			"seat_name": seat_name,
			"occupant_name": occupant_name,
			"is_self": is_self,
		})

		if is_self:
			out["current_seat_name"] = seat_name
			out["turret_name"] = turret_name

			var turret := _get_turret_from_mount(mount)
			if turret != null:
				out["turret_ammo"] = _get_turret_ammo_hud_data(turret)

	return out

func request_reload_turret_for_player(peer_id: int) -> bool:
	if not multiplayer.is_server():
		return false

	for seat_index in range(1, seat_count + 1):
		var occupant_peer_id := get_seat_occupant(seat_index)

		if occupant_peer_id != peer_id:
			continue

		var mount := get_mount_for_seat(seat_index)
		if mount == null:
			return false

		var turret := _get_turret_from_mount(mount)
		if turret == null:
			return false

		if not turret.has_method("reload_turret"):
			return false

		return turret.reload_turret()

	return false

@rpc("any_peer", "call_remote", "reliable")
func request_reload_turret_rpc() -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id := multiplayer.get_remote_sender_id()
	if sender_peer_id <= 0:
		return

	request_reload_turret_for_player(sender_peer_id)

func _get_turret_from_mount(mount: Node) -> Node:
	if mount == null:
		return null

	if mount.has_method("get_turret"):
		var turret = mount.call("get_turret")
		if turret != null and is_instance_valid(turret):
			return turret

	if mount.has_method("get_current_turret"):
		var turret = mount.call("get_current_turret")
		if turret != null and is_instance_valid(turret):
			return turret

	if mount.has_method("get_turret_instance"):
		var turret = mount.call("get_turret_instance")
		if turret != null and is_instance_valid(turret):
			return turret

	var possible_properties := [
		"turret",
		"current_turret",
		"active_turret",
		"turret_instance",
	]

	for property_name in possible_properties:
		var turret = mount.get(property_name)
		if turret != null and is_instance_valid(turret):
			return turret

	return null


func _get_turret_ammo_hud_data(turret: Node) -> Dictionary:
	if turret == null:
		return {}

	return {
		"magazine_ammo": turret.get_magazine_ammo(),
		"magazine_max_ammo": turret.get_magazine_max_ammo(),
		"reserve_ammo": turret.get_reserve_ammo(),
		"reserve_max_ammo": turret.get_reserve_max_ammo(),
		"infinite_ammo": turret.has_infinite_ammo(),
	}

func _find_player_by_peer_id(peer_id: int) -> Node:
	for node in get_tree().get_nodes_in_group("players"):
		if "player_id" in node and int(node.player_id) == peer_id:
			return node
	return null


func _scan_seat_markers() -> void:
	seat_markers.clear()
	if seats_root == null:
		return

	_collect_seat_markers(seats_root)

	seat_markers.sort_custom(func(a: Marker3D, b: Marker3D) -> bool:
		return _extract_seat_index(a.name) < _extract_seat_index(b.name)
	)

	seat_count = seat_markers.size()


func _collect_seat_markers(node: Node) -> void:
	for child in node.get_children():
		if child is Marker3D and String(child.name).begins_with("Seat"):
			seat_markers.append(child as Marker3D)
		_collect_seat_markers(child)


func _extract_seat_index(name_value: String) -> int:
	var digits := ""
	for c in name_value:
		if c >= "0" and c <= "9":
			digits += c
		elif digits != "":
			break

	return int(digits) if digits != "" else 9999


func _ensure_seat_occupants() -> void:
	seat_occupants.resize(seat_count)
	for i in range(seat_count):
		if typeof(seat_occupants[i]) != TYPE_INT:
			seat_occupants[i] = -1
		elif int(seat_occupants[i]) == 0:
			seat_occupants[i] = -1


func _scan_turret_mounts() -> void:
	turret_mounts.clear()
	_collect_turret_mounts(self)
	turret_mounts.sort_custom(func(a: VehicleTurretMount, b: VehicleTurretMount) -> bool:
		return a.seat_index < b.seat_index
	)

	for mount in turret_mounts:
		mount.initialize(self)


func _collect_turret_mounts(node: Node) -> void:
	for child in node.get_children():
		if child is VehicleTurretMount and child.is_in_group("vehicle_turret_mount"):
			turret_mounts.append(child as VehicleTurretMount)
		_collect_turret_mounts(child)


func _scan_available_shop_turrets() -> void:
	available_shop_turrets.clear()
	_scan_turret_folder_recursive(TURRET_SCAN_ROOT)

	available_shop_turrets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("turret_label", "")) < String(b.get("turret_label", ""))
	)

	for i in range(available_shop_turrets.size()):
		available_shop_turrets[i]["shop_index"] = i


func _scan_turret_folder_recursive(folder_path: String) -> void:
	var dir := DirAccess.open(folder_path)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break

		if entry.begins_with("."):
			continue

		var full_path := folder_path.path_join(entry)

		if dir.current_is_dir():
			_scan_turret_folder_recursive(full_path)
			continue

		if not entry.ends_with(".tscn"):
			continue

		_try_register_shop_turret_scene(full_path)

	dir.list_dir_end()


func _try_register_shop_turret_scene(scene_path: String) -> void:
	var scene := load(scene_path) as PackedScene
	if scene == null:
		return

	var entry := VehicleTurretBase.inspect_scene(scene)
	if entry.is_empty():
		return

	var turret_id := String(entry.get("turret_id", ""))
	if turret_id == "" or turret_id == "driver_turret":
		return

	var turret_size := int(entry.get("turret_size", 0))
	if turret_size <= 0:
		return

	for existing in available_shop_turrets:
		if String(existing.get("turret_id", "")) == turret_id:
			return

	entry["shop_index"] = available_shop_turrets.size()
	entry["turret_scene"] = scene
	entry["scene_path"] = scene_path
	available_shop_turrets.append(entry)


func _scan_available_chassis_entries() -> void:
	available_chassis_entries.clear()

	var dir := DirAccess.open(CHASSIS_SCAN_ROOT)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break

		if entry.begins_with(".") or dir.current_is_dir():
			continue

		if not entry.ends_with(".tscn"):
			continue

		var scene_path := CHASSIS_SCAN_ROOT.path_join(entry)
		var scene := load(scene_path) as PackedScene
		if scene == null:
			continue

		var info := inspect_chassis_scene(scene)
		if info.is_empty():
			continue

		var candidate_id := String(info.get("chassis_id", ""))
		if candidate_id == "":
			continue

		var exists := false
		for existing in available_chassis_entries:
			if String(existing.get("chassis_id", "")) == candidate_id:
				exists = true
				break

		if exists:
			continue

		info["chassis_index"] = available_chassis_entries.size()
		info["scene"] = scene
		info["scene_path"] = scene_path
		available_chassis_entries.append(info)

	dir.list_dir_end()

	available_chassis_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("chassis_price", 0)) < int(b.get("chassis_price", 0))
	)

	for i in range(available_chassis_entries.size()):
		available_chassis_entries[i]["chassis_index"] = i


func _update_drive_controls(delta: float) -> void:
	var driver_peer_id := get_driver_peer_id()

	if driver_peer_id == -1:
		steer_input = 0.0
		drive_input = 0.0
		engine_force = 0.0
		brake = idle_brake_force
		current_steering = move_toward(current_steering, 0.0, steering_speed * delta)
		steering = current_steering
		return

	var steering_sign := -1.0 if invert_steering else 1.0
	var target_steering := deg_to_rad(max_steering_deg) * steer_input * steering_sign
	current_steering = move_toward(current_steering, target_steering, steering_speed * delta)
	steering = current_steering

	var forward_speed := linear_velocity.dot(global_basis * Vector3.MODEL_FRONT)
	engine_force = 0.0
	brake = 0.0

	if drive_input > 0.05:
		if forward_speed < -1.0:
			brake = brake_force
		else:
			engine_force = engine_force_forward * drive_input
	elif drive_input < -0.05:
		if forward_speed > 1.0:
			brake = brake_force
		else:
			engine_force = -engine_force_reverse * abs(drive_input)
	else:
		brake = idle_brake_force

	if downforce_strength > 0.0:
		var speed := linear_velocity.length()
		if speed > 0.1:
			apply_central_force(-global_basis.y * speed * downforce_strength)


func apply_damage(amount: int) -> void:
	if not multiplayer.is_server():
		return

	if is_dead:
		return

	health = max(health - amount, 0)
	if health <= 0:
		_server_destroy_vehicle()
		return

	_sync_vehicle_health.rpc(health)


func apply_repair(amount: int) -> void:
	if not multiplayer.is_server():
		return

	if amount <= 0:
		return

	if health >= max_health and not is_dead:
		return

	health = clampi(health + amount, 0, max_health)

	if is_dead and health > 0:
		_server_revive_vehicle()
		return

	_sync_vehicle_health.rpc(health)


func _server_revive_vehicle() -> void:
	if not multiplayer.is_server():
		return

	if health <= 0:
		health = 1

	_sync_vehicle_revived.rpc(health)
	_broadcast_seat_layout()
	state_timer = 0.0


func _server_destroy_vehicle() -> void:
	if is_dead:
		return

	is_dead = true
	health = 0
	steer_input = 0.0
	drive_input = 0.0
	engine_force = 0.0
	brake = brake_force
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	sleeping = true

	_force_all_players_out()
	set_use_area_enabled(false)
	_broadcast_seat_layout()
	_sync_vehicle_destroyed.rpc()

func apply_projectile_damage(
	amount: int,
	to_projectile_penetration: int = 0,
	_source_team: int = 0,
	_allow_tk: bool = false,
	_source: Node = null
) -> void:
	if not multiplayer.is_server():
		return

	var effective_armor = max(armor_rating - to_projectile_penetration, 0)
	var final_damage = max(amount - effective_armor, 1)

	if final_damage <= 0:
		return

	apply_damage(final_damage)


func _setup_enemy_soft_impact_area() -> void:
	if not enemy_soft_collision_enabled:
		return

	var area_node := get_node_or_null(enemy_soft_impact_area_path)
	if area_node == null:
		push_warning("[VEHICLE] EnemySoftImpactArea introuvable sur %s. Cree une Area3D dans la scene du vehicule ou corrige enemy_soft_impact_area_path." % name)
		return

	if not (area_node is Area3D):
		push_warning("[VEHICLE] Le node indique par enemy_soft_impact_area_path n'est pas une Area3D sur %s." % name)
		return

	_enemy_soft_impact_area = area_node as Area3D
	_enemy_soft_impact_area.monitoring = true
	_enemy_soft_impact_area.monitorable = false


func _process_enemy_soft_impacts(delta: float) -> void:
	if not multiplayer.is_server():
		return

	if not enemy_soft_collision_enabled:
		return

	if not impact_damage_enabled:
		return

	if _enemy_soft_impact_area == null:
		return

	var speed := linear_velocity.length()
	if speed < impact_min_speed:
		return

	for body in _enemy_soft_impact_area.get_overlapping_bodies():
		_try_enemy_soft_impact(body, speed, delta)


func _try_enemy_soft_impact(body: Node, speed: float, delta: float) -> void:
	if body == null or body == self:
		return

	var target := _get_enemy_soft_impact_target(body)
	if target == null:
		return
	
	print("tank push")
	_apply_enemy_soft_push(target, speed, delta)

	if _is_impact_target_on_cooldown(target):
		return

	var damage := _get_impact_damage_from_speed(speed)
	if damage <= 0:
		return
	
	print("tank damage")
	_register_impact_hit(target)
	_apply_impact_damage_to_target(target, damage)

	if impact_damage_debug:
		print("[VEHICLE SOFT IMPACT] ", name, " hit ", target.name, " | speed=", speed, " | damage=", damage)


#func _get_enemy_soft_impact_target(body: Node) -> Node:
	#if body == null or body == self:
		#return null
#
	#if body.is_in_group(&"vehicle") or body.is_in_group(&"vehicles"):
		#return null
#
	#for group_name in enemy_soft_collision_groups:
		#if body.is_in_group(group_name):
			#return body
#
	#return null


func _get_enemy_soft_impact_target(body: Node) -> Node:
	if body == null or body == self:
		return null

	var current: Node = body

	while current != null:
		if current == self:
			return null

		if current.is_in_group(&"vehicle") or current.is_in_group(&"vehicles"):
			return null

		for group_name in enemy_soft_collision_groups:
			if current.is_in_group(group_name):
				return current

		if current.has_method(&"apply_vehicle_push"):
			return current

		current = current.get_parent()

	return null


func _apply_enemy_soft_push(target: Node, speed: float, delta: float) -> void:
	if target == null or not (target is Node3D):
		return

	var direction := linear_velocity
	direction.y = 0.0

	if direction.length_squared() < 0.01:
		direction = (target as Node3D).global_position - global_position
		direction.y = 0.0

	if direction.length_squared() < 0.01:
		return

	direction = direction.normalized()
	var speed_factor = max(speed / max(impact_min_speed, 0.001), 1.0)
	var push_velocity = direction * enemy_soft_push_velocity * speed_factor
	push_velocity.y += enemy_soft_push_upward_velocity

	if target.has_method(&"apply_vehicle_push"):
		target.call(&"apply_vehicle_push", push_velocity, self)
		return

	if target.has_method(&"apply_knockback"):
		target.call(&"apply_knockback", direction, push_velocity.length(), self)
		return

	if target is RigidBody3D:
		var rigidbody := target as RigidBody3D
		rigidbody.apply_central_impulse(push_velocity * enemy_soft_push_rigidbody_impulse_multiplier)
		return

	if target is CharacterBody3D:
		var character := target as CharacterBody3D
		character.velocity += push_velocity
		if enemy_soft_position_nudge > 0.0:
			character.global_position += direction * enemy_soft_position_nudge * speed_factor * delta
		return

	if "velocity" in target:
		target.velocity += push_velocity
		return

	if enemy_soft_position_nudge > 0.0:
		(target as Node3D).global_position += direction * enemy_soft_position_nudge * speed_factor * delta


func _with_collision_layer_bit(mask_value: int, layer_bit: int) -> int:
	var safe_layer_bit = clampi(layer_bit, 1, 32)
	return mask_value | (1 << (safe_layer_bit - 1))


func _on_vehicle_body_entered(body: Node) -> void:
	if not multiplayer.is_server():
		return

	if not impact_damage_enabled:
		return

	if body == null or body == self:
		return

	var speed := linear_velocity.length()
	if speed < impact_min_speed:
		return

	var target := _get_impact_damage_target(body)
	if target == null:
		return

	if _is_player_impact_target(target) and _is_player_exit_impact_safety_active():
		if impact_damage_debug:
			print("[VEHICLE IMPACT] player impact blocked after vehicle exit: ", target.name)
		return

	if _is_impact_target_on_cooldown(target):
		return

	var damage := _get_impact_damage_from_speed(speed)
	if damage <= 0:
		return

	_register_impact_hit(target)
	_apply_impact_damage_to_target(target, damage)

	if impact_damage_debug:
		print("[VEHICLE IMPACT] ", name, " hit ", target.name, " | speed=", speed, " | damage=", damage)


func _get_impact_damage_target(body: Node) -> Node:
	if body == null or body == self:
		return null

	if body.is_in_group(&"vehicle") or body.is_in_group(&"vehicles"):
		if impact_damage_other_vehicles:
			return body
		return null

	# Cas special des props.
	# Le body touche est souvent IntactBody, alors que le script de vie est sur le parent Crate.
	# On ne remonte dans les parents que pour les props / props.
	if _is_impact_prop_candidate(body):
		return _get_impact_prop_damage_target(body)

	# Pour les ennemis et les autres damageables, on ne remonte pas dans le parent.
	# Le node qui entre en collision doit porter directement le groupe ou la methode de degats.
	if _is_valid_direct_impact_damage_target(body):
		return body

	return null


func _is_impact_prop_candidate(body: Node) -> bool:
	if body == null:
		return false

	if body.is_in_group(&"prop") or body.is_in_group(&"props"):
		return true

	if body.has_meta(&"destructible_prop"):
		return true

	return false


func _get_impact_prop_damage_target(body: Node) -> Node:
	if body == null:
		return null

	# Priorite au helper de ton script DestructibleProp.
	# Il transforme IntactBody en Crate, donc on touche le node qui possede apply_damage().
	var destructible_prop := DestructibleProp.from_collider(body)
	if destructible_prop != null:
		return destructible_prop

	# Fallback pour d'autres props destructibles qui n'utilisent pas DestructibleProp.
	var current := body
	while current != null:
		if current == self:
			return null

		if _has_impact_damage_method(current):
			return current

		current = current.get_parent()

	return null


func _is_valid_direct_impact_damage_target(target: Node) -> bool:
	if target == null:
		return false

	if target.is_in_group(&"vehicle") or target.is_in_group(&"vehicles"):
		return impact_damage_other_vehicles

	for group_name in impact_target_groups:
		# Les props sont resolues par _get_impact_prop_damage_target().
		# Ne jamais retourner directement IntactBody juste parce qu'il est dans props.
		if group_name == &"prop" or group_name == &"props":
			continue

		if target.is_in_group(group_name):
			return true

	return _has_impact_damage_method(target)


func _has_impact_damage_method(target: Node) -> bool:
	if target == null:
		return false

	return (
		target.has_method(&"apply_vehicle_impact_damage")
		or target.has_method(&"apply_damage")
		or target.has_method(&"take_damage")
		or target.has_method(&"apply_projectile_damage")
	)


func _is_player_impact_target(target: Node) -> bool:
	if target == null:
		return false

	for group_name in impact_player_groups:
		if target.is_in_group(group_name):
			return true

	return false


func _is_player_exit_impact_safety_active() -> bool:
	if impact_disable_player_damage_after_exit_frames <= 0:
		return false

	return Engine.get_physics_frames() <= _impact_disable_player_damage_until_frame


func _register_player_exit_impact_safety() -> void:
	if impact_disable_player_damage_after_exit_frames <= 0:
		return

	_impact_disable_player_damage_until_frame = Engine.get_physics_frames() + impact_disable_player_damage_after_exit_frames


func _is_impact_target_on_cooldown(target: Node) -> bool:
	var id := target.get_instance_id()
	var now := Time.get_ticks_msec() * 0.001
	var last_time := float(_impact_last_hit_time.get(id, -9999.0))
	return now - last_time < impact_damage_cooldown


func _register_impact_hit(target: Node) -> void:
	_impact_last_hit_time[target.get_instance_id()] = Time.get_ticks_msec() * 0.001


func _get_impact_damage_from_speed(speed: float) -> int:
	var raw_damage := float(impact_damage_at_min_speed) + ((speed - impact_min_speed) * impact_damage_per_speed)
	var damage := int(round(raw_damage))
	return min(max(damage, 0), impact_max_damage)


func _apply_impact_damage_to_target(target: Node, amount: int) -> void:
	var hit_position := global_position
	if target is Node3D:
		hit_position = (target as Node3D).global_position

	var impulse := Vector3.ZERO
	if linear_velocity.length_squared() > 0.0:
		impulse = linear_velocity.normalized() * float(amount)

	if _try_call_damage_method(target, &"apply_vehicle_impact_damage", [amount, self]):
		print("apply damage from vehicle")
		apply_projectile_damage(5)
		return
	else:
		print("no apply damage vehicle")
	
	if _try_call_damage_method(target, &"apply_damage", [amount, hit_position, impulse]):
		apply_projectile_damage(5)
		return

	if _try_call_damage_method(target, &"take_damage", [amount, hit_position, impulse]):
		apply_projectile_damage(5)
		return

	if _try_call_damage_method(target, &"apply_projectile_damage", [amount, 0, 0, false, self]):
		apply_projectile_damage(5)
		return

	if impact_damage_debug:
		print("[VEHICLE IMPACT] can't hit target: ", target, " | class=", target.get_class())


func _try_call_damage_method(target: Node, method_name: StringName, candidate_args: Array) -> bool:
	if target == null or not target.has_method(method_name):
		return false

	for method_info in target.get_method_list():
		if StringName(method_info.get("name", &"")) != method_name:
			continue

		var method_args: Array = method_info.get("args", [])
		var default_args: Array = method_info.get("default_args", [])
		var min_arg_count = max(method_args.size() - default_args.size(), 0)
		var max_arg_count = method_args.size()

		if candidate_args.size() < min_arg_count:
			return false

		var call_args := candidate_args.slice(0, min(candidate_args.size(), max_arg_count))
		if call_args.size() < min_arg_count:
			return false

		target.callv(method_name, call_args)
		return true

	return false


func is_available() -> bool:
	if is_dead:
		return false
	return _get_first_available_seat_index() != -1 and not bool(get_meta("upgrade_station_locked", false))


func get_driver_peer_id() -> int:
	if seat_count < 1:
		return -1
	return seat_occupants[0]


func get_seat_occupant(seat_index: int) -> int:
	if seat_index < 1 or seat_index > seat_count:
		return -1
	return seat_occupants[seat_index - 1]

func get_driver() -> Node:
	return _get_player_node_from_peer_id(get_driver_peer_id())


func get_driver_player() -> Node:
	return get_driver()


func get_current_driver() -> Node:
	return get_driver()


func get_occupants() -> Array[Node]:
	var result: Array[Node] = []

	for peer_id_value in seat_occupants:
		var peer_id: int = int(peer_id_value)
		var player_node: Node = _get_player_node_from_peer_id(peer_id)
		if player_node == null:
			continue
		if result.has(player_node):
			continue
		result.append(player_node)

	return result


func get_players_inside() -> Array[Node]:
	return get_occupants()


func get_passenger_players() -> Array[Node]:
	return get_occupants()


func get_passengers() -> Array[Node]:
	return get_occupants()


func get_seat_occupants() -> Array[Node]:
	return get_occupants()


func _get_player_node_from_peer_id(peer_id: int) -> Node:
	if peer_id <= 0:
		return null

	var player_node: Node = get_player_node_by_peer_id(peer_id)
	if player_node != null:
		return player_node

	player_node = _find_player_by_peer_id(peer_id)
	if player_node != null:
		return player_node

	for candidate in get_tree().get_nodes_in_group("players"):
		if candidate == null or not is_instance_valid(candidate):
			continue
		if not (candidate is Node):
			continue

		var candidate_node: Node = candidate as Node
		if candidate_node.get_multiplayer_authority() == peer_id:
			return candidate_node

		var player_id_value = candidate_node.get("player_id")
		if player_id_value != null and int(player_id_value) == peer_id:
			return candidate_node

	return null



func get_seat_index_for_peer(peer_id: int) -> int:
	for i in range(seat_count):
		if seat_occupants[i] == peer_id:
			return i + 1
	return -1


func get_seat_marker(seat_index: int) -> Marker3D:
	if seat_index < 1 or seat_index > seat_markers.size():
		return null
	return seat_markers[seat_index - 1]


func get_mount_for_seat(seat_index: int) -> VehicleTurretMount:
	for mount in turret_mounts:
		if mount.seat_index == seat_index:
			return mount
	return null


func get_player_node_by_peer_id(peer_id: int) -> Node:
	for player in get_tree().get_nodes_in_group("players"):
		if player.get_multiplayer_authority() == peer_id:
			return player
	return null


func get_local_player() -> Node:
	for player in get_tree().get_nodes_in_group("players"):
		if player.is_multiplayer_authority():
			return player
	return null


func get_available_shop_entries() -> Array[Dictionary]:
	return available_shop_turrets.duplicate(true)


func get_available_chassis_entries() -> Array[Dictionary]:
	return available_chassis_entries.duplicate(true)


func get_chassis_trade_in_value() -> int:
	return chassis_trade_in_value if chassis_trade_in_value >= 0 else chassis_price


func get_seat_ui_data() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []

	for seat_index in range(1, seat_count + 1):
		var mount := get_mount_for_seat(seat_index)
		var row := {
			"seat_index": seat_index,
			"seat_name": "Siège %d" % seat_index,
			"occupant_peer_id": get_seat_occupant(seat_index),
			"turret_slot_size": 0,
			"has_turret": false,
			"turret_name": "",
			"turret_price": 0,
			"can_sell": false,
			"is_driver_slot": false,
			"empty_reason": "Aucun emplacement de tourelle"
		}

		if mount != null:
			row["seat_name"] = mount.seat_label
			row["turret_slot_size"] = mount.turret_size
			row["is_driver_slot"] = mount.driver_turret
			row["has_turret"] = mount.has_turret()
			row["turret_name"] = mount.get_turret_label()
			row["turret_price"] = mount.get_turret_price()
			row["can_sell"] = mount.has_turret() and not mount.driver_turret
			row["empty_reason"] = mount.get_empty_reason()

		rows.append(row)

	return rows


func _can_peer_modify_loadout(peer_id: int) -> bool:
	if bool(get_meta("upgrade_station_locked", false)):
		return int(get_meta("upgrade_station_user_peer_id", -1)) == peer_id

	return _can_peer_open_menu(peer_id)


func can_install_shop_entry_on_seat(shop_index: int, seat_index: int) -> bool:
	var mount := get_mount_for_seat(seat_index)
	if mount == null:
		return false

	if mount.driver_turret:
		return false

	if mount.turret_size <= 0:
		return false

	if mount.has_turret():
		return false

	if shop_index < 0 or shop_index >= available_shop_turrets.size():
		return false

	var entry := available_shop_turrets[shop_index]
	var turret_size := int(entry.get("turret_size", 0))
	var turret_price := int(entry.get("turret_price", 0))

	#if turret_size != mount.turret_size:
		#return false
	
	if turret_size > mount.turret_size:
		return false
	
	return shop_money >= turret_price


func apply_host_input(steer: float, drive: float) -> void:
	if not multiplayer.is_server():
		return

	if multiplayer.get_unique_id() != get_driver_peer_id():
		return

	steer_input = clampf(steer, -1.0, 1.0)
	drive_input = clampf(drive, -1.0, 1.0)


@rpc("any_peer", "call_remote", "reliable")
func request_enter() -> void:
	if not multiplayer.is_server():
		return

	if is_dead:
		return
	
	print("[VEHICLE] request_enter | sender= x", " | locked=", get_meta("upgrade_station_locked", false), " | seats=", seat_occupants)
	var sender := multiplayer.get_remote_sender_id()
	_server_try_enter(sender)


@rpc("any_peer", "call_remote", "reliable")
func request_exit() -> void:
	if not multiplayer.is_server():
		return

	var sender := multiplayer.get_remote_sender_id()
	if get_seat_index_for_peer(sender) == -1:
		return

	_server_do_exit(sender)


@rpc("any_peer", "call_remote", "reliable")
func request_switch_seat() -> void:
	if not multiplayer.is_server():
		return

	var sender := multiplayer.get_remote_sender_id()
	_server_switch_to_next_available_seat(sender)


@rpc("any_peer", "call_remote", "unreliable")
func send_input(steer: float, drive: float) -> void:
	if not multiplayer.is_server():
		return

	var sender := multiplayer.get_remote_sender_id()
	if sender != get_driver_peer_id():
		return

	steer_input = clampf(steer, -1.0, 1.0)
	drive_input = clampf(drive, -1.0, 1.0)


@rpc("any_peer", "call_remote", "reliable")
func request_open_loadout_menu() -> void:
	if not multiplayer.is_server():
		return

	var sender := multiplayer.get_remote_sender_id()
	_server_open_loadout_menu(sender)


@rpc("any_peer", "call_remote", "reliable")
func request_install_turret(shop_index: int, seat_index: int) -> void:
	if not multiplayer.is_server():
		return

	var sender := multiplayer.get_remote_sender_id()
	_server_install_turret(sender, shop_index, seat_index)


@rpc("any_peer", "call_remote", "reliable")
func request_sell_turret(seat_index: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	_server_sell_turret(sender, seat_index)


func server_try_enter_from_host() -> void:
	if multiplayer.is_server():
		_server_try_enter(multiplayer.get_unique_id())


func server_exit_from_host() -> void:
	if multiplayer.is_server():
		_server_do_exit(multiplayer.get_unique_id())


func server_switch_seat_from_host() -> void:
	if multiplayer.is_server():
		_server_switch_to_next_available_seat(multiplayer.get_unique_id())


func server_open_loadout_for_host() -> void:
	if multiplayer.is_server():
		_server_open_loadout_menu(multiplayer.get_unique_id())


func _server_try_enter(peer_id: int) -> void:
	if is_dead:
		return

	if bool(get_meta("upgrade_station_locked", false)):
		return

	if get_seat_index_for_peer(peer_id) != -1:
		return

	var seat_index := _get_first_available_seat_index()
	if seat_index == -1:
		return

	seat_occupants[seat_index - 1] = peer_id
	_broadcast_seat_layout()
	sync_enter.rpc(peer_id, seat_index)


func _server_do_exit(peer_id: int) -> void:
	var current_seat_index := get_seat_index_for_peer(peer_id)
	if current_seat_index == -1:
		return

	seat_occupants[current_seat_index - 1] = -1

	if current_seat_index == 1:
		steer_input = 0.0
		drive_input = 0.0

	_register_player_exit_impact_safety()

	_broadcast_seat_layout()
	sync_exit.rpc(peer_id, exit_point.global_position)


func _server_switch_to_next_available_seat(peer_id: int) -> void:
	var current_seat_index := get_seat_index_for_peer(peer_id)
	if current_seat_index == -1:
		return

	var next_seat_index := _get_next_available_seat_index(current_seat_index)
	if next_seat_index == -1 or next_seat_index == current_seat_index:
		return

	seat_occupants[current_seat_index - 1] = -1
	seat_occupants[next_seat_index - 1] = peer_id

	if current_seat_index == 1:
		steer_input = 0.0
		drive_input = 0.0

	_broadcast_seat_layout()
	sync_switch_seat.rpc(peer_id, next_seat_index)


func _server_open_loadout_menu(peer_id: int) -> void:
	_force_all_players_out()
	_broadcast_seat_layout()
	_open_loadout_menu_for_peer(peer_id)


func _server_install_turret(peer_id: int, shop_index: int, seat_index: int) -> void:
	if not _can_peer_modify_loadout(peer_id):
		return

	var mount := get_mount_for_seat(seat_index)
	if mount == null:
		return

	if not can_install_shop_entry_on_seat(shop_index, seat_index):
		return

	var entry := available_shop_turrets[shop_index]
	var turret_scene: PackedScene = entry.get("turret_scene", null)
	var price := int(entry.get("turret_price", 0))

	if turret_scene == null:
		return

	if shop_money < price:
		return

	shop_money -= price
	mount.install_turret(turret_scene)
	_broadcast_loadout_state()


func _server_sell_turret(peer_id: int, seat_index: int) -> void:
	if not _can_peer_modify_loadout(peer_id):
		return

	var mount := get_mount_for_seat(seat_index)
	if seat_index < 1 or seat_index > seat_count:
		return
	if mount == null:
		return
	if not mount.has_turret():
		return
	if mount.driver_turret:
		return
	if not bool(get_meta("upgrade_station_locked", false)):
		return

	var refund := mount.get_turret_price()
	shop_money += refund
	mount.remove_turret()
	_broadcast_loadout_state()


func _can_peer_open_menu(peer_id: int) -> bool:
	var player := get_player_node_by_peer_id(peer_id)
	if player == null:
		return false

	var distance := global_position.distance_to(player.global_position)
	return distance <= 8.0


func _force_all_players_out() -> void:
	var safe_exit_position := global_position
	if exit_point != null:
		safe_exit_position = exit_point.global_position

	for i in range(seat_count):
		var peer_id := seat_occupants[i]
		if peer_id != -1:
			seat_occupants[i] = -1
			sync_exit.rpc(peer_id, safe_exit_position)

	steer_input = 0.0
	drive_input = 0.0


func _open_loadout_menu_for_peer(peer_id: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		_open_loadout_menu_local()
	else:
		_open_loadout_menu_remote.rpc_id(peer_id)


func _get_first_available_seat_index() -> int:
	for i in range(seat_count):
		if seat_occupants[i] == -1:
			return i + 1
	return -1


func _get_next_available_seat_index(current_seat_index: int) -> int:
	for offset in range(1, seat_count + 1):
		var candidate := ((current_seat_index - 1 + offset) % seat_count) + 1
		if seat_occupants[candidate - 1] == -1:
			return candidate
	return current_seat_index


func _broadcast_seat_layout() -> void:
	_sync_seat_layout.rpc(seat_occupants)


func _broadcast_loadout_state() -> void:
	var config: Array[Dictionary] = []

	for mount in turret_mounts:
		config.append({
			"seat_index": mount.seat_index,
			"turret_scene_path": mount.get_turret_scene_path(),
		})

	_sync_loadout_state.rpc(shop_money, config)


func _open_loadout_menu_local() -> void:
	var local_player := get_local_player()
	if local_player == null:
		return

	var interactor := _find_interactor(local_player)
	if interactor != null and interactor.has_method("open_vehicle_loadout_menu"):
		interactor.open_vehicle_loadout_menu(self)


func _find_interactor(node: Node) -> Node:
	if node == null:
		return null

	if node is VehicleInteractor:
		return node

	if node.has_node("VehicleInteractor"):
		return node.get_node("VehicleInteractor")

	for child in node.get_children():
		if child is VehicleInteractor:
			return child

	return null


@rpc("call_local", "reliable")
func _sync_seat_layout(new_layout: Array) -> void:
	seat_occupants = new_layout.duplicate()
	seat_count = seat_occupants.size()

	for mount in turret_mounts:
		mount.on_vehicle_seat_layout_changed()

	emit_signal("seat_layout_changed")


@rpc("call_local", "reliable")
func _sync_loadout_state(new_money: int, mount_config: Array) -> void:
	shop_money = new_money

	for info in mount_config:
		var seat_index := int(info.get("seat_index", -1))
		var mount := get_mount_for_seat(seat_index)
		if mount == null:
			continue

		var scene_path := String(info.get("turret_scene_path", ""))
		if scene_path.is_empty():
			mount.remove_turret()
			continue

		var scene := load(scene_path) as PackedScene
		mount.install_turret(scene)

	for mount in turret_mounts:
		mount.on_vehicle_seat_layout_changed()

	emit_signal("loadout_state_changed")


@rpc("call_local", "reliable")
func sync_enter(peer_id: int, seat_index: int) -> void:
	if seat_index < 1 or seat_index > seat_occupants.size():
		return
	seat_occupants[seat_index - 1] = peer_id
	var interactor := _get_interactor_for_peer(peer_id)
	if interactor != null:
		interactor.enter_vehicle(self, seat_index)

	emit_signal("seat_layout_changed")


@rpc("call_local", "reliable")
func sync_switch_seat(peer_id: int, seat_index: int) -> void:
	for i in range(seat_occupants.size()):
		if seat_occupants[i] == peer_id:
			seat_occupants[i] = -1

	if seat_index >= 1 and seat_index <= seat_occupants.size():
		seat_occupants[seat_index - 1] = peer_id

	var interactor := _get_interactor_for_peer(peer_id)
	if interactor != null:
		interactor.switch_to_seat(seat_index)

	emit_signal("seat_layout_changed")


@rpc("call_local", "reliable")
func sync_exit(peer_id: int, exit_pos: Vector3) -> void:
	for i in range(seat_occupants.size()):
		if seat_occupants[i] == peer_id:
			seat_occupants[i] = -1

	var interactor := _get_interactor_for_peer(peer_id)
	if interactor != null:
		interactor.exit_vehicle(exit_pos)

	emit_signal("seat_layout_changed")

@rpc("call_local", "reliable")
func _sync_vehicle_health(new_health: int) -> void:
	health = clampi(new_health, 0, max_health)
	if health > 0 and is_dead:
		_apply_vehicle_revived_state(health)


func _apply_vehicle_revived_state(new_health: int) -> void:
	is_dead = false
	health = clampi(max(new_health, 1), 1, max_health)
	steer_input = 0.0
	drive_input = 0.0
	engine_force = 0.0
	brake = idle_brake_force
	freeze = false
	sleeping = false
	client_has_target_transform = false

	set_use_area_enabled(not bool(get_meta("upgrade_station_locked", false)))
	emit_signal("seat_layout_changed")


@rpc("call_local", "reliable")
func _sync_vehicle_revived(new_health: int) -> void:
	_apply_vehicle_revived_state(new_health)


@rpc("call_local", "reliable")
func _sync_vehicle_destroyed() -> void:
	is_dead = true
	health = 0
	steer_input = 0.0
	drive_input = 0.0
	engine_force = 0.0
	brake = brake_force

	if use_area != null:
		use_area.set_deferred("monitoring", false)
		use_area.set_deferred("monitorable", false)

	if multiplayer.is_server():
		freeze = true
		sleeping = true

	emit_signal("seat_layout_changed")


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _sync_vehicle_state(
	new_transform: Transform3D,
	new_linear_velocity: Vector3,
	new_angular_velocity: Vector3,
	new_steering: float,
	new_engine_force: float,
	new_brake: float
) -> void:
	if multiplayer.is_server():
		return

	state_buffer.append({
		"time": Time.get_ticks_msec() * 0.001,
		"transform": new_transform,
		"linear_velocity": new_linear_velocity,
		"angular_velocity": new_angular_velocity,
		"steering": new_steering,
		"engine_force": new_engine_force,
		"brake": new_brake
	})

	while state_buffer.size() > max_state_buffer_size:
		state_buffer.pop_front()


@rpc("authority", "call_remote", "reliable")
func _open_loadout_menu_remote() -> void:
	if multiplayer.is_server():
		return
	_open_loadout_menu_local()


#func _exit_tree() -> void:
	#VehicleState.unregister_vehicle(self)

func _get_interactor_for_peer(peer_id: int) -> VehicleInteractor:
	var player := get_player_node_by_peer_id(peer_id)
	if player == null:
		return null

	if player.has_node("VehicleInteractor"):
		return player.get_node("VehicleInteractor") as VehicleInteractor

	for child in player.get_children():
		if child is VehicleInteractor:
			return child as VehicleInteractor

	return null


func _on_use_area_body_entered(body: Node) -> void:
	#print("[VEHICLE] body entered use area -> ", body, " | name=", body.name, " | class=", body.get_class())

	var interactor := _find_interactor(body)
	#print("[VEHICLE] interactor found = ", interactor)

	if interactor != null and interactor.has_method("set_near_vehicle"):
		interactor.set_near_vehicle(self)
		#print("[VEHICLE] near vehicle set")


func _on_use_area_body_exited(body: Node) -> void:
	var interactor := _find_interactor(body)
	if interactor != null and interactor.has_method("clear_near_vehicle"):
		interactor.clear_near_vehicle(self)
