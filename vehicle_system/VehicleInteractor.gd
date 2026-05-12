extends Node
class_name VehicleInteractor

@export var player_body_path: NodePath = NodePath("..")
@export var player_visuals_path: NodePath
@export var player_collision_path: NodePath
@export var player_camera_path: NodePath = NodePath("../CameraRig/SpringArm3D/Camera3D")
@export var use_action: StringName = &"use"
@export var switch_seat_action: StringName = &"switch_seat"
@export var fire_action: StringName = &"fire"
@export var reload_turret_action: StringName = &"reload_weapon"
@export_group("Vehicle Mods")
@export var mod_use_1_action: StringName = &"mod_use_1"
@export var mod_use_2_action: StringName = &"mod_use_2"
@export var mod_use_3_action: StringName = &"mod_use_3"
@export var mod_use_4_action: StringName = &"mod_use_4"
@export var mod_use_5_action: StringName = &"mod_use_5"
@export var mod_use_6_action: StringName = &"mod_use_6"
#@export var accept_legacy_mode_use_typo: bool = true
@export_group("Movement")
@export var move_forward_action: StringName = &"move_forward"
@export var move_backward_action: StringName = &"move_backward"
@export var move_left_action: StringName = &"move_left"
@export var move_right_action: StringName = &"move_right"
@export var hide_visuals_when_driving: bool = true
@export var disable_collision_when_driving: bool = true
@export var sync_player_to_seat: bool = true
@export var rotate_player_with_vehicle: bool = false #true
@export var extra_nodes_to_disable_when_driving: Array[NodePath] = []
@export var aim_ray_length: float = 400.0

var nearby_vehicle: Vehicle = null
var current_vehicle: Vehicle = null
var current_seat_index: int = -1

var _disabled_nodes: Array[Node] = []

@onready var player_body: CharacterBody3D = get_node_or_null(player_body_path)
@onready var player_visuals: Node3D = get_node_or_null(player_visuals_path)
@onready var player_collision: CollisionShape3D = get_node_or_null(player_collision_path)
@onready var player_camera: Camera3D = get_node_or_null(player_camera_path)


func _ready() -> void:
	if player_body == null:
		push_warning("VehicleInteractor: player_body_path est invalide.")
		return

	if not player_body.is_in_group("players"):
		player_body.add_to_group("players")

	if player_visuals == null:
		player_visuals = player_body.get_node_or_null("VisualRoot") as Node3D

	if player_collision == null:
		player_collision = player_body.get_node_or_null("CollisionShape3D") as CollisionShape3D

	if player_camera == null:
		player_camera = player_body.get_node_or_null("CameraRig/SpringArm3D/Camera3D") as Camera3D
		if player_camera == null:
			player_camera = player_body.get_node_or_null("CameraRig/Camera3D") as Camera3D

	for path in extra_nodes_to_disable_when_driving:
		var node := get_node_or_null(path)
		if node != null:
			_disabled_nodes.append(node)

func _is_valid_vehicle_ref(vehicle: Vehicle) -> bool:
	return vehicle != null and is_instance_valid(vehicle) and not bool(vehicle.get("is_dead"))


func _clear_invalid_vehicle_refs() -> void:
	if current_vehicle != null and not _is_valid_vehicle_ref(current_vehicle):
		current_vehicle = null
		current_seat_index = -1
		if player_body != null:
			player_body.set_meta("in_vehicle", false)
			if player_body.has_method("set_vehicle_mode"):
				player_body.set_vehicle_mode(false)

	if nearby_vehicle != null and not _is_valid_vehicle_ref(nearby_vehicle):
		nearby_vehicle = null


