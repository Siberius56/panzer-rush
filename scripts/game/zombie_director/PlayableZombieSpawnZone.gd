extends Node3D

# Zone de spawn contrôlée par le HordeDirector.
# Le nom affiché est automatiquement basé sur le nom du node.
# Usage :
# - IDLE_PRESENT : zombies déjà présents dans le décor.
# - HORDE_ATTACK : horde dynamique, hors champ si possible.
# - MIXED : peut servir aux deux.

class_name PlayableZombieSpawnZone

enum ZoneMode {
	IDLE_PRESENT,
	HORDE_ATTACK,
	MIXED
}

@export var enabled: bool = true
@export var zone_mode: ZoneMode = ZoneMode.IDLE_PRESENT
@export var section_id: int = 0

@export_group("Runtime Activation")
@export var runtime_active: bool = true
@export var unregister_when_runtime_inactive: bool = false

var owner_level_block: Node = null
var owner_level_block_slot: int = -1

@export_group("Spawn Count")
@export var min_spawn_count: int = 6
@export var max_spawn_count: int = 12
@export var max_alive_from_zone: int = 20

@export_group("Validation")
@export var min_distance_from_target: float = 24.0
@export var max_distance_from_target: float = 120.0
@export var cooldown_seconds: float = 30.0
@export var require_not_visible: bool = true

@export_group("Debug")
@export var show_debug_messages: bool = false

var last_spawn_time_msec: int = -999999999
var spawned_nodes: Array[Node] = []


func _ready() -> void:
	add_to_group("zombie_spawn_zone")
	_refresh_debug_label()
	call_deferred("_register_to_horde_director")


func _exit_tree() -> void:
	_unregister_from_horde_director()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PATH_RENAMED:
		_refresh_debug_label()


func _register_to_horde_director() -> void:
	if not is_inside_tree():
		return
	if unregister_when_runtime_inactive and not runtime_active:
		return
	if GameSessionState == null:
		return
	if GameSessionState.has_method("register_horde_spawn_zone"):
		GameSessionState.call("register_horde_spawn_zone", self)


func _unregister_from_horde_director() -> void:
	if GameSessionState == null:
		return
	if GameSessionState.has_method("unregister_horde_spawn_zone"):
		GameSessionState.call("unregister_horde_spawn_zone", self)


func can_spawn_idle() -> bool:
	if not is_runtime_active():
		return false
	return zone_mode == ZoneMode.IDLE_PRESENT or zone_mode == ZoneMode.MIXED


func can_spawn_attack() -> bool:
	if not is_runtime_active():
		return false
	return zone_mode == ZoneMode.HORDE_ATTACK or zone_mode == ZoneMode.MIXED


func get_spawn_points() -> Array[Marker3D]:
	var result: Array[Marker3D] = []
	_collect_spawn_points(self, result)
	return result


func is_valid_for_targets(target_positions: Array[Vector3], wants_attack: bool, wanted_section_id: int) -> bool:
	if not is_runtime_active():
		return false

	if not enabled:
		return false

	if section_id != wanted_section_id:
		return false

	if wants_attack and not can_spawn_attack():
		return false

	if not wants_attack and not can_spawn_idle():
		return false

	if get_alive_spawned_count() >= max_alive_from_zone:
		return false

	if _is_on_cooldown():
		return false

	if target_positions.is_empty():
		return true

	var closest_distance: float = _get_closest_distance_to_targets(target_positions)
	if closest_distance < min_distance_from_target:
		return false

	if closest_distance > max_distance_from_target:
		return false

	return true



func set_zone_runtime_active(active: bool) -> void:
	runtime_active = active
	if active:
		if unregister_when_runtime_inactive:
			_register_to_horde_director()
	else:
		if unregister_when_runtime_inactive:
			_unregister_from_horde_director()


func is_runtime_active() -> bool:
	return runtime_active and is_inside_tree() and process_mode != Node.PROCESS_MODE_DISABLED


func set_owner_level_block(block_node: Node, slot_index: int) -> void:
	owner_level_block = block_node
	owner_level_block_slot = slot_index
	section_id = slot_index
	set_meta("owner_level_block_slot", slot_index)
	if block_node != null and is_instance_valid(block_node):
		set_meta("owner_level_block_instance_id", block_node.get_instance_id())


func get_owner_level_block() -> Node:
	return owner_level_block


func get_owner_level_block_slot() -> int:
	return owner_level_block_slot


func register_spawned(node: Node) -> void:
	if node == null:
		return

	spawned_nodes.append(node)
	last_spawn_time_msec = Time.get_ticks_msec()


func get_alive_spawned_count() -> int:
	_cleanup_spawned_nodes()
	return spawned_nodes.size()


func get_zone_label() -> String:
	return String(name)


func get_mode_text() -> String:
	if zone_mode == ZoneMode.IDLE_PRESENT:
		return "Déjà présents"
	if zone_mode == ZoneMode.HORDE_ATTACK:
		return "Horde dynamique"
	return "Mixte"


func get_debug_line() -> String:
	var alive_count: int = get_alive_spawned_count()
	return "%s | %s | vivants: %d/%d" % [get_zone_label(), get_mode_text(), alive_count, max_alive_from_zone]


func mark_used_now() -> void:
	last_spawn_time_msec = Time.get_ticks_msec()


func _collect_spawn_points(root: Node, result: Array[Marker3D]) -> void:
	for child: Node in root.get_children():
		if child is Marker3D:
			result.append(child as Marker3D)
		_collect_spawn_points(child, result)


func _is_on_cooldown() -> bool:
	if last_spawn_time_msec < 0:
		return false

	var elapsed_seconds: float = float(Time.get_ticks_msec() - last_spawn_time_msec) / 1000.0
	return elapsed_seconds < cooldown_seconds


func _get_closest_distance_to_targets(target_positions: Array[Vector3]) -> float:
	var closest_distance: float = 999999.0

	for target_position: Vector3 in target_positions:
		var distance: float = global_position.distance_to(target_position)
		if distance < closest_distance:
			closest_distance = distance

	return closest_distance


func _cleanup_spawned_nodes() -> void:
	var cleaned: Array[Node] = []

	for node: Node in spawned_nodes:
		if node != null and is_instance_valid(node) and node.is_inside_tree():
			cleaned.append(node)

	spawned_nodes = cleaned


func _refresh_debug_label() -> void:
	var label: Label3D = get_node_or_null("Label3D") as Label3D
	if label == null:
		return

	label.text = "%s\n%s" % [get_zone_label(), get_mode_text()]
