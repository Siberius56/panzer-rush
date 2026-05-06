extends CharacterBody3D

signal health_changed(current: int, maximum: int)
signal died

const DEFAULT_VISUAL_BULLET_SCENE := preload("res://scenes/weapons/VisualBullet.tscn")
const WORLD_WEAPON_SCENE := preload("uid://dha7qfqc5vywa") #preload("res://weapons/WorldWeapon3D.tscn")
const PISTOL_SCENE := preload("uid://dd33dmmqhjkul") #preload("res://weapons/PistolWeapon.tscn")
const SMG_SCENE := preload("uid://nykf7fy7m5jg") #preload("res://weapons/SMGWeapon.tscn")
const RIFLE_SCENE := preload("uid://dluj1jv7g4ocm") #preload("res://weapons/RifleWeapon.tscn")

static var NEXT_WORLD_WEAPON_NET_ID: int = 1

@export_group("Movement")
@export var move_speed: float = 8.0
@export var acceleration: float = 30.0
@export var gravity_strength: float = 24.0
@export var jump_velocity: float = 8.5
@export var state_send_interval: float = 0.05

@export_group("Health")
@export var max_health: int = 100
@export var armor_rating: int = 0

@export_group("Death Body")
@export var death_body_enabled: bool = true
@export var death_body_mass: float = 3.0
@export var death_body_impulse_force: float = 5.5
@export var death_body_upward_impulse: float = 1.5
@export var death_body_knockdown_angular_impulse: float = 5.0
@export var death_body_random_impulse: float = 0.65
@export_range(0.0, 20.0, 0.1) var death_body_linear_damp: float = 1.0
@export_range(0.0, 20.0, 0.1) var death_body_angular_damp: float = 5.0
@export var death_body_lock_yaw_rotation: bool = true
@export_flags_3d_physics var death_body_collision_layer: int = 0
@export_flags_3d_physics var death_body_collision_mask: int = 1

@export_group("Weapons")
@export var projectile_team: int = 1
@export var pickup_radius: float = 2.4
@export var world_drop_forward_offset: float = 1.0
@export var world_drop_up_offset: float = 1.25

@export_group("Aiming")
@export var aim_projection_distance: float = 45.0
@export_flags_3d_physics var aim_collision_mask: int = 0xFFFFFFFF
@export var aim_min_target_distance: float = 0.05
@export var visual_aim_min_target_distance: float = 0.05

@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D
@onready var aim_root: Node3D = $AimRoot
@onready var hand_socket: Node3D = $AimRoot/HandSocket
@onready var name_label: Label3D = $NameLabel3D
@onready var visual_root: Node3D = %VisualRoot
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var back_socket_1: Node3D = %BackSocket1
@onready var back_socket_2: Node3D = %BackSocket2
@onready var vehicle_interactor = get_node_or_null("VehicleInteractor")

var current_vehicle: Node = null
var weapon_slot_1: Node = null
var weapon_slot_2: Node = null
var equipped_weapon: Node = null
#var ammo_reserve := {
	#"9mm": 120,
	#"shell": 24,
	#"rifle": 90
#}

var player_id: int = 1
var player_name: String = "Player"
var health: int = 0
var is_dead: bool = false
var vehicle_mode: bool = false

var state_timer: float = 0.0
var replicated_position: Vector3 = Vector3.ZERO
var replicated_velocity: Vector3 = Vector3.ZERO
var replicated_aim_rotation: Vector3 = Vector3.ZERO
var replicated_visual_y: float = 0.0

var ui_input_blocked: bool = false

var weapon_slots := [{}, {}]
var current_weapon_slot: int = 0
var weapon_nodes := [null, null]

var local_fire_cooldown: float = 0.0
var server_fire_cooldown: float = 0.0
var is_reloading_local: bool = false
var is_reloading_server: bool = false
var reload_timer_local: float = 0.0
var reload_timer_server: float = 0.0

const PLAYER_HUD_SCENE = preload("uid://q654pbgk6xhk")

var hud: PlayerHUD = null
var death_body_node: RigidBody3D = null


func set_ui_input_blocked(active: bool) -> void:
	ui_input_blocked = active
	if active:
		velocity = Vector3.ZERO

func _ready() -> void:
	if is_multiplayer_authority():
		hud = PLAYER_HUD_SCENE.instantiate()
		get_tree().current_scene.add_child(hud)#.call_deferred(hud)
		#add_sibling(hud)
		hud.set_player(self)
		if hud.has_signal("respawn_requested"):
			hud.respawn_requested.connect(_on_hud_respawn_requested)
	
	ui_input_blocked = false
	add_to_group("player")
	add_to_group("players")
	health = max_health
	replicated_position = global_position
	replicated_velocity = velocity
	replicated_aim_rotation = aim_root.rotation
	replicated_visual_y = visual_root.rotation.y
	update_name_label()
	camera.current = is_multiplayer_authority()
	if is_multiplayer_authority():
		name_label.visible = false
	_refresh_weapon_nodes()
	emit_signal("health_changed", health, max_health)

func _exit_tree() -> void:
	_clear_death_body()
	if hud != null and is_instance_valid(hud):
		hud.queue_free()
	hud = null

func update_name_label() -> void:
	if is_dead:
		name_label.text = "%s (KO)" % player_name
	else:
		name_label.text = player_name

func is_alive() -> bool:
	return not is_dead

func is_in_vehicle() -> bool:
	if vehicle_mode:
		return true
	if vehicle_interactor != null:
		return vehicle_interactor.is_in_vehicle()
	return false

func set_vehicle_mode(active: bool) -> void:
	vehicle_mode = active
	if active:
		velocity = Vector3.ZERO
		if not is_dead:
			visual_root.visible = true

func _sync_to_vehicle_seat() -> void:
	if vehicle_interactor == null:
		return
	if vehicle_interactor.has_method("_sync_body_to_vehicle"):
		vehicle_interactor._sync_body_to_vehicle()

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_weapon_tick(delta)

	if is_multiplayer_authority():
		_local_weapon_tick(delta)

	if ui_input_blocked:
		velocity.x = 0.0
		velocity.z = 0.0
		if is_multiplayer_authority():
			_send_state_if_needed(delta)
		return

	var driving := is_in_vehicle()

	if is_multiplayer_authority():
		if is_dead or driving:
			velocity = Vector3.ZERO
		else:
			_update_movement(delta)
			_update_aim()
			_update_weapon_input()

		if driving:
			_sync_to_vehicle_seat()
		else:
			move_and_slide()

		_send_state_if_needed(delta)
	else:
		_apply_replicated_state(delta)

