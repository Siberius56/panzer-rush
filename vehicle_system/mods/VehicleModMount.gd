extends Node3D
class_name VehicleModMount

@export_range(1, 6, 1) var mod_use_id: int = 1
@export var mount_label: String = "Emplacement de module"
@export_range(0, 4, 1) var max_mod_size: int = 1
@export_enum("front", "rear", "side", "center") var placement: String = "center"
@export var mod_scene: PackedScene

var vehicle: Vehicle = null
var mod: VehicleModBase = null


func _ready() -> void:
	if not is_in_group("vehicle_mod_mount"):
		add_to_group("vehicle_mod_mount")


func initialize(owner_vehicle: Vehicle) -> void:
	vehicle = owner_vehicle

	if max_mod_size <= 0:
		_clear_mod()
		return

	if mod_scene != null and mod == null:
		_spawn_mod(mod_scene)

	if mod != null:
		mod.setup(self, vehicle)


func has_mod() -> bool:
	return mod != null


func can_peer_operate(peer_id: int) -> bool:
	return vehicle != null and vehicle.get_driver_peer_id() == peer_id and mod != null


func get_mod_label() -> String:
	if mod == null:
		return ""
	return mod.mod_label


func get_mod_price() -> int:
	if mod == null:
		return 0
	return mod.mod_price


func get_mod_scene_path() -> String:
	if mod_scene == null:
		return ""
	return mod_scene.resource_path


func get_empty_reason() -> String:
	if max_mod_size <= 0:
		return "Aucun emplacement de module"
	if has_mod():
		return "Emplacement déjà occupé"
	return "Emplacement libre"


func get_runtime_data() -> Dictionary:
	var data: Dictionary = {
		"mod_use_id": mod_use_id,
		"input_action": "mod_use_%d" % mod_use_id,
		"input_label": str(mod_use_id),
		"mount_label": mount_label,
		"max_mod_size": max_mod_size,
		"placement": placement,
		"has_mod": has_mod(),
		"mod_label": "",
		"mod_id": "",
		"activation_mode": "",
		"is_active": false,
		"active_remaining": 0.0,
		"active_duration": 0.0,
		"cooldown_remaining": 0.0,
		"cooldown_duration": 0.0,
		"can_use": false,
	}

	if mod != null:
		var runtime_data: Dictionary = mod.get_runtime_data()
		for key in runtime_data.keys():
			data[key] = runtime_data[key]
		data["has_mod"] = true

	return data


func can_install_mod_scene(new_mod_scene: PackedScene) -> bool:
	if has_mod():
		return false
	return _is_mod_scene_compatible(new_mod_scene)


func _is_mod_scene_compatible(new_mod_scene: PackedScene) -> bool:
	if new_mod_scene == null:
		return false

	if max_mod_size <= 0:
		return false

	var info: Dictionary = VehicleModBase.inspect_scene(new_mod_scene)
	if info.is_empty():
		return false

	var new_size: int = int(info.get("mod_size", 0))
	if new_size <= 0 or new_size > max_mod_size:
		return false

	var allowed_placements: Array = info.get("allowed_placements", [])
	if allowed_placements.is_empty():
		return true

	var normalized_placement: String = _normalize_placement(placement)
	for raw_allowed_value in allowed_placements:
		if _normalize_placement(String(raw_allowed_value)) == normalized_placement:
			return true

	return false


func install_mod(new_mod_scene: PackedScene) -> bool:
	if not _is_mod_scene_compatible(new_mod_scene):
		return false

	mod_scene = new_mod_scene
	_spawn_mod(mod_scene)

	if mod != null and vehicle != null:
		mod.setup(self, vehicle)
		return true

	return false


func remove_mod() -> void:
	mod_scene = null
	_clear_mod()


func apply_host_use(peer_id: int) -> bool:
	if not multiplayer.is_server():
		return false

	if not can_peer_operate(peer_id):
		return false

	if mod == null:
		return false

	return mod.try_activate(peer_id)


func _spawn_mod(scene: PackedScene) -> void:
	_clear_mod()

	if scene == null:
		return

	var instance: Node = scene.instantiate()
	instance.name = "MountedMod"
	add_child(instance)

	if instance is VehicleModBase:
		mod = instance as VehicleModBase
	else:
		push_warning("VehicleModMount: la scène de module doit avoir VehicleModBase à la racine.")
		instance.queue_free()
		mod = null


func _clear_mod() -> void:
	if mod != null:
		mod.teardown()
		remove_child(mod)
		mod.queue_free()
		mod = null


func _normalize_placement(raw_value: String) -> String:
	var normalized_value: String = raw_value.strip_edges().to_lower()
	if normalized_value == "front":
		return "front"
	if normalized_value == "rear":
		return "rear"
	if normalized_value == "side" or normalized_value == "lateral":
		return "side"
	if normalized_value == "center":
		return "center"
	return normalized_value


@rpc("any_peer", "call_remote", "reliable")
func send_mod_use_input() -> void:
	if not multiplayer.is_server():
		return

	var sender: int = multiplayer.get_remote_sender_id()
	apply_host_use(sender)
