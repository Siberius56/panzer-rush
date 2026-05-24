extends Node3D

@export var rig_id: String = "default_spawn_rig"


func get_player_spawn_points() -> Array[Node3D]:
	return _collect_node3d_children("SpawnPoints")


func get_vehicle_spawn_points() -> Array[Node3D]:
	return _collect_node3d_children("VehicleSpawns")


func _collect_node3d_children(root_name: String) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var root: Node = get_node_or_null(root_name)
	if root == null:
		return result

	for child: Node in root.get_children():
		if child is Node3D:
			result.append(child as Node3D)

	return result
