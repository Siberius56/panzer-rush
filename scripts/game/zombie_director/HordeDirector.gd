extends Node3D

# Director de horde inspiré d'un AI Director.
# Il sépare clairement :
# - les zombies déjà présents dans le décor.
# - les hordes dynamiques qui arrivent pendant le niveau.
# - les méga hordes rares, depuis 2 ou 3 zones.
#
# Le Director choisit des SpawnPoints valides, pas seulement des zones valides.
# Un SpawnPoint est refusé s'il est visible par la caméra d'au moins un joueur.
# En multijoueur, il est conseillé de laisser uniquement l'host décider des spawns/despawns.

class_name HordeDirectorDemo

enum DirectorState {
	REST,
	BUILD_UP,
	HORDE,
	SUPER_HORDE,
	COOLDOWN
}

@export var director_enabled: bool = true
@export var server_only: bool = true
@export var current_section_id: int = 0

@export_group("Spawn Scenes")
# Ancien champ conservé comme fallback.
# Si tonfa_enemy_scene n'est pas assignée, zombie_scene sera utilisé comme soldat tonfa par défaut.
@export var zombie_scene: PackedScene
@export var enemies_root_path: NodePath = ^"../Enemies"

@export_group("Enemy Scene Auto Load")
@export var auto_load_enemy_scenes_from_paths: bool = true
@export_file("*.tscn") var tonfa_enemy_scene_path: String = "res://scenes/enemies/NetworkTonfaEnemy.tscn"
@export_file("*.tscn") var shield_enemy_scene_path: String = "res://scenes/enemies/NetworkShieldEnemy.tscn"
@export_file("*.tscn") var rifleman_enemy_scene_path: String = "res://scenes/enemies/NetworkRiflemanEnemy.tscn"
@export_file("*.tscn") var anti_tank_enemy_scene_path: String = "res://scenes/enemies/NetworkAntiTankEnemy.tscn"
@export_file("*.tscn") var hammer_enemy_scene_path: String = "res://scenes/enemies/NetworkHammerEnemy.tscn"

@export_group("Enemy Composition")
@export var use_enemy_composition_for_idle_population: bool = false
@export var tonfa_enemy_scene: PackedScene
@export_range(0, 100, 1) var tonfa_weight: int = 55
@export var shield_enemy_scene: PackedScene
@export_range(0, 100, 1) var shield_weight: int = 25
@export var rifleman_enemy_scene: PackedScene
@export_range(0, 100, 1) var rifleman_weight: int = 15
@export var anti_tank_enemy_scene: PackedScene
@export_range(0, 100, 1) var anti_tank_weight: int = 5

@export_group("Super Horde Composition")
@export var super_horde_extra_minions_min: int = 8
@export var super_horde_extra_minions_max: int = 16
@export var allow_hammers_in_super_hordes: bool = true
@export var hammer_enemy_scene: PackedScene
@export var super_horde_min_hammers: int = 1
@export var super_horde_max_hammers: int = 2

@export_group("Targets")
@export var player_group_name: String = "players"
@export var fallback_target_path: NodePath = ^"../DirectorDemoTarget"

@export_group("Director Timing")
@export var rest_min_seconds: float = 18.0
@export var rest_max_seconds: float = 35.0
@export var build_up_seconds: float = 6.0
@export var cooldown_seconds: float = 14.0
@export var spawn_interval_min: float = 0.12
@export var spawn_interval_max: float = 0.28

@export_group("Mega Horde")
@export var mega_horde_enabled: bool = true
@export_range(0.0, 1.0, 0.01) var mega_horde_chance: float = 0.12
@export var mega_horde_cooldown_seconds: float = 240.0
@export var mega_horde_min_zones: int = 2
@export var mega_horde_max_zones: int = 3
@export var mega_horde_min_zombies: int = 35
@export var mega_horde_max_zombies: int = 65
@export var mega_horde_extra_cooldown_seconds: float = 28.0

@export_group("Visibility")
@export var avoid_visible_spawns: bool = true
@export var use_real_player_cameras: bool = true
@export var use_topdown_visibility_fallback: bool = true
@export var player_camera_node_name: String = "Camera3D"
@export var visibility_margin_pixels: float = 96.0
@export var topdown_visible_half_width: float = 42.0
@export var topdown_visible_half_depth: float = 28.0
@export var topdown_visibility_margin: float = 8.0

@export_group("Cleanup")
@export var cleanup_enabled: bool = true
@export var cleanup_check_interval: float = 3.0
@export var despawn_distance: float = 180.0
@export var despawn_old_sections: bool = true
@export var sections_to_keep_behind: int = 0
@export var despawn_only_director_spawned: bool = false
@export var cleanup_far_zombies_only_when_above_limit: bool = true
@export var debug_print_cleanup_reasons: bool = true

@export_group("Limits")
@export var max_alive_zombies: int = 80
@export var idle_population_on_ready: bool = true
@export var max_idle_zones_populated_on_ready: int = 3

@export_group("Debug")
@export var debug_print_events: bool = true

