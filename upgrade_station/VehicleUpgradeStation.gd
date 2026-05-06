extends Node3D
class_name VehicleUpgradeStation

const PLAYER_VEHICLE_NODE_NAME := "vehicle_player"

@export_group("Scenes")
@export var fallback_loadout_menu_scene: PackedScene = preload("res://vehicle_system/VehicleLoadoutMenu.tscn")

@export_group("Visuals")
@export var inactive_color: Color = Color(1.0, 0.2, 0.2, 1.0)
@export var ready_color: Color = Color(0.2, 1.0, 0.2, 1.0)
@export var busy_color: Color = Color(1.0, 0.6, 0.0, 1.0)

@export_group("Debug")
@export var debug_prints: bool = true
@export var player_push_distance: float = 5.0

@onready var platform_area: Area3D = $PlatformArea
@onready var button_area: Area3D = $ButtonPivot/ButtonArea
@onready var button_mesh: MeshInstance3D = $ButtonPivot/ButtonMesh
@onready var vehicle_spawn_point: Marker3D = $VehicleSpawnPoint

var active_vehicle_path: NodePath = NodePath("")
var active_vehicle: Vehicle = null
var using_peer_id: int = -1
var button_users: Dictionary = {}

var _local_menu: Node = null
var _suppress_local_close_request: bool = false


func _ready() -> void:
	set_multiplayer_authority(1)
	_update_button_visual()


func _dbg(text: String) -> void:
	if debug_prints:
		print("[UPGRADE_STATION] ", text)


func _update_button_visual() -> void:
	if button_mesh == null:
		return

	var can_use := active_vehicle != null and is_instance_valid(active_vehicle) and using_peer_id == -1
	var in_use := using_peer_id != -1

	var mat := StandardMaterial3D.new()
	if in_use:
		mat.albedo_color = busy_color
	elif can_use:
		mat.albedo_color = ready_color
	else:
		mat.albedo_color = inactive_color

	button_mesh.material_override = mat


func can_local_player_try_use() -> bool:
	return active_vehicle_path != NodePath("") and using_peer_id == -1


func get_active_vehicle() -> Vehicle:
	if active_vehicle != null and is_instance_valid(active_vehicle):
		return active_vehicle

	if active_vehicle_path != NodePath(""):
		active_vehicle = get_node_or_null(active_vehicle_path) as Vehicle

	return active_vehicle


@rpc("call_local", "reliable")
func _sync_station_state(vehicle_path: NodePath, user_peer_id: int) -> void:
	var previous_vehicle := active_vehicle

	active_vehicle_path = vehicle_path
	active_vehicle = get_node_or_null(vehicle_path) as Vehicle if vehicle_path != NodePath("") else null
	using_peer_id = user_peer_id

	# On force l'état du précédent véhicule au cas où il existe encore localement
	if previous_vehicle != null and is_instance_valid(previous_vehicle) and previous_vehicle != active_vehicle:
		if previous_vehicle.has_method("set_use_area_enabled"):
			previous_vehicle.set_use_area_enabled(true)

	# On force l'état du véhicule actif selon l'état réel de la station
	if active_vehicle != null and is_instance_valid(active_vehicle):
		active_vehicle.set_meta("upgrade_station_locked", using_peer_id != -1)
		active_vehicle.set_meta("upgrade_station_user_peer_id", using_peer_id)

		if active_vehicle.has_method("set_use_area_enabled"):
			active_vehicle.set_use_area_enabled(using_peer_id == -1)

	_update_button_visual()

	print("[UPGRADE_STATION] SYNC STATE | vehicle=", active_vehicle, " | using_peer_id=", using_peer_id)


@rpc("any_peer", "call_remote", "reliable")
func request_open_menu() -> void:
	if not multiplayer.is_server():
		return

	var sender := multiplayer.get_remote_sender_id()

	if using_peer_id != -1:
		return

	if active_vehicle == null or not is_instance_valid(active_vehicle):
		return

	if not button_users.has(sender):
		return

	_server_open_menu_for_peer(sender)


@rpc("any_peer", "call_remote", "reliable")
func request_close_menu() -> void:
	if not multiplayer.is_server():
		return

	var sender := multiplayer.get_remote_sender_id()
	if sender != using_peer_id:
		return

	_server_close_menu()


@rpc("any_peer", "call_remote", "reliable")
func request_buy_chassis(chassis_index: int) -> void:
	if not multiplayer.is_server():
		return

	var sender := multiplayer.get_remote_sender_id()
	_server_buy_chassis_for_peer(sender, chassis_index)


