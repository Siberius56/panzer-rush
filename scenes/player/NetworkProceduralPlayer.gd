extends CharacterBody3D

signal health_changed(current: int, maximum: int)
signal damage_taken(amount: int)
signal died

const DEFAULT_VISUAL_BULLET_SCENE := preload("res://scenes/weapons/VisualBullet.tscn")
const WORLD_WEAPON_SCENE := preload("uid://dha7qfqc5vywa") #preload("res://weapons/WorldWeapon3D.tscn")
const PISTOL_SCENE := preload("uid://dd33dmmqhjkul") #preload("res://weapons/PistolWeapon.tscn")
const SMG_SCENE := preload("uid://nykf7fy7m5jg") #preload("res://weapons/SMGWeapon.tscn")
const GRAVITY_GUN_SCENE = preload("uid://cp3e1snyeddda")
const RIFLE_SCENE := preload("uid://dluj1jv7g4ocm") #preload("res://weapons/RifleWeapon.tscn")
const REPAIR_TOOL_SCENE := preload("res://scenes/weapons/RepairToolWeapon.tscn")
const BOMB_SCENE := preload("res://scenes/weapons/BombWeapon.tscn")
const EMPTY_WEAPON_SCENE_PATH := "res://scenes/weapons/weapon_empty.tscn"
const EMPTY_WEAPON_SCENE := preload("res://scenes/weapons/weapon_empty.tscn")

static var NEXT_WORLD_WEAPON_NET_ID: int = 1

@export_group("Movement")
@export var move_speed: float = 8.0
@export var acceleration: float = 30.0
@export var gravity_strength: float = 24.0
@export var jump_velocity: float = 8.5
@export var state_send_interval: float = 0.05

@export_group("Gravity Gun Push")
@export var gravity_gun_push_decay: float = 22.0
@export var gravity_gun_push_max_horizontal_speed: float = 24.0
@export var gravity_gun_push_max_vertical_speed: float = 12.0
@export var gravity_gun_push_min_horizontal_speed: float = 0.05

@export_group("Fall Damage")
@export var fall_damage_enabled: bool = true
@export var fall_safe_height: float = 3.0
@export var fall_minor_height: float = 5.0
@export var fall_minor_damage: int = 10
@export var fall_lethal_height: float = 10.0
@export var fall_lethal_damage: int = 100
@export var fall_min_impact_speed: float = 9.0

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
@export_flags_3d_physics var death_body_collision_mask: int = 14
@export var death_body_use_player_collision_mask: bool = true

@export_group("Respawn")
@export var respawn_delay_seconds: float = 5.0
@export var respawn_damage_grace_seconds: float = 0.25
@export var downed_to_final_death_seconds: float = 30.0

@export_group("Revive")
@export var revive_action: StringName = &"heal"
@export var revive_range: float = 2.8
@export var revive_duration: float = 3.0
@export_range(0.01, 1.0, 0.01) var revive_health_ratio: float = 0.2
@export var revive_name_height: float = 2.1

@export_group("Weapons")
@export var projectile_team: int = 1
@export var pickup_radius: float = 2.4
@export var interaction_radius: float = 2.4
@export var world_drop_forward_offset: float = 1.0
@export var world_drop_up_offset: float = 1.25

@export_group("Aiming")
@export var aim_projection_distance: float = 45.0
@export_flags_3d_physics var aim_collision_mask: int = 0xFFFFFFFF
@export var aim_min_target_distance: float = 0.05
@export var visual_aim_min_target_distance: float = 0.05

@export_group("Weapon Laser Sight")
@export var show_weapon_laser_sight: bool = true
@export var weapon_laser_min_length: float = 0.05

@export_group("Camera")
@export var camera_on_foot_spring_length: float = 7.0
@export var camera_vehicle_spring_length: float = 16.0
@export var camera_spring_length_tween_duration: float = 0.35
@export var camera_on_foot_dof_far_distance: float = 16.0
@export var camera_vehicle_dof_far_distance: float = 20.0

@export_group("Vehicle Visuals")
@export var hide_player_visuals_when_in_vehicle: bool = true

@export_group("Network Procedural Animation")
@export var remote_animation_velocity_lerp_speed: float = 16.0
@export var remote_animation_move_threshold: float = 0.08
@export_range(0.05, 1.0, 0.01) var remote_animation_fallback_speed_ratio: float = 0.42

@export_group("Procedural Gait")
@export var friction: float = 22.0
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

@export_group("Procedural Body Motion")
@export var body_bob_amount: float = 0.045
@export var body_tilt_amount: float = 0.10
@export var landing_squash_strength: float = 0.12

@export_group("Procedural Limb Lengths")
@export var upper_leg_length: float = 0.44
@export var lower_leg_length: float = 0.44
@export var upper_arm_length: float = 0.36
@export var lower_arm_length: float = 0.40

@export_group("Procedural Weapon Pose")
@export var weapon_local_position: Vector3 = Vector3(0.22, 1.25, -0.50)
@export var fallback_left_grip_local_position: Vector3 = Vector3(-0.09, 0.0, -0.19)
@export var fallback_right_grip_local_position: Vector3 = Vector3(0.08, 0.0, 0.16)
@export var weapon_follow_speed: float = 14.0
@export var aim_target_height_offset: float = 1.0

@export_group("Procedural Empty Weapon")
@export var use_empty_weapon_when_unarmed: bool = true
@export var empty_weapon_scene: PackedScene = EMPTY_WEAPON_SCENE
@export var empty_weapon_local_position: Vector3 = Vector3(0.08, 1.12, -0.28)
@export var empty_weapon_left_grip_local_position: Vector3 = Vector3(-0.18, 0.0, -0.08)
@export var empty_weapon_right_grip_local_position: Vector3 = Vector3(0.18, 0.0, 0.08)
@export var empty_weapon_use_neutral_rotation: bool = true

@onready var camera: Camera3D = _find_camera()
@onready var camera_spring_arm: SpringArm3D = _find_camera_spring_arm()
@onready var aim_root: Node3D = get_node_or_null("AimRoot") as Node3D
@onready var weapon_socket: Node3D = get_node_or_null("VisualRoot/WeaponSocket") as Node3D
@onready var hand_socket: Node3D = weapon_socket
@onready var visual_root: Node3D = get_node_or_null("VisualRoot") as Node3D
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
@onready var back_socket_1: Node3D = get_node_or_null("VisualRoot/BackSocket1") as Node3D
@onready var back_socket_2: Node3D = get_node_or_null("VisualRoot/BackSocket2") as Node3D
@onready var vehicle_interactor = get_node_or_null("VehicleInteractor")
@onready var upgrade_station_interactor = get_node_or_null("UpgradeStationInteractor")

@onready var placeholder_weapon: Node3D = get_node_or_null("VisualRoot/Weapon") as Node3D
@onready var placeholder_left_grip: Node3D = get_node_or_null("VisualRoot/Weapon/LeftGrip") as Node3D
@onready var placeholder_right_grip: Node3D = get_node_or_null("VisualRoot/Weapon/RightGrip") as Node3D
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
@onready var aim_cursor: Node3D = get_node_or_null("AimCursor") as Node3D

var left_grip: Node3D = null
var right_grip: Node3D = null
var aim_target_position: Vector3 = Vector3.FORWARD
var last_valid_aim_target_position: Vector3 = Vector3.FORWARD
var visual_yaw: float = 0.0
var walk_phase: float = 0.0
var landing_squash: float = 0.0
var procedural_nodes_ready: bool = false
var camera_spring_length_target: float = 7.0
var camera_spring_length_tween: Tween = null
var camera_dof_far_distance_target: float = 16.0
var camera_dof_far_distance_tween: Tween = null

var _fall_was_airborne: bool = false
var _fall_start_y: float = 0.0
var _fall_lowest_velocity_y: float = 0.0

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
var is_final_dead: bool = false
var vehicle_mode: bool = false

var state_timer: float = 0.0
var replicated_position: Vector3 = Vector3.ZERO
var replicated_velocity: Vector3 = Vector3.ZERO
var replicated_aim_rotation: Vector3 = Vector3.ZERO
var replicated_visual_y: float = 0.0
var replicated_is_grounded: bool = true
var replicated_is_moving: bool = false
var replicated_in_vehicle: bool = false
var procedural_animation_velocity: Vector3 = Vector3.ZERO
var procedural_animation_grounded: bool = true
var procedural_animation_moving: bool = false

var ui_input_blocked: bool = false
var cinematic_invulnerability_locks: int = 0
var gravity_gun_external_velocity: Vector3 = Vector3.ZERO

var weapon_slots := [{}, {}]
var current_weapon_slot: int = 0
var weapon_nodes := [null, null]
var empty_weapon_instance: Node3D = null
var empty_weapon_node_name: StringName = &"weapon_empty"

var local_fire_cooldown: float = 0.0
var server_fire_cooldown: float = 0.0
var is_reloading_local: bool = false
var is_reloading_server: bool = false
var reload_timer_local: float = 0.0
var reload_timer_server: float = 0.0

const PLAYER_HUD_SCENE = preload("uid://q654pbgk6xhk")

var hud: PlayerHUD = null
var death_body_node: RigidBody3D = null

var death_elapsed_time: float = 0.0
var last_death_was_killzone: bool = false
var _server_death_msec: int = 0
var _server_respawn_protection_until_msec: int = 0
var _server_final_death_synced: bool = false
var _local_revive_button_down: bool = false
var _server_revive_target: Node = null
var _server_revive_progress: float = 0.0

var revive_active: bool = false
var revive_role: int = 0 # 0 = aucun, 1 = réanimateur, 2 = réanimé
var revive_other_player_id: int = 0
var revive_other_player_name: String = ""
var revive_progress: float = 0.0

var is_spectating: bool = false
var spectator_target_player_id: int = 0

@export_group("Money")
@export var carried_money: int = 0


@export_group("Ammo")
var ammo_reserve := {
	"9mm": 140,
	"shell": 32,
	"rifle": 50,
	"energy": 90
}

var ammo_reserve_max := {
	"9mm": 140,
	"shell": 32,
	"rifle": 50,
	"energy": 90
}


func set_ui_input_blocked(active: bool) -> void:
	ui_input_blocked = active
	if active:
		velocity = Vector3.ZERO


func set_cinematic_invulnerable(active: bool) -> void:
	if active:
		cinematic_invulnerability_locks += 1
	else:
		cinematic_invulnerability_locks = maxi(cinematic_invulnerability_locks - 1, 0)

	var is_active: bool = cinematic_invulnerability_locks > 0
	set_meta("cinematic_invulnerable", is_active)

	if is_active:
		_reset_fall_damage_tracking()


func is_cinematic_invulnerable() -> bool:
	if cinematic_invulnerability_locks > 0:
		return true

	if has_meta("cinematic_invulnerable"):
		return bool(get_meta("cinematic_invulnerable"))

	return false


func _can_receive_damage() -> bool:
	if is_dead:
		return false
	if is_cinematic_invulnerable():
		return false
	if _is_server_respawn_protected():
		return false

	return true

