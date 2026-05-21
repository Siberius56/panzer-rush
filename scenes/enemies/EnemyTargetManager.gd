extends Node
@export var include_players: bool = true
@export var include_vehicles: bool = true
@export var enable_safety_group_refresh: bool = true
@export_range(60, 600, 1) var safety_refresh_interval_frames: int = 300

var players: Array[Node3D] = []
var vehicles: Array[Node3D] = []
var _safety_refresh_frame_offset: int = 0


func _ready() -> void:
	add_to_group("enemy_target_manager")
	_safety_refresh_frame_offset = randi() % max(safety_refresh_interval_frames, 1)
	_safety_refresh_from_groups()


func _physics_process(_delta: float) -> void:
	if not enable_safety_group_refresh:
		return

	var interval: int = max(safety_refresh_interval_frames, 1)
	if int(Engine.get_physics_frames()) % interval != _safety_refresh_frame_offset % interval:
		return

	_safety_refresh_from_groups()


func register_player(player: Node3D) -> void:
	if not include_players:
		return
	if player == null or not is_instance_valid(player):
		return
	if players.has(player):
		return

	players.append(player)
	_connect_auto_unregister(player)


func unregister_player(player: Node3D) -> void:
	if player == null:
		return

	players.erase(player)


func register_vehicle(vehicle: Node3D) -> void:
	if not include_vehicles:
		return
	if vehicle == null or not is_instance_valid(vehicle):
		return
	if vehicles.has(vehicle):
		return

	vehicles.append(vehicle)
	_connect_auto_unregister(vehicle)


func unregister_vehicle(vehicle: Node3D) -> void:
	if vehicle == null:
		return

	vehicles.erase(vehicle)


func register_target(target: Node3D) -> void:
	if target == null or not is_instance_valid(target):
		return

	if target.is_in_group("player") or target.is_in_group("players"):
		register_player(target)
		return

	if target.is_in_group("vehicle") or target.is_in_group("vehicles"):
		register_vehicle(target)
		return


func unregister_target(target: Node3D) -> void:
	if target == null:
		return

	players.erase(target)
	vehicles.erase(target)


func get_nearest_target(from_position: Vector3, max_distance: float = INF) -> Node3D:
	# Hot path. Called by many enemies. Do not allocate arrays here.
	# Do not call back into each enemy. The manager validates targets directly.
	var best_target: Node3D = null
	var best_distance_sq: float = max_distance * max_distance

	if include_players:
		for player: Node3D in players:
			if not _is_valid_cached_target(player):
				continue

			var distance_sq: float = from_position.distance_squared_to(player.global_position)
			if distance_sq < best_distance_sq:
				best_distance_sq = distance_sq
				best_target = player

	if include_vehicles:
		for vehicle: Node3D in vehicles:
			if not _is_valid_cached_target(vehicle):
				continue

			var distance_sq: float = from_position.distance_squared_to(vehicle.global_position)
			if distance_sq < best_distance_sq:
				best_distance_sq = distance_sq
				best_target = vehicle

	return best_target


func is_target_valid(target: Node3D) -> bool:
	return _is_valid_cached_target(target)


func get_valid_players() -> Array[Node3D]:
	_cleanup_cached_targets()
	var result: Array[Node3D] = []
	for player: Node3D in players:
		if _is_valid_cached_target(player):
			result.append(player)
	return result


func get_valid_vehicles() -> Array[Node3D]:
	_cleanup_cached_targets()
	var result: Array[Node3D] = []
	for vehicle: Node3D in vehicles:
		if _is_valid_cached_target(vehicle):
			result.append(vehicle)
	return result


func force_refresh_from_groups() -> void:
	_safety_refresh_from_groups()


func _connect_auto_unregister(target: Node3D) -> void:
	var target_exiting_callable: Callable = Callable(self, "_on_target_tree_exiting").bind(target)
	if not target.tree_exiting.is_connected(target_exiting_callable):
		target.tree_exiting.connect(target_exiting_callable)


func _on_target_tree_exiting(target: Node3D) -> void:
	unregister_target(target)


func _is_valid_cached_target(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not target.is_inside_tree():
		return false

	# Project fast path. Your Player and Vehicle both expose `is_dead`.
	# This avoids expensive get_property_list() scans and avoids callbacks into enemies.
	var dead_value: Variant = target.get("is_dead")
	if dead_value is bool:
		return not bool(dead_value)

	# Generic fallback for future targets.
	if target.has_method("is_alive"):
		return bool(target.call("is_alive"))

	return true


func _safety_refresh_from_groups() -> void:
	_cleanup_cached_targets()

	if include_players:
		_collect_group_targets([&"player", &"players"], true)

	if include_vehicles:
		_collect_group_targets([&"vehicle", &"vehicles"], false)


func _collect_group_targets(group_names: Array[StringName], targets_are_players: bool) -> void:
	for group_name: StringName in group_names:
		var nodes: Array = get_tree().get_nodes_in_group(group_name)
		for node in nodes:
			var target: Node3D = node as Node3D
			if target == null:
				continue

			if targets_are_players:
				register_player(target)
			else:
				register_vehicle(target)


func _cleanup_cached_targets() -> void:
	for i: int in range(players.size() - 1, -1, -1):
		var player: Node3D = players[i]
		if player == null or not is_instance_valid(player) or not player.is_inside_tree():
			players.remove_at(i)

	for i: int in range(vehicles.size() - 1, -1, -1):
		var vehicle: Node3D = vehicles[i]
		if vehicle == null or not is_instance_valid(vehicle) or not vehicle.is_inside_tree():
			vehicles.remove_at(i)