func _send_state_if_needed(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		state_timer = state_send_interval
		_receive_state.rpc(global_position, velocity, aim_root.rotation, visual_root.rotation.y)

func _update_movement(delta: float) -> void:
	if is_in_vehicle():
		return

	var input_vector := Input.get_vector("move_left", "move_right", "move_backward", "move_forward")

	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var right := camera.global_basis.x
	right.y = 0.0
	right = right.normalized()

	var desired_velocity := (right * input_vector.x + forward * input_vector.y) * move_speed
	velocity.x = move_toward(velocity.x, desired_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, acceleration * delta)

	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		velocity.y -= gravity_strength * delta

func _update_aim() -> void:
	if is_in_vehicle():
		return

	var target_position := _get_cursor_aim_target()
	var aim_distance := aim_root.global_position.distance_to(target_position)

	if aim_distance >= aim_min_target_distance:
		aim_root.look_at(target_position, Vector3.UP)
		aim_root.rotation.z = 0.0

	var visual_target := target_position
	visual_target.y = visual_root.global_position.y

	if visual_root.global_position.distance_to(visual_target) >= visual_aim_min_target_distance:
		visual_root.look_at(visual_target, Vector3.UP)
		visual_root.rotation.x = 0.0
		visual_root.rotation.z = 0.0


func _get_cursor_aim_target() -> Vector3:
	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position).normalized()
	var ray_end := ray_origin + ray_direction * aim_projection_distance

	# On vise maintenant le vrai point 3D sous le curseur.
	# Ancien problème : la hauteur était déduite de la position Y de la souris à l'écran.
	# Résultat : plus le curseur était haut dans l'écran, plus l'arme visait vers le haut,
	# même quand le joueur visait simplement loin sur le sol.
	var direct_space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [get_rid()]
	query.collision_mask = aim_collision_mask
	query.hit_from_inside = false

	var result := direct_space_state.intersect_ray(query)
	if not result.is_empty():
		var hit_position = result.get("position")
		if hit_position is Vector3:
			return hit_position

	# Fallback : si le rayon ne touche aucun collider, on vise le plan horizontal du joueur.
	# Cela évite une hauteur artificielle et garde un tir lisible au sol.
	var ground_plane := Plane(Vector3.UP, global_position.y)
	var ground_hit = ground_plane.intersects_ray(ray_origin, ray_direction)
	if ground_hit != null:
		return ground_hit

	return ray_end


func _get_shot_direction_from_weapon(weapon: WeaponInstance3D) -> Vector3:
	if weapon == null:
		return -aim_root.global_basis.z.normalized()

	var muzzle_transform := weapon.get_muzzle_transform()
	var base_direction := -muzzle_transform.basis.z.normalized()
	return _apply_lateral_shot_dispersion(base_direction, weapon.shot_dispersion_degrees)


func _apply_lateral_shot_dispersion(direction: Vector3, dispersion_degrees: float) -> Vector3:
	var base_direction := direction.normalized()
	if base_direction.length_squared() <= 0.0001:
		return Vector3.FORWARD

	var max_angle := deg_to_rad(max(dispersion_degrees, 0.0))
	if max_angle <= 0.0001:
		return base_direction

	# Dispersion uniquement sur la largeur.
	# On tourne autour de l'axe vertical global pour conserver la hauteur de visée.
	var lateral_angle := randf_range(-max_angle, max_angle)
	return base_direction.rotated(Vector3.UP, lateral_angle).normalized()

func _local_weapon_tick(delta: float) -> void:
	if local_fire_cooldown > 0.0:
		local_fire_cooldown = max(local_fire_cooldown - delta, 0.0)

	if is_reloading_local:
		reload_timer_local -= delta
		if reload_timer_local <= 0.0:
			_finish_local_reload()

func _server_weapon_tick(delta: float) -> void:
	if server_fire_cooldown > 0.0:
		server_fire_cooldown = max(server_fire_cooldown - delta, 0.0)

	if is_reloading_server:
		reload_timer_server -= delta
		if reload_timer_server <= 0.0:
			_finish_server_reload()


@export_group("Money")
@export var carried_money: int = 0


@export_group("Ammo")
var ammo_reserve := {
	"9mm": 120,
	"shell": 24,
	"rifle": 90
}

var ammo_reserve_max := {
	"9mm": 120,
	"shell": 24,
	"rifle": 90
}


func add_ammo(ammo_type: String, amount: int) -> bool:
	if amount <= 0:
		return false

	var key := ammo_type.to_lower()
	if not ammo_reserve.has(key):
		return false

	var old_value := int(ammo_reserve.get(key, 0))
	var max_value := int(ammo_reserve_max.get(key, old_value))
	ammo_reserve[key] = clampi(old_value + amount, 0, max_value)

	return int(ammo_reserve[key]) > old_value