var state: DirectorState = DirectorState.REST
var state_timer: float = 0.0
var next_spawn_timer: float = 0.0
var horde_remaining: int = 0
var super_horde_hammer_remaining: int = 0
var active_horde_zone: Node = null
var active_horde_zones: Array[Node] = []
var active_horde_points_by_zone: Dictionary = {}
var last_event_text: String = "Initialisation"
var cached_zones: Array[Node] = []
var initial_idle_population_done: bool = false
var waiting_for_idle_population_deferred: bool = false
var random: RandomNumberGenerator = RandomNumberGenerator.new()
var time_since_last_mega_horde: float = 999999.0
var cleanup_timer: float = 0.0
var spawned_zombie_sections: Dictionary = {}
var spawned_zombie_last_combat_time: Dictionary = {}


func _ready() -> void:
	add_to_group("horde_director")
	random.randomize()
	_auto_load_enemy_scenes()
	_register_in_game_session_state()
	_collect_zones()
	_schedule_rest()
	_schedule_initial_idle_population_once()
	_emit_event("Director prêt. Zones trouvées : %d" % cached_zones.size())


func _exit_tree() -> void:
	_unregister_from_game_session_state()


func _process(delta: float) -> void:
	if not director_enabled:
		return

	if server_only and multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	time_since_last_mega_horde += delta
	_update_state(delta)
	_update_cleanup(delta)


func get_debug_info() -> Dictionary:
	_prune_cached_zones()
	var info: Dictionary = {}
	info["state"] = get_state_text()
	info["state_key"] = get_state_key()
	info["timer"] = max(state_timer, 0.0)
	info["alive"] = get_alive_zombie_count()
	info["max_alive"] = max_alive_zombies
	info["remaining"] = horde_remaining
	info["hammer_remaining"] = super_horde_hammer_remaining
	info["active_zone"] = _get_active_zones_text()
	info["last_event"] = last_event_text
	info["zones"] = cached_zones.size()
	info["next_action"] = _get_next_action_text()
	info["mega_cooldown"] = max(mega_horde_cooldown_seconds - time_since_last_mega_horde, 0.0)
	info["visibility_filter"] = avoid_visible_spawns
	return info


func force_horde_now() -> void:
	if state == DirectorState.HORDE or state == DirectorState.SUPER_HORDE:
		return

	_start_build_up(false)


func force_mega_horde_now() -> void:
	if state == DirectorState.HORDE or state == DirectorState.SUPER_HORDE:
		return

	_start_build_up(true)


func get_state_text() -> String:
	if state == DirectorState.REST:
		return "Repos"
	if state == DirectorState.BUILD_UP:
		if active_horde_zones.size() > 1:
			return "Préparation méga horde"
		return "Préparation de horde"
	if state == DirectorState.HORDE:
		return "HORDE ACTIVE"
	if state == DirectorState.SUPER_HORDE:
		return "MÉGA HORDE ACTIVE"
	if state == DirectorState.COOLDOWN:
		return "Récupération"
	return "Inconnu"


func get_state_key() -> String:
	if state == DirectorState.REST:
		return "idle"
	if state == DirectorState.BUILD_UP:
		return "preparation"
	if state == DirectorState.HORDE:
		return "horde"
	if state == DirectorState.SUPER_HORDE:
		return "super_horde"
	if state == DirectorState.COOLDOWN:
		return "cooldown"
	return "unknown"


func get_alive_zombie_count() -> int:
	var count: int = 0
	var enemies_root: Node = _get_enemies_root()

	if enemies_root != null:
		for child in enemies_root.get_children():
			if child != null and is_instance_valid(child) and child.is_inside_tree():
				if child.is_in_group("zombies") or child.is_in_group("enemies") or child.is_in_group("enemy"):
					count += 1
		return count

	for node in get_tree().get_nodes_in_group("zombies"):
		if node != null and is_instance_valid(node):
			count += 1

	return count


func _update_state(delta: float) -> void:
	state_timer -= delta

	if state == DirectorState.REST:
		if state_timer <= 0.0:
			var wants_mega_horde: bool = _should_start_mega_horde()
			_start_build_up(wants_mega_horde)
		return

	if state == DirectorState.BUILD_UP:
		if state_timer <= 0.0:
			_start_horde()
		return

	if state == DirectorState.HORDE or state == DirectorState.SUPER_HORDE:
		_update_horde_spawning(delta)
		return

	if state == DirectorState.COOLDOWN:
		if state_timer <= 0.0:
			_schedule_rest()
		return


func _schedule_rest() -> void:
	state = DirectorState.REST
	state_timer = random.randf_range(rest_min_seconds, rest_max_seconds)
	active_horde_zone = null
	active_horde_zones.clear()
	active_horde_points_by_zone.clear()
	horde_remaining = 0
	super_horde_hammer_remaining = 0
	_emit_event("Repos. Prochaine décision dans %.1f s." % state_timer)