func server_try_open_from_host() -> void:
	if not multiplayer.is_server():
		return

	var local_peer := multiplayer.get_unique_id()
	button_users[local_peer] = true

	if using_peer_id != -1:
		return

	if active_vehicle == null or not is_instance_valid(active_vehicle):
		return

	_server_open_menu_for_peer(local_peer)


func server_buy_chassis_from_host(chassis_index: int) -> void:
	if not multiplayer.is_server():
		return
	_server_buy_chassis_for_peer(multiplayer.get_unique_id(), chassis_index)


func _server_open_menu_for_peer(peer_id: int) -> void:
	using_peer_id = peer_id

	var vehicle := get_active_vehicle()
	if vehicle == null:
		using_peer_id = -1
		_update_button_visual()
		return

	_set_vehicle_locked(vehicle, true)
	_eject_all_vehicle_players(vehicle)

	_sync_station_state.rpc(vehicle.get_path(), using_peer_id)
	if peer_id == multiplayer.get_unique_id():
		_open_menu_local(vehicle.get_path())
	else:
		_open_menu_local.rpc_id(peer_id, vehicle.get_path())


func _server_close_menu() -> void:
	var vehicle := get_active_vehicle()

	print("[UPGRADE_STATION] _server_close_menu | active_vehicle = ", vehicle)

	if vehicle != null and is_instance_valid(vehicle):
		_set_vehicle_locked(vehicle, false)

	using_peer_id = -1
	_sync_station_state.rpc(active_vehicle_path, using_peer_id)


func _server_buy_chassis_for_peer(peer_id: int, chassis_index: int) -> void:
	if peer_id != using_peer_id:
		print("[UPGRADE_STATION] BUY CHASSIS REFUS: mauvais utilisateur")
		return

	var old_vehicle := get_active_vehicle()
	if old_vehicle == null or not is_instance_valid(old_vehicle):
		print("[UPGRADE_STATION] BUY CHASSIS REFUS: old_vehicle null")
		return

	var entries := old_vehicle.get_available_chassis_entries()
	if chassis_index < 0 or chassis_index >= entries.size():
		print("[UPGRADE_STATION] BUY CHASSIS REFUS: chassis_index invalide")
		return

	var entry := entries[chassis_index]

	var target_chassis_id := String(entry.get("chassis_id", ""))
	if target_chassis_id == old_vehicle.chassis_id:
		print("[UPGRADE_STATION] BUY CHASSIS REFUS: même châssis")
		return

	var new_scene_path := String(entry.get("scene_path", ""))
	if new_scene_path.is_empty():
		var target_scene: PackedScene = entry.get("scene", null)
		if target_scene != null:
			new_scene_path = target_scene.resource_path

	if new_scene_path.is_empty():
		print("[UPGRADE_STATION] BUY CHASSIS REFUS: scene_path vide")
		return

	var new_price := int(entry.get("chassis_price", 0))
	var new_money := old_vehicle.shop_money + old_vehicle.get_chassis_trade_in_value() - new_price
	if new_money < 0:
		print("[UPGRADE_STATION] BUY CHASSIS REFUS: pas assez d'argent")
		return

	_push_players_out_of_platform()
	_eject_all_vehicle_players(old_vehicle)

	var spawn_transform := _get_platform_spawn_transform(old_vehicle)
	var old_vehicle_path := old_vehicle.get_path()

	print("[UPGRADE_STATION] BUY CHASSIS OK -> replace ", old_vehicle_path, " by ", new_scene_path)

	_replace_active_vehicle_local.rpc(old_vehicle_path, new_scene_path, spawn_transform, new_money)

	# après le remplacement local host, active_vehicle pointe sur le nouveau
	if active_vehicle != null and is_instance_valid(active_vehicle):
		_set_vehicle_locked(active_vehicle, true)
		_sync_station_state.rpc(active_vehicle.get_path(), using_peer_id)

@rpc("authority", "call_local", "reliable")
func _open_menu_local(vehicle_path: NodePath) -> void:
	var vehicle := get_node_or_null(vehicle_path) as Vehicle
	if vehicle == null:
		return

	if _local_menu != null and is_instance_valid(_local_menu):
		_local_menu.queue_free()
		_local_menu = null

	var menu_scene: PackedScene = fallback_loadout_menu_scene
	if vehicle.loadout_menu_scene != null:
		menu_scene = vehicle.loadout_menu_scene

	if menu_scene == null:
		return

	_local_menu = menu_scene.instantiate()
	if _local_menu == null:
		return

	_local_menu.tree_exited.connect(_on_local_menu_tree_exited)
	get_tree().current_scene.add_child(_local_menu)

	var local_interactor := _find_local_vehicle_interactor()
	if _local_menu.has_method("setup"):
		_local_menu.setup(vehicle, local_interactor, self)