func consume_ammo(ammo_type: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false

	var key := ammo_type.to_lower()
	var current := int(ammo_reserve.get(key, 0))
	if current < amount:
		return false

	ammo_reserve[key] = current - amount
	return true


func get_ammo(ammo_type: String) -> int:
	return int(ammo_reserve.get(ammo_type.to_lower(), 0))


func get_ammo_max(ammo_type: String) -> int:
	return int(ammo_reserve_max.get(ammo_type.to_lower(), 0))

func pickup_loot(kind: String, amount: int, _pickup: Node = null) -> bool:
	match kind:
		"money":
			return add_carried_money(amount)

		"pistol":
			return add_ammo("9mm", amount)

		"smg":
			return add_ammo("9mm", amount)

		"rifle":
			return add_ammo("rifle", amount)

		"shell":
			return add_ammo("shell", amount)

	return false


func add_carried_money(amount: int) -> bool:
	if amount <= 0:
		return false
	if not multiplayer.is_server():
		return false

	carried_money += amount
	_sync_carried_money.rpc(carried_money)
	return true


func get_carried_money() -> int:
	return carried_money


func deposit_carried_money_to_vehicle(vehicle: Node) -> bool:
	if not multiplayer.is_server():
		return false
	if vehicle == null:
		return false
	if carried_money <= 0:
		return false

	var current_money = vehicle.get("shop_money")
	if current_money == null:
		return false

	vehicle.set("shop_money", int(current_money) + carried_money)
	carried_money = 0
	_sync_carried_money.rpc(carried_money)

	if vehicle.has_method("_broadcast_loadout_state"):
		vehicle._broadcast_loadout_state()

	return true


func on_entered_vehicle(vehicle: Node) -> void:
	if not multiplayer.is_server():
		return
	deposit_carried_money_to_vehicle(vehicle)

func _update_weapon_input() -> void:
	if is_in_vehicle() or is_dead:
		return

	if Input.is_action_just_pressed("weapon_slot_1"):
		_select_weapon_slot_local(0)
		_request_select_weapon_slot(0)

	if Input.is_action_just_pressed("weapon_slot_2"):
		_select_weapon_slot_local(1)
		_request_select_weapon_slot(1)

	if Input.is_action_just_pressed("reload_weapon"):
		_request_reload_current_weapon()

	if Input.is_action_just_pressed("drop_weapon"):
		_request_drop_current_weapon()

	if Input.is_action_just_pressed("interact"):
		_request_pickup_nearest_weapon()

	var weapon := _get_current_weapon_node()
	if weapon == null:
		return

	var wants_fire := false
	if weapon.automatic_fire:
		wants_fire = Input.is_action_pressed("fire")
	else:
		wants_fire = Input.is_action_just_pressed("fire")

	if wants_fire:
		_try_fire_local()


func _get_reserve_for_weapon(weapon: WeaponInstance3D) -> int:
	if weapon == null:
		return 0

	var ammo_type := _get_ammo_type_for_weapon(weapon)
	if ammo_type.is_empty():
		return 0

	return int(ammo_reserve.get(ammo_type, 0))


func _get_ammo_type_for_weapon(weapon: WeaponInstance3D) -> String:
	if weapon == null:
		return ""

	var weapon_id := ""

	if "weapon_id" in weapon:
		weapon_id = str(weapon.weapon_id).to_lower()
	else:
		return ""

	match weapon_id:
		"pistol":
			return "9mm"
		"smg":
			return "9mm"
		"rifle":
			return "rifle"
		"shotgun":
			return "shell"
		_:
			return ""

func _can_reload_weapon_from_player_reserve(weapon: WeaponInstance3D) -> bool:
	if weapon == null:
		return false

	if weapon.ammo_in_magazine >= weapon.magazine_size:
		return false

	return _get_reserve_for_weapon(weapon) > 0


func _get_weapon_reload_amount(weapon: WeaponInstance3D) -> int:
	if weapon == null:
		return 0

	var reserve := _get_reserve_for_weapon(weapon)
	var missing :int = weapon.magazine_size - weapon.ammo_in_magazine

	if missing <= 0 or reserve <= 0:
		return 0

	return min(missing, reserve)


func _try_fire_local() -> void:
	if ui_input_blocked or is_in_vehicle() or is_dead:
		return

	if is_reloading_local or local_fire_cooldown > 0.0:
		return

	var slot_state := _get_current_weapon_state()
	if slot_state.is_empty():
		return

	var weapon := _get_current_weapon_node()
	if weapon == null:
		return

	var current_ammo := int(slot_state.get("ammo_in_magazine", 0))

	if current_ammo <= 0:
		if _get_reserve_for_weapon(weapon) > 0:
			_request_reload_current_weapon()
		return

	var predicted_ammo := current_ammo - 1

	# Important :
	# Si on est client, on fait une prédiction locale.
	# Si on est serveur / hôte, on ne touche pas aux munitions ici.
	# Le serveur va les consommer dans _server_fire_weapon().
	if not multiplayer.is_server():
		slot_state["ammo_in_magazine"] = predicted_ammo
		weapon.apply_runtime_state(slot_state)

	local_fire_cooldown = weapon.fire_cooldown

	var muzzle_transform := weapon.get_muzzle_transform()
	var shot_origin := muzzle_transform.origin
	var shot_direction := _get_shot_direction_from_weapon(weapon)

	# Prédiction visuelle uniquement côté client.
	# Le serveur spawn la vraie balle dans _server_fire_weapon().
	if not multiplayer.is_server():
		_spawn_visual_bullet_from_weapon(weapon, shot_origin, shot_direction)

	if multiplayer.is_server():
		_server_fire_weapon(current_weapon_slot, shot_origin, shot_direction)
	else:
		_request_fire_weapon.rpc_id(1, current_weapon_slot, shot_origin, shot_direction)
	
	# Seulement côté client.
	# Le serveur gère lui-même le reload réel.
	if not multiplayer.is_server():
		if predicted_ammo <= 0 and _get_reserve_for_weapon(weapon) > 0:
			_request_reload_current_weapon()

func _spawn_visual_bullet_from_weapon(weapon: WeaponInstance3D, start_pos: Vector3, direction: Vector3) -> void:
	spawn_projectile(
		weapon.projectile_scene,
		start_pos,
		direction,
		projectile_team,
		weapon.projectile_damage,
		weapon.projectile_penetration,
		weapon.projectile_tk,
		self,
		weapon.projectile_impact_scene
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
		scene = DEFAULT_VISUAL_BULLET_SCENE

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

func _request_select_weapon_slot(slot_index: int) -> void:
	if multiplayer.is_server():
		_server_select_weapon_slot(slot_index)
	else:
		_request_select_weapon_slot_rpc.rpc_id(1, slot_index)

func _select_weapon_slot_local(slot_index: int) -> void:
	current_weapon_slot = clamp(slot_index, 0, 1)
	_cancel_local_reload()
	_refresh_weapon_nodes()

func _request_reload_current_weapon() -> void:
	if is_dead:
		return
	var weapon := _get_current_weapon_node()
	if weapon == null:
		return
	if is_reloading_local:
		return
	#if not weapon.can_reload():
		#return
	if not _can_reload_weapon_from_player_reserve(weapon):
		return
	
	_start_local_reload(weapon.reload_duration)

	if multiplayer.is_server():
		_server_start_reload_current_weapon()
	else:
		_request_reload_current_weapon_rpc.rpc_id(1)

func _request_drop_current_weapon() -> void:
	if is_dead:
		return
	if _get_current_weapon_state().is_empty():
		return

	if multiplayer.is_server():
		_server_drop_current_weapon()
		return

	_cancel_local_reload()
	weapon_slots[current_weapon_slot] = {}
	_refresh_weapon_nodes()
	_request_drop_current_weapon_rpc.rpc_id(1)

#func _request_pickup_nearest_weapon() -> void:
	#var world_weapon := _find_nearest_world_weapon()
	#if world_weapon == null:
		#return
#
	#if multiplayer.is_server():
		#_server_pickup_weapon(world_weapon.net_id)
	#else:
		#_request_pickup_weapon_rpc.rpc_id(1, world_weapon.net_id)

func _request_pickup_nearest_weapon() -> void:
	if is_dead:
		return
	if multiplayer.is_server():
		_server_pickup_nearest_weapon()
	else:
		_request_pickup_nearest_weapon_rpc.rpc_id(1)

#func _server_pickup_nearest_weapon() -> void:
	#if not multiplayer.is_server():
		#return
#
	#var world_weapon := _find_nearest_world_weapon()
	#if world_weapon == null:
		#return
#
	#_server_pickup_weapon(world_weapon.net_id)

func _server_pickup_nearest_weapon() -> void:
	if is_dead:
		return
	if not multiplayer.is_server():
		return

	var world_weapon := _find_nearest_world_weapon()
	if world_weapon == null:
		return

	_server_pickup_world_weapon(world_weapon)

func _find_nearest_world_weapon() -> WorldWeapon3D:
	var closest: WorldWeapon3D = null
	var closest_distance := INF

	for node in get_tree().get_nodes_in_group("world_weapon"):
		if not (node is WorldWeapon3D):
			continue
		if not is_instance_valid(node):
			continue

		var world_weapon := node as WorldWeapon3D
		var distance := global_position.distance_to(world_weapon.global_position)
		if distance > pickup_radius:
			continue
		if distance < closest_distance:
			closest_distance = distance
			closest = world_weapon

	return closest

func _server_pickup_world_weapon(world_weapon: WorldWeapon3D) -> void:
	if not multiplayer.is_server():
		return

	if world_weapon == null:
		_sync_weapon_inventory_to_peers()
		return

	if not is_instance_valid(world_weapon):
		_sync_weapon_inventory_to_peers()
		return

	if global_position.distance_to(world_weapon.global_position) > pickup_radius + 0.6:
		return

	var picked_state := world_weapon.get_weapon_state()
	if picked_state.is_empty():
		return

	var slot_to_use := current_weapon_slot

	if weapon_slots[current_weapon_slot].is_empty():
		slot_to_use = current_weapon_slot
	else:
		var empty_slot := _get_first_empty_weapon_slot()

		if empty_slot != -1:
			slot_to_use = empty_slot
		else:
			slot_to_use = current_weapon_slot
			_server_drop_slot_weapon(slot_to_use)

	_server_despawn_world_weapon(world_weapon)

	picked_state["reserve_ammo"] = 0
	weapon_slots[slot_to_use] = picked_state.duplicate(true)
	current_weapon_slot = slot_to_use

	_cancel_server_reload()
	_sync_weapon_inventory_to_peers()


func _server_pickup_weapon(weapon_net_id: int) -> void:
	if not multiplayer.is_server():
		return

	var world_weapon := _find_world_weapon_by_net_id(weapon_net_id)
	if world_weapon == null:
		_sync_weapon_inventory_to_peers()
		return

	_server_pickup_world_weapon(world_weapon)

func _get_first_empty_weapon_slot() -> int:
	for slot_index in range(weapon_slots.size()):
		if weapon_slots[slot_index].is_empty():
			return slot_index

	return -1

func _server_drop_current_weapon() -> void:
	if not multiplayer.is_server():
		return
	_server_drop_slot_weapon(current_weapon_slot)
	_sync_weapon_inventory_to_peers()

func _server_drop_slot_weapon(slot_index: int) -> void:
	var slot_state: Dictionary = weapon_slots[slot_index]
	if slot_state.is_empty():
		return

	var forward := -aim_root.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()

	if forward.length_squared() <= 0.0001:
		forward = -global_basis.z
		forward.y = 0.0
		forward = forward.normalized()

	var drop_position := global_position + Vector3.UP * world_drop_up_offset + forward * world_drop_forward_offset

	_server_spawn_world_weapon(slot_state, drop_position, forward)
	weapon_slots[slot_index] = {}
	_cancel_server_reload()

func _server_spawn_world_weapon(state: Dictionary, spawn_position: Vector3, forward: Vector3) -> void:
	var net_id := NEXT_WORLD_WEAPON_NET_ID
	NEXT_WORLD_WEAPON_NET_ID += 1

	#_spawn_world_weapon_local(net_id, String(state.get("weapon_id", "")), int(state.get("ammo_in_magazine", 0)), int(state.get("reserve_ammo", 0)), spawn_position, forward)
	#_spawn_world_weapon_remote.rpc(net_id, String(state.get("weapon_id", "")), int(state.get("ammo_in_magazine", 0)), int(state.get("reserve_ammo", 0)), spawn_position, forward)
	_spawn_world_weapon_local(net_id, String(state.get("weapon_id", "")), int(state.get("ammo_in_magazine", 0)), 0, spawn_position, forward)
	_spawn_world_weapon_remote.rpc(net_id, String(state.get("weapon_id", "")), int(state.get("ammo_in_magazine", 0)), 0, spawn_position, forward)

func _spawn_world_weapon_local(net_id: int, weapon_id: String, ammo_in_magazine: int, reserve_ammo: int, spawn_position: Vector3, forward: Vector3) -> void:
	var world_weapon := WORLD_WEAPON_SCENE.instantiate() as WorldWeapon3D
	world_weapon.name = "WorldWeapon_%d" % net_id
	world_weapon.net_id = net_id
	get_tree().current_scene.add_child(world_weapon)
	world_weapon.global_position = spawn_position
	world_weapon.replicated_transform = world_weapon.global_transform
	world_weapon.setup_from_state(weapon_id, ammo_in_magazine, reserve_ammo)
	world_weapon.apply_spawn_impulse(forward)

func _server_despawn_world_weapon(world_weapon: WorldWeapon3D) -> void:
	if world_weapon == null:
		return

	if not is_instance_valid(world_weapon):
		return

	var net_id := world_weapon.net_id
	var node_path := world_weapon.get_path()

	_despawn_world_weapon_remote.rpc(net_id, node_path)
	world_weapon.queue_free()

func _find_world_weapon_by_net_id(weapon_net_id: int) -> WorldWeapon3D:
	for node in get_tree().get_nodes_in_group("world_weapon"):
		if node is WorldWeapon3D and node.net_id == weapon_net_id:
			return node as WorldWeapon3D
	return null

func _server_select_weapon_slot(slot_index: int) -> void:
	if is_dead:
		return
	current_weapon_slot = clamp(slot_index, 0, 1)
	_cancel_server_reload()
	_sync_weapon_inventory_to_peers()

func _server_start_reload_current_weapon() -> void:
	if is_dead:
		return
	var slot_state := _get_current_weapon_state()
	if slot_state.is_empty():
		return

	var weapon_scene := _get_weapon_scene_by_id(String(slot_state.get("weapon_id", "")))
	if weapon_scene == null:
		return

	var weapon := weapon_scene.instantiate() as WeaponInstance3D
	if weapon == null:
		return

	#weapon.apply_runtime_state(slot_state)
	#if not weapon.can_reload():
		#weapon.free()
		#return
	
	weapon.apply_runtime_state(slot_state)
	
	if weapon.ammo_in_magazine >= weapon.magazine_size:
		weapon.free()
		return

	if _get_reserve_for_weapon(weapon) <= 0:
		weapon.free()
		return
	
	_cancel_server_reload()
	is_reloading_server = true
	reload_timer_server = weapon.reload_duration
	weapon.free()
	_sync_weapon_inventory_to_peers()

func _finish_server_reload() -> void:
	is_reloading_server = false
	reload_timer_server = 0.0

	var slot_state := _get_current_weapon_state()
	if slot_state.is_empty():
		_sync_weapon_inventory_to_peers()
		return

	var weapon_scene := _get_weapon_scene_by_id(String(slot_state.get("weapon_id", "")))
	if weapon_scene == null:
		_sync_weapon_inventory_to_peers()
		return

	var weapon := weapon_scene.instantiate() as WeaponInstance3D
	if weapon == null:
		_sync_weapon_inventory_to_peers()
		return
	
	weapon.apply_runtime_state(slot_state)

	var to_load := _get_weapon_reload_amount(weapon)
	if to_load <= 0:
		weapon.free()
		_sync_weapon_inventory_to_peers()
		return

	weapon.ammo_in_magazine += to_load
	var ammo_type := _get_ammo_type_for_weapon(weapon)
	if not ammo_type.is_empty():
		ammo_reserve[ammo_type] = _get_reserve_for_weapon(weapon) - to_load
	
	if "reserve_ammo" in weapon:
		weapon.reserve_ammo = 0

	weapon_slots[current_weapon_slot] = weapon.to_runtime_state()
	weapon_slots[current_weapon_slot]["reserve_ammo"] = 0
	weapon.free()
	_sync_weapon_inventory_to_peers()

func _server_fire_weapon(slot_index: int, shot_origin: Vector3, shot_direction: Vector3) -> void:
	if is_dead:
		return
	if not multiplayer.is_server():
		return

	if slot_index != current_weapon_slot:
		return

	if is_reloading_server or server_fire_cooldown > 0.0:
		return

	var slot_state: Dictionary = weapon_slots[slot_index]
	if slot_state.is_empty():
		return

	var weapon_scene := _get_weapon_scene_by_id(String(slot_state.get("weapon_id", "")))
	if weapon_scene == null:
		return

	var weapon := weapon_scene.instantiate() as WeaponInstance3D
	if weapon == null:
		return

	weapon.apply_runtime_state(slot_state)

	if not weapon.consume_round():
		var can_reload_now := _can_reload_weapon_from_player_reserve(weapon)
		weapon.free()

		if can_reload_now:
			_server_start_reload_current_weapon()

		return

	weapon.reserve_ammo = 0
	weapon_slots[slot_index] = weapon.to_runtime_state()

	server_fire_cooldown = weapon.fire_cooldown

	# Balle serveur.
	# C'est elle qui applique les dégâts réels.
	_spawn_visual_bullet_from_weapon(weapon, shot_origin, shot_direction)

	# Effet visuel pour les autres clients.
	_spawn_bullet_fx.rpc(shot_origin, shot_direction, slot_index)

	# Désactivé.
	# Ancien système hitscan instantané.
	# _process_server_shot(shot_origin, shot_direction, weapon)

	# Important :
	# On reload uniquement si le chargeur est vide.
	var needs_reload := weapon.ammo_in_magazine <= 0 and _can_reload_weapon_from_player_reserve(weapon)

	weapon.free()

	if needs_reload:
		_server_start_reload_current_weapon()
	else:
		_sync_weapon_inventory_to_peers()

func _process_server_shot(shot_origin: Vector3, shot_direction: Vector3, weapon: WeaponInstance3D) -> void:
	var direct_space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(shot_origin, shot_origin + shot_direction * weapon.hitscan_range)
	query.collision_mask = 2
	query.hit_from_inside = false

	var result := direct_space_state.intersect_ray(query)
	if result.is_empty():
		return

	var collider = result.get("collider")
	if collider != null and collider.has_method("apply_projectile_damage"):
		#print("BAM 1  ?!")
		collider.apply_projectile_damage(
			weapon.projectile_damage,
			weapon.projectile_penetration,
			projectile_team,
			weapon.projectile_tk,
			self
		)
	elif collider != null and collider.has_method("apply_damage"):
		#print("BAM 2  ?!")
		collider.apply_damage(weapon.projectile_damage)

func _get_weapon_scene_by_id(weapon_id: String) -> PackedScene:
	match weapon_id:
		"pistol":
			return PISTOL_SCENE
		"smg":
			return SMG_SCENE
		"rifle":
			return RIFLE_SCENE
		_:
			return null

func _get_current_weapon_state() -> Dictionary:
	return weapon_slots[current_weapon_slot]

func _get_current_weapon_node() -> WeaponInstance3D:
	var node = weapon_nodes[current_weapon_slot]
	if node == null:
		return null
	return node as WeaponInstance3D

func _cancel_local_reload() -> void:
	is_reloading_local = false
	reload_timer_local = 0.0

func _cancel_server_reload() -> void:
	is_reloading_server = false
	reload_timer_server = 0.0

func _start_local_reload(duration: float) -> void:
	_cancel_local_reload()
	is_reloading_local = true
	reload_timer_local = duration

func _finish_local_reload() -> void:
	is_reloading_local = false
	reload_timer_local = 0.0

	var slot_state := _get_current_weapon_state()
	if slot_state.is_empty():
		return

	var weapon := _get_current_weapon_node()
	if weapon == null:
		return

	#weapon.apply_runtime_state(slot_state)
	#weapon.perform_reload()
	#weapon_slots[current_weapon_slot] = weapon.to_runtime_state()
	#_refresh_weapon_nodes()
	
	weapon.apply_runtime_state(slot_state)

	var to_load := _get_weapon_reload_amount(weapon)
	if to_load <= 0:
		_refresh_weapon_nodes()
		return

	weapon.ammo_in_magazine += to_load
	var ammo_type := _get_ammo_type_for_weapon(weapon)
	if not ammo_type.is_empty():
		ammo_reserve[ammo_type] = _get_reserve_for_weapon(weapon) - to_load
	
	if "reserve_ammo" in weapon:
		weapon.reserve_ammo = 0

	weapon_slots[current_weapon_slot] = weapon.to_runtime_state()
	weapon_slots[current_weapon_slot]["reserve_ammo"] = 0
	_refresh_weapon_nodes()

func _sync_weapon_inventory_to_peers() -> void:
	var slot_0 = weapon_slots[0].duplicate(true)
	var slot_1 = weapon_slots[1].duplicate(true)

	# Envoie l'inventaire aux autres peers.
	_receive_weapon_inventory.rpc(slot_0, slot_1, current_weapon_slot, is_reloading_server, reload_timer_server)

	# Important :
	# Le serveur doit aussi appliquer localement l'inventaire du joueur concerné.
	# Sinon le host voit l'état serveur dans les données, mais pas le visuel équipé.
	_apply_received_weapon_inventory(slot_0, slot_1, current_weapon_slot, is_reloading_server, reload_timer_server)

func _apply_received_weapon_inventory(slot_0: Dictionary, slot_1: Dictionary, selected_slot: int, reloading: bool, remaining_reload: float) -> void:
	weapon_slots[0] = slot_0.duplicate(true)
	weapon_slots[1] = slot_1.duplicate(true)
	current_weapon_slot = clamp(selected_slot, 0, 1)
	is_reloading_local = reloading
	reload_timer_local = max(remaining_reload, 0.0)
	_refresh_weapon_nodes()

func _refresh_weapon_nodes() -> void:
	for node in weapon_nodes:
		if node != null and is_instance_valid(node):
			node.queue_free()

	weapon_nodes = [null, null]

	for slot_index in range(2):
		var slot_state: Dictionary = weapon_slots[slot_index]
		if slot_state.is_empty():
			continue

		var scene := _get_weapon_scene_by_id(String(slot_state.get("weapon_id", "")))
		if scene == null:
			continue

		var weapon := scene.instantiate() as WeaponInstance3D
		if weapon == null:
			continue

		weapon.apply_runtime_state(slot_state)
		weapon_nodes[slot_index] = weapon
		_attach_weapon_node(slot_index, weapon)

func _attach_weapon_node(slot_index: int, weapon: WeaponInstance3D) -> void:
	if slot_index == current_weapon_slot:
		hand_socket.add_child(weapon)
		weapon.position = weapon.hand_position
		weapon.rotation_degrees = weapon.hand_rotation_deg
	else:
		var back_socket := back_socket_1 if slot_index == 0 else back_socket_2
		back_socket.add_child(weapon)
		weapon.position = weapon.back_position
		weapon.rotation_degrees = weapon.back_rotation_deg

func _apply_replicated_state(delta: float) -> void:
	global_position = global_position.lerp(replicated_position, min(delta * 12.0, 1.0))
	velocity = velocity.lerp(replicated_velocity, min(delta * 10.0, 1.0))

	var aim_lerp_weight :float = min(delta * 16.0, 1.0)
	aim_root.rotation.x = lerp_angle(aim_root.rotation.x, replicated_aim_rotation.x, aim_lerp_weight)
	aim_root.rotation.y = lerp_angle(aim_root.rotation.y, replicated_aim_rotation.y, aim_lerp_weight)
	aim_root.rotation.z = lerp_angle(aim_root.rotation.z, replicated_aim_rotation.z, aim_lerp_weight)
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, replicated_visual_y, aim_lerp_weight)
	visual_root.rotation.x = 0.0
	visual_root.rotation.z = 0.0

func apply_damage(amount: int, damage_source: Node = null) -> void:
	if not multiplayer.is_server():
		return
	if is_dead:
		return
	if amount <= 0:
		return

	health = max(health - amount, 0)

	if health <= 0:
		_server_die(damage_source)
		return

	_apply_health_state(health, false)
	_receive_health_state.rpc(health, false)

func apply_projectile_damage(
	amount: int,
	to_projectile_penetration: int = 0,
	_source_team: int = 0,
	_allow_tk: bool = false,
	_source: Node = null
) -> void:
	if not multiplayer.is_server():
		return
	if is_dead:
		return

	var effective_armor = max(armor_rating - to_projectile_penetration, 0)
	var final_damage = max(amount - effective_armor, 0)
	if final_damage <= 0:
		return

	apply_damage(final_damage, _source)

func request_respawn() -> void:
	if not is_dead:
		return

	if multiplayer.is_server():
		_server_respawn_player()
	else:
		_request_respawn_rpc.rpc_id(1)

func _on_hud_respawn_requested() -> void:
	request_respawn()

func _server_die(damage_source: Node = null) -> void:
	if not multiplayer.is_server():
		return
	if is_dead:
		return

	var death_transform := global_transform
	var impulse_direction := _get_death_impulse_direction(damage_source)

	health = 0
	_server_drop_all_weapons_for_death(impulse_direction)
	_apply_death_state(health, death_transform, impulse_direction)
	_receive_player_death_state.rpc(health, death_transform, impulse_direction)

func _server_drop_all_weapons_for_death(impulse_direction: Vector3) -> void:
	if not multiplayer.is_server():
		return

	_cancel_server_reload()
	_cancel_local_reload()

	for slot_index in range(2):
		_server_drop_slot_weapon_for_death(slot_index, impulse_direction)

	current_weapon_slot = 0
	_sync_weapon_inventory_to_peers()

func _server_drop_slot_weapon_for_death(slot_index: int, impulse_direction: Vector3) -> void:
	if slot_index < 0 or slot_index >= weapon_slots.size():
		return

	var slot_state: Dictionary = weapon_slots[slot_index]
	if slot_state.is_empty():
		return

	var forward := impulse_direction
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = -global_basis.z
		forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()

	var right := global_basis.x
	right.y = 0.0
	if right.length_squared() <= 0.0001:
		right = forward.cross(Vector3.UP).normalized()
	right = right.normalized()

	var side_sign := -1.0 if slot_index == 0 else 1.0
	var side_offset := right * side_sign * 0.38
	var drop_position := global_position + Vector3.UP * world_drop_up_offset + forward * 0.35 + side_offset
	var drop_forward := (forward + right * side_sign * 0.25).normalized()

	_server_spawn_world_weapon(slot_state, drop_position, drop_forward)
	weapon_slots[slot_index] = {}

func _get_death_impulse_direction(damage_source: Node = null) -> Vector3:
	var direction := Vector3.ZERO

	if damage_source != null and is_instance_valid(damage_source):
		if "velocity" in damage_source:
			var source_velocity = damage_source.get("velocity")
			if source_velocity is Vector3 and source_velocity.length_squared() > 0.05:
				direction = source_velocity.normalized()

		if direction.length_squared() <= 0.0001 and damage_source is Node3D:
			var source_position := (damage_source as Node3D).global_position
			direction = global_position - source_position

	direction.y = 0.0

	if direction.length_squared() <= 0.0001:
		direction = -global_basis.z
		direction.y = 0.0

	if direction.length_squared() <= 0.0001:
		direction = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))

	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD

	return direction.normalized()