func _start_build_up(wants_mega_horde: bool = false) -> void:
	if get_alive_zombie_count() >= max_alive_zombies:
		state_timer = 8.0
		_emit_event("Horde refusée. Trop de zombies actifs.")
		return

	active_horde_zones.clear()
	active_horde_points_by_zone.clear()
	active_horde_zone = null

	if wants_mega_horde:
		active_horde_zones = _pick_valid_zones_for_mega_horde()
		if active_horde_zones.size() < mega_horde_min_zones:
			active_horde_zones.clear()
			_emit_event("Méga horde refusée. Pas assez de zones hors caméra.")
			_start_build_up(false)
			return
	else:
		active_horde_zone = _pick_valid_zone(true)
		if active_horde_zone != null:
			active_horde_zones.append(active_horde_zone)

	if active_horde_zones.is_empty():
		state_timer = 8.0
		_emit_event("Aucune zone valide pour une horde.")
		return

	state = DirectorState.BUILD_UP
	state_timer = build_up_seconds

	if active_horde_zones.size() > 1:
		_emit_event("Préparation MÉGA HORDE : %s." % _get_active_zones_text())
	else:
		_emit_event("Préparation horde : %s." % _get_active_zones_text())


func _start_horde() -> void:
	if active_horde_zones.is_empty():
		_schedule_rest()
		return

	if active_horde_zones.size() > 1:
		state = DirectorState.SUPER_HORDE
		var base_count: int = random.randi_range(mega_horde_min_zombies, mega_horde_max_zombies)
		var extra_minion_count: int = _get_super_horde_extra_minion_count()
		super_horde_hammer_remaining = _get_super_horde_hammer_count()
		horde_remaining = base_count + extra_minion_count + super_horde_hammer_remaining
		time_since_last_mega_horde = 0.0
	else:
		state = DirectorState.HORDE
		super_horde_hammer_remaining = 0
		horde_remaining = _get_zone_spawn_count(active_horde_zones[0])

	state_timer = 0.0
	next_spawn_timer = 0.0

	for zone in active_horde_zones:
		if zone != null and is_instance_valid(zone) and zone.has_method("mark_used_now"):
			zone.call("mark_used_now")

	if state == DirectorState.SUPER_HORDE:
		_emit_event("MÉGA HORDE lancée depuis %d zones. Ennemis prévus : %d, hammers : %d." % [active_horde_zones.size(), horde_remaining, super_horde_hammer_remaining])
	else:
		_emit_event("Horde lancée depuis : %s. Zombies prévus : %d." % [_get_active_zones_text(), horde_remaining])


func _update_horde_spawning(delta: float) -> void:
	if horde_remaining <= 0:
		state = DirectorState.COOLDOWN
		state_timer = cooldown_seconds
		if active_horde_zones.size() > 1:
			state_timer += mega_horde_extra_cooldown_seconds
		_emit_event("Horde terminée. Cooldown %.1f s." % state_timer)
		return

	if get_alive_zombie_count() >= max_alive_zombies:
		state = DirectorState.COOLDOWN
		state_timer = cooldown_seconds
		_emit_event("Horde stoppée. Limite de zombies atteinte.")
		return

	next_spawn_timer -= delta
	if next_spawn_timer > 0.0:
		return

	var zone: Node = _pick_active_horde_zone_for_spawn()
	if zone == null:
		state = DirectorState.COOLDOWN
		state_timer = cooldown_seconds
		_emit_event("Horde stoppée. Plus aucun SpawnPoint valide hors caméra.")
		return

	_spawn_one_from_zone(zone, "attack")
	horde_remaining -= 1
	next_spawn_timer = random.randf_range(spawn_interval_min, spawn_interval_max)


func _spawn_initial_idle_population() -> void:
	var populated_count: int = 0

	for zone in cached_zones:
		if populated_count >= max_idle_zones_populated_on_ready:
			return

		if get_alive_zombie_count() >= max_alive_zombies:
			_emit_event("Population idle stoppée. Limite globale atteinte : %d/%d." % [get_alive_zombie_count(), max_alive_zombies])
			return

		if zone == null or not is_instance_valid(zone):
			continue

		if not zone.has_method("can_spawn_idle") or not zone.call("can_spawn_idle"):
			continue

		var requested_spawn_count: int = _get_zone_spawn_count(zone)
		var remaining_budget: int = max_alive_zombies - get_alive_zombie_count()
		var spawn_count: int = clampi(requested_spawn_count, 0, remaining_budget)
		if spawn_count <= 0:
			return

		var actual_spawn_count: int = 0
		for index in range(spawn_count):
			var spawned: Node = _spawn_one_from_zone(zone, "idle")
			if spawned != null:
				actual_spawn_count += 1

		if actual_spawn_count <= 0:
			continue

		if zone.has_method("mark_used_now"):
			zone.call("mark_used_now")

		populated_count += 1
		if actual_spawn_count < requested_spawn_count:
			_emit_event("Population idle : %s, %d/%d zombies. Budget global atteint." % [_get_zone_name(zone), actual_spawn_count, requested_spawn_count])
		else:
			_emit_event("Population idle : %s, %d zombies." % [_get_zone_name(zone), actual_spawn_count])


