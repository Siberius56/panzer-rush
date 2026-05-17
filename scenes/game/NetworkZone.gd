extends Node3D
class_name NetworkZone

@export var cache_on_ready: bool = true
@export var affects_multiplayer_synchronizers: bool = true
@export var affects_multiplayer_spawners: bool = false
@export var hide_when_inactive: bool = false
@export var disable_process_when_inactive: bool = false
@export var disable_physics_process_when_inactive: bool = false
@export var debug_zone: bool = false

var cached_synchronizers: Array[MultiplayerSynchronizer] = []
var cached_spawners: Array[MultiplayerSpawner] = []


func _ready() -> void:
	if cache_on_ready:
		refresh_cache()


func refresh_cache() -> void:
	cached_synchronizers.clear()
	cached_spawners.clear()
	
	var sync_nodes: Array[Node] = find_children("*", "MultiplayerSynchronizer", true, false)
	for node: Node in sync_nodes:
		var sync: MultiplayerSynchronizer = node as MultiplayerSynchronizer
		if sync != null:
			cached_synchronizers.append(sync)
	
	var spawner_nodes: Array[Node] = find_children("*", "MultiplayerSpawner", true, false)
	for node: Node in spawner_nodes:
		var spawner: MultiplayerSpawner = node as MultiplayerSpawner
		if spawner != null:
			cached_spawners.append(spawner)
	
	if debug_zone:
		print("[NetworkZone] ", name, " cache: ", cached_synchronizers.size(), " synchronizers, ", cached_spawners.size(), " spawners.")


func set_network_zone_active(active: bool) -> void:
	if affects_multiplayer_synchronizers:
		_set_synchronizers_active(active)
	
	if affects_multiplayer_spawners:
		_set_spawners_active(active)
	
	if hide_when_inactive:
		visible = active
	
	if disable_process_when_inactive:
		_set_process_recursive(self, active)
	
	if disable_physics_process_when_inactive:
		_set_physics_process_recursive(self, active)
	
	if debug_zone:
		print("[NetworkZone] ", name, " active = ", active)


func _set_synchronizers_active(active: bool) -> void:
	for sync: MultiplayerSynchronizer in cached_synchronizers:
		if sync == null or not is_instance_valid(sync):
			continue
		
		sync.public_visibility = active
		
		for peer_id: int in multiplayer.get_peers():
			sync.set_visibility_for(peer_id, active)


func _set_spawners_active(active: bool) -> void:
	for spawner: MultiplayerSpawner in cached_spawners:
		if spawner == null or not is_instance_valid(spawner):
			continue
		
		spawner.public_visibility = active
		
		for peer_id: int in multiplayer.get_peers():
			spawner.set_visibility_for(peer_id, active)


func _set_process_recursive(root: Node, active: bool) -> void:
	root.set_process(active)
	
	for child: Node in root.get_children():
		_set_process_recursive(child, active)


func _set_physics_process_recursive(root: Node, active: bool) -> void:
	root.set_physics_process(active)
	
	for child: Node in root.get_children():
		_set_physics_process_recursive(child, active)
