extends RigidBody3D
class_name WorldWeapon3D

const PISTOL_SCENE := preload("uid://dd33dmmqhjkul")
const SMG_SCENE := preload("uid://nykf7fy7m5jg")
const RIFLE_SCENE := preload("uid://dluj1jv7g4ocm")
const REPAIR_TOOL_SCENE := preload("res://scenes/weapons/RepairToolWeapon.tscn")
const BOMB_SCENE := preload("res://scenes/weapons/BombWeapon.tscn")
const GRAVITY_GUN_SCENE := preload("res://scenes/weapons/GravityGunWeapon.tscn")
const ENCRYPTION_REMOTE_SCENE := preload("res://scenes/weapons/EncryptionRemoteWeapon.tscn")

@export var state_send_interval: float = 0.05

@export_enum("pistol", "smg", "rifle", "repair_tool", "bomb", "gravity_gun", "encryption_remote") var editor_weapon_id: String = "pistol"
@export var editor_ammo_in_magazine: int = 12
@export var editor_reserve_ammo: int = 36
@export var editor_spawn_on_ready: bool = true

@onready var visual_socket: Node3D = $VisualSocket

@onready var label_3d = %Label3D


var net_id: int = -1
var weapon_visual: WeaponInstance3D
var replicated_transform: Transform3D
var state_timer: float = 0.0
var is_despawning: bool = false
var current_weapon_id: String = ""
var objective_origin_transform: Transform3D = Transform3D.IDENTITY
var objective_origin_initialized: bool = false

signal lost(world_weapon: WorldWeapon3D)

static func get_weapon_scene_by_id(weapon_id: String) -> PackedScene:
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
		"encryption_remote":
			return ENCRYPTION_REMOTE_SCENE
		_:
			return null

func _ready() -> void:
	add_to_group("world_weapon")
	replicated_transform = global_transform
	_set_objective_origin_transform(global_transform)
	
	if is_instance_valid(label_3d):
		label_3d.hide()
	
	if editor_spawn_on_ready:
		setup_from_state(editor_weapon_id, editor_ammo_in_magazine, editor_reserve_ammo)

	if not multiplayer.is_server():
		freeze = true
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO

func setup_from_state(weapon_id: String, ammo_in_magazine: int, reserve_ammo: int, extra_state: Dictionary = {}) -> void:
	_clear_visual()
	current_weapon_id = weapon_id

	if extra_state.has("objective_origin_transform") and extra_state["objective_origin_transform"] is Transform3D:
		_set_objective_origin_transform(extra_state["objective_origin_transform"])

	var scene: PackedScene = get_weapon_scene_by_id(weapon_id)
	if scene == null:
		push_error("Unknown weapon_id on world weapon: %s" % weapon_id)
		return

	weapon_visual = scene.instantiate() as WeaponInstance3D
	visual_socket.add_child(weapon_visual)
	weapon_visual.apply_runtime_state({
		"ammo_in_magazine": ammo_in_magazine,
		"reserve_ammo": reserve_ammo,
	})

func get_weapon_state() -> Dictionary:
	if weapon_visual == null:
		return {}

	var state: Dictionary = weapon_visual.to_runtime_state()
	if _is_objective_item():
		state["objective_origin_transform"] = objective_origin_transform

	return state

func apply_spawn_impulse(forward: Vector3) -> void:
	if not multiplayer.is_server():
		return

	var dir: Vector3 = forward.normalized()
	if dir == Vector3.ZERO:
		dir = Vector3.FORWARD

	linear_velocity = dir * 6.0 + Vector3.UP * 2.5
	angular_velocity = Vector3(
		randf_range(-3.0, 3.0),
		randf_range(-8.0, 8.0),
		randf_range(-3.0, 3.0)
	)

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		state_timer -= delta
		if state_timer <= 0.0:
			state_timer = state_send_interval
			_receive_world_state.rpc(global_transform)
	else:
		var weight: float = min(delta * 14.0, 1.0)
		global_position = global_position.lerp(replicated_transform.origin, weight)
		var current_q: Quaternion = global_basis.get_rotation_quaternion()
		var target_q: Quaternion = replicated_transform.basis.get_rotation_quaternion()
		global_basis = Basis(current_q.slerp(target_q, weight))

func _clear_visual() -> void:
	for child in visual_socket.get_children():
		child.queue_free()
	weapon_visual = null

func set_objective_origin_transform(new_transform: Transform3D) -> void:
	objective_origin_transform = new_transform
	objective_origin_initialized = true


func _set_objective_origin_transform(new_transform: Transform3D) -> void:
	set_objective_origin_transform(new_transform)


func _is_objective_item() -> bool:
	if current_weapon_id == "bomb" or current_weapon_id == "encryption_remote":
		return true

	if weapon_visual != null and "weapon_behavior" in weapon_visual:
		return str(weapon_visual.weapon_behavior).to_lower() == "objective_item"

	return false


func is_objective_bomb() -> bool:
	return current_weapon_id == "bomb"


func is_encryption_remote() -> bool:
	return current_weapon_id == "encryption_remote"


func handle_killzone_entered(killzone: Node) -> bool:
	if not _is_objective_item():
		return false

	if not multiplayer.is_server():
		return true

	_reset_objective_item_to_origin()
	_notify_lost.rpc()
	return true


func _reset_objective_item_to_origin() -> void:
	if not objective_origin_initialized:
		_set_objective_origin_transform(global_transform)

	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = objective_origin_transform
	replicated_transform = objective_origin_transform
	sleeping = false
	state_timer = 0.0
	_receive_world_state.rpc(global_transform)


@rpc("authority", "call_local", "reliable")
func _notify_lost() -> void:
	lost.emit(self)


func despawn() -> void:
	if is_despawning:
		return

	if multiplayer.is_server():
		is_despawning = true
		_despawn.rpc()
	else:
		_request_despawn.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_despawn() -> void:
	if not multiplayer.is_server():
		return

	if is_despawning:
		return

	is_despawning = true
	_despawn.rpc()


@rpc("authority", "call_local", "reliable")
func _despawn() -> void:
	queue_free()

@rpc("authority", "call_remote", "unreliable_ordered")
func _receive_world_state(new_transform: Transform3D) -> void:
	if multiplayer.is_server():
		return

	replicated_transform = new_transform