func _spawn_one_from_zone(zone: Node, behaviour: String) -> Node:
	if zone == null or not is_instance_valid(zone):
		return null

	var point: Marker3D = _pick_valid_spawn_point(zone, behaviour == "attack")
	if point == null:
		_emit_event("Aucun SpawnPoint valide hors caméra : %s." % _get_zone_name(zone))
		return null

	var scene_to_spawn: PackedScene = _get_scene_to_spawn(behaviour)
	if scene_to_spawn == null:
		_emit_event("Aucune scène d'ennemi assignée.")
		return null

	var spawn_position: Vector3 = _get_navigation_safe_position(point.global_position)
	var zombie: Node = scene_to_spawn.instantiate()
	var enemies_root: Node = _get_enemies_root()

	if enemies_root != null:
		enemies_root.add_child(zombie)
	else:
		get_tree().current_scene.add_child(zombie)

	if zombie is Node3D:
		var zombie_3d: Node3D = zombie as Node3D
		zombie_3d.global_position = spawn_position
		zombie_3d.rotation.y = random.randf_range(-PI, PI)

	_add_basic_groups(zombie)
	_register_spawned_zombie(zombie)
	_setup_spawned_zombie(zombie, behaviour)

	if zone.has_method("register_spawned"):
		zone.call("register_spawned", zombie)

	return zombie


func _setup_spawned_zombie(zombie: Node, behaviour: String) -> void:
	var target_position: Vector3 = _get_targets_center()

	if zombie.has_method("setup_director_demo"):
		zombie.call("setup_director_demo", behaviour, target_position)
		return

	if zombie.has_method("set_spawn_behaviour"):
		zombie.call("set_spawn_behaviour", behaviour)

	if behaviour == "attack":
		if zombie.has_method("set_target_position"):
			zombie.call("set_target_position", target_position)
		elif zombie.has_method("set_target"):
			var target_node: Node = _get_best_target_node()
			if target_node != null:
				zombie.call("set_target", target_node)

	if zombie.has_method("set_ai_enabled_delayed"):
		zombie.call("set_ai_enabled_delayed", random.randf_range(0.1, 1.2))


func _register_spawned_zombie(zombie: Node) -> void:
	if zombie == null:
		return

	spawned_zombie_sections[zombie.get_instance_id()] = current_section_id
	spawned_zombie_last_combat_time[zombie.get_instance_id()] = Time.get_ticks_msec()

	if zombie.has_method("set_spawned_section_id"):
		zombie.call("set_spawned_section_id", current_section_id)


func register_spawn_zone(zone: Node) -> void:
	if zone == null or not is_instance_valid(zone):
		return
	if not _is_valid_spawn_zone_node(zone):
		return

	_prune_cached_zones()
	if not cached_zones.has(zone):
		cached_zones.append(zone)
		_emit_event("Zone enregistrée : %s. Total : %d" % [_get_zone_name(zone), cached_zones.size()])

	_schedule_initial_idle_population_once()


func unregister_spawn_zone(zone: Node) -> void:
	if zone == null:
		return

	if cached_zones.has(zone):
		cached_zones.erase(zone)

	if active_horde_zone == zone:
		active_horde_zone = null

	if active_horde_zones.has(zone):
		active_horde_zones.erase(zone)

	if is_instance_valid(zone):
		active_horde_points_by_zone.erase(zone.get_instance_id())

	if cached_zones.is_empty():
		initial_idle_population_done = false
		waiting_for_idle_population_deferred = false


func refresh_registered_spawn_zones() -> void:
	_collect_zones()
	_schedule_initial_idle_population_once()


func clear_registered_spawn_zones() -> void:
	cached_zones.clear()
	active_horde_zone = null
	active_horde_zones.clear()
	active_horde_points_by_zone.clear()
	initial_idle_population_done = false
	waiting_for_idle_population_deferred = false


func _register_in_game_session_state() -> void:
	if GameSessionState == null:
		return
	if GameSessionState.has_method("set_horde_director"):
		GameSessionState.call("set_horde_director", self)


func _unregister_from_game_session_state() -> void:
	if GameSessionState == null:
		return
	if GameSessionState.has_method("clear_horde_director"):
		GameSessionState.call("clear_horde_director", self)


func _schedule_initial_idle_population_once() -> void:
	if not idle_population_on_ready:
		return
	if initial_idle_population_done:
		return
	if waiting_for_idle_population_deferred:
		return

	waiting_for_idle_population_deferred = true
	call_deferred("_try_spawn_initial_idle_population_once")


func _try_spawn_initial_idle_population_once() -> void:
	waiting_for_idle_population_deferred = false
	if initial_idle_population_done:
		return

	_prune_cached_zones()
	if cached_zones.is_empty():
		return

	initial_idle_population_done = true
	_spawn_initial_idle_population()


func _collect_zones() -> void:
	cached_zones.clear()

	if GameSessionState != null and GameSessionState.has_method("get_horde_spawn_zones"):
		var session_zones: Array = GameSessionState.call("get_horde_spawn_zones")
		for zone in session_zones:
			_add_zone_if_valid(zone)

	var tree: SceneTree = get_tree()
	if tree != null:
		for node in tree.get_nodes_in_group("zombie_spawn_zone"):
			_add_zone_if_valid(node)

	if cached_zones.is_empty():
		_collect_zones_from_children(self)

	_prune_cached_zones()