func _apply_death_state(value: int, death_transform: Transform3D, impulse_direction: Vector3) -> void:
	var was_dead := is_dead

	health = clampi(value, 0, max_health)
	is_dead = true
	velocity = Vector3.ZERO
	replicated_position = death_transform.origin
	replicated_velocity = Vector3.ZERO
	global_transform = death_transform

	_cancel_local_reload()
	_cancel_server_reload()
	_set_body_collision_enabled(false)

	if not was_dead:
		_spawn_death_body(death_transform, impulse_direction)

	visual_root.visible = false
	update_name_label()
	camera.current = is_multiplayer_authority()
	emit_signal("health_changed", health, max_health)

	if not was_dead:
		emit_signal("died")

func _spawn_death_body(death_transform: Transform3D, impulse_direction: Vector3) -> void:
	if not death_body_enabled:
		return

	_clear_death_body()

	var parent := get_tree().current_scene
	if parent == null:
		parent = get_parent()
	if parent == null:
		return

	var body := RigidBody3D.new()
	body.name = "PlayerDeathBody_%s" % player_id
	body.mass = max(death_body_mass, 0.1)
	body.collision_layer = death_body_collision_layer
	body.collision_mask = death_body_collision_mask
	body.linear_damp = death_body_linear_damp
	body.angular_damp = death_body_angular_damp
	body.can_sleep = true
	body.axis_lock_angular_y = death_body_lock_yaw_rotation

	parent.add_child(body)
	body.global_transform = death_transform
	death_body_node = body

	var visual_copy := visual_root.duplicate()
	body.add_child(visual_copy)
	visual_copy.name = "VisualRoot"
	visual_copy.transform = visual_root.transform
	visual_copy.visible = true
	_force_node_visible(visual_copy)
	visual_copy.process_mode = Node.PROCESS_MODE_DISABLED

	if collision_shape != null:
		var shape_copy := collision_shape.duplicate() as CollisionShape3D
		if shape_copy != null:
			body.add_child(shape_copy)
			shape_copy.name = "CollisionShape3D"
			shape_copy.transform = collision_shape.transform
			shape_copy.disabled = false

	var direction := impulse_direction
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = -death_transform.basis.z
		direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	direction = direction.normalized()

	var random_horizontal := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	if random_horizontal.length_squared() > 0.0001:
		random_horizontal = random_horizontal.normalized() * death_body_random_impulse

	var impulse := direction * death_body_impulse_force + Vector3.UP * death_body_upward_impulse + random_horizontal
	body.apply_central_impulse(impulse)

	var knockdown_axis := direction.cross(Vector3.UP)
	if knockdown_axis.length_squared() <= 0.0001:
		knockdown_axis = death_transform.basis.x
	knockdown_axis = knockdown_axis.normalized()
	body.apply_torque_impulse(knockdown_axis * death_body_knockdown_angular_impulse)