func _unhandled_input(event: InputEvent) -> void:
	_clear_invalid_vehicle_refs()

	if not _is_local_player():
		return

	if current_vehicle != null and _try_use_vehicle_mod_from_input(event):
		get_viewport().set_input_as_handled()
		return

	if current_vehicle != null and event.is_action_pressed(switch_seat_action):
		if multiplayer.is_server():
			current_vehicle.server_switch_seat_from_host()
		else:
			current_vehicle.request_switch_seat.rpc_id(1)
		get_viewport().set_input_as_handled()
		return

	if current_vehicle != null and event.is_action_pressed(reload_turret_action):
		_try_reload_current_turret()
		get_viewport().set_input_as_handled()
		return

	if not event.is_action_pressed(use_action):
		return

	if current_vehicle != null:
		if multiplayer.is_server():
			current_vehicle.server_exit_from_host()
		else:
			current_vehicle.request_exit.rpc_id(1)
		get_viewport().set_input_as_handled()
		return

	if nearby_vehicle == null:
		return

	if not nearby_vehicle.is_available():
		return

	if multiplayer.is_server():
		nearby_vehicle.server_try_enter_from_host()
	else:
		nearby_vehicle.request_enter.rpc_id(1)

	get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	_clear_invalid_vehicle_refs()

	if current_vehicle != null and sync_player_to_seat:
		_sync_body_to_vehicle()

	if not _is_local_player():
		return

	if current_vehicle == null:
		return

	var my_peer_id := multiplayer.get_unique_id()

	if current_vehicle.get_driver_peer_id() == my_peer_id:
		var steer := Input.get_axis(move_left_action, move_right_action)
		var drive := Input.get_action_strength(move_forward_action) - Input.get_action_strength(move_backward_action)

		if multiplayer.is_server():
			current_vehicle.apply_host_input(steer, drive)
		else:
			current_vehicle.send_input.rpc_id(1, steer, drive)

	var mount := current_vehicle.get_mount_for_seat(current_seat_index)
	if mount != null and mount.has_turret():
		var aim_world := _compute_turret_aim_point_from_mouse()
		var wants_fire := Input.is_action_pressed(fire_action)
		
		mount.preview_local_aim_target(aim_world)
		
		if multiplayer.is_server():
			mount.apply_host_input(my_peer_id, aim_world, wants_fire)
		else:
			mount.send_turret_input.rpc_id(1, aim_world, wants_fire)



func _try_use_vehicle_mod_from_input(event: InputEvent) -> bool:
	if current_vehicle == null:
		return false

	var my_peer_id: int = multiplayer.get_unique_id()
	if current_vehicle.get_driver_peer_id() != my_peer_id:
		return false

	for mod_use_id in range(1, 7):
		if not _is_mod_use_action_pressed(event, mod_use_id):
			continue

		if multiplayer.is_server():
			current_vehicle.server_try_use_mod_from_host(mod_use_id)
		else:
			current_vehicle.request_use_mod.rpc_id(1, mod_use_id)
		return true

	return false


func _is_mod_use_action_pressed(event: InputEvent, mod_use_id: int) -> bool:
	var action_name: StringName = _get_mod_use_action_name(mod_use_id)
	if event.is_action_pressed(action_name):
		return true

	#if accept_legacy_mode_use_typo:
		#var legacy_action: StringName = StringName("mode_use_%d" % mod_use_id)
		#if event.is_action_pressed(legacy_action):
			#return true

	return false


func _get_mod_use_action_name(mod_use_id: int) -> StringName:
	match mod_use_id:
		1:
			return mod_use_1_action
		2:
			return mod_use_2_action
		3:
			return mod_use_3_action
		4:
			return mod_use_4_action
		5:
			return mod_use_5_action
		6:
			return mod_use_6_action
		_:
			return &""


func _try_reload_current_turret() -> void:
	if current_vehicle == null:
		return

	var mount := current_vehicle.get_mount_for_seat(current_seat_index)
	if not _mount_has_reloadable_turret(mount):
		return

	var my_peer_id := multiplayer.get_unique_id()

	if multiplayer.is_server():
		_apply_reload_on_mount_from_host(mount, my_peer_id)
		return

	if mount.has_method("send_reload_input"):
		mount.rpc_id(1, "send_reload_input")


func _mount_has_reloadable_turret(mount: Node) -> bool:
	if mount == null:
		return false

	if mount.has_method("has_turret") and not mount.has_turret():
		return false

	if mount.has_method("has_reloadable_turret"):
		return bool(mount.call("has_reloadable_turret"))

	var turret := _get_reloadable_turret_from_mount(mount)
	return turret != null


func _apply_reload_on_mount_from_host(mount: Node, peer_id: int) -> bool:
	if mount == null:
		return false

	if mount.has_method("apply_host_reload"):
		return bool(mount.call("apply_host_reload", peer_id))

	var turret := _get_reloadable_turret_from_mount(mount)
	if turret == null:
		return false

	if turret.has_method("reload_turret"):
		return bool(turret.call("reload_turret"))

	return false