func _collect_zones_from_children(root: Node) -> void:
	for child in root.get_children():
		if child != null and child.is_in_group("zombie_spawn_zone"):
			_add_zone_if_valid(child)
		_collect_zones_from_children(child)


func _add_zone_if_valid(zone: Variant) -> void:
	if not (zone is Node):
		return
	var zone_node: Node = zone as Node
	if not _is_valid_spawn_zone_node(zone_node):
		return
	if cached_zones.has(zone_node):
		return
	cached_zones.append(zone_node)


func _is_valid_spawn_zone_node(zone: Node) -> bool:
	if zone == null or not is_instance_valid(zone):
		return false
	if not zone.is_inside_tree():
		return false
	if zone.has_method("get_spawn_points"):
		return true
	return zone.is_in_group("zombie_spawn_zone")


func _prune_cached_zones() -> void:
	var cleaned: Array[Node] = []
	for zone in cached_zones:
		if _is_valid_spawn_zone_node(zone):
			cleaned.append(zone)
	cached_zones = cleaned

	var cleaned_active: Array[Node] = []
	for zone in active_horde_zones:
		if _is_valid_spawn_zone_node(zone):
			cleaned_active.append(zone)
	active_horde_zones = cleaned_active

	if active_horde_zone != null and not _is_valid_spawn_zone_node(active_horde_zone):
		active_horde_zone = null


func _pick_valid_zone(wants_attack: bool) -> Node:
	var candidates: Array[Node] = _get_valid_zones(wants_attack)

	if candidates.is_empty():
		return null

	return candidates[random.randi_range(0, candidates.size() - 1)]


func _pick_valid_zones_for_mega_horde() -> Array[Node]:
	var candidates: Array[Node] = _get_valid_zones(true)
	var selected: Array[Node] = []

	if candidates.size() < mega_horde_min_zones:
		return selected

	candidates.shuffle()

	var zone_count: int = random.randi_range(mega_horde_min_zones, mega_horde_max_zones)
	zone_count = min(zone_count, candidates.size())

	for index in range(zone_count):
		selected.append(candidates[index])

	return selected


func _get_valid_zones(wants_attack: bool) -> Array[Node]:
	_prune_cached_zones()
	var target_positions: Array[Vector3] = _get_target_positions()
	var candidates: Array[Node] = []

	for zone in cached_zones:
		if zone == null or not is_instance_valid(zone):
			continue

		if zone.has_method("is_valid_for_targets"):
			var is_valid: bool = zone.call("is_valid_for_targets", target_positions, wants_attack, current_section_id)
			if not is_valid:
				continue

		if wants_attack:
			var valid_points: Array[Marker3D] = _get_valid_spawn_points(zone, true)
			if valid_points.is_empty():
				continue
			active_horde_points_by_zone[zone.get_instance_id()] = valid_points

		candidates.append(zone)

	return candidates


func _pick_active_horde_zone_for_spawn() -> Node:
	var valid_zones: Array[Node] = []

	for zone in active_horde_zones:
		if zone == null or not is_instance_valid(zone):
			continue

		var valid_points: Array[Marker3D] = _get_valid_spawn_points(zone, true)
		if valid_points.is_empty():
			continue

		active_horde_points_by_zone[zone.get_instance_id()] = valid_points
		valid_zones.append(zone)

	if valid_zones.is_empty():
		return null

	return valid_zones[random.randi_range(0, valid_zones.size() - 1)]


func _pick_valid_spawn_point(zone: Node, wants_attack: bool) -> Marker3D:
	var valid_points: Array[Marker3D] = _get_valid_spawn_points(zone, wants_attack)

	if valid_points.is_empty():
		return null

	return valid_points[random.randi_range(0, valid_points.size() - 1)]


func _get_valid_spawn_points(zone: Node, wants_attack: bool) -> Array[Marker3D]:
	var result: Array[Marker3D] = []

	if zone == null or not is_instance_valid(zone):
		return result

	var raw_spawn_points: Array = []
	if zone.has_method("get_spawn_points"):
		raw_spawn_points = zone.call("get_spawn_points")

	for raw_point in raw_spawn_points:
		if not (raw_point is Marker3D):
			continue

		var point: Marker3D = raw_point as Marker3D
		if point == null:
			continue

		if wants_attack and not _is_spawn_position_hidden_from_all_players(point.global_position):
			continue

		result.append(point)

	return result


func _is_spawn_position_hidden_from_all_players(world_position: Vector3) -> bool:
	if not avoid_visible_spawns:
		return true

	if use_real_player_cameras and _is_position_visible_by_any_player_camera(world_position):
		return false

	if use_topdown_visibility_fallback and _is_position_inside_any_player_view_approx(world_position):
		return false

	return true