func _force_node_visible(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).visible = true
	elif node is Node3D:
		(node as Node3D).visible = true

	for child in node.get_children():
		_force_node_visible(child)

func _clear_death_body() -> void:
	if death_body_node != null and is_instance_valid(death_body_node):
		death_body_node.queue_free()
	death_body_node = null

func _set_body_collision_enabled(enabled: bool) -> void:
	if collision_shape != null:
		collision_shape.disabled = not enabled

func _server_respawn_player() -> void:
	if not multiplayer.is_server():
		return
	if not is_dead:
		return

	var spawn_transform := _get_respawn_transform_from_main()

	health = max_health
	is_dead = false
	velocity = Vector3.ZERO
	current_weapon_slot = 0
	weapon_slots[0] = {}
	weapon_slots[1] = {}

	_cancel_server_reload()
	_cancel_local_reload()
	_sync_weapon_inventory_to_peers()

	_apply_respawn_state(spawn_transform, health)
	_receive_respawn_state.rpc(spawn_transform, health)

func _get_respawn_transform_from_main() -> Transform3D:
	var fallback := global_transform
	fallback.origin = Vector3.ZERO

	var main := get_tree().current_scene
	if main == null:
		return fallback

	if main.has_method("get_respawn_transform_for_player"):
		var transform_value = main.call("get_respawn_transform_for_player", player_id)
		if typeof(transform_value) == TYPE_TRANSFORM3D:
			return transform_value

	if main.has_method("get_respawn_position_for_player"):
		var position_value = main.call("get_respawn_position_for_player", player_id)
		if typeof(position_value) == TYPE_VECTOR3:
			fallback.origin = position_value
			return fallback

	var spawn_root := main.get_node_or_null("SpawnPoints")
	if spawn_root != null:
		var points := spawn_root.get_children()
		if not points.is_empty():
			var point := points[randi() % points.size()]
			if point is Node3D:
				return (point as Node3D).global_transform

	return fallback

