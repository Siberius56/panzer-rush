extends Node3D
class_name VehicleModBase

signal runtime_state_changed

@export_group("Meta")
@export var mod_id: String = "mod"
@export var mod_label: String = "Module"
@export_range(1, 4, 1) var mod_size: int = 1
@export var mod_price: int = 0
@export_enum("passive", "active") var activation_mode: String = "passive"
@export var allowed_placements: Array[String] = ["center"]

@export_group("Active")
@export var active_duration: float = 0.0
@export var cooldown_duration: float = 0.0
@export var cooldown_starts_after_active: bool = true
@export var allow_reactivate_while_active: bool = false

@export_group("Visual")
@export var visual_root_path: NodePath = NodePath("VisualRoot")
@export var show_visual_only_when_active: bool = false

var mount: VehicleModMount = null
var vehicle: Vehicle = null
var is_runtime_active: bool = false
var active_remaining: float = 0.0
var cooldown_remaining: float = 0.0
var passive_enabled: bool = false
var visual_root: Node3D = null


static func inspect_scene(scene: PackedScene) -> Dictionary:
	if scene == null:
		return {}

	var instance: Node = scene.instantiate()
	if instance == null:
		return {}

	var info: Dictionary = {
		"mod_id": "",
		"mod_label": "",
		"mod_size": 0,
		"mod_price": 0,
		"activation_mode": "passive",
		"allowed_placements": [],
	}

	if instance is VehicleModBase:
		var mod: VehicleModBase = instance as VehicleModBase
		info["mod_id"] = mod.mod_id
		info["mod_label"] = mod.mod_label
		info["mod_size"] = mod.mod_size
		info["mod_price"] = mod.mod_price
		info["activation_mode"] = mod.activation_mode
		info["allowed_placements"] = mod.allowed_placements.duplicate()

	instance.queue_free()
	return info


func _ready() -> void:
	_cache_visual_root()
	_update_visual_visibility()


func setup(owner_mount: VehicleModMount, owner_vehicle: Vehicle) -> void:
	mount = owner_mount
	vehicle = owner_vehicle
	set_multiplayer_authority(1)
	_cache_visual_root()
	_update_visual_visibility()

	if multiplayer.is_server() and is_passive_mod() and not passive_enabled:
		passive_enabled = true
		_on_passive_enabled()


func teardown() -> void:
	if multiplayer.is_server():
		if is_runtime_active:
			_finish_active()
		if passive_enabled:
			_on_passive_disabled()
			passive_enabled = false

	mount = null
	vehicle = null


func is_active_mod() -> bool:
	return activation_mode == "active"


func is_passive_mod() -> bool:
	return activation_mode == "passive"


func can_be_installed_on(placement: String) -> bool:
	if allowed_placements.is_empty():
		return true

	var normalized_placement: String = _normalize_placement(placement)
	for allowed_value in allowed_placements:
		if _normalize_placement(String(allowed_value)) == normalized_placement:
			return true

	return false


func try_activate(peer_id: int) -> bool:
	if not multiplayer.is_server():
		return false

	if not is_active_mod():
		return false

	if vehicle == null or mount == null:
		return false

	if peer_id != vehicle.get_driver_peer_id():
		return false

	if is_runtime_active and not allow_reactivate_while_active:
		return false

	if cooldown_remaining > 0.0:
		return false

	is_runtime_active = true
	active_remaining = maxf(active_duration, 0.0)

	if not cooldown_starts_after_active:
		cooldown_remaining = maxf(cooldown_duration, 0.0)

	_on_active_started(peer_id)
	_update_visual_visibility()
	_sync_mod_runtime_state.rpc(is_runtime_active, cooldown_remaining, active_remaining)
	emit_signal("runtime_state_changed")

	if active_duration <= 0.0:
		_finish_active()

	return true


func force_end_active() -> void:
	if not multiplayer.is_server():
		return
	_finish_active()


func get_runtime_data() -> Dictionary:
	return {
		"mod_id": mod_id,
		"mod_label": mod_label,
		"activation_mode": activation_mode,
		"is_active": is_runtime_active,
		"active_remaining": active_remaining,
		"active_duration": active_duration,
		"cooldown_remaining": cooldown_remaining,
		"cooldown_duration": cooldown_duration,
		"can_use": is_active_mod() and cooldown_remaining <= 0.0 and not is_runtime_active,
	}


func get_modifier_key() -> String:
	return "%s:%d" % [mod_id, get_instance_id()]


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		if is_runtime_active:
			active_remaining = maxf(active_remaining - delta, 0.0)
		elif cooldown_remaining > 0.0:
			cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
		return

	if is_runtime_active:
		active_remaining = maxf(active_remaining - delta, 0.0)
		_on_active_physics(delta)

		if active_remaining <= 0.0:
			_finish_active()
		return

	if cooldown_remaining > 0.0:
		cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
		if cooldown_remaining <= 0.0:
			_sync_mod_runtime_state.rpc(is_runtime_active, cooldown_remaining, active_remaining)
			emit_signal("runtime_state_changed")


func _finish_active() -> void:
	if not is_runtime_active:
		return

	_on_active_ended()
	is_runtime_active = false
	active_remaining = 0.0

	if cooldown_starts_after_active:
		cooldown_remaining = maxf(cooldown_duration, 0.0)

	_update_visual_visibility()
	_sync_mod_runtime_state.rpc(is_runtime_active, cooldown_remaining, active_remaining)
	emit_signal("runtime_state_changed")


func _cache_visual_root() -> void:
	visual_root = get_node_or_null(visual_root_path) as Node3D


func _update_visual_visibility() -> void:
	if visual_root == null:
		return

	if show_visual_only_when_active:
		visual_root.visible = is_runtime_active
	else:
		visual_root.visible = true


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


func _on_passive_enabled() -> void:
	pass


func _on_passive_disabled() -> void:
	pass


func _on_active_started(_peer_id: int) -> void:
	pass


func _on_active_physics(_delta: float) -> void:
	pass


func _on_active_ended() -> void:
	pass


@rpc("authority", "call_local", "reliable")
func _sync_mod_runtime_state(synced_active: bool, synced_cooldown_remaining: float, synced_active_remaining: float) -> void:
	is_runtime_active = synced_active
	cooldown_remaining = maxf(synced_cooldown_remaining, 0.0)
	active_remaining = maxf(synced_active_remaining, 0.0)
	_update_visual_visibility()
	emit_signal("runtime_state_changed")