func _is_position_visible_by_any_player_camera(world_position: Vector3) -> bool:
	var players: Array[Node] = get_tree().get_nodes_in_group(player_group_name)
	var found_camera: bool = false

	for player in players:
		var camera: Camera3D = _get_player_camera(player)
		if camera == null:
			continue

		found_camera = true
		if _is_position_visible_by_camera(camera, world_position, visibility_margin_pixels):
			return true

	if found_camera:
		return false

	var fallback_camera: Camera3D = get_viewport().get_camera_3d()
	if fallback_camera != null:
		return _is_position_visible_by_camera(fallback_camera, world_position, visibility_margin_pixels)

	return false


func _is_position_visible_by_camera(camera: Camera3D, world_position: Vector3, margin_pixels: float) -> bool:
	if camera == null:
		return false

	if camera.is_position_behind(world_position):
		return false

	var screen_position: Vector2 = camera.unproject_position(world_position)
	var viewport_rect: Rect2 = camera.get_viewport().get_visible_rect()
	var safe_rect: Rect2 = viewport_rect.grow(margin_pixels)

	return safe_rect.has_point(screen_position)


func _get_player_camera(player: Node) -> Camera3D:
	if player == null:
		return null

	var camera: Camera3D = player.get_node_or_null(player_camera_node_name) as Camera3D
	if camera != null:
		return camera

	camera = player.find_child(player_camera_node_name, true, false) as Camera3D
	if camera != null:
		return camera

	camera = player.find_child("Camera3D", true, false) as Camera3D
	return camera


func _is_position_inside_any_player_view_approx(world_position: Vector3) -> bool:
	var target_positions: Array[Vector3] = _get_target_positions()
	var half_width: float = topdown_visible_half_width + topdown_visibility_margin
	var half_depth: float = topdown_visible_half_depth + topdown_visibility_margin

	for target_position in target_positions:
		var delta: Vector3 = world_position - target_position
		if absf(delta.x) <= half_width and absf(delta.z) <= half_depth:
			return true

	return false


func _should_start_mega_horde() -> bool:
	if not mega_horde_enabled:
		return false

	if time_since_last_mega_horde < mega_horde_cooldown_seconds:
		return false

	if get_alive_zombie_count() > int(float(max_alive_zombies) * 0.45):
		return false

	if random.randf() > mega_horde_chance:
		return false

	var valid_zones: Array[Node] = _get_valid_zones(true)
	return valid_zones.size() >= mega_horde_min_zones


func _update_cleanup(delta: float) -> void:
	if not cleanup_enabled:
		return

	cleanup_timer -= delta
	if cleanup_timer > 0.0:
		return

	cleanup_timer = cleanup_check_interval
	cleanup_far_or_old_zombies()


func cleanup_far_or_old_zombies() -> void:
	var zombies: Array[Node] = _get_zombie_nodes_for_cleanup()
	var alive_count: int = zombies.size()
	var removed_count: int = 0
	var reasons: Dictionary = {}

	for zombie in zombies:
		if not (zombie is Node3D):
			continue

		var zombie_3d: Node3D = zombie as Node3D
		var despawn_reason: String = _get_despawn_reason(zombie_3d, alive_count)
		if despawn_reason.is_empty():
			continue

		_unregister_spawned_zombie(zombie_3d)
		zombie_3d.queue_free()
		removed_count += 1
		alive_count = max(alive_count - 1, 0)
		reasons[despawn_reason] = int(reasons.get(despawn_reason, 0)) + 1

	if removed_count > 0:
		if debug_print_cleanup_reasons:
			_emit_event("Cleanup : %d zombies despawn. Raisons : %s." % [removed_count, _format_cleanup_reasons(reasons)])
		else:
			_emit_event("Cleanup : %d zombies despawn." % removed_count)


func _get_zombie_nodes_for_cleanup() -> Array[Node]:
	var result: Array[Node] = []

	if despawn_only_director_spawned:
		var enemies_root: Node = _get_enemies_root()
		var candidates: Array[Node] = []
		if enemies_root != null:
			candidates = enemies_root.get_children()
		else:
			candidates = get_tree().get_nodes_in_group("zombies")

		for candidate in candidates:
			if candidate == null or not is_instance_valid(candidate):
				continue
			if spawned_zombie_sections.has(candidate.get_instance_id()):
				result.append(candidate)
		return result

	var enemies_root_all: Node = _get_enemies_root()
	if enemies_root_all != null:
		for child in enemies_root_all.get_children():
			if child != null and is_instance_valid(child):
				if child.is_in_group("zombies") or child.is_in_group("enemies") or child.is_in_group("enemy"):
					result.append(child)
		return result

	for node in get_tree().get_nodes_in_group("zombies"):
		if node != null and is_instance_valid(node):
			result.append(node)

	return result


func _can_despawn_zombie(zombie: Node3D) -> bool:
	return not _get_despawn_reason(zombie, get_alive_zombie_count()).is_empty()