func _apply_respawn_state(spawn_transform: Transform3D, health_value: int) -> void:
	_clear_death_body()

	health = clampi(health_value, 1, max_health)
	is_dead = false
	velocity = Vector3.ZERO
	replicated_position = spawn_transform.origin
	replicated_velocity = Vector3.ZERO
	replicated_aim_rotation = Vector3.ZERO
	replicated_visual_y = spawn_transform.basis.get_euler().y

	global_transform = spawn_transform
	aim_root.rotation = Vector3.ZERO
	visual_root.rotation = Vector3.ZERO

	weapon_slots[0] = {}
	weapon_slots[1] = {}
	current_weapon_slot = 0
	_refresh_weapon_nodes()

	_cancel_local_reload()
	_cancel_server_reload()
	_set_body_collision_enabled(true)
	visual_root.visible = true
	camera.current = is_multiplayer_authority()
	update_name_label()
	emit_signal("health_changed", health, max_health)


func get_hud_data() -> Dictionary:
	var vehicle := _get_current_vehicle_for_hud()
	var to_equipped_weapon := get_equipped_weapon()
	var weapon_1 := get_weapon_in_slot(0)
	var weapon_2 := get_weapon_in_slot(1)

	return {
		"hp": health,
		"is_dead": is_dead,
		"max_hp": max_health,
		"money": carried_money,
		"in_vehicle": vehicle != null or is_in_vehicle(),
		"vehicle": vehicle,
		"equipped_weapon_name": _hud_weapon_name(to_equipped_weapon),
		"weapon_1_name": _hud_weapon_name(weapon_1),
		"weapon_2_name": _hud_weapon_name(weapon_2),
		"mag_ammo": _hud_mag_ammo(to_equipped_weapon),
		"reserve_ammo": _hud_reserve_ammo(to_equipped_weapon),
		"ammo_reserve_data": ammo_reserve.duplicate(true),
		"equipped_ammo_type": _hud_equipped_ammo_type(to_equipped_weapon),
	}