@rpc("authority", "call_local", "reliable")
func _retarget_menu_local(vehicle_path: NodePath) -> void:
	var vehicle := get_node_or_null(vehicle_path) as Vehicle
	if vehicle == null:
		return

	if _local_menu != null and is_instance_valid(_local_menu) and _local_menu.has_method("retarget_vehicle"):
		_local_menu.retarget_vehicle(vehicle)


@rpc("authority", "call_local", "reliable")
func _force_close_menu_local() -> void:
	_suppress_local_close_request = true
	if _local_menu != null and is_instance_valid(_local_menu):
		_local_menu.queue_free()
		_local_menu = null


func _on_local_menu_tree_exited() -> void:
	_local_menu = null

	if _suppress_local_close_request:
		_suppress_local_close_request = false
		return

	if multiplayer.is_server():
		if using_peer_id == multiplayer.get_unique_id():
			_server_close_menu()
	else:
		request_close_menu.rpc_id(1)


func _server_force_vehicle_left() -> void:
	if using_peer_id != -1:
		if using_peer_id == multiplayer.get_unique_id():
			_force_close_menu_local()
		else:
			_force_close_menu_local.rpc_id(using_peer_id)

	var vehicle := get_active_vehicle()
	if vehicle != null and is_instance_valid(vehicle):
		_set_vehicle_locked(vehicle, false)

	using_peer_id = -1
	active_vehicle = null
	active_vehicle_path = NodePath("")
	_sync_station_state.rpc(NodePath(""), -1)


func _on_platform_area_body_entered(body: Node) -> void:
	if not multiplayer.is_server():
		return
	
	if active_vehicle != null and is_instance_valid(active_vehicle):
		return
	
	var vehicle := _find_vehicle_from_body(body)
	if vehicle == null:
		return
	
	active_vehicle = vehicle
	active_vehicle_path = vehicle.get_path()
	_sync_station_state.rpc(active_vehicle_path, using_peer_id)


func _on_platform_area_body_exited(body: Node) -> void:
	if not multiplayer.is_server():
		return

	if active_vehicle == null:
		return

	var vehicle := _find_vehicle_from_body(body)
	if vehicle != active_vehicle:
		return

	_server_force_vehicle_left()


func _on_button_area_body_entered(body: Node) -> void:
	var interactor = _find_upgrade_interactor(body)
	if interactor != null:
		interactor.set_near_upgrade_station(self)

	if multiplayer.is_server():
		var player := _find_player_node(body)
		if player != null:
			button_users[player.get_multiplayer_authority()] = true


func _on_button_area_body_exited(body: Node) -> void:
	var interactor = _find_upgrade_interactor(body)
	if interactor != null:
		interactor.clear_near_upgrade_station(self)

	if multiplayer.is_server():
		var player := _find_player_node(body)
		if player != null:
			button_users.erase(player.get_multiplayer_authority())


func _find_vehicle_from_body(body: Node) -> Vehicle:
	if body is Vehicle:
		return body

	var node := body
	while node != null:
		if node is Vehicle:
			return node as Vehicle
		node = node.get_parent()

	return null


func _find_player_node(node: Node) -> Node:
	if node == null:
		return null

	var current := node
	while current != null:
		if current.is_in_group("players"):
			return current
		current = current.get_parent()

	return null


func _find_upgrade_interactor(node: Node):
	var player := _find_player_node(node)
	if player == null:
		return null

	if player.has_node("UpgradeStationInteractor"):
		return player.get_node("UpgradeStationInteractor")

	for child in player.get_children():
		if child.has_method("set_near_upgrade_station") and child.has_method("clear_near_upgrade_station"):
			return child

	return null


func _find_local_vehicle_interactor() -> Node:
	var my_peer := multiplayer.get_unique_id()

	for player in get_tree().get_nodes_in_group("players"):
		if player.get_multiplayer_authority() != my_peer:
			continue

		if player.has_node("VehicleInteractor"):
			return player.get_node("VehicleInteractor")

		for child in player.get_children():
			if child.get_script() != null and child.has_method("enter_vehicle") and child.has_method("exit_vehicle"):
				return child

	return null