func _get_reloadable_turret_from_mount(mount: Node) -> Node:
	if mount == null:
		return null

	# Cas où le mount est directement la tourelle.
	if mount.has_method("reload_turret"):
		return mount

	var method_names := [
		"get_turret",
		"get_current_turret",
		"get_turret_instance",
		"get_active_turret",
	]

	for method_name in method_names:
		if not mount.has_method(method_name):
			continue

		var turret = mount.call(method_name)
		if turret != null and is_instance_valid(turret) and turret.has_method("reload_turret"):
			return turret

	var property_names := [
		"turret",
		"current_turret",
		"active_turret",
		"turret_instance",
	]

	for property_name in property_names:
		var turret = mount.get(property_name)
		if turret != null and is_instance_valid(turret) and turret.has_method("reload_turret"):
			return turret

	return null


func is_in_vehicle() -> bool:
	return _is_valid_vehicle_ref(current_vehicle)


func get_current_seat_index() -> int:
	return current_seat_index


func get_current_seat_marker() -> Marker3D:
	if not _is_valid_vehicle_ref(current_vehicle):
		return null
	return current_vehicle.get_seat_marker(current_seat_index)


func set_near_vehicle(vehicle: Vehicle) -> void:
	nearby_vehicle = vehicle


func clear_near_vehicle(vehicle: Vehicle) -> void:
	if nearby_vehicle == vehicle:
		nearby_vehicle = null


func enter_vehicle(vehicle: Vehicle, seat_index: int = -1) -> void:
	if not _is_valid_vehicle_ref(vehicle):
		return

	current_vehicle = vehicle
	nearby_vehicle = vehicle
	current_seat_index = seat_index
	
	if hide_visuals_when_driving and player_visuals != null:
		player_visuals.visible = false

	if disable_collision_when_driving and player_collision != null:
		player_collision.disabled = true

	for node in _disabled_nodes:
		node.process_mode = Node.PROCESS_MODE_DISABLED

	if player_body != null:
		player_body.set_meta("in_vehicle", true)
		player_body.velocity = Vector3.ZERO

		if player_body.has_method("set_vehicle_mode"):
			player_body.set_vehicle_mode(true)

		if player_body.has_method("on_entered_vehicle"):
			player_body.on_entered_vehicle(vehicle)

	_sync_body_to_vehicle()


func switch_to_seat(seat_index: int) -> void:
	current_seat_index = seat_index
	_sync_body_to_vehicle()


func exit_vehicle(exit_pos: Vector3) -> void:
	current_vehicle = null
	current_seat_index = -1

	if hide_visuals_when_driving and player_visuals != null:
		player_visuals.visible = true

	if disable_collision_when_driving and player_collision != null:
		player_collision.disabled = false

	for node in _disabled_nodes:
		node.process_mode = Node.PROCESS_MODE_INHERIT

	if player_body != null:
		player_body.global_position = exit_pos
		player_body.set_meta("in_vehicle", false)
		player_body.velocity = Vector3.ZERO

		if player_body.has_method("set_vehicle_mode"):
			player_body.set_vehicle_mode(false)

		if player_body.has_method("on_exited_vehicle"):
			player_body.on_exited_vehicle()


func _sync_body_to_vehicle() -> void:
	if player_body == null or not _is_valid_vehicle_ref(current_vehicle):
		return

	var seat := current_vehicle.get_seat_marker(current_seat_index)
	if seat == null:
		return

	player_body.global_position = seat.global_position

	if rotate_player_with_vehicle:
		var rotation_copy := player_body.global_rotation_degrees
		rotation_copy.y = current_vehicle.global_rotation_degrees.y + 180.0
		player_body.global_rotation_degrees = rotation_copy


func _compute_turret_aim_point_from_mouse() -> Vector3:
	var cam: Camera3D = player_camera
	if cam == null:
		cam = get_viewport().get_camera_3d()

	if cam == null:
		return Vector3.ZERO

	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := cam.project_ray_origin(mouse_position)
	var ray_direction := cam.project_ray_normal(mouse_position)
	var ray_end := ray_origin + ray_direction * aim_ray_length

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var excludes: Array[RID] = []

	if current_vehicle != null:
		excludes.append(current_vehicle.get_rid())

	if player_body != null:
		excludes.append(player_body.get_rid())

	query.exclude = excludes

	if not _is_valid_vehicle_ref(current_vehicle):
		return ray_end

	var result := current_vehicle.get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		return result["position"]

	return ray_end