func _get_despawn_reason(zombie: Node3D, current_alive_count: int) -> String:
	if zombie == null or not is_instance_valid(zombie):
		return ""

	if avoid_visible_spawns and not _is_spawn_position_hidden_from_all_players(zombie.global_position):
		return ""

	if zombie.has_method("is_in_combat"):
		if zombie.call("is_in_combat"):
			return ""

	if zombie.has_method("is_recently_damaged"):
		if zombie.call("is_recently_damaged"):
			return ""

	if despawn_old_sections and _is_zombie_behind_progression(zombie):
		return "old_section"

	var is_far_from_players: bool = _get_distance_to_closest_target(zombie.global_position) > despawn_distance
	if not is_far_from_players:
		return ""

	if cleanup_far_zombies_only_when_above_limit and current_alive_count <= max_alive_zombies:
		return ""

	if current_alive_count > max_alive_zombies:
		return "above_limit_far"

	return "far_distance"


func _format_cleanup_reasons(reasons: Dictionary) -> String:
	if reasons.is_empty():
		return "aucune"

	var parts: Array[String] = []
	for key: Variant in reasons.keys():
		parts.append("%s=%d" % [String(key), int(reasons[key])])

	return ", ".join(parts)


func _is_zombie_behind_progression(zombie: Node) -> bool:
	if zombie == null:
		return false

	var instance_id: int = zombie.get_instance_id()
	if not spawned_zombie_sections.has(instance_id):
		return false

	var zombie_section_id: int = int(spawned_zombie_sections[instance_id])
	return zombie_section_id < current_section_id - sections_to_keep_behind


func _unregister_spawned_zombie(zombie: Node) -> void:
	if zombie == null:
		return

	var instance_id: int = zombie.get_instance_id()
	spawned_zombie_sections.erase(instance_id)
	spawned_zombie_last_combat_time.erase(instance_id)


func _get_target_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []

	for node in get_tree().get_nodes_in_group(player_group_name):
		if node is Node3D:
			positions.append((node as Node3D).global_position)

	if not positions.is_empty():
		return positions

	var fallback_target: Node3D = get_node_or_null(fallback_target_path) as Node3D
	if fallback_target != null:
		positions.append(fallback_target.global_position)

	return positions


func _get_targets_center() -> Vector3:
	var positions: Array[Vector3] = _get_target_positions()
	if positions.is_empty():
		return global_position

	var center: Vector3 = Vector3.ZERO
	for position in positions:
		center += position

	return center / float(positions.size())


func _get_best_target_node() -> Node:
	for node in get_tree().get_nodes_in_group(player_group_name):
		if node is Node3D:
			return node

	return get_node_or_null(fallback_target_path)


func _get_distance_to_closest_target(world_position: Vector3) -> float:
	var positions: Array[Vector3] = _get_target_positions()
	if positions.is_empty():
		return 999999.0

	var closest_distance: float = 999999.0
	for target_position in positions:
		var distance: float = world_position.distance_to(target_position)
		if distance < closest_distance:
			closest_distance = distance

	return closest_distance


func _get_navigation_safe_position(position: Vector3) -> Vector3:
	var world: World3D = get_world_3d()
	if world == null:
		return position

	var navigation_map: RID = world.navigation_map
	if not navigation_map.is_valid():
		return position

	var closest_point: Vector3 = NavigationServer3D.map_get_closest_point(navigation_map, position)
	if closest_point == Vector3.ZERO and position.distance_to(Vector3.ZERO) > 20.0:
		return position

	return closest_point


func _get_zone_spawn_count(zone: Node) -> int:
	var min_count: int = 4
	var max_count: int = 8

	var min_value: Variant = zone.get("min_spawn_count")
	var max_value: Variant = zone.get("max_spawn_count")

	if min_value != null:
		min_count = int(min_value)
	if max_value != null:
		max_count = int(max_value)

	if max_count < min_count:
		max_count = min_count

	return random.randi_range(min_count, max_count)


func _get_scene_to_spawn(behaviour: String) -> PackedScene:
	if behaviour == "attack" and state == DirectorState.SUPER_HORDE:
		var hammer_scene: PackedScene = _try_get_super_horde_hammer_scene()
		if hammer_scene != null:
			return hammer_scene

	if behaviour == "idle" and not use_enemy_composition_for_idle_population:
		return _get_default_enemy_scene()

	return _get_weighted_standard_enemy_scene()


func _auto_load_enemy_scenes() -> void:
	if not auto_load_enemy_scenes_from_paths:
		return

	tonfa_enemy_scene = _try_auto_load_enemy_scene(tonfa_enemy_scene, tonfa_enemy_scene_path)
	shield_enemy_scene = _try_auto_load_enemy_scene(shield_enemy_scene, shield_enemy_scene_path)
	rifleman_enemy_scene = _try_auto_load_enemy_scene(rifleman_enemy_scene, rifleman_enemy_scene_path)
	anti_tank_enemy_scene = _try_auto_load_enemy_scene(anti_tank_enemy_scene, anti_tank_enemy_scene_path)
	hammer_enemy_scene = _try_auto_load_enemy_scene(hammer_enemy_scene, hammer_enemy_scene_path)

	if zombie_scene == null and tonfa_enemy_scene != null:
		zombie_scene = tonfa_enemy_scene