func _get_current_vehicle_for_hud() -> Node:
	if current_vehicle != null:
		if is_instance_valid(current_vehicle):
			return current_vehicle
		current_vehicle = null

	if vehicle_interactor != null and is_instance_valid(vehicle_interactor):
		for p in vehicle_interactor.get_property_list():
			if p.name == "current_vehicle":
				var property_value = vehicle_interactor.get("current_vehicle")
				if property_value != null and is_instance_valid(property_value) and property_value is Node:
					return property_value
				return null

		if vehicle_interactor.has_method("get_current_vehicle"):
			var value = vehicle_interactor.call("get_current_vehicle")
			if value != null and is_instance_valid(value) and value is Node:
				return value

	return null

func _hud_weapon_name(weapon: Node) -> String:
	if weapon == null:
		return "Aucune"

	if "weapon_label" in weapon:
		return str(weapon.weapon_label)

	if "weapon_name" in weapon:
		return str(weapon.weapon_name)

	if "weapon_id" in weapon:
		return str(weapon.weapon_id)

	return weapon.name

func _hud_equipped_ammo_type(weapon: Node) -> String:
	var typed_weapon := weapon as WeaponInstance3D
	if typed_weapon == null:
		return ""

	return _get_ammo_type_for_weapon(typed_weapon)

func _hud_mag_ammo(weapon: Node) -> int:
	if weapon == null:
		return 0

	if "ammo_in_magazine" in weapon:
		return int(weapon.ammo_in_magazine)

	return 0

func _hud_reserve_ammo(weapon: Node) -> int:
	var typed_weapon := weapon as WeaponInstance3D
	if typed_weapon == null:
		return 0

	var ammo_type := _get_ammo_type_for_weapon(typed_weapon)
	if ammo_type.is_empty():
		return 0

	return int(ammo_reserve.get(ammo_type, 0))

func get_equipped_weapon() -> Node:
	return _get_current_weapon_node()

func get_weapon_in_slot(slot_index: int) -> Node:
	if slot_index < 0 or slot_index >= weapon_nodes.size():
		return null
	return weapon_nodes[slot_index]