func _is_local_player() -> bool:
	return player_body != null and player_body.is_multiplayer_authority()


#extends Node
#class_name VehicleInteractor
#
#@export var player_body_path: NodePath = NodePath("..")
#@export var player_visuals_path: NodePath
#@export var player_collision_path: NodePath
#@export var player_camera_path: NodePath = NodePath("../CameraRig/SpringArm3D/Camera3D")
#@export var use_action: StringName = &"use"
#@export var switch_seat_action: StringName = &"switch_seat"
#@export var fire_action: StringName = &"fire"
#@export var move_forward_action: StringName = &"move_forward"
#@export var move_backward_action: StringName = &"move_backward"
#@export var move_left_action: StringName = &"move_left"
#@export var move_right_action: StringName = &"move_right"
#@export var hide_visuals_when_driving: bool = false
#@export var disable_collision_when_driving: bool = true
#@export var sync_player_to_seat: bool = true
#@export var rotate_player_with_vehicle: bool = false #true
#@export var extra_nodes_to_disable_when_driving: Array[NodePath] = []
#@export var aim_ray_length: float = 400.0
#
#var nearby_vehicle: Vehicle = null
#var current_vehicle: Vehicle = null
#var current_seat_index: int = -1
#
#var _disabled_nodes: Array[Node] = []
#
#@onready var player_body: CharacterBody3D = get_node_or_null(player_body_path)
#@onready var player_visuals: Node3D = get_node_or_null(player_visuals_path)
#@onready var player_collision: CollisionShape3D = get_node_or_null(player_collision_path)
#@onready var player_camera: Camera3D = get_node_or_null(player_camera_path)
#
#
#func _ready() -> void:
	#if player_body == null:
		#push_warning("VehicleInteractor: player_body_path est invalide.")
		#return
#
	#if not player_body.is_in_group("players"):
		#player_body.add_to_group("players")
#
	#for path in extra_nodes_to_disable_when_driving:
		#var node := get_node_or_null(path)
		#if node != null:
			#_disabled_nodes.append(node)
#
#
#func _unhandled_input(event: InputEvent) -> void:
	#if not _is_local_player():
		#return
#
	#if current_vehicle != null and event.is_action_pressed(switch_seat_action):
		#if multiplayer.is_server():
			#current_vehicle.server_switch_seat_from_host()
		#else:
			#current_vehicle.request_switch_seat.rpc_id(1)
		#get_viewport().set_input_as_handled()
		#return
#
	#if not event.is_action_pressed(use_action):
		#return
#
	#if current_vehicle != null:
		#if multiplayer.is_server():
			#current_vehicle.server_exit_from_host()
		#else:
			#current_vehicle.request_exit.rpc_id(1)
		#get_viewport().set_input_as_handled()
		#return
#
	#if nearby_vehicle == null:
		#return
#
	#if not nearby_vehicle.is_available():
		#return
#
	#if multiplayer.is_server():
		#nearby_vehicle.server_try_enter_from_host()
	#else:
		#nearby_vehicle.request_enter.rpc_id(1)
#
	#get_viewport().set_input_as_handled()
#
#
#func _physics_process(_delta: float) -> void:
	#if current_vehicle != null and sync_player_to_seat:
		#_sync_body_to_vehicle()
#
	#if not _is_local_player():
		#return
#
	#if current_vehicle == null:
		#return
#
	#var my_peer_id := multiplayer.get_unique_id()
#
	#if current_vehicle.get_driver_peer_id() == my_peer_id:
		#var steer := Input.get_axis(move_left_action, move_right_action)
		#var drive := Input.get_action_strength(move_forward_action) - Input.get_action_strength(move_backward_action)
#
		#if multiplayer.is_server():
			#current_vehicle.apply_host_input(steer, drive)
		#else:
			#current_vehicle.send_input.rpc_id(1, steer, drive)
#
	#var mount := current_vehicle.get_mount_for_seat(current_seat_index)
	#if mount != null and mount.has_turret():
		#var aim_world := _compute_turret_aim_point_from_mouse()
		#var wants_fire := Input.is_action_pressed(fire_action)