func _ready() -> void:
	
	procedural_nodes_ready = _validate_procedural_scene_nodes()
	if not procedural_nodes_ready:
		set_physics_process(false)
		return

	if placeholder_weapon != null:
		placeholder_weapon.visible = false

	if left_probe != null:
		left_probe.enabled = true
	if right_probe != null:
		right_probe.enabled = true

	visual_yaw = global_transform.basis.get_euler().y
	if foot_probe_root != null:
		foot_probe_root.rotation.y = visual_yaw

	if is_multiplayer_authority():
		hud = PLAYER_HUD_SCENE.instantiate()
		get_tree().current_scene.add_child(hud)
		hud.set_player(self)
		if hud.has_signal("respawn_requested"):
			hud.respawn_requested.connect(_on_hud_respawn_requested)
		if hud.has_signal("spectate_next_requested"):
			hud.spectate_next_requested.connect(_on_hud_spectate_next_requested)

	ui_input_blocked = false
	add_to_group("player")
	add_to_group("players")
	_register_self_as_enemy_target()
	health = max_health
	replicated_position = global_position
	replicated_velocity = velocity
	procedural_animation_velocity = velocity
	procedural_animation_grounded = is_on_floor()
	procedural_animation_moving = Vector3(velocity.x, 0.0, velocity.z).length() > remote_animation_move_threshold
	replicated_is_grounded = procedural_animation_grounded
	replicated_is_moving = procedural_animation_moving
	replicated_in_vehicle = is_in_vehicle()
	_reset_fall_damage_tracking()
	if aim_root != null:
		replicated_aim_rotation = aim_root.rotation
	replicated_visual_y = visual_yaw
	if camera != null:
		camera.current = is_multiplayer_authority()

	_apply_camera_spring_length_for_vehicle_mode(vehicle_mode, true)
	_apply_camera_dof_for_vehicle_mode(vehicle_mode, true)
	_apply_vehicle_visual_state()

	_refresh_weapon_nodes()
	_reset_procedural_pose()
	_update_visuals(0.016)
	_apply_vehicle_visual_state()
	emit_signal("health_changed", health, max_health)
	if multiplayer.is_server():
		_server_sync_team_respawn_lives_state()

func _exit_tree() -> void:
	_unregister_self_as_enemy_target()
	if multiplayer.is_server():
		_server_cancel_revive(false)
		_server_cancel_revives_targeting(self)
	_clear_death_body()
	_clear_empty_weapon_instance()
	if hud != null and is_instance_valid(hud):
		hud.queue_free()
	hud = null

func _register_self_as_enemy_target() -> void:
	var target_manager: Node = get_node_or_null("/root/EnemyTargetManager")
	if target_manager == null:
		return

	if target_manager.has_method("register_player"):
		target_manager.call("register_player", self)
	elif target_manager.has_method("register_target"):
		target_manager.call("register_target", self)


func _unregister_self_as_enemy_target() -> void:
	var target_manager: Node = get_node_or_null("/root/EnemyTargetManager")
	if target_manager == null:
		return

	if target_manager.has_method("unregister_player"):
		target_manager.call("unregister_player", self)
	elif target_manager.has_method("unregister_target"):
		target_manager.call("unregister_target", self)


func build_session_state() -> Dictionary:
	return {
		"player_id": player_id,
		"player_name": player_name,
		"max_health": max_health,
		"health": health,
		"is_dead": is_dead,
		"is_final_dead": is_final_dead,
		"carried_money": carried_money,
		"weapon_slots": weapon_slots.duplicate(true),
		"current_weapon_slot": current_weapon_slot,
		"ammo_reserve": ammo_reserve.duplicate(true),
		"ammo_reserve_max": ammo_reserve_max.duplicate(true)
	}


func apply_session_state(state: Dictionary, force_alive: bool = true) -> void:
	player_name = String(state.get("player_name", player_name))
	max_health = int(state.get("max_health", max_health))

	var restored_health: int = int(state.get("health", max_health))
	var restored_dead: bool = bool(state.get("is_dead", false))
	var restored_final_dead: bool = bool(state.get("is_final_dead", false))

	if force_alive:
		restored_dead = false
		restored_final_dead = false
		restored_health = max(restored_health, 1)

	health = clampi(restored_health, 0, max_health)
	is_dead = restored_dead
	is_final_dead = restored_final_dead and restored_dead
	carried_money = max(int(state.get("carried_money", carried_money)), 0)

	var restored_ammo_reserve = state.get("ammo_reserve", ammo_reserve)
	if restored_ammo_reserve is Dictionary:
		ammo_reserve = restored_ammo_reserve.duplicate(true)

	var restored_ammo_reserve_max = state.get("ammo_reserve_max", ammo_reserve_max)
	if restored_ammo_reserve_max is Dictionary:
		ammo_reserve_max = restored_ammo_reserve_max.duplicate(true)

	var restored_weapon_slots = state.get("weapon_slots", weapon_slots)
	if restored_weapon_slots is Array:
		weapon_slots = [{}, {}]
		if restored_weapon_slots.size() > 0 and restored_weapon_slots[0] is Dictionary:
			weapon_slots[0] = restored_weapon_slots[0].duplicate(true)
		if restored_weapon_slots.size() > 1 and restored_weapon_slots[1] is Dictionary:
			weapon_slots[1] = restored_weapon_slots[1].duplicate(true)

	current_weapon_slot = clampi(int(state.get("current_weapon_slot", current_weapon_slot)), 0, 1)
	_cancel_local_reload()
	_cancel_server_reload()
	_clear_death_body()
	_refresh_weapon_nodes()
	_apply_health_state(health, is_dead)
	_sync_carried_money(carried_money)

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
	replicated_in_vehicle = active
	procedural_animation_moving = false
	if active:
		velocity = Vector3.ZERO
		procedural_animation_velocity = Vector3.ZERO

	_apply_vehicle_visual_state()
	_apply_camera_spring_length_for_vehicle_mode(active, false)
	_apply_camera_dof_for_vehicle_mode(active, false)

func _sync_to_vehicle_seat() -> void:
	if vehicle_interactor == null:
		return
	if vehicle_interactor.has_method("_sync_body_to_vehicle"):
		vehicle_interactor._sync_body_to_vehicle()

func _physics_process(delta: float) -> void:
	if is_dead:
		if not _is_final_death_countdown_paused():
			death_elapsed_time += delta
	else:
		death_elapsed_time = 0.0

	if multiplayer.is_server():
		_server_weapon_tick(delta)
		_server_final_death_tick()
		_server_revive_tick(delta)

	if is_multiplayer_authority():
		_local_weapon_tick(delta)
		_update_revive_input()
		_update_spectator_camera_state()

	if ui_input_blocked:
		velocity.x = 0.0
		velocity.z = 0.0
		_reset_fall_damage_tracking()
		_update_procedural_animation(delta)
		if is_multiplayer_authority():
			_send_state_if_needed(delta)
		return

	if is_multiplayer_authority() and is_dead:
		velocity = Vector3.ZERO
		_reset_fall_damage_tracking()
		_send_state_if_needed(delta)
		return

	var driving: bool = is_in_vehicle()

	if is_multiplayer_authority():
		if is_dead or driving:
			velocity = Vector3.ZERO
		else:
			_update_movement(delta)
			_apply_gravity_gun_external_velocity(delta)
			_update_aim()
			_update_weapon_input()

		if driving:
			_reset_fall_damage_tracking()
			_sync_to_vehicle_seat()
		else:
			_update_fall_damage_tracking_before_move()
			move_and_slide()
			_update_fall_damage_tracking_after_move()

		_update_procedural_animation(delta)
		_send_state_if_needed(delta)
	else:
		_apply_replicated_state(delta)
		_update_procedural_animation(delta)