func _set_vehicle_locked(vehicle: Node, locked: bool) -> void:
	if vehicle == null:
		return

	print("[UPGRADE_STATION] _set_vehicle_locked | vehicle=", vehicle, " | locked=", locked)

	vehicle.set_meta("upgrade_station_locked", locked)

	if locked:
		vehicle.set_meta("upgrade_station_user_peer_id", using_peer_id)
	else:
		vehicle.set_meta("upgrade_station_user_peer_id", -1)

	if vehicle.has_method("set_upgrade_station_locked"):
		vehicle.set_upgrade_station_locked(locked)

	if vehicle.has_method("set_use_area_enabled"):
		vehicle.set_use_area_enabled(not locked)
	elif vehicle.has_node("UseArea"):
		var use_area := vehicle.get_node("UseArea") as Area3D
		if use_area != null:
			use_area.monitoring = not locked
			use_area.monitorable = not locked
			use_area.set_deferred("monitoring", not locked)
			use_area.set_deferred("monitorable", not locked)

	if locked:
		for player in get_tree().get_nodes_in_group("players"):
			if player.has_node("VehicleInteractor"):
				var interactor = player.get_node("VehicleInteractor")
				if interactor.has_method("clear_near_vehicle"):
					interactor.clear_near_vehicle(vehicle)

func _eject_all_vehicle_players(vehicle: Node) -> void:
	if vehicle == null:
		return

	var peer_ids: Array[int] = []
	var seat_data = vehicle.get("seat_occupants")

	if seat_data is Array:
		for value in seat_data:
			var peer_id := int(value)
			if peer_id > 0 and not peer_ids.has(peer_id):
				peer_ids.append(peer_id)

	var exit_pos := vehicle_spawn_point.global_position + Vector3(4.0, 0.5, 0.0)

	for peer_id in peer_ids:
		if vehicle.has_method("rpc"):
			vehicle.rpc("sync_exit", peer_id, exit_pos)

	if vehicle.has_method("set"):
		vehicle.set("steer_input", 0.0)
		vehicle.set("drive_input", 0.0)


func _push_players_out_of_platform() -> void:
	if not platform_area.monitoring:
		return

	var index := 0
	for body in platform_area.get_overlapping_bodies():
		var player := _find_player_node(body)
		if player == null:
			continue

		var dir := Vector3.RIGHT.rotated(Vector3.UP, float(index) * PI * 0.5)
		var safe_pos := global_position + dir * player_push_distance + Vector3.UP * 0.6

		if player is Node3D:
			(player as Node3D).global_position = safe_pos

		if player.has_method("set_ui_input_blocked"):
			player.set_ui_input_blocked(false)

		index += 1

func _get_platform_spawn_transform(old_vehicle: Vehicle) -> Transform3D:
	var spawn_transform := old_vehicle.global_transform
	spawn_transform.origin = platform_area.global_position + Vector3.UP * 0.35
	return spawn_transform


@rpc("authority", "call_local", "reliable")
func _replace_active_vehicle_local(old_vehicle_path: NodePath, new_scene_path: String, spawn_transform: Transform3D, new_money: int) -> void:
	var old_vehicle := get_node_or_null(old_vehicle_path) as Vehicle
	if old_vehicle == null:
		print("[UPGRADE_STATION] REPLACE FAIL: old vehicle not found -> ", old_vehicle_path)
		return

	var parent := old_vehicle.get_parent()
	if parent == null:
		print("[UPGRADE_STATION] REPLACE FAIL: parent null")
		return

	var new_scene := load(new_scene_path) as PackedScene
	if new_scene == null:
		print("[UPGRADE_STATION] REPLACE FAIL: scene null -> ", new_scene_path)
		return

	var new_vehicle := new_scene.instantiate() as Vehicle
	if new_vehicle == null:
		print("[UPGRADE_STATION] REPLACE FAIL: instantiate failed")
		return

	parent.remove_child(old_vehicle)
	old_vehicle.queue_free()

	new_vehicle.name = PLAYER_VEHICLE_NODE_NAME
	parent.add_child(new_vehicle, true)
	new_vehicle.global_transform = spawn_transform
	new_vehicle.shop_money = new_money
	new_vehicle.set_multiplayer_authority(1)

	active_vehicle = new_vehicle
	active_vehicle_path = new_vehicle.get_path()

	# IMPORTANT :
	# On ne lock / unlock PAS ici selon using_peer_id.
	# Le vrai état vient de _sync_station_state().
	# Ici on laisse le véhicule utilisable par défaut jusqu'à la sync officielle.
	if new_vehicle.has_method("set_use_area_enabled"):
		new_vehicle.set_use_area_enabled(true)

	_update_button_visual()

	if _local_menu != null and is_instance_valid(_local_menu):
		if _local_menu.has_method("retarget_vehicle"):
			_local_menu.retarget_vehicle(new_vehicle)
		else:
			_local_menu.set("vehicle", new_vehicle)
			if _local_menu.has_method("_refresh"):
				_local_menu._refresh()

	print("[UPGRADE_STATION] REPLACE OK -> ", new_vehicle.get_path())
