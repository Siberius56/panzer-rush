extends Node

signal snapshot_changed

var players: Dictionary = {}
var vehicles: Dictionary = {}
var pending_lobby_vehicle_state: Dictionary = {}
var player_snapshot_active: bool = false
var vehicle_snapshot_active: bool = false


func reset_run_state() -> void:
	players.clear()
	vehicles.clear()
	player_snapshot_active = false
	vehicle_snapshot_active = false
	snapshot_changed.emit()


func apply_snapshot(new_players: Dictionary, new_vehicles: Dictionary) -> void:
	print("> before")
	print("players: ", players)
	print("vehicles: ", vehicles)
	
	players = new_players.duplicate(true)
	vehicles = new_vehicles.duplicate(true)
	pending_lobby_vehicle_state.clear()
	player_snapshot_active = true
	vehicle_snapshot_active = true
	snapshot_changed.emit()
	
	print("> after")
	print("players: ", players)
	print("vehicles: ", vehicles)

func set_pending_lobby_vehicle_state(state: Dictionary) -> void:
	pending_lobby_vehicle_state = state.duplicate(true)
	vehicles[0] = pending_lobby_vehicle_state.duplicate(true)
	vehicle_snapshot_active = true
	snapshot_changed.emit()


func clear_pending_lobby_vehicle_state() -> void:
	pending_lobby_vehicle_state.clear()
	snapshot_changed.emit()


func has_pending_lobby_vehicle_state() -> bool:
	return not pending_lobby_vehicle_state.is_empty()


func get_pending_lobby_vehicle_state() -> Dictionary:
	return pending_lobby_vehicle_state.duplicate(true)


func capture_scene_state(players_root: Node, vehicles_root: Node) -> void:
	capture_players(players_root)
	capture_vehicles(vehicles_root)
	snapshot_changed.emit()


func capture_players(players_root: Node) -> void:
	players.clear()
	player_snapshot_active = true

	if players_root == null:
		return

	for child in players_root.get_children():
		capture_player(child)


func capture_player(player: Node) -> void:
	if player == null or not is_instance_valid(player):
		return

	var peer_id: int = int(player.get("player_id"))
	if peer_id <= 0:
		return

	if player.has_method("build_session_state"):
		players[peer_id] = player.call("build_session_state")
		return

	players[peer_id] = _build_player_state_fallback(player)


func has_player_state(peer_id: int) -> bool:
	return player_snapshot_active and players.has(peer_id)


func get_player_state(peer_id: int) -> Dictionary:
	if not players.has(peer_id):
		return {}
	return players[peer_id].duplicate(true)


func apply_player_state_to_node(player: Node, force_alive: bool = true) -> void:
	if player == null or not is_instance_valid(player):
		return

	var peer_id: int = int(player.get("player_id"))
	if not has_player_state(peer_id):
		return

	var state: Dictionary = get_player_state(peer_id)
	if player.has_method("apply_session_state"):
		player.call("apply_session_state", state, force_alive)
		return

	_apply_player_state_fallback(player, state, force_alive)


func capture_vehicles(vehicles_root: Node) -> void:
	vehicles.clear()
	vehicle_snapshot_active = true

	if vehicles_root == null:
		return

	var vehicle_index: int = 0
	for child in vehicles_root.get_children():
		capture_vehicle(vehicle_index, child)
		vehicle_index += 1

	if not vehicles.is_empty():
		pending_lobby_vehicle_state.clear()


func capture_vehicle(vehicle_index: int, vehicle: Node) -> void:
	if vehicle == null or not is_instance_valid(vehicle):
		return

	if vehicle.has_method("build_session_state"):
		vehicles[vehicle_index] = vehicle.call("build_session_state")
		vehicles[vehicle_index]["vehicle_index"] = vehicle_index
		return

	vehicles[vehicle_index] = _build_vehicle_state_fallback(vehicle_index, vehicle)


func has_vehicle_snapshot() -> bool:
	return vehicle_snapshot_active or not pending_lobby_vehicle_state.is_empty()


func has_vehicle_state(vehicle_index: int) -> bool:
	if vehicle_snapshot_active and vehicles.has(vehicle_index):
		return true
	return vehicle_index == 0 and not pending_lobby_vehicle_state.is_empty()


func get_vehicle_state(vehicle_index: int) -> Dictionary:
	if vehicles.has(vehicle_index):
		return vehicles[vehicle_index].duplicate(true)
	if vehicle_index == 0 and not pending_lobby_vehicle_state.is_empty():
		return pending_lobby_vehicle_state.duplicate(true)
	return {}


func get_vehicle_count() -> int:
	if vehicle_snapshot_active:
		return vehicles.size()
	if not pending_lobby_vehicle_state.is_empty():
		return 1
	return 0


func get_vehicle_indexes() -> Array[int]:
	var result: Array[int] = []
	for key in vehicles.keys():
		result.append(int(key))
	if result.is_empty() and not pending_lobby_vehicle_state.is_empty():
		result.append(0)
	result.sort()
	return result


