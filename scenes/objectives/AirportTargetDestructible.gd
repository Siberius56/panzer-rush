extends StaticBody3D

# AirportTargetDestructible.gd
# Godot 4.x
#
# Rôle :
# - Objet destructible utilisé comme sous-objectif d'aéroport.
# - Compatible avec VisualBullet.gd et ProjectileExplosion.gd.
# - Passe visuellement de IntactRoot à DestroyedRoot.
# - Émet un signal quand il est détruit.

signal damaged(target_id: String, current_health: float, max_health: float)
signal destroyed(target_id: String)
signal objective_completed(target_id: String)

@export_group("Target")
@export var target_id: String = ""
@export var max_health: float = 70.0
@export var start_destroyed: bool = false
@export var remove_enemy_group_when_destroyed: bool = true
@export var disable_collision_when_destroyed: bool = true

@export_group("Projectile Team")
# 0 = neutral, 1 = ally, 2 = enemy.
# Important : VisualBullet.gd refuse les dégâts sur les cibles neutres.
@export var projectile_team: int = 2
@export var team_id: int = 2
@export var aim_height: float = 1.0

@export_group("Visuals")
@export var intact_root_path: NodePath = ^"VisualRoot/IntactRoot"
@export var destroyed_root_path: NodePath = ^"VisualRoot/DestroyedRoot"
@export var animation_player_path: NodePath = ^"AnimationPlayer"
@export var destroyed_animation_name: StringName = &"destroyed"

@export_group("Debug")
@export var debug_logs: bool = false

var current_health: float = 0.0
var is_destroyed: bool = false

@onready var intact_root: Node3D = get_node_or_null(intact_root_path) as Node3D
@onready var destroyed_root: Node3D = get_node_or_null(destroyed_root_path) as Node3D
@onready var animation_player: AnimationPlayer = get_node_or_null(animation_player_path) as AnimationPlayer


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("enemies")
	add_to_group("airport_objective_targets")

	current_health = max_health

	if start_destroyed:
		current_health = 0.0
		_set_destroyed_state(false)
	else:
		_set_visual_state(false)


func get_target_id() -> String:
	if not target_id.strip_edges().is_empty():
		return target_id.strip_edges()
	return name


func is_target_destroyed() -> bool:
	return is_destroyed


func is_objective_completed() -> bool:
	return is_destroyed


func apply_projectile_damage(
	amount: int,
	_penetration: int = 0,
	_source_team: int = 0,
	_allow_tk: bool = false,
	_source: Node = null
) -> void:
	apply_damage(float(amount))


func apply_damage(amount: float, _hit_position: Vector3 = Vector3.ZERO, _impulse: Vector3 = Vector3.ZERO) -> void:
	if is_destroyed:
		return

	# En multi, seul le serveur modifie l'état réel.
	# Les clients recevront l'état détruit via RPC.
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	var safe_amount: float = maxf(amount, 0.0)
	if safe_amount <= 0.0:
		return

	current_health = maxf(current_health - safe_amount, 0.0)
	damaged.emit(get_target_id(), current_health, max_health)

	if debug_logs:
		print("[AirportTarget:%s] damage=%.1f hp=%.1f/%.1f" % [name, safe_amount, current_health, max_health])

	if current_health <= 0.0:
		_destroy()


func force_destroy() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	_destroy()


func reset_target() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	current_health = max_health
	is_destroyed = false
	_set_visual_state(false)
	_set_collision_enabled(true)
	add_to_group("enemy")
	add_to_group("enemies")


func _destroy() -> void:
	if is_destroyed:
		return

	if multiplayer.has_multiplayer_peer():
		_rpc_set_destroyed.rpc()
	else:
		_rpc_set_destroyed()


@rpc("authority", "call_local", "reliable")
func _rpc_set_destroyed() -> void:
	_set_destroyed_state(true)


func _set_destroyed_state(emit_signals: bool = true) -> void:
	if is_destroyed:
		return

	is_destroyed = true
	current_health = 0.0

	_set_visual_state(true)

	if disable_collision_when_destroyed:
		_set_collision_enabled(false)

	if remove_enemy_group_when_destroyed:
		remove_from_group("enemy")
		remove_from_group("enemies")

	if animation_player != null and animation_player.has_animation(destroyed_animation_name):
		animation_player.play(destroyed_animation_name)

	if debug_logs:
		print("[AirportTarget:%s] destroyed" % name)

	if emit_signals:
		destroyed.emit(get_target_id())
		objective_completed.emit(get_target_id())


func _set_visual_state(destroyed_state: bool) -> void:
	if intact_root != null:
		intact_root.visible = not destroyed_state
	if destroyed_root != null:
		destroyed_root.visible = destroyed_state


func _set_collision_enabled(enabled: bool) -> void:
	for child: Node in get_children():
		_set_collision_enabled_recursive(child, enabled)


func _set_collision_enabled_recursive(node: Node, enabled: bool) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = not enabled

	for child: Node in node.get_children():
		_set_collision_enabled_recursive(child, enabled)