func _send_state_if_needed(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		state_timer = state_send_interval
		var aim_rotation: Vector3 = Vector3.ZERO
		if aim_root != null:
			aim_rotation = aim_root.rotation

		var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
		var grounded_value: bool = is_on_floor()
		var moving_value: bool = horizontal_velocity.length() > remote_animation_move_threshold
		var in_vehicle_value: bool = is_in_vehicle()

		if in_vehicle_value or is_dead:
			moving_value = false
			grounded_value = true

		_receive_state.rpc(
			global_position,
			velocity,
			aim_rotation,
			visual_yaw,
			grounded_value,
			moving_value,
			in_vehicle_value
		)

func _update_movement(delta: float) -> void:
	if is_in_vehicle():
		return
	if camera == null:
		return

	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_backward", "move_forward")

	var forward: Vector3 = -camera.global_basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()

	var right: Vector3 = camera.global_basis.x
	right.y = 0.0
	if right.length_squared() <= 0.0001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()

	var desired_velocity: Vector3 = (right * input_vector.x + forward * input_vector.y) * move_speed
	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var move_rate: float = acceleration if input_vector.length_squared() > 0.001 else friction
	horizontal_velocity = horizontal_velocity.move_toward(desired_velocity, move_rate * delta)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = -0.1
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
			landing_squash = -0.55
	else:
		velocity.y -= gravity_strength * delta


func apply_gravity_gun_push(push_velocity: Vector3, from_position: Vector3 = Vector3.ZERO, source_node: Node = null) -> void:
	if is_dead or is_in_vehicle():
		return

	if push_velocity.length_squared() <= 0.0001:
		return

	# En multijoueur, le projectile physique agit côté serveur.
	# Le joueur, lui, est contrôlé par son peer d'autorité.
	# On relaie donc la poussée au peer qui possède réellement ce CharacterBody3D.
	if multiplayer != null and multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not is_multiplayer_authority():
		var authority_id: int = get_multiplayer_authority()
		if authority_id > 0:
			_receive_gravity_gun_push_rpc.rpc_id(authority_id, push_velocity, from_position)
		return

	_apply_gravity_gun_push_local(push_velocity)


func _apply_gravity_gun_push_local(push_velocity: Vector3) -> void:
	if is_dead or is_in_vehicle():
		return

	var horizontal_push: Vector3 = Vector3(push_velocity.x, 0.0, push_velocity.z)
	var horizontal_speed: float = horizontal_push.length()

	if horizontal_speed > gravity_gun_push_max_horizontal_speed and gravity_gun_push_max_horizontal_speed > 0.0:
		horizontal_push = horizontal_push.normalized() * gravity_gun_push_max_horizontal_speed

	if horizontal_speed > gravity_gun_push_min_horizontal_speed:
		var current_horizontal: Vector3 = Vector3(gravity_gun_external_velocity.x, 0.0, gravity_gun_external_velocity.z)
		gravity_gun_external_velocity.x = current_horizontal.x + horizontal_push.x
		gravity_gun_external_velocity.z = current_horizontal.z + horizontal_push.z

		var stored_horizontal: Vector3 = Vector3(gravity_gun_external_velocity.x, 0.0, gravity_gun_external_velocity.z)
		if gravity_gun_push_max_horizontal_speed > 0.0 and stored_horizontal.length() > gravity_gun_push_max_horizontal_speed:
			stored_horizontal = stored_horizontal.normalized() * gravity_gun_push_max_horizontal_speed
			gravity_gun_external_velocity.x = stored_horizontal.x
			gravity_gun_external_velocity.z = stored_horizontal.z

	if push_velocity.y > 0.0:
		var vertical_push: float = minf(push_velocity.y, gravity_gun_push_max_vertical_speed) if gravity_gun_push_max_vertical_speed > 0.0 else push_velocity.y
		velocity.y = maxf(velocity.y, vertical_push)


func _apply_gravity_gun_external_velocity(delta: float) -> void:
	if gravity_gun_external_velocity.length_squared() <= 0.0001:
		gravity_gun_external_velocity = Vector3.ZERO
		return

	velocity.x += gravity_gun_external_velocity.x
	velocity.z += gravity_gun_external_velocity.z

	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var max_horizontal_speed: float = maxf(move_speed + gravity_gun_push_max_horizontal_speed, move_speed)
	if gravity_gun_push_max_horizontal_speed > 0.0 and horizontal_velocity.length() > max_horizontal_speed:
		horizontal_velocity = horizontal_velocity.normalized() * max_horizontal_speed
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z

	gravity_gun_external_velocity = gravity_gun_external_velocity.move_toward(Vector3.ZERO, gravity_gun_push_decay * delta)


@rpc("any_peer", "call_local", "reliable")
func _receive_gravity_gun_push_rpc(push_velocity: Vector3, from_position: Vector3) -> void:
	if multiplayer != null and multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		var sender_id: int = multiplayer.get_remote_sender_id()
		if sender_id != 1:
			return

	_apply_gravity_gun_push_local(push_velocity)


func _reset_fall_damage_tracking() -> void:
	_fall_was_airborne = false
	_fall_start_y = global_position.y
	_fall_lowest_velocity_y = 0.0

func _update_fall_damage_tracking_before_move() -> void:
	if not fall_damage_enabled or is_dead or is_in_vehicle() or is_cinematic_invulnerable():
		_reset_fall_damage_tracking()
		return

	if _fall_was_airborne:
		_fall_lowest_velocity_y = min(_fall_lowest_velocity_y, velocity.y)

func _update_fall_damage_tracking_after_move() -> void:
	if not fall_damage_enabled or is_dead or is_in_vehicle() or is_cinematic_invulnerable():
		_reset_fall_damage_tracking()
		return

	var grounded: bool = is_on_floor()

	if not grounded:
		if not _fall_was_airborne:
			_fall_was_airborne = true
			_fall_start_y = global_position.y
			_fall_lowest_velocity_y = velocity.y
		else:
			_fall_lowest_velocity_y = min(_fall_lowest_velocity_y, velocity.y)
		return

	if not _fall_was_airborne:
		_fall_start_y = global_position.y
		_fall_lowest_velocity_y = 0.0
		return

	var fall_height: float = max(_fall_start_y - global_position.y, 0.0)
	var impact_speed: float = max(-_fall_lowest_velocity_y, 0.0)
	_reset_fall_damage_tracking()

	var fall_damage: int = _get_fall_damage(fall_height, impact_speed)
	if fall_damage <= 0:
		return

	_report_fall_damage_to_server(fall_damage, fall_height, impact_speed)

func _get_fall_damage(fall_height: float, impact_speed: float) -> int:
	if not fall_damage_enabled or is_cinematic_invulnerable():
		return 0
	if impact_speed < fall_min_impact_speed:
		return 0

	var safe_height: float = max(fall_safe_height, 0.0)
	var minor_height: float = max(fall_minor_height, safe_height + 0.01)
	var lethal_height: float = max(fall_lethal_height, minor_height + 0.01)
	var minor_damage: float = max(float(fall_minor_damage), 0.0)
	var lethal_damage: float = max(float(fall_lethal_damage), minor_damage)

	if fall_height <= safe_height:
		return 0

	if fall_height <= minor_height:
		var low_t: float = clampf(inverse_lerp(safe_height, minor_height, fall_height), 0.0, 1.0)
		return max(1, int(round(lerpf(0.0, minor_damage, low_t))))

	var high_t: float = clampf(inverse_lerp(minor_height, lethal_height, fall_height), 0.0, 1.0)
	var curved_t: float = pow(high_t, 1.35)
	var damage: float = lerpf(minor_damage, lethal_damage, curved_t)

	if fall_height > lethal_height:
		var extra_height: float = fall_height - lethal_height
		damage += extra_height * lethal_damage * 0.18

	return max(1, int(round(damage)))

func _report_fall_damage_to_server(fall_damage: int, fall_height: float, impact_speed: float) -> void:
	if fall_damage <= 0:
		return
	if is_cinematic_invulnerable():
		return

	if multiplayer.is_server():
		apply_damage(fall_damage, self)
		return

	_request_apply_fall_damage_rpc.rpc_id(1, fall_damage, fall_height, impact_speed)

func _update_aim() -> void:
	if is_in_vehicle():
		return
	if aim_root == null:
		return

	var target_position: Vector3 = _get_cursor_aim_target()
	var aim_distance: float = aim_root.global_position.distance_to(target_position)

	if aim_distance >= aim_min_target_distance:
		aim_root.look_at(target_position, Vector3.UP)
		aim_root.rotation.z = 0.0

	aim_target_position = target_position
	last_valid_aim_target_position = target_position

	if aim_cursor != null:
		aim_cursor.global_position = aim_target_position + Vector3.UP * 0.035

func _get_cursor_aim_target() -> Vector3:
	if camera == null:
		return global_position + Vector3.FORWARD * 4.0 + Vector3.UP * aim_target_height_offset

	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_position)
	var ray_direction: Vector3 = camera.project_ray_normal(mouse_position).normalized()
	var ray_end: Vector3 = ray_origin + ray_direction * aim_projection_distance

	var direct_space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [get_rid()]
	query.collision_mask = aim_collision_mask
	query.hit_from_inside = false

	var result: Dictionary = direct_space_state.intersect_ray(query)
	if not result.is_empty():
		var hit_position = result.get("position")
		if hit_position is Vector3:
			var typed_hit_position: Vector3 = hit_position
			return typed_hit_position + Vector3.UP * aim_target_height_offset

	var ground_plane: Plane = Plane(Vector3.UP, global_position.y)
	var ground_hit = ground_plane.intersects_ray(ray_origin, ray_direction)
	if ground_hit != null:
		var typed_ground_hit: Vector3 = ground_hit
		return typed_ground_hit + Vector3.UP * aim_target_height_offset

	return ray_end

func _get_shot_direction_from_weapon(weapon: WeaponInstance3D) -> Vector3:
	if weapon == null:
		if aim_root != null:
			return -aim_root.global_basis.z.normalized()
		return Vector3.FORWARD

	var muzzle_transform: Transform3D = weapon.get_muzzle_transform()
	var base_direction: Vector3 = -muzzle_transform.basis.z.normalized()
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
	match kind.to_lower():
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

		"energy":
			return add_ammo("energy", amount)

		"repair_tool":
			return add_ammo("energy", amount)
		
		"gravity_gun":
			return add_ammo("energy", amount)

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
		_request_context_interaction()

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
		"repair_tool":
			return "energy"
		"gravity_gun":
			return "energy"
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

	if _is_non_firing_weapon(weapon):
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
	var uses_repair_tool := _is_repair_tool_weapon(weapon)

	if uses_repair_tool:
		_update_local_repair_target_hud(shot_origin, shot_direction, weapon)

	if not uses_repair_tool:
		_emit_weapon_fire_camera_shake(weapon)

	# Prédiction visuelle uniquement côté client.
	# Le serveur spawn la vraie balle dans _server_fire_weapon().
	# Le repair tool n'utilise pas de projectile.
	if not multiplayer.is_server() and not uses_repair_tool:
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

func _emit_weapon_fire_camera_shake(weapon: WeaponInstance3D) -> void:
	if weapon == null:
		return

	if _is_repair_tool_weapon(weapon):
		return

	var intensity: float = 0.0
	if weapon.has_method("get_fire_camera_shake_intensity"):
		intensity = float(weapon.get_fire_camera_shake_intensity())
	elif "camera_shake_intensity" in weapon:
		intensity = float(weapon.camera_shake_intensity)

	if intensity <= 0.0:
		return

	var frequency_multiplier: float = 1.0
	if "camera_shake_frequency_multiplier" in weapon:
		frequency_multiplier = float(weapon.camera_shake_frequency_multiplier)

	CameraShakeController.emit_local_shake(get_tree(), intensity, frequency_multiplier)

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
	current_weapon_slot = clampi(slot_index, 0, 1)
	_cancel_local_reload()
	_refresh_weapon_nodes()
	_apply_current_held_weapon_pose_immediately()

func _request_reload_current_weapon() -> void:
	if is_dead:
		return
	var weapon := _get_current_weapon_node()
	if weapon == null:
		return
	if is_reloading_local:
		return
	if _is_non_firing_weapon(weapon):
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

func _request_context_interaction() -> void:
	if is_dead:
		return

	if multiplayer.is_server():
		var did_interact: bool = _server_interact_nearest_gate_button()
		if not did_interact:
			_server_pickup_nearest_weapon()
		return

	_request_context_interaction_rpc.rpc_id(1)


func _server_interact_nearest_gate_button() -> bool:
	if is_dead:
		return false
	if not multiplayer.is_server():
		return false

	var interactable: Node = _find_nearest_gate_button()
	if interactable == null:
		return false

	if interactable.has_method("can_interact"):
		var can_interact_value: bool = bool(interactable.call("can_interact", self))
		if not can_interact_value:
			return false

	if interactable.has_method("interact"):
		return bool(interactable.call("interact", self))
	if interactable.has_method("activate"):
		return bool(interactable.call("activate", self))
	if interactable.has_method("use"):
		return bool(interactable.call("use", self))
	if interactable.has_method("press"):
		return bool(interactable.call("press", self))

	return false


func _find_nearest_gate_button() -> Node:
	var closest: Node = null
	var closest_distance: float = INF
	var radius: float = max(interaction_radius, 0.1)

	for node in get_tree().get_nodes_in_group("gate_buttons"):
		if node == null or not is_instance_valid(node):
			continue
		if not (node is Node3D):
			continue

		var node_3d: Node3D = node as Node3D
		var distance: float = global_position.distance_to(node_3d.global_position)
		if distance > radius:
			continue
		if distance < closest_distance:
			closest_distance = distance
			closest = node

	return closest

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

	var spawn_state: Dictionary = state.duplicate(true)
	spawn_state["reserve_ammo"] = 0

	_spawn_world_weapon_local(net_id, spawn_state, spawn_position, forward)
	_spawn_world_weapon_remote.rpc(net_id, spawn_state, spawn_position, forward)

func _spawn_world_weapon_local(net_id: int, state: Dictionary, spawn_position: Vector3, forward: Vector3) -> void:
	var world_weapon := WORLD_WEAPON_SCENE.instantiate() as WorldWeapon3D
	world_weapon.name = "WorldWeapon_%d" % net_id
	world_weapon.net_id = net_id
	get_tree().current_scene.add_child(world_weapon)
	world_weapon.global_position = spawn_position
	world_weapon.replicated_transform = world_weapon.global_transform

	var origin_transform: Transform3D = world_weapon.global_transform
	if state.has("objective_origin_transform") and state["objective_origin_transform"] is Transform3D:
		origin_transform = state["objective_origin_transform"]
	world_weapon.set_objective_origin_transform(origin_transform)

	world_weapon.setup_from_state(
		String(state.get("weapon_id", "")),
		int(state.get("ammo_in_magazine", 0)),
		0,
		state
	)
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
	current_weapon_slot = clampi(slot_index, 0, 1)
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

	if _is_non_firing_weapon(weapon):
		weapon.free()
		return

	if not weapon.consume_round():
		var can_reload_now := _can_reload_weapon_from_player_reserve(weapon)
		weapon.free()

		if can_reload_now:
			_server_start_reload_current_weapon()

		return

	weapon.reserve_ammo = 0
	weapon_slots[slot_index] = weapon.to_runtime_state()

	server_fire_cooldown = weapon.fire_cooldown

	if _is_repair_tool_weapon(weapon):
		_process_server_repair_tool(shot_origin, shot_direction, weapon)
	else:
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


func _is_repair_tool_weapon(weapon: WeaponInstance3D) -> bool:
	if weapon == null:
		return false

	if "weapon_behavior" in weapon and str(weapon.weapon_behavior).to_lower() == "repair_tool":
		return true

	if "weapon_id" in weapon and str(weapon.weapon_id).to_lower() == "repair_tool":
		return true

	return false


func _is_non_firing_weapon(weapon: WeaponInstance3D) -> bool:
	if weapon == null:
		return false

	if weapon.has_method("can_fire"):
		return weapon.call("can_fire") != true

	if "weapon_behavior" in weapon and str(weapon.weapon_behavior).to_lower() == "objective_item":
		return true

	return false