func apply_vehicle_state_to_node(vehicle_index: int, vehicle: Node) -> void:
	if vehicle == null or not is_instance_valid(vehicle):
		return
	if not has_vehicle_state(vehicle_index):
		return

	var state: Dictionary = get_vehicle_state(vehicle_index)
	if vehicle.has_method("apply_session_state"):
		vehicle.call("apply_session_state", state)
		return

	_apply_vehicle_state_fallback(vehicle, state)


func _build_player_state_fallback(player: Node) -> Dictionary:
	var weapon_slots_value = player.get("weapon_slots")
	var ammo_reserve_value = player.get("ammo_reserve")
	var ammo_reserve_max_value = player.get("ammo_reserve_max")

	return {
		"player_id": int(player.get("player_id")),
		"player_name": str(player.get("player_name")),
		"max_health": int(player.get("max_health")),
		"health": int(player.get("health")),
		"is_dead": bool(player.get("is_dead")),
		"carried_money": int(player.get("carried_money")),
		"weapon_slots": weapon_slots_value.duplicate(true) if weapon_slots_value is Array else [{}, {}],
		"current_weapon_slot": int(player.get("current_weapon_slot")),
		"ammo_reserve": ammo_reserve_value.duplicate(true) if ammo_reserve_value is Dictionary else {},
		"ammo_reserve_max": ammo_reserve_max_value.duplicate(true) if ammo_reserve_max_value is Dictionary else {}
	}


func _apply_player_state_fallback(player: Node, state: Dictionary, force_alive: bool) -> void:
	var maximum: int = int(state.get("max_health", player.get("max_health")))
	var value: int = int(state.get("health", maximum))
	var dead_now: bool = bool(state.get("is_dead", false))

	if force_alive:
		dead_now = false
		value = max(value, 1)

	player.set("max_health", maximum)
	player.set("health", clampi(value, 0, maximum))
	player.set("is_dead", dead_now)
	player.set("carried_money", int(state.get("carried_money", 0)))

	var weapon_slots_value = state.get("weapon_slots", [{}, {}])
	if weapon_slots_value is Array:
		player.set("weapon_slots", weapon_slots_value.duplicate(true))

	var ammo_reserve_value = state.get("ammo_reserve", {})
	if ammo_reserve_value is Dictionary:
		player.set("ammo_reserve", ammo_reserve_value.duplicate(true))

	var selected_slot: int = clampi(int(state.get("current_weapon_slot", 0)), 0, 1)
	player.set("current_weapon_slot", selected_slot)

	if player.has_method("_refresh_weapon_nodes"):
		player.call("_refresh_weapon_nodes")
	if player.has_method("_apply_health_state"):
		player.call("_apply_health_state", int(player.get("health")), dead_now)


func _build_vehicle_state_fallback(vehicle_index: int, vehicle: Node) -> Dictionary:
	var turret_config: Array[Dictionary] = []
	var turret_mounts_value = vehicle.get("turret_mounts")

	if turret_mounts_value is Array:
		for mount_value in turret_mounts_value:
			var mount: Node = mount_value as Node
			if mount == null:
				continue

			var scene_path: String = ""
			if mount.has_method("get_turret_scene_path"):
				scene_path = str(mount.call("get_turret_scene_path"))

			turret_config.append({
				"seat_index": int(mount.get("seat_index")),
				"turret_scene_path": scene_path
			})

	var scene_path_value: String = ""
	if "scene_file_path" in vehicle:
		scene_path_value = str(vehicle.get("scene_file_path"))

	return {
		"vehicle_index": vehicle_index,
		"scene_path": scene_path_value,
		"vehicle_display_name": str(vehicle.get("vehicle_display_name")),
		"chassis_id": str(vehicle.get("chassis_id")),
		"max_health": int(vehicle.get("max_health")),
		"health": int(vehicle.get("health")),
		"is_dead": bool(vehicle.get("is_dead")),
		"shop_money": int(vehicle.get("shop_money")),
		"turret_config": turret_config
	}


func _apply_vehicle_state_fallback(vehicle: Node, state: Dictionary) -> void:
	var maximum: int = int(state.get("max_health", vehicle.get("max_health")))
	var value: int = int(state.get("health", maximum))
	var dead_now: bool = bool(state.get("is_dead", false)) or value <= 0

	vehicle.set("vehicle_display_name", str(state.get("vehicle_display_name", vehicle.get("vehicle_display_name"))))
	vehicle.set("chassis_id", str(state.get("chassis_id", vehicle.get("chassis_id"))))
	vehicle.set("max_health", maximum)
	vehicle.set("health", clampi(value, 0, maximum))
	vehicle.set("is_dead", dead_now)
	vehicle.set("shop_money", int(state.get("shop_money", vehicle.get("shop_money"))))

	var turret_config = state.get("turret_config", [])
	if turret_config is Array and vehicle.has_method("_sync_loadout_state"):
		vehicle.call("_sync_loadout_state", int(vehicle.get("shop_money")), turret_config)

	if dead_now and vehicle.has_method("_sync_vehicle_destroyed"):
		vehicle.call("_sync_vehicle_destroyed")
	elif vehicle.has_method("_sync_vehicle_health"):
		vehicle.call("_sync_vehicle_health", int(vehicle.get("health")))