#
		#mount.preview_local_aim_target(aim_world)
#
		#if multiplayer.is_server():
			#mount.apply_host_input(my_peer_id, aim_world, wants_fire)
		#else:
			#mount.send_turret_input.rpc_id(1, aim_world, wants_fire)
#
#
#func is_in_vehicle() -> bool:
	#return current_vehicle != null
#
#
#func get_current_seat_index() -> int:
	#return current_seat_index
#
#
#func get_current_seat_marker() -> Marker3D:
	#if current_vehicle == null:
		#return null
	#return current_vehicle.get_seat_marker(current_seat_index)
#
#
#func set_near_vehicle(vehicle: Vehicle) -> void:
	#nearby_vehicle = vehicle
#
#
#func clear_near_vehicle(vehicle: Vehicle) -> void:
	#if nearby_vehicle == vehicle:
		#nearby_vehicle = null
#
#
#func enter_vehicle(vehicle: Vehicle, seat_index: int = -1) -> void:
	#current_vehicle = vehicle
	#nearby_vehicle = vehicle
	#current_seat_index = seat_index
	#
	#if hide_visuals_when_driving and player_visuals != null:
		#player_visuals.visible = false
#
	#if disable_collision_when_driving and player_collision != null:
		#player_collision.disabled = true
#
	#for node in _disabled_nodes:
		#node.process_mode = Node.PROCESS_MODE_DISABLED
#
	#if player_body != null:
		#player_body.set_meta("in_vehicle", true)
		#player_body.velocity = Vector3.ZERO
#
		#if player_body.has_method("set_vehicle_mode"):
			#player_body.set_vehicle_mode(true)
#
		#if player_body.has_method("on_entered_vehicle"):
			#player_body.on_entered_vehicle(vehicle)
#
	#_sync_body_to_vehicle()
#
#
#func switch_to_seat(seat_index: int) -> void:
	#current_seat_index = seat_index
	#_sync_body_to_vehicle()
#
#
#func exit_vehicle(exit_pos: Vector3) -> void:
	#current_vehicle = null
	#current_seat_index = -1
#
	#if hide_visuals_when_driving and player_visuals != null:
		#player_visuals.visible = true
#
	#if disable_collision_when_driving and player_collision != null:
		#player_collision.disabled = false
#
	#for node in _disabled_nodes:
		#node.process_mode = Node.PROCESS_MODE_INHERIT
#
	#if player_body != null:
		#player_body.global_position = exit_pos
		#player_body.set_meta("in_vehicle", false)
		#player_body.velocity = Vector3.ZERO
#
		#if player_body.has_method("set_vehicle_mode"):
			#player_body.set_vehicle_mode(false)
#
#
#func _sync_body_to_vehicle() -> void:
	#if player_body == null or current_vehicle == null:
		#return
#
	#var seat := current_vehicle.get_seat_marker(current_seat_index)
	#if seat == null:
		#return
#
	#player_body.global_position = seat.global_position
#
	#if rotate_player_with_vehicle:
		#var rotation_copy := player_body.global_rotation_degrees
		#rotation_copy.y = current_vehicle.global_rotation_degrees.y + 180.0
		#player_body.global_rotation_degrees = rotation_copy
#
#
#func _compute_turret_aim_point_from_mouse() -> Vector3:
	#var cam: Camera3D = player_camera
	#if cam == null:
		#cam = get_viewport().get_camera_3d()
#
	#if cam == null:
		#return Vector3.ZERO
#
	#var mouse_position := get_viewport().get_mouse_position()
	#var ray_origin := cam.project_ray_origin(mouse_position)
	#var ray_direction := cam.project_ray_normal(mouse_position)
	#var ray_end := ray_origin + ray_direction * aim_ray_length
#
	#var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	#var excludes: Array[RID] = []
#
	#if current_vehicle != null:
		#excludes.append(current_vehicle.get_rid())
#
	#if player_body != null:
		#excludes.append(player_body.get_rid())
#
	#query.exclude = excludes
#
	#var result := current_vehicle.get_world_3d().direct_space_state.intersect_ray(query)
	#if not result.is_empty():
		#return result["position"]
#
	#return ray_end
#
#
#func _is_local_player() -> bool:
	#return player_body != null and player_body.is_multiplayer_authority()
