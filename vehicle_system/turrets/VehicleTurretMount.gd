extends Node3D
class_name VehicleTurretMount

@export_range(1, 4, 1) var seat_index: int = 1
@export var seat_label: String = "Siège"
@export_range(0, 4, 1) var turret_size: int = 0
@export var driver_turret: bool = false
@export var turret_scene: PackedScene

var vehicle: Vehicle = null
var turret: VehicleTurretBase = null


func _ready() -> void:
	if not is_in_group("vehicle_turret_mount"):
		add_to_group("vehicle_turret_mount")


func initialize(owner_vehicle: Vehicle) -> void:
	vehicle = owner_vehicle

	if turret_size <= 0:
		_clear_turret()
		return

	if turret_scene != null and turret == null:
		_spawn_turret(turret_scene)

	if turret != null:
		turret.setup(self, vehicle)


func has_turret() -> bool:
	return turret != null


func can_peer_operate(peer_id: int) -> bool:
	return vehicle != null and vehicle.get_seat_index_for_peer(peer_id) == seat_index and turret != null


func get_operator_peer_id() -> int:
	if vehicle == null:
		return -1
	return vehicle.get_seat_occupant(seat_index)


func get_current_global_yaw() -> float:
	if turret == null:
		return global_rotation.y
	return turret.get_current_global_yaw()


func get_turret_label() -> String:
	if turret == null:
		return ""
	return turret.turret_label


func get_turret_price() -> int:
	if turret == null:
		return 0
	return turret.turret_price


func get_turret_scene_path() -> String:
	if turret_scene == null:
		return ""
	return turret_scene.resource_path


func get_empty_reason() -> String:
	if driver_turret:
		return "Tourelle conducteur permanente"
	if turret_size <= 0:
		return "Aucun emplacement de tourelle"
	if has_turret():
		return "Emplacement déjà occupé"
	return "Emplacement libre"


func preview_local_aim_target(aim_world: Vector3) -> void:
	if turret != null:
		turret.preview_local_aim_target(aim_world)


func apply_host_input(peer_id: int, aim_world: Vector3, wants_fire: bool) -> void:
	if not multiplayer.is_server():
		return

	if not can_peer_operate(peer_id):
		return

	if turret != null:
		turret.apply_host_input(peer_id, aim_world, wants_fire)


func on_vehicle_seat_layout_changed() -> void:
	if turret != null:
		turret.on_vehicle_seat_layout_changed()


func install_turret(new_turret_scene: PackedScene) -> void:
	if new_turret_scene == null:
		return

	var info := VehicleTurretBase.inspect_scene(new_turret_scene)
	var new_size := int(info.get("turret_size", 0))
	if turret_size <= 0 or new_size > turret_size:
		return

	turret_scene = new_turret_scene
	_spawn_turret(turret_scene)

	if turret != null and vehicle != null:
		turret.setup(self, vehicle)


func remove_turret() -> void:
	if driver_turret:
		return
	turret_scene = null
	_clear_turret()


func _spawn_turret(scene: PackedScene) -> void:
	_clear_turret()

	if scene == null:
		return

	var instance := scene.instantiate()
	instance.name = "MountedTurret"
	add_child(instance)

	if instance is VehicleTurretBase:
		turret = instance as VehicleTurretBase
	else:
		push_warning("VehicleTurretMount: la scène de tourelle doit avoir VehicleTurretBase à la racine.")
		instance.queue_free()
		turret = null


func _clear_turret() -> void:
	if turret != null:
		remove_child(turret)
		turret.queue_free()
		turret = null


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func send_turret_input(aim_world: Vector3, wants_fire: bool) -> void:
	if not multiplayer.is_server():
		return

	var sender := multiplayer.get_remote_sender_id()
	apply_host_input(sender, aim_world, wants_fire)