func _apply_health_state(value: int, dead_now: bool) -> void:
	health = clampi(value, 0, max_health)
	var was_dead := is_dead
	is_dead = dead_now
	update_name_label()
	emit_signal("health_changed", health, max_health)

	if is_dead:
		velocity = Vector3.ZERO
		_set_body_collision_enabled(false)
		visual_root.visible = false
		if not was_dead:
			emit_signal("died")
	else:
		_set_body_collision_enabled(true)
		visual_root.visible = true

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _receive_state(position_value: Vector3, velocity_value: Vector3, aim_rotation: Vector3, visual_yaw: float) -> void:
	if is_multiplayer_authority():
		return
	if is_dead:
		replicated_position = global_position
		replicated_velocity = Vector3.ZERO
		return
	replicated_position = position_value
	replicated_velocity = velocity_value
	replicated_aim_rotation = aim_rotation
	replicated_visual_y = visual_yaw

func _is_valid_owner_request(action_name: String) -> bool:
	if not multiplayer.is_server():
		return false

	var sender_id := multiplayer.get_remote_sender_id()
	var expected_id := get_multiplayer_authority()

	# Fallback de sécurité si l'autorité n'a pas été définie au spawn.
	if expected_id == 0:
		expected_id = player_id

	if sender_id != expected_id:
		print(
			"[WEAPON_NET] rejected ",
			action_name,
			" sender=",
			sender_id,
			" expected_authority=",
			expected_id,
			" player_id=",
			player_id,
			" node=",
			name
		)
		return false

	return true


@rpc("any_peer", "call_remote", "unreliable")
func _spawn_bullet_fx(shot_origin: Vector3, shot_direction: Vector3, slot_index: int) -> void:
	if is_multiplayer_authority():
		return

	var slot_state: Dictionary = weapon_slots[slot_index]
	if slot_state.is_empty():
		return

	var scene := _get_weapon_scene_by_id(String(slot_state.get("weapon_id", "")))
	if scene == null:
		return

	var weapon := scene.instantiate() as WeaponInstance3D
	if weapon == null:
		return

	_spawn_visual_bullet_from_weapon(weapon, shot_origin, shot_direction)
	weapon.free()

@rpc("any_peer", "reliable")
func _request_fire_weapon(slot_index: int, shot_origin: Vector3, shot_direction: Vector3) -> void:
	if not _is_valid_owner_request("fire_weapon"):
		return

	_server_fire_weapon(slot_index, shot_origin, shot_direction.normalized())

@rpc("any_peer", "call_remote", "reliable")
func _request_pickup_nearest_weapon_rpc() -> void:
	if not _is_valid_owner_request("pickup_nearest_weapon"):
		return

	_server_pickup_nearest_weapon()

@rpc("any_peer", "reliable")
func _request_drop_current_weapon_rpc() -> void:
	if not _is_valid_owner_request("drop_current_weapon"):
		return

	_server_drop_current_weapon()

@rpc("any_peer", "reliable")
func _request_reload_current_weapon_rpc() -> void:
	if not _is_valid_owner_request("reload_current_weapon"):
		return

	_server_start_reload_current_weapon()

@rpc("any_peer", "reliable")
func _request_select_weapon_slot_rpc(slot_index: int) -> void:
	if not _is_valid_owner_request("select_weapon_slot"):
		return

	_server_select_weapon_slot(slot_index)

@rpc("any_peer", "call_remote", "reliable")
func _receive_weapon_inventory(slot_0: Dictionary, slot_1: Dictionary, selected_slot: int, reloading: bool, remaining_reload: float) -> void:
	_apply_received_weapon_inventory(slot_0, slot_1, selected_slot, reloading, remaining_reload)

@rpc("any_peer", "call_remote", "reliable")
func _spawn_world_weapon_remote(net_id: int, weapon_id: String, ammo_in_magazine: int, reserve_ammo: int, spawn_position: Vector3, forward: Vector3) -> void:
	if multiplayer.is_server():
		return

	# Seul le serveur doit créer les armes au sol sur les clients.
	# Avec SteamMultiplayerPeer, ce RPC peut être appelé depuis le node joueur d'un client.
	# On valide donc l'expéditeur au lieu de dépendre de l'autorité du node.
	if multiplayer.get_remote_sender_id() != 1:
		print("[WEAPON_NET] rejected world weapon spawn from sender=", multiplayer.get_remote_sender_id())
		return

	# Évite les doublons si le RPC est reçu deux fois ou si une arme stale existe encore localement.
	var existing := _find_world_weapon_by_net_id(net_id)
	if existing != null and is_instance_valid(existing):
		existing.queue_free()

	_spawn_world_weapon_local(net_id, weapon_id, ammo_in_magazine, reserve_ammo, spawn_position, forward)

@rpc("any_peer", "call_remote", "reliable")
func _despawn_world_weapon_remote(net_id: int, node_path: NodePath) -> void:
	if multiplayer.is_server():
		return

	# Important : ne pas utiliser @rpc("authority") ici.
	# Ce script est attaché à chaque NetworkPlayer. Pour le joueur client,
	# l'autorité du node est le client, pas le serveur.
	# Le serveur doit pourtant pouvoir ordonner la disparition de l'arme au sol.
	if multiplayer.get_remote_sender_id() != 1:
		print("[WEAPON_NET] rejected world weapon despawn from sender=", multiplayer.get_remote_sender_id())
		return

	var world_weapon: WorldWeapon3D = null

	if net_id != -1:
		world_weapon = _find_world_weapon_by_net_id(net_id)

	if world_weapon == null and has_node(node_path):
		var node := get_node(node_path)
		if node is WorldWeapon3D:
			world_weapon = node as WorldWeapon3D

	if world_weapon != null and is_instance_valid(world_weapon):
		print("[WEAPON_NET] despawn world weapon on client net_id=", net_id)
		world_weapon.queue_free()
	else:
		print("[WEAPON_NET] despawn requested but weapon not found on client net_id=", net_id, " path=", node_path)


@rpc("any_peer", "reliable")
func _request_respawn_rpc() -> void:
	if not _is_valid_owner_request("respawn"):
		return

	_server_respawn_player()

@rpc("any_peer", "call_remote", "reliable")
func _receive_player_death_state(value: int, death_transform: Transform3D, impulse_direction: Vector3) -> void:
	_apply_death_state(value, death_transform, impulse_direction)

@rpc("any_peer", "call_remote", "reliable")
func _receive_respawn_state(spawn_transform: Transform3D, health_value: int) -> void:
	_apply_respawn_state(spawn_transform, health_value)

@rpc("authority", "call_local", "reliable")
func _sync_carried_money(value: int) -> void:
	carried_money = max(value, 0)


@rpc("any_peer", "call_remote", "reliable")
func _receive_health_state(value: int, dead_now: bool) -> void:
	_apply_health_state(value, dead_now)