func _process_server_repair_tool(shot_origin: Vector3, shot_direction: Vector3, weapon: WeaponInstance3D) -> void:
	if weapon == null:
		return
	if not multiplayer.is_server():
		return

	var direction := shot_direction.normalized()
	if direction.length_squared() <= 0.0001:
		direction = -aim_root.global_basis.z.normalized()

	var range_value: float = max(weapon.repair_range, 0.1)
	var ray_end := shot_origin + direction * range_value

	var query := PhysicsRayQueryParameters3D.create(shot_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = weapon.repair_collision_mask
	query.hit_from_inside = true

	var exclude: Array = []
	_collect_repair_tool_exclude_rids(self, exclude)
	query.exclude = exclude

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return

	var collider_value = result.get("collider", null)
	if not (collider_value is Node):
		return

	var target := _find_repair_tool_target(collider_value as Node)
	if target == null:
		return

	if target.has_method("apply_repair"):
		if not weapon.repair_revive_dead_vehicle and "is_dead" in target and bool(target.is_dead):
			return
		target.apply_repair(weapon.repair_amount)
		return

	_apply_repair_tool_damage(target, weapon)


func _update_local_repair_target_hud(shot_origin: Vector3, shot_direction: Vector3, weapon: WeaponInstance3D) -> void:
	if hud == null or not is_instance_valid(hud):
		return
	if weapon == null:
		return

	var direction := shot_direction.normalized()
	if direction.length_squared() <= 0.0001:
		direction = -aim_root.global_basis.z.normalized()

	var range_value: float = max(weapon.repair_range, 0.1)
	var ray_end := shot_origin + direction * range_value

	var query := PhysicsRayQueryParameters3D.create(shot_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = weapon.repair_collision_mask
	query.hit_from_inside = true

	var exclude: Array = []
	_collect_repair_tool_exclude_rids(self, exclude)
	query.exclude = exclude

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return

	var collider_value = result.get("collider", null)
	if not (collider_value is Node):
		return

	var target := _find_repair_tool_target(collider_value as Node)
	if target == null or not target.has_method("apply_repair"):
		return

	if not weapon.repair_revive_dead_vehicle and "is_dead" in target and bool(target.is_dead):
		return

	if hud.has_method("show_repair_target"):
		hud.show_repair_target(target)


func _find_repair_tool_target(node: Node) -> Node:
	if node == null:
		return null

	var current: Node = node
	while current != null:
		if current == self:
			return null
		if current.has_method("apply_repair"):
			return current
		current = current.get_parent()

	current = node
	while current != null:
		if current == self:
			return null
		if current.has_method("apply_projectile_damage") or current.has_method("apply_damage"):
			return current
		current = current.get_parent()

	return null


func _apply_repair_tool_damage(target: Node, weapon: WeaponInstance3D) -> void:
	if target == null or weapon == null:
		return

	var damage_amount: int = max(weapon.repair_damage, 0)
	if damage_amount <= 0:
		return

	if target.has_method("apply_projectile_damage"):
		target.apply_projectile_damage(
			damage_amount,
			weapon.projectile_penetration,
			projectile_team,
			weapon.projectile_tk,
			self
		)
	elif target.has_method("apply_damage"):
		target.apply_damage(damage_amount)


func _collect_repair_tool_exclude_rids(node: Node, output: Array) -> void:
	if node == null or not is_instance_valid(node):
		return

	if node is CollisionObject3D:
		var rid := (node as CollisionObject3D).get_rid()
		if not output.has(rid):
			output.append(rid)

	for child in node.get_children():
		_collect_repair_tool_exclude_rids(child, output)

func _get_weapon_scene_by_id(weapon_id: String) -> PackedScene:
	match weapon_id:
		"pistol":
			return PISTOL_SCENE
		"smg":
			return SMG_SCENE
		"rifle":
			return RIFLE_SCENE
		"repair_tool":
			return REPAIR_TOOL_SCENE
		"bomb":
			return BOMB_SCENE
		"gravity_gun":
			return GRAVITY_GUN_SCENE
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
	current_weapon_slot = clampi(selected_slot, 0, 1)
	is_reloading_local = reloading
	reload_timer_local = max(remaining_reload, 0.0)
	_refresh_weapon_nodes()
	_apply_current_held_weapon_pose_immediately()

func _refresh_weapon_nodes() -> void:
	_clear_empty_weapon_instance()

	# Les références de weapon_nodes peuvent déjà avoir été libérées par un clear précédent.
	# On les libère avant de nettoyer les sockets, puis on annule les références pour éviter
	# de repasser un objet "previously freed" à une fonction typée.
	for node in weapon_nodes:
		_free_visual_node_now(node)

	weapon_nodes = [null, null]
	_clear_weapon_visual_sockets()

	for slot_index in range(2):
		var slot_state: Dictionary = weapon_slots[slot_index]
		if slot_state.is_empty():
			continue

		var scene: PackedScene = _get_weapon_scene_by_id(String(slot_state.get("weapon_id", "")))
		if scene == null:
			continue

		var weapon: WeaponInstance3D = scene.instantiate() as WeaponInstance3D
		if weapon == null:
			continue

		weapon.apply_runtime_state(slot_state)
		weapon_nodes[slot_index] = weapon
		_attach_weapon_node(slot_index, weapon)

	_ensure_empty_weapon_for_current_slot()
	_apply_current_held_weapon_pose_immediately()
	_refresh_procedural_hand_grips()
	call_deferred("_deferred_refresh_empty_weapon_after_socket_cleanup")

func _attach_weapon_node(slot_index: int, weapon: WeaponInstance3D) -> void:
	if weapon == null:
		return

	if slot_index == current_weapon_slot:
		if weapon_socket == null:
			return
		weapon_socket.add_child(weapon)
		weapon.position = _get_weapon_local_position(weapon)
		weapon.rotation = Vector3.ZERO
		if "hand_rotation_deg" in weapon:
			weapon.rotation_degrees = weapon.hand_rotation_deg
	else:
		var back_socket: Node3D = back_socket_1 if slot_index == 0 else back_socket_2
		if back_socket == null:
			return
		back_socket.add_child(weapon)
		if "back_position" in weapon:
			weapon.position = weapon.back_position
		else:
			weapon.position = Vector3.ZERO
		if "back_rotation_deg" in weapon:
			weapon.rotation_degrees = weapon.back_rotation_deg
		else:
			weapon.rotation_degrees = Vector3.ZERO

func _ensure_empty_weapon_for_current_slot() -> void:
	if not _should_show_empty_weapon_for_current_slot():
		_clear_empty_weapon_instance()
		return

	_remove_stale_held_weapon_visuals_for_empty_slot()

	if empty_weapon_instance != null and is_instance_valid(empty_weapon_instance) and not empty_weapon_instance.is_queued_for_deletion():
		if empty_weapon_instance.get_parent() != weapon_socket:
			empty_weapon_instance.reparent(weapon_socket)
		_configure_empty_weapon_instance()
		return

	var existing_empty_weapon: Node3D = _find_existing_empty_weapon_in_socket()
	if existing_empty_weapon != null:
		empty_weapon_instance = existing_empty_weapon
		_configure_empty_weapon_instance()
		return

	_attach_empty_weapon_node()


func _deferred_refresh_empty_weapon_after_socket_cleanup() -> void:
	_ensure_empty_weapon_for_current_slot()
	_apply_current_held_weapon_pose_immediately()
	_refresh_procedural_hand_grips()


func _should_show_empty_weapon_for_current_slot() -> bool:
	if not use_empty_weapon_when_unarmed:
		return false
	if weapon_socket == null:
		return false
	if empty_weapon_scene == null:
		return false
	if current_weapon_slot < 0 or current_weapon_slot >= weapon_slots.size():
		return false

	var slot_state: Dictionary = weapon_slots[current_weapon_slot]
	if slot_state.is_empty():
		return true

	# Sécurité : si le slot prétend avoir une arme mais que la scène n'a pas pu être instanciée,
	# on force quand même weapon_empty pour éviter une pose cassée.
	return _get_current_weapon_node() == null


func _find_existing_empty_weapon_in_socket() -> Node3D:
	if weapon_socket == null:
		return null

	for child in weapon_socket.get_children():
		if not (child is Node3D):
			continue
		if child.is_queued_for_deletion():
			continue
		if _is_empty_weapon_node(child):
			return child as Node3D

	return null


func _attach_empty_weapon_node() -> void:
	if not _should_show_empty_weapon_for_current_slot():
		return

	var instance: Node = empty_weapon_scene.instantiate()
	if not (instance is Node3D):
		if instance != null:
			instance.queue_free()
		push_warning("NetworkProceduralPlayer: weapon_empty doit avoir un root Node3D.")
		return

	empty_weapon_instance = instance as Node3D
	empty_weapon_instance.name = String(empty_weapon_node_name)
	weapon_socket.add_child(empty_weapon_instance)
	_configure_empty_weapon_instance()


func _configure_empty_weapon_instance() -> void:
	if empty_weapon_instance == null or not is_instance_valid(empty_weapon_instance):
		return

	empty_weapon_instance.visible = true
	empty_weapon_instance.position = _get_weapon_local_position(empty_weapon_instance)
	empty_weapon_instance.scale = Vector3.ONE

	if empty_weapon_use_neutral_rotation:
		empty_weapon_instance.rotation = Vector3.ZERO
	else:
		empty_weapon_instance.rotation = Vector3.ZERO

	# On force ces valeurs depuis le joueur pour que weapon_empty reste utilisable
	# même si la scène weapon_empty.tscn n'a pas encore les bons exports.
	if "weapon_local_position" in empty_weapon_instance:
		empty_weapon_instance.set("weapon_local_position", empty_weapon_local_position)
	if "left_grip_position" in empty_weapon_instance:
		empty_weapon_instance.set("left_grip_position", empty_weapon_left_grip_local_position)
	if "right_grip_position" in empty_weapon_instance:
		empty_weapon_instance.set("right_grip_position", empty_weapon_right_grip_local_position)

	var empty_left_grip: Node3D = empty_weapon_instance.find_child("LeftGrip", true, false) as Node3D
	if empty_left_grip != null:
		empty_left_grip.position = empty_weapon_left_grip_local_position

	var empty_right_grip: Node3D = empty_weapon_instance.find_child("RightGrip", true, false) as Node3D
	if empty_right_grip != null:
		empty_right_grip.position = empty_weapon_right_grip_local_position


func _clear_empty_weapon_instance() -> void:
	if empty_weapon_instance != null and is_instance_valid(empty_weapon_instance):
		_free_visual_node_now(empty_weapon_instance)
	empty_weapon_instance = null

	if weapon_socket == null:
		return

	for child in weapon_socket.get_children():
		if not (child is Node3D):
			continue
		if _is_empty_weapon_node(child):
			_free_visual_node_now(child)


func _clear_weapon_visual_sockets() -> void:
	_clear_children_from_socket(weapon_socket)
	_clear_children_from_socket(back_socket_1)
	_clear_children_from_socket(back_socket_2)


func _clear_children_from_socket(socket: Node3D) -> void:
	if socket == null:
		return

	for child in socket.get_children():
		if not (child is Node3D):
			continue
		_free_visual_node_now(child)


func _remove_stale_held_weapon_visuals_for_empty_slot() -> void:
	if weapon_socket == null:
		return

	for child in weapon_socket.get_children():
		if not (child is Node3D):
			continue
		if _is_empty_weapon_node(child):
			continue
		_free_visual_node_now(child)


func _free_visual_node_now(node) -> void:
	if node == null:
		return

	# Important : node peut être une ancienne référence vers un objet Godot déjà libéré.
	# Le paramètre reste volontairement non typé pour éviter l'erreur :
	# "previously freed is not a subclass of the expected argument class".
	if not is_instance_valid(node):
		return

	var node_to_free: Node = node as Node
	if node_to_free == null:
		return
	if node_to_free.is_queued_for_deletion():
		return

	var parent: Node = node_to_free.get_parent()
	if parent != null:
		parent.remove_child(node_to_free)
	node_to_free.free()


func _is_empty_weapon_node(node: Node) -> bool:
	if node == null:
		return false
	var node_name := String(node.name)
	return node_name == String(empty_weapon_node_name) or node_name.begins_with(String(empty_weapon_node_name) + "@")


func _get_current_held_visual_weapon() -> Node3D:
	var current_weapon := _get_current_weapon_node()
	if current_weapon != null:
		return current_weapon as Node3D

	_ensure_empty_weapon_for_current_slot()

	if empty_weapon_instance != null and is_instance_valid(empty_weapon_instance) and not empty_weapon_instance.is_queued_for_deletion():
		return empty_weapon_instance
	return null


func _apply_current_held_weapon_pose_immediately() -> void:
	var current_visual_weapon: Node3D = _get_current_held_visual_weapon()
	if current_visual_weapon == null:
		return

	current_visual_weapon.position = _get_weapon_local_position(current_visual_weapon)

	if current_visual_weapon == empty_weapon_instance:
		_configure_empty_weapon_instance()
		return

	current_visual_weapon.rotation = Vector3.ZERO
	if "hand_rotation_deg" in current_visual_weapon:
		current_visual_weapon.rotation_degrees = current_visual_weapon.hand_rotation_deg


func _apply_replicated_state(delta: float) -> void:
	global_position = global_position.lerp(replicated_position, min(delta * 12.0, 1.0))
	velocity = velocity.lerp(replicated_velocity, min(delta * 10.0, 1.0))

	var aim_lerp_weight: float = min(delta * 16.0, 1.0)
	if aim_root != null:
		aim_root.rotation.x = lerp_angle(aim_root.rotation.x, replicated_aim_rotation.x, aim_lerp_weight)
		aim_root.rotation.y = lerp_angle(aim_root.rotation.y, replicated_aim_rotation.y, aim_lerp_weight)
		aim_root.rotation.z = lerp_angle(aim_root.rotation.z, replicated_aim_rotation.z, aim_lerp_weight)
		aim_target_position = aim_root.global_position + (-aim_root.global_basis.z.normalized() * max(aim_projection_distance * 0.25, 4.0))
		last_valid_aim_target_position = aim_target_position

	visual_yaw = lerp_angle(visual_yaw, replicated_visual_y, aim_lerp_weight)

	if vehicle_mode != replicated_in_vehicle:
		vehicle_mode = replicated_in_vehicle
		_apply_vehicle_visual_state()

	if aim_cursor != null:
		aim_cursor.global_position = aim_target_position + Vector3.UP * 0.035

func apply_damage(amount: int, damage_source: Node = null) -> void:
	if not multiplayer.is_server():
		return
	if amount <= 0:
		return
	if not _can_receive_damage():
		return

	_server_cancel_revive(true)
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
	if not _can_receive_damage():
		return

	var effective_armor = max(armor_rating - to_projectile_penetration, 0)
	var final_damage = max(amount - effective_armor, 0)
	if final_damage <= 0:
		return

	apply_damage(final_damage, _source)

func request_respawn() -> void:
	if not is_dead:
		return
	if death_elapsed_time < respawn_delay_seconds and not multiplayer.is_server():
		return
	if GameSessionState.get_team_respawn_lives() <= 0 and not multiplayer.is_server():
		return

	if multiplayer.is_server():
		_server_respawn_player()
	else:
		_request_respawn_rpc.rpc_id(1)

func _on_hud_respawn_requested() -> void:
	request_respawn()


func _on_hud_spectate_next_requested() -> void:
	request_spectate_next()

func _server_die(damage_source: Node = null) -> void:
	if not multiplayer.is_server():
		return
	if is_dead:
		return

	var death_transform := global_transform
	var impulse_direction := _get_death_impulse_direction(damage_source)
	last_death_was_killzone = _is_killzone_damage_source(damage_source)
	_server_respawn_protection_until_msec = 0

	health = 0
	is_final_dead = false
	_server_final_death_synced = false
	_server_death_msec = Time.get_ticks_msec()
	_server_cancel_revive(true)
	_server_cancel_revives_targeting(self)
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

func _is_killzone_damage_source(damage_source: Node = null) -> bool:
	if damage_source == null or not is_instance_valid(damage_source):
		return false

	if damage_source.is_in_group("killzone") or damage_source.is_in_group("KillZone") or damage_source.is_in_group("killzones"):
		return true

	var source_name: String = String(damage_source.name).to_lower()
	if source_name.contains("killzone") or source_name.contains("kill_zone"):
		return true

	var parent: Node = damage_source.get_parent()
	while parent != null and is_instance_valid(parent):
		if parent.is_in_group("killzone") or parent.is_in_group("KillZone") or parent.is_in_group("killzones"):
			return true

		var parent_name: String = String(parent.name).to_lower()
		if parent_name.contains("killzone") or parent_name.contains("kill_zone"):
			return true

		parent = parent.get_parent()

	return false

func _is_server_respawn_protected() -> bool:
	if not multiplayer.is_server():
		return false
	if _server_respawn_protection_until_msec <= 0:
		return false

	var current_msec: int = Time.get_ticks_msec()
	if current_msec <= _server_respawn_protection_until_msec:
		return true

	_server_respawn_protection_until_msec = 0
	return false

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
	var was_dead: bool = is_dead

	health = clampi(value, 0, max_health)
	is_dead = true
	is_final_dead = false
	death_elapsed_time = 0.0
	_apply_revive_progress_state(false, 0, 0, "", 0.0)
	_stop_spectating()
	velocity = Vector3.ZERO
	replicated_position = death_transform.origin
	replicated_velocity = Vector3.ZERO
	replicated_is_grounded = true
	replicated_is_moving = false
	procedural_animation_velocity = Vector3.ZERO
	procedural_animation_moving = false
	global_transform = death_transform

	_cancel_local_reload()
	_cancel_server_reload()
	_set_body_collision_enabled(false)

	if not was_dead:
		_spawn_death_body(death_transform, impulse_direction)

	_set_procedural_visible(false)
	if camera != null:
		camera.current = is_multiplayer_authority()
	emit_signal("health_changed", health, max_health)

	if not was_dead:
		emit_signal("died")


func _server_final_death_tick() -> void:
	if not multiplayer.is_server():
		return
	if not is_dead or is_final_dead:
		return

	var delay: float = max(downed_to_final_death_seconds, 0.0)
	if delay <= 0.0:
		_server_set_final_dead()
		return

	var elapsed: float = death_elapsed_time
	if elapsed >= delay:
		_server_set_final_dead()


func _server_set_final_dead() -> void:
	if not multiplayer.is_server():
		return
	if not is_dead or is_final_dead:
		return

	is_final_dead = true
	_server_final_death_synced = true
	_server_cancel_revives_targeting(self)
	_apply_final_dead_state(true)
	_receive_final_dead_state.rpc(true)


func _apply_final_dead_state(final_dead_now: bool) -> void:
	is_final_dead = final_dead_now and is_dead
	if is_final_dead:
		_apply_revive_progress_state(false, 0, 0, "", 0.0)
	emit_signal("health_changed", health, max_health)


func _is_final_death_countdown_paused() -> bool:
	return is_dead and not is_final_dead and revive_active and revive_role == 2

func _spawn_death_body(death_transform: Transform3D, impulse_direction: Vector3) -> void:
	if not death_body_enabled:
		return

	_clear_death_body()

	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_parent()
	if parent == null:
		return

	var body: RigidBody3D = RigidBody3D.new()
	body.name = "PlayerDeathBody_%s" % player_id
	body.mass = max(death_body_mass, 0.1)
	body.collision_layer = death_body_collision_layer
	body.collision_mask = collision_mask if death_body_use_player_collision_mask else death_body_collision_mask
	body.linear_damp = death_body_linear_damp
	body.angular_damp = death_body_angular_damp
	body.can_sleep = true
	body.axis_lock_angular_y = death_body_lock_yaw_rotation

	parent.add_child(body)
	var body_transform: Transform3D = death_transform
	body_transform.origin += Vector3.UP * 0.05
	body.global_transform = body_transform
	death_body_node = body

	_duplicate_death_visual_part(body, visual_root, "VisualRoot")
	_duplicate_death_visual_part(body, limbs_root, "Limbs")
	_duplicate_death_visual_part(body, left_foot, "LeftFoot")
	_duplicate_death_visual_part(body, right_foot, "RightFoot")

	if collision_shape != null:
		var shape_copy: CollisionShape3D = collision_shape.duplicate() as CollisionShape3D
		if shape_copy != null:
			body.add_child(shape_copy)
			shape_copy.name = "CollisionShape3D"
			shape_copy.global_transform = collision_shape.global_transform
			shape_copy.disabled = false

	var direction: Vector3 = impulse_direction
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = -death_transform.basis.z
		direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	direction = direction.normalized()

	var random_horizontal: Vector3 = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	if random_horizontal.length_squared() > 0.0001:
		random_horizontal = random_horizontal.normalized() * death_body_random_impulse

	var impulse: Vector3 = direction * death_body_impulse_force + Vector3.UP * death_body_upward_impulse + random_horizontal
	body.apply_central_impulse(impulse)

	var knockdown_axis: Vector3 = direction.cross(Vector3.UP)
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
	if not _server_can_respawn_now():
		return
	if not GameSessionState.consume_team_respawn_life():
		_server_sync_team_respawn_lives_state()
		return

	_server_sync_team_respawn_lives_state()
	_server_cancel_revives_targeting(self)
	var spawn_transform: Transform3D = _get_respawn_transform_from_main()
	var respawn_health: int = max_health

	velocity = Vector3.ZERO
	current_weapon_slot = 0
	weapon_slots[0] = {}
	weapon_slots[1] = {}

	_cancel_server_reload()
	_cancel_local_reload()
	_sync_weapon_inventory_to_peers()

	_apply_respawn_state(spawn_transform, respawn_health)
	_receive_respawn_state.rpc(spawn_transform, respawn_health)

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
	_set_body_collision_enabled(false)

	_apply_revive_progress_state(false, 0, 0, "", 0.0)
	velocity = Vector3.ZERO
	replicated_position = spawn_transform.origin
	replicated_velocity = Vector3.ZERO
	replicated_aim_rotation = Vector3.ZERO
	replicated_visual_y = spawn_transform.basis.get_euler().y
	replicated_is_grounded = true
	replicated_is_moving = false
	replicated_in_vehicle = false
	procedural_animation_velocity = Vector3.ZERO
	procedural_animation_grounded = true
	procedural_animation_moving = false
	visual_yaw = replicated_visual_y

	global_transform = spawn_transform
	if aim_root != null:
		aim_root.rotation = Vector3.ZERO
	if visual_root != null:
		visual_root.rotation = Vector3.ZERO

	weapon_slots[0] = {}
	weapon_slots[1] = {}
	current_weapon_slot = 0
	_refresh_weapon_nodes()

	_cancel_local_reload()
	_cancel_server_reload()
	_set_procedural_visible(true)
	_reset_procedural_pose()

	health = clampi(health_value, 1, max_health)
	is_dead = false
	is_final_dead = false
	_server_final_death_synced = false
	death_elapsed_time = 0.0
	last_death_was_killzone = false
	if multiplayer.is_server():
		var grace_duration_msec: int = int(max(respawn_damage_grace_seconds, 0.0) * 1000.0)
		_server_respawn_protection_until_msec = Time.get_ticks_msec() + grace_duration_msec

	_set_body_collision_enabled(true)
	_stop_spectating()
	if camera != null:
		camera.current = is_multiplayer_authority()
	emit_signal("health_changed", health, max_health)

func _update_revive_input() -> void:
	if not _revive_input_action_exists():
		return

	if is_dead or is_in_vehicle() or ui_input_blocked:
		if _local_revive_button_down:
			_local_revive_button_down = false
			_request_cancel_revive()
		return

	if Input.is_action_just_pressed(revive_action):
		_local_revive_button_down = true
		_request_start_revive()
	elif Input.is_action_just_released(revive_action):
		_local_revive_button_down = false
		_request_cancel_revive()

func _revive_input_action_exists() -> bool:
	var action_name := String(revive_action)
	return not action_name.is_empty() and InputMap.has_action(action_name)

func _request_start_revive() -> void:
	if is_dead:
		return

	if multiplayer.is_server():
		_server_start_revive_nearest()
	else:
		_request_start_revive_rpc.rpc_id(1)

func _request_cancel_revive() -> void:
	if multiplayer.is_server():
		_server_cancel_revive(true)
	else:
		_request_cancel_revive_rpc.rpc_id(1)

func _server_start_revive_nearest() -> void:
	if not multiplayer.is_server():
		return
	if is_dead or is_in_vehicle():
		_server_cancel_revive(true)
		return

	var target := _server_find_nearest_revive_target()
	if target == null:
		_server_cancel_revive(true)
		return

	if _server_revive_target == target:
		return

	_server_cancel_revive(false)
	_server_revive_target = target
	_server_revive_progress = 0.0
	_server_sync_revive_pair(target, 0.0)


func _node_is_final_dead(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false

	for property_data in node.get_property_list():
		if str(property_data.get("name", "")) == "is_final_dead":
			return bool(node.get("is_final_dead"))

	return false

func _server_find_nearest_revive_target() -> Node:
	var closest: Node = null
	var closest_distance := INF

	for node in get_tree().get_nodes_in_group("players"):
		if node == self:
			continue
		if not (node is Node3D):
			continue
		if not is_instance_valid(node):
			continue
		if not bool(node.get("is_dead")):
			continue
		if _node_is_final_dead(node):
			continue

		var target_position := Vector3.ZERO
		if node.has_method("get_current_physical_body_position"):
			target_position = node.call("get_current_physical_body_position")
		else:
			target_position = (node as Node3D).global_position

		var distance := global_position.distance_to(target_position)
		if distance > revive_range:
			continue
		if distance < closest_distance:
			closest_distance = distance
			closest = node

	return closest

func _server_revive_tick(delta: float) -> void:
	if _server_revive_target == null:
		return

	if not _server_can_continue_revive(_server_revive_target):
		_server_cancel_revive(true)
		return

	_server_revive_progress = min(_server_revive_progress + delta, max(revive_duration, 0.01))
	var normalized_progress :float = clamp(_server_revive_progress / max(revive_duration, 0.01), 0.0, 1.0)
	_server_sync_revive_pair(_server_revive_target, normalized_progress)

	if normalized_progress >= 1.0:
		_server_finish_revive(_server_revive_target)

func _server_can_continue_revive(target: Node) -> bool:
	if not multiplayer.is_server():
		return false
	if is_dead or is_in_vehicle():
		return false
	if target == null or not is_instance_valid(target):
		return false
	if not bool(target.get("is_dead")):
		return false
	if _node_is_final_dead(target):
		return false

	var target_position := Vector3.ZERO
	if target.has_method("get_current_physical_body_position"):
		target_position = target.call("get_current_physical_body_position")
	elif target is Node3D:
		target_position = (target as Node3D).global_position
	else:
		return false

	return global_position.distance_to(target_position) <= revive_range

func _server_finish_revive(target: Node) -> void:
	if not multiplayer.is_server():
		return
	if target == null or not is_instance_valid(target):
		_server_cancel_revive(true)
		return

	var revived_health := 1
	var target_max_health := int(target.get("max_health"))
	if target_max_health > 0:
		revived_health = max(1, int(ceil(float(target_max_health) * revive_health_ratio)))

	_server_revive_target = null
	_server_revive_progress = 0.0
	_server_sync_single_revive_state(false, 0, null, 0.0)

	if target.has_method("_server_sync_single_revive_state"):
		target.call("_server_sync_single_revive_state", false, 0, null, 0.0)
	if target.has_method("_server_revive_from_physical_body"):
		target.call("_server_revive_from_physical_body", revived_health)

func _server_cancel_revive(sync_state: bool = true) -> void:
	if not multiplayer.is_server():
		return

	var old_target := _server_revive_target
	_server_revive_target = null
	_server_revive_progress = 0.0

	if sync_state:
		_server_sync_single_revive_state(false, 0, null, 0.0)
		if old_target != null and is_instance_valid(old_target) and old_target.has_method("_server_sync_single_revive_state"):
			old_target.call("_server_sync_single_revive_state", false, 0, null, 0.0)

func _server_cancel_revives_targeting(target: Node) -> void:
	if not multiplayer.is_server():
		return

	for node in get_tree().get_nodes_in_group("players"):
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_method("_server_get_revive_target"):
			continue
		var current_target = node.call("_server_get_revive_target")
		if current_target == target and node.has_method("_server_cancel_revive"):
			node.call("_server_cancel_revive", true)

func _server_get_revive_target() -> Node:
	return _server_revive_target

func _server_sync_revive_pair(target: Node, progress_value: float) -> void:
	_server_sync_single_revive_state(true, 1, target, progress_value)
	if target != null and is_instance_valid(target) and target.has_method("_server_sync_single_revive_state"):
		target.call("_server_sync_single_revive_state", true, 2, self, progress_value)

func _server_sync_single_revive_state(active: bool, role: int, other_player: Node, progress_value: float) -> void:
	if not multiplayer.is_server():
		return

	var other_id := 0
	var other_name := ""
	if other_player != null and is_instance_valid(other_player):
		other_id = int(other_player.get("player_id"))
		other_name = str(other_player.get("player_name"))

	_apply_revive_progress_state(active, role, other_id, other_name, progress_value)
	_receive_revive_progress_state.rpc(active, role, other_id, other_name, progress_value)

func _apply_revive_progress_state(active: bool, role: int, other_id: int, other_name: String, progress_value: float) -> void:
	revive_active = active
	revive_role = role if active else 0
	revive_other_player_id = other_id if active else 0
	revive_other_player_name = other_name if active else ""
	revive_progress = clamp(progress_value, 0.0, 1.0) if active else 0.0

func _server_revive_from_physical_body(health_value: int) -> void:
	if not multiplayer.is_server():
		return
	if not is_dead:
		return
	if is_final_dead:
		return

	_server_cancel_revives_targeting(self)

	var revive_transform: Transform3D = Transform3D.IDENTITY
	if last_death_was_killzone:
		revive_transform = _get_respawn_transform_from_main()
	else:
		revive_transform = get_current_physical_body_transform()
		var revive_position: Vector3 = revive_transform.origin
		revive_transform = Transform3D(Basis.IDENTITY, revive_position)

	var revived_health: int = clampi(health_value, 1, max_health)

	velocity = Vector3.ZERO
	current_weapon_slot = 0
	weapon_slots[0] = {}
	weapon_slots[1] = {}

	_cancel_server_reload()
	_cancel_local_reload()
	_sync_weapon_inventory_to_peers()

	_apply_respawn_state(revive_transform, revived_health)
	_receive_respawn_state.rpc(revive_transform, revived_health)

func _server_can_respawn_now() -> bool:
	if _server_death_msec <= 0:
		return death_elapsed_time >= respawn_delay_seconds

	var elapsed := float(Time.get_ticks_msec() - _server_death_msec) / 1000.0
	return elapsed >= respawn_delay_seconds

func get_current_physical_body_position() -> Vector3:
	if death_body_node != null and is_instance_valid(death_body_node):
		return death_body_node.global_position
	return global_position

func get_current_physical_body_transform() -> Transform3D:
	var result := global_transform
	if death_body_node != null and is_instance_valid(death_body_node):
		result.origin = death_body_node.global_position
		var yaw := death_body_node.global_transform.basis.get_euler().y
		result.basis = Basis(Vector3.UP, yaw)
	return result

func get_hud_name_marker_position() -> Vector3:
	return get_current_physical_body_position() + Vector3.UP * revive_name_height

func get_hud_camera() -> Camera3D:
	return camera

func get_hud_aim_target_position() -> Vector3:
	return aim_target_position



func request_spectate_next() -> void:
	if not is_multiplayer_authority():
		return
	if not is_dead:
		_stop_spectating()
		return

	var candidates: Array[Node] = _get_spectator_candidates()
	if candidates.is_empty():
		_stop_spectating()
		return

	var current_index: int = -1
	for i in range(candidates.size()):
		var candidate: Node = candidates[i]
		if candidate != null and is_instance_valid(candidate) and int(candidate.get("player_id")) == spectator_target_player_id:
			current_index = i
			break

	var next_index: int = (current_index + 1) % candidates.size()
	_apply_spectator_target(candidates[next_index])


func _get_spectator_candidates() -> Array[Node]:
	var candidates: Array[Node] = []
	for node in get_tree().get_nodes_in_group("players"):
		if node == null or not is_instance_valid(node):
			continue
		if not (node is Node3D):
			continue
		if not node.has_method("get_hud_camera"):
			continue
		var target_camera = node.call("get_hud_camera")
		if target_camera is Camera3D and is_instance_valid(target_camera):
			candidates.append(node)

	candidates.sort_custom(func(a: Node, b: Node) -> bool:
		return int(a.get("player_id")) < int(b.get("player_id"))
	)
	return candidates


func _apply_spectator_target(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		_stop_spectating()
		return

	var target_camera = target.call("get_hud_camera") if target.has_method("get_hud_camera") else null
	if not (target_camera is Camera3D) or not is_instance_valid(target_camera):
		_stop_spectating()
		return

	is_spectating = target != self
	spectator_target_player_id = int(target.get("player_id"))
	(target_camera as Camera3D).current = true

	if target == self:
		is_spectating = false


func _update_spectator_camera_state() -> void:
	if not is_spectating:
		return
	if not is_dead:
		_stop_spectating()
		return

	var target: Node = _get_player_by_id(spectator_target_player_id)
	if target == null or not is_instance_valid(target):
		request_spectate_next()
		return

	var target_camera = target.call("get_hud_camera") if target.has_method("get_hud_camera") else null
	if target_camera is Camera3D and is_instance_valid(target_camera) and not (target_camera as Camera3D).current:
		(target_camera as Camera3D).current = true


func _stop_spectating() -> void:
	if not is_multiplayer_authority():
		return
	is_spectating = false
	spectator_target_player_id = player_id
	if camera != null and is_instance_valid(camera):
		camera.current = true


func _get_player_by_id(target_player_id: int) -> Node:
	for node in get_tree().get_nodes_in_group("players"):
		if node != null and is_instance_valid(node) and int(node.get("player_id")) == target_player_id:
			return node
	return null


func get_spectator_target_name() -> String:
	var target: Node = _get_player_by_id(spectator_target_player_id)
	if target != null and is_instance_valid(target) and "player_name" in target:
		return str(target.get("player_name"))
	return player_name


func _server_sync_team_respawn_lives_state() -> void:
	if not multiplayer.is_server():
		return

	var remaining: int = GameSessionState.get_team_respawn_lives()
	var maximum: int = GameSessionState.get_max_team_respawn_lives()
	_apply_team_respawn_lives_state(remaining, maximum)
	_receive_team_respawn_lives_state.rpc(remaining, maximum)


func _apply_team_respawn_lives_state(remaining: int, maximum: int) -> void:
	GameSessionState.set_team_respawn_lives(remaining, maximum)


func get_hud_data() -> Dictionary:
	var vehicle := _get_current_vehicle_for_hud()
	var to_equipped_weapon := get_equipped_weapon()
	var weapon_1 := get_weapon_in_slot(0)
	var weapon_2 := get_weapon_in_slot(1)

	return {
		"hp": health,
		"is_dead": is_dead,
		"is_final_dead": is_final_dead,
		"max_hp": max_health,
		"respawn_delay": respawn_delay_seconds,
		"death_elapsed": death_elapsed_time,
		"respawn_remaining": max(respawn_delay_seconds - death_elapsed_time, 0.0),
		"respawn_available": death_elapsed_time >= respawn_delay_seconds and GameSessionState.get_team_respawn_lives() > 0,
		"team_respawn_lives": GameSessionState.get_team_respawn_lives(),
		"team_respawn_lives_max": GameSessionState.get_max_team_respawn_lives(),
		"final_death_delay": downed_to_final_death_seconds,
		"final_death_elapsed": death_elapsed_time,
		"final_death_remaining": max(downed_to_final_death_seconds - death_elapsed_time, 0.0),
		"final_death_progress": 1.0 if downed_to_final_death_seconds <= 0.0 else clamp(death_elapsed_time / downed_to_final_death_seconds, 0.0, 1.0),
		"final_death_timer_paused": _is_final_death_countdown_paused(),
		"spectating": is_spectating,
		"spectator_target_player_id": spectator_target_player_id,
		"spectator_target_name": get_spectator_target_name(),
		"revive_active": revive_active,
		"revive_role": revive_role,
		"revive_other_player_id": revive_other_player_id,
		"revive_other_player_name": revive_other_player_name,
		"revive_progress": revive_progress,
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
		"reload_active": is_reloading_local,
		"reload_remaining": max(reload_timer_local, 0.0),
		"reload_duration": _hud_reload_duration(to_equipped_weapon),
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

func _hud_reload_duration(weapon: Node) -> float:
	var typed_weapon: WeaponInstance3D = weapon as WeaponInstance3D
	if typed_weapon == null:
		return 0.0

	return max(float(typed_weapon.reload_duration), 0.0)

func get_equipped_weapon() -> Node:
	return _get_current_weapon_node()

func get_weapon_in_slot(slot_index: int) -> Node:
	if slot_index < 0 or slot_index >= weapon_nodes.size():
		return null
	return weapon_nodes[slot_index]


func _apply_health_state(value: int, dead_now: bool) -> void:
	var previous_health: int = health
	health = clampi(value, 0, max_health)
	var was_dead: bool = is_dead
	is_dead = dead_now
	if health < previous_health:
		emit_signal("damage_taken", previous_health - health)
	emit_signal("health_changed", health, max_health)

	if is_dead:
		velocity = Vector3.ZERO
		_set_body_collision_enabled(false)
		_set_procedural_visible(false)
		if not was_dead:
			emit_signal("died")
	else:
		is_final_dead = false
		_stop_spectating()
		_set_body_collision_enabled(true)
		_apply_vehicle_visual_state()

func _apply_vehicle_visual_state() -> void:
	if is_dead:
		_set_procedural_visible(false)
		return

	if vehicle_mode and hide_player_visuals_when_in_vehicle:
		_set_procedural_visible(false)
		return

	_set_procedural_visible(true)


func _apply_camera_spring_length_for_vehicle_mode(in_vehicle: bool, instant: bool = false) -> void:
	camera_spring_length_target = camera_vehicle_spring_length if in_vehicle else camera_on_foot_spring_length

	if camera_spring_arm == null:
		camera_spring_arm = _find_camera_spring_arm()

	if camera_spring_arm == null:
		return

	if camera_spring_length_tween != null and camera_spring_length_tween.is_valid():
		camera_spring_length_tween.kill()
		camera_spring_length_tween = null

	if instant or camera_spring_length_tween_duration <= 0.0:
		camera_spring_arm.spring_length = camera_spring_length_target
		return

	camera_spring_length_tween = create_tween()
	camera_spring_length_tween.set_trans(Tween.TRANS_CUBIC)
	camera_spring_length_tween.set_ease(Tween.EASE_OUT)
	camera_spring_length_tween.tween_property(camera_spring_arm, "spring_length", camera_spring_length_target, camera_spring_length_tween_duration)


func _apply_camera_dof_for_vehicle_mode(in_vehicle: bool, instant: bool = false) -> void:
	camera_dof_far_distance_target = camera_vehicle_dof_far_distance if in_vehicle else camera_on_foot_dof_far_distance

	var attributes: CameraAttributes = _get_camera_dof_attributes()
	if attributes == null:
		return

	if not _object_has_property(attributes, &"dof_blur_far_distance"):
		return

	if camera_dof_far_distance_tween != null and camera_dof_far_distance_tween.is_valid():
		camera_dof_far_distance_tween.kill()
		camera_dof_far_distance_tween = null

	if instant or camera_spring_length_tween_duration <= 0.0:
		attributes.set("dof_blur_far_distance", camera_dof_far_distance_target)
		return

	camera_dof_far_distance_tween = create_tween()
	camera_dof_far_distance_tween.set_trans(Tween.TRANS_CUBIC)
	camera_dof_far_distance_tween.set_ease(Tween.EASE_OUT)
	camera_dof_far_distance_tween.tween_property(attributes, "dof_blur_far_distance", camera_dof_far_distance_target, camera_spring_length_tween_duration)


func _get_camera_dof_attributes() -> CameraAttributes:
	if camera == null:
		camera = _find_camera()

	if camera == null:
		return null

	var attributes: CameraAttributes = camera.attributes
	if attributes == null:
		return null

	if not attributes.resource_local_to_scene:
		var unique_attributes: CameraAttributes = attributes.duplicate(true) as CameraAttributes
		if unique_attributes != null:
			unique_attributes.resource_local_to_scene = true
			camera.attributes = unique_attributes
			attributes = unique_attributes

	return attributes


func _object_has_property(target: Object, property_name: StringName) -> bool:
	if target == null:
		return false

	for property_data in target.get_property_list():
		if StringName(property_data.get("name", "")) == property_name:
			return true

	return false


func _find_camera_spring_arm() -> SpringArm3D:
	var spring_arm: SpringArm3D = get_node_or_null("CameraRig/SpringArm3D") as SpringArm3D
	if spring_arm != null:
		return spring_arm

	if camera != null:
		var parent := camera.get_parent()
		if parent is SpringArm3D:
			return parent as SpringArm3D

	return null


func _find_camera() -> Camera3D:
	var direct_camera: Camera3D = get_node_or_null("CameraRig/Camera3D") as Camera3D
	if direct_camera != null:
		return direct_camera

	var spring_camera: Camera3D = get_node_or_null("CameraRig/SpringArm3D/Camera3D") as Camera3D
	if spring_camera != null:
		return spring_camera

	return get_viewport().get_camera_3d()


func _validate_procedural_scene_nodes() -> bool:
	var missing_nodes: Array[String] = []
	var required_nodes: Dictionary = {
		"VisualRoot": visual_root,
		"VisualRoot/WeaponSocket": weapon_socket,
		"VisualRoot/LeftHip": left_hip,
		"VisualRoot/RightHip": right_hip,
		"VisualRoot/LeftShoulder": left_shoulder,
		"VisualRoot/RightShoulder": right_shoulder,
		"FootProbeRoot": foot_probe_root,
		"FootProbeRoot/LeftFootProbe": left_probe,
		"FootProbeRoot/RightFootProbe": right_probe,
		"Feet/LeftFoot": left_foot,
		"Feet/RightFoot": right_foot,
		"CameraRig/SpringArm3D/Camera3D": camera,
		"AimRoot": aim_root,
	}

	for node_path: String in required_nodes.keys():
		if required_nodes[node_path] == null:
			missing_nodes.append(node_path)

	if not missing_nodes.is_empty():
		push_error("NetworkProceduralPlayer: nodes obligatoires manquants: " + ", ".join(missing_nodes))
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
		push_warning("NetworkProceduralPlayer: membres manquants, ils seront ignorés: " + ", ".join(missing_limb_nodes))

	return true


func _reset_procedural_pose() -> void:
	if not procedural_nodes_ready:
		return

	visual_yaw = global_transform.basis.get_euler().y
	if foot_probe_root != null:
		foot_probe_root.rotation.y = visual_yaw

	if placeholder_left_grip != null:
		placeholder_left_grip.position = fallback_left_grip_local_position
	if placeholder_right_grip != null:
		placeholder_right_grip.position = fallback_right_grip_local_position

	left_foot.global_position = _sample_grounded_foot_position(-1.0, Vector3.ZERO, 0.0, true)
	right_foot.global_position = _sample_grounded_foot_position(1.0, Vector3.ZERO, PI, true)
	aim_target_position = global_position + Vector3.FORWARD * 2.0 + Vector3.UP * aim_target_height_offset
	last_valid_aim_target_position = aim_target_position
	_refresh_procedural_hand_grips()


func _set_procedural_visible(visible_value: bool) -> void:
	if visual_root != null:
		visual_root.visible = visible_value
	if limbs_root != null:
		limbs_root.visible = visible_value
	if left_foot != null:
		left_foot.visible = false
	if right_foot != null:
		right_foot.visible = false
	if aim_cursor != null:
		aim_cursor.visible = visible_value and is_multiplayer_authority() and not is_dead


func _update_procedural_animation(delta: float) -> void:
	if not procedural_nodes_ready:
		return
	if is_dead:
		return

	_update_procedural_animation_state(delta)
	_update_feet(delta)
	_update_visuals(delta)


func _update_procedural_animation_state(delta: float) -> void:
	if is_multiplayer_authority():
		procedural_animation_velocity = velocity
		procedural_animation_grounded = is_on_floor()
		procedural_animation_moving = Vector3(velocity.x, 0.0, velocity.z).length() > remote_animation_move_threshold
		if is_in_vehicle():
			procedural_animation_velocity = Vector3.ZERO
			procedural_animation_grounded = true
			procedural_animation_moving = false
		return

	var target_velocity: Vector3 = replicated_velocity
	if replicated_in_vehicle or not replicated_is_moving:
		target_velocity.x = 0.0
		target_velocity.z = 0.0

	var velocity_lerp_weight: float = min(delta * remote_animation_velocity_lerp_speed, 1.0)
	procedural_animation_velocity = procedural_animation_velocity.lerp(target_velocity, velocity_lerp_weight)
	procedural_animation_grounded = replicated_is_grounded
	procedural_animation_moving = replicated_is_moving and not replicated_in_vehicle


func _get_procedural_horizontal_velocity() -> Vector3:
	var source_velocity: Vector3 = procedural_animation_velocity if not is_multiplayer_authority() else velocity
	var horizontal_velocity: Vector3 = Vector3(source_velocity.x, 0.0, source_velocity.z)

	if not is_multiplayer_authority() and procedural_animation_moving:
		if horizontal_velocity.length() <= remote_animation_move_threshold:
			var yaw_basis: Basis = Basis(Vector3.UP, visual_yaw)
			var fallback_forward: Vector3 = -yaw_basis.z.normalized()
			horizontal_velocity = fallback_forward * move_speed * remote_animation_fallback_speed_ratio

	return horizontal_velocity


func _is_procedural_grounded() -> bool:
	if is_multiplayer_authority():
		return is_on_floor()
	return procedural_animation_grounded


func _refresh_procedural_hand_grips() -> void:
	left_grip = placeholder_left_grip
	right_grip = placeholder_right_grip

	var current_visual_weapon: Node3D = _get_current_held_visual_weapon()
	if current_visual_weapon == null:
		return

	var found_left: Node = current_visual_weapon.find_child("LeftGrip", true, false)
	var found_right: Node = current_visual_weapon.find_child("RightGrip", true, false)

	if found_left is Node3D:
		left_grip = found_left as Node3D
	else:
		push_warning("NetworkProceduralPlayer: l'arme tenue n'a pas de node3D LeftGrip: " + current_visual_weapon.name)

	if found_right is Node3D:
		right_grip = found_right as Node3D
	else:
		push_warning("NetworkProceduralPlayer: l'arme tenue n'a pas de node3D RightGrip: " + current_visual_weapon.name)


func _get_weapon_local_position(weapon: Node) -> Vector3:
	if weapon != null and _is_empty_weapon_node(weapon):
		return empty_weapon_local_position

	if weapon != null:
		var weapon_pose = weapon.get("weapon_local_position")
		if weapon_pose is Vector3:
			var typed_weapon_pose: Vector3 = weapon_pose
			return typed_weapon_pose

		var hand_pose = weapon.get("hand_position")
		if hand_pose is Vector3:
			var typed_hand_pose: Vector3 = hand_pose
			return typed_hand_pose

	return weapon_local_position


func _duplicate_death_visual_part(body: RigidBody3D, source: Node3D, copy_name: String) -> void:
	if body == null or source == null:
		return

	var visual_copy: Node3D = source.duplicate() as Node3D
	if visual_copy == null:
		return

	body.add_child(visual_copy)
	visual_copy.name = copy_name
	visual_copy.global_transform = source.global_transform
	visual_copy.visible = true
	_force_node_visible(visual_copy)
	visual_copy.process_mode = Node.PROCESS_MODE_DISABLED


func _update_feet(delta: float) -> void:
	var horizontal_velocity: Vector3 = _get_procedural_horizontal_velocity()
	var speed_ratio: float = clamp(horizontal_velocity.length() / move_speed, 0.0, 1.0)
	var grounded: bool = _is_procedural_grounded()

	if grounded and speed_ratio > 0.03:
		walk_phase += delta * lerp(3.0, gait_frequency, speed_ratio)

	if foot_probe_root != null:
		foot_probe_root.rotation.y = visual_yaw

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
	visual_root.rotation = Vector3(pitch, visual_yaw, roll)
	visual_root.scale = Vector3(1.0 + abs(squash) * 0.45, 1.0 - squash, 1.0 + abs(squash) * 0.25)


func _update_weapon_pose(delta: float) -> void:
	var current_visual_weapon: Node3D = _get_current_held_visual_weapon()
	_hide_lasers_except(current_visual_weapon)

	if current_visual_weapon == null:
		_refresh_procedural_hand_grips()
		return

	var current_weapon_local_position: Vector3 = current_visual_weapon.position
	var target_local_position: Vector3 = _get_weapon_local_position(current_visual_weapon)
	current_visual_weapon.position = current_weapon_local_position.lerp(target_local_position, min(delta * weapon_follow_speed, 1.0))

	if current_visual_weapon == empty_weapon_instance:
		# Arme factice : elle sert uniquement à placer les mains.
		# Elle ne doit pas reprendre l'orientation d'un fusil ou viser la target.
		if empty_weapon_use_neutral_rotation:
			current_visual_weapon.rotation = Vector3.ZERO
		_set_weapon_laser_visible(current_visual_weapon, false)
		_refresh_procedural_hand_grips()
		return

	var weapon_to_target: Vector3 = aim_target_position - current_visual_weapon.global_position
	var flat_weapon_to_target: Vector3 = weapon_to_target
	flat_weapon_to_target.y = 0.0

	if flat_weapon_to_target.length() < aim_min_target_distance:
		_set_weapon_laser_visible(current_visual_weapon, false)
		return

	if weapon_to_target.length_squared() > 0.001:
		current_visual_weapon.look_at(aim_target_position, Vector3.UP)
		current_visual_weapon.rotation.z = 0.0

	_update_current_weapon_laser(current_visual_weapon)
	_refresh_procedural_hand_grips()

func _update_current_weapon_laser(current_visual_weapon: Node3D) -> void:
	if current_visual_weapon == null:
		return
	if not show_weapon_laser_sight or is_dead or is_in_vehicle():
		_set_weapon_laser_visible(current_visual_weapon, false)
		return
	if not current_visual_weapon.has_method("get_muzzle_transform"):
		_set_weapon_laser_visible(current_visual_weapon, false)
		return

	var laser := _get_weapon_laser_node(current_visual_weapon)
	if laser == null or not laser.has_method("set_laser_segment"):
		return

	var muzzle_value = current_visual_weapon.call("get_muzzle_transform")
	if not (muzzle_value is Transform3D):
		_set_weapon_laser_visible(current_visual_weapon, false)
		return

	var muzzle_transform: Transform3D = muzzle_value
	var start_position: Vector3 = muzzle_transform.origin
	var end_position: Vector3 = aim_target_position
	if start_position.distance_to(end_position) < weapon_laser_min_length:
		_set_weapon_laser_visible(current_visual_weapon, false)
		return

	laser.call("set_laser_segment", start_position, end_position)

func _get_weapon_laser_node(weapon_node: Node) -> Node:
	if weapon_node == null:
		return null
	var laser := weapon_node.get_node_or_null("WeaponLaserSight")
	if laser != null:
		return laser
	laser = weapon_node.get_node_or_null("WeaponLaserSight3D")
	if laser != null:
		return laser
	return null

func _set_weapon_laser_visible(weapon_node: Node, active: bool) -> void:
	var laser := _get_weapon_laser_node(weapon_node)
	if laser == null:
		return
	if laser.has_method("set_laser_visible"):
		laser.call("set_laser_visible", active)
	elif laser is Node3D:
		(laser as Node3D).visible = active

func _hide_lasers_except(current_visual_weapon: Node3D) -> void:
	for weapon_node in weapon_nodes:
		if weapon_node == null or not is_instance_valid(weapon_node):
			continue
		if weapon_node == current_visual_weapon:
			continue
		_set_weapon_laser_visible(weapon_node, false)

	if empty_weapon_instance != null and empty_weapon_instance != current_visual_weapon:
		_set_weapon_laser_visible(empty_weapon_instance, false)

func set_weapon_pose(new_weapon_local_position: Vector3, new_left_grip_local_position: Vector3, new_right_grip_local_position: Vector3) -> void:
	weapon_local_position = new_weapon_local_position
	fallback_left_grip_local_position = new_left_grip_local_position
	fallback_right_grip_local_position = new_right_grip_local_position
	if placeholder_left_grip != null:
		placeholder_left_grip.position = fallback_left_grip_local_position
	if placeholder_right_grip != null:
		placeholder_right_grip.position = fallback_right_grip_local_position


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

	var left_knee: Vector3 = _solve_two_bone_joint(
		left_hip.global_position,
		left_foot.global_position,
		(body_forward + body_right * -0.25).normalized(),
		upper_leg_length,
		lower_leg_length
	)
	var right_knee: Vector3 = _solve_two_bone_joint(
		right_hip.global_position,
		right_foot.global_position,
		(body_forward + body_right * 0.25).normalized(),
		upper_leg_length,
		lower_leg_length
	)

	_place_segment_between_points(left_upper_leg, left_hip.global_position, left_knee)
	_place_segment_between_points(left_lower_leg, left_knee, left_foot.global_position)
	_place_segment_between_points(right_upper_leg, right_hip.global_position, right_knee)
	_place_segment_between_points(right_lower_leg, right_knee, right_foot.global_position)

	var left_elbow: Vector3 = _solve_two_bone_joint(
		left_shoulder.global_position,
		left_grip.global_position,
		(-body_forward + body_right * -1.00).normalized(),
		upper_arm_length,
		lower_arm_length
	)
	var right_elbow: Vector3 = _solve_two_bone_joint(
		right_shoulder.global_position,
		right_grip.global_position,
		(-body_forward + body_right * 0.70).normalized(),
		upper_arm_length,
		lower_arm_length
	)

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

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _receive_state(
	position_value: Vector3,
	velocity_value: Vector3,
	aim_rotation: Vector3,
	visual_yaw_value: float,
	grounded_value: bool,
	moving_value: bool,
	in_vehicle_value: bool
) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() != 0:
		if not _is_valid_state_sender():
			return
		_receive_state.rpc(
			position_value,
			velocity_value,
			aim_rotation,
			visual_yaw_value,
			grounded_value,
			moving_value,
			in_vehicle_value
		)

	if is_multiplayer_authority():
		return
	if is_dead:
		replicated_position = global_position
		replicated_velocity = Vector3.ZERO
		replicated_is_grounded = true
		replicated_is_moving = false
		replicated_in_vehicle = false
		return

	replicated_position = position_value
	replicated_velocity = velocity_value
	replicated_aim_rotation = aim_rotation
	replicated_visual_y = visual_yaw_value
	replicated_is_grounded = grounded_value
	replicated_is_moving = moving_value
	replicated_in_vehicle = in_vehicle_value

	if in_vehicle_value:
		replicated_velocity = Vector3.ZERO
		replicated_is_grounded = true
		replicated_is_moving = false


func _is_valid_state_sender() -> bool:
	if not multiplayer.is_server():
		return true

	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		return true

	var expected_id: int = get_multiplayer_authority()
	if expected_id == 0:
		expected_id = player_id

	return sender_id == expected_id

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

	weapon.apply_runtime_state(slot_state)
	if _is_repair_tool_weapon(weapon):
		weapon.free()
		return

	_spawn_visual_bullet_from_weapon(weapon, shot_origin, shot_direction)
	weapon.free()

@rpc("any_peer", "reliable")
func _request_fire_weapon(slot_index: int, shot_origin: Vector3, shot_direction: Vector3) -> void:
	if not _is_valid_owner_request("fire_weapon"):
		return

	_server_fire_weapon(slot_index, shot_origin, shot_direction.normalized())

@rpc("any_peer", "call_remote", "reliable")
func _request_context_interaction_rpc() -> void:
	if not _is_valid_owner_request("context_interaction"):
		return

	var did_interact: bool = _server_interact_nearest_gate_button()
	if not did_interact:
		_server_pickup_nearest_weapon()

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
func _spawn_world_weapon_remote(net_id: int, state: Dictionary, spawn_position: Vector3, forward: Vector3) -> void:
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

	_spawn_world_weapon_local(net_id, state, spawn_position, forward)

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
func _request_start_revive_rpc() -> void:
	if not _is_valid_owner_request("start_revive"):
		return

	_server_start_revive_nearest()

@rpc("any_peer", "reliable")
func _request_cancel_revive_rpc() -> void:
	if not _is_valid_owner_request("cancel_revive"):
		return

	_server_cancel_revive(true)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _receive_revive_progress_state(active: bool, role: int, other_id: int, other_name: String, progress_value: float) -> void:
	if not multiplayer.is_server() and multiplayer.get_remote_sender_id() != 1:
		return

	_apply_revive_progress_state(active, role, other_id, other_name, progress_value)

@rpc("any_peer", "call_remote", "reliable")
func _receive_final_dead_state(final_dead_now: bool) -> void:
	if not multiplayer.is_server() and multiplayer.get_remote_sender_id() != 1:
		return

	_apply_final_dead_state(final_dead_now)


@rpc("any_peer", "call_remote", "reliable")
func _receive_team_respawn_lives_state(remaining: int, maximum: int) -> void:
	if not multiplayer.is_server() and multiplayer.get_remote_sender_id() != 1:
		return

	_apply_team_respawn_lives_state(remaining, maximum)


@rpc("any_peer", "reliable")
func _request_apply_fall_damage_rpc(fall_damage: int, fall_height: float, impact_speed: float) -> void:
	if not _is_valid_owner_request("fall_damage"):
		return
	if is_dead:
		return
	if fall_damage <= 0:
		return

	# Le serveur recalcule avec ses exports pour éviter un dégât arbitraire envoyé par le client.
	var server_damage: int = _get_fall_damage(max(fall_height, 0.0), max(impact_speed, 0.0))
	if server_damage <= 0:
		return

	apply_damage(server_damage, self)


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