func _try_auto_load_enemy_scene(current_scene: PackedScene, scene_path: String) -> PackedScene:
	if current_scene != null:
		return current_scene

	if scene_path.is_empty():
		return null

	if not ResourceLoader.exists(scene_path):
		return null

	return ResourceLoader.load(scene_path) as PackedScene


func _get_default_enemy_scene() -> PackedScene:
	if tonfa_enemy_scene != null:
		return tonfa_enemy_scene
	return zombie_scene


func _get_weighted_standard_enemy_scene() -> PackedScene:
	var entries: Array[Dictionary] = _get_standard_enemy_entries()
	if entries.is_empty():
		return _get_default_enemy_scene()

	var total_weight: int = 0
	for entry in entries:
		total_weight += int(entry.get("weight", 0))

	if total_weight <= 0:
		return _get_default_enemy_scene()

	var roll: int = random.randi_range(1, total_weight)
	var cursor: int = 0

	for entry in entries:
		cursor += int(entry.get("weight", 0))
		if roll <= cursor:
			return entry.get("scene", null) as PackedScene

	return entries.back().get("scene", null) as PackedScene


func _get_standard_enemy_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	_append_enemy_entry(entries, _get_default_enemy_scene(), tonfa_weight)
	_append_enemy_entry(entries, shield_enemy_scene, shield_weight)
	_append_enemy_entry(entries, rifleman_enemy_scene, rifleman_weight)
	_append_enemy_entry(entries, anti_tank_enemy_scene, anti_tank_weight)
	return entries


func _append_enemy_entry(entries: Array[Dictionary], scene: PackedScene, weight: int) -> void:
	if scene == null:
		return

	if weight <= 0:
		return

	entries.append({
		"scene": scene,
		"weight": weight
	})


func _get_super_horde_extra_minion_count() -> int:
	var min_count: int = max(super_horde_extra_minions_min, 0)
	var max_count: int = max(super_horde_extra_minions_max, 0)

	if max_count < min_count:
		max_count = min_count

	return random.randi_range(min_count, max_count)


func _get_super_horde_hammer_count() -> int:
	if not allow_hammers_in_super_hordes:
		return 0

	if hammer_enemy_scene == null:
		return 0

	var min_count: int = max(super_horde_min_hammers, 0)
	var max_count: int = max(super_horde_max_hammers, 0)

	if max_count < min_count:
		max_count = min_count

	return random.randi_range(min_count, max_count)


func _try_get_super_horde_hammer_scene() -> PackedScene:
	if not allow_hammers_in_super_hordes:
		return null

	if hammer_enemy_scene == null:
		return null

	if super_horde_hammer_remaining <= 0:
		return null

	var slots_left: int = horde_remaining
	if slots_left < 1:
		slots_left = 1

	if slots_left <= super_horde_hammer_remaining:
		super_horde_hammer_remaining -= 1
		return hammer_enemy_scene

	var hammer_chance: float = clampf(float(super_horde_hammer_remaining) / float(slots_left), 0.0, 1.0)
	if random.randf() <= hammer_chance:
		super_horde_hammer_remaining -= 1
		return hammer_enemy_scene

	return null


func _get_enemies_root() -> Node:
	if enemies_root_path.is_empty():
		return null
	return get_node_or_null(enemies_root_path)


func _add_basic_groups(zombie: Node) -> void:
	if zombie == null:
		return

	if not zombie.is_in_group("zombies"):
		zombie.add_to_group("zombies")
	if not zombie.is_in_group("enemies"):
		zombie.add_to_group("enemies")


func _get_zone_name(zone: Node) -> String:
	if zone == null or not is_instance_valid(zone):
		return "Aucune"

	var label_value: Variant = zone.get("zone_label")
	if label_value != null:
		return str(label_value)

	return zone.name


func _get_active_zones_text() -> String:
	if active_horde_zones.is_empty():
		return "Aucune"

	var names: Array[String] = []
	for zone in active_horde_zones:
		names.append(_get_zone_name(zone))

	return ", ".join(names)


func _get_next_action_text() -> String:
	if state == DirectorState.REST:
		var mega_cd: float = max(mega_horde_cooldown_seconds - time_since_last_mega_horde, 0.0)
		if mega_horde_enabled and mega_cd > 0.0:
			return "Repos. Méga horde possible dans %.0f s." % mega_cd
		return "Le Director attend avant de préparer une horde."
	if state == DirectorState.BUILD_UP:
		return "Une horde est sélectionnée. Les sons/alertes peuvent être joués maintenant."
	if state == DirectorState.HORDE:
		return "Spawn par petites salves depuis une zone hors caméra."
	if state == DirectorState.SUPER_HORDE:
		if super_horde_hammer_remaining > 0:
			return "Méga horde : spawn depuis plusieurs zones. Hammers restants : %d." % super_horde_hammer_remaining
		return "Méga horde : spawn depuis plusieurs zones hors caméra."
	if state == DirectorState.COOLDOWN:
		return "Le Director laisse les joueurs respirer."
	return ""


func _emit_event(text: String) -> void:
	last_event_text = text
	if debug_print_events:
		print("[HordeDirector] %s" % text)
