extends StaticBody3D
class_name BombRadarObjective

signal armed_state_changed(is_armed: bool, remaining_seconds: float)
signal destroyed_state_changed(is_destroyed: bool)

const DEFAULT_EXPLOSION_SCENE := preload("res://scenes/weapons/ProjectileExplosion.tscn")

@export_group("Objective")
@export var activation_duration: float = 5.0
@export var consume_bomb_on_success: bool = true

@export_group("Explosion")
@export var explosion_scene: PackedScene = DEFAULT_EXPLOSION_SCENE
@export var bomb_explosion_damage: int = 120
@export var radar_explosion_damage: int = 80
@export var explosion_penetration: int = 0
@export var explosion_team: int = 0
@export var explosion_tk: bool = true
@export var radar_explosion_offset: Vector3 = Vector3(0.0, 1.1, 0.0)

@onready var activation_area: Area3D = %ActivationArea
@onready var countdown_label: Label3D = %CountdownLabel
@onready var animation_player: AnimationPlayer = %AnimationPlayer

var is_destroyed: bool = false
var _is_armed: bool = false
var _remaining_seconds: float = 0.0
var _tracked_bomb: WorldWeapon3D = null


func _ready() -> void:
	add_to_group("objective_radar")
	_remaining_seconds = activation_duration

	if activation_area != null:
		activation_area.body_entered.connect(_on_activation_body_entered)
		activation_area.body_exited.connect(_on_activation_body_exited)
		call_deferred("_scan_initial_overlaps")

	_update_countdown_label()


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return

	if is_destroyed:
		return

	if not _is_armed:
		return

	if not _is_valid_tracked_bomb_inside():
		_cancel_arming()
		return

	_remaining_seconds = maxf(_remaining_seconds - delta, 0.0)
	_update_countdown_label()
	_receive_armed_state.rpc(true, _remaining_seconds)

	if _remaining_seconds <= 0.0:
		_complete_objective()


func _scan_initial_overlaps() -> void:
	if activation_area == null:
		return

	for body in activation_area.get_overlapping_bodies():
		_try_track_bomb(body)
		if _tracked_bomb != null:
			return


func _on_activation_body_entered(body: Node3D) -> void:
	_try_track_bomb(body)


func _on_activation_body_exited(body: Node3D) -> void:
	if _tracked_bomb == null:
		return

	if body == _tracked_bomb:
		_cancel_arming()


func _try_track_bomb(body: Node) -> void:
	if is_destroyed:
		return

	if not multiplayer.is_server():
		return

	var bomb: WorldWeapon3D = _find_bomb_from_node(body)
	if bomb == null:
		return

	_tracked_bomb = bomb
	_start_arming()


func _find_bomb_from_node(node: Node) -> WorldWeapon3D:
	var current: Node = node
	while current != null:
		if current is WorldWeapon3D:
			var world_weapon: WorldWeapon3D = current as WorldWeapon3D
			if world_weapon.has_method("is_objective_bomb") and world_weapon.call("is_objective_bomb") == true:
				return world_weapon
		current = current.get_parent()

	return null


func _start_arming() -> void:
	if _is_armed:
		return

	_is_armed = true
	_remaining_seconds = activation_duration
	_update_countdown_label()
	_receive_armed_state.rpc(true, _remaining_seconds)


func _cancel_arming() -> void:
	if not _is_armed:
		return

	_is_armed = false
	_remaining_seconds = activation_duration
	_tracked_bomb = null
	_update_countdown_label()
	_receive_armed_state.rpc(false, _remaining_seconds)


func _is_valid_tracked_bomb_inside() -> bool:
	if _tracked_bomb == null or not is_instance_valid(_tracked_bomb):
		return false

	if activation_area == null:
		return false

	return activation_area.get_overlapping_bodies().has(_tracked_bomb)


func _complete_objective() -> void:
	if is_destroyed:
		return

	var bomb_position: Vector3 = global_position
	if _tracked_bomb != null and is_instance_valid(_tracked_bomb):
		bomb_position = _tracked_bomb.global_position

	_spawn_objective_explosion.rpc(bomb_position, bomb_explosion_damage)

	if consume_bomb_on_success and _tracked_bomb != null and is_instance_valid(_tracked_bomb):
		_tracked_bomb.despawn()

	_set_destroyed(true)
	_spawn_objective_explosion.rpc(global_position + radar_explosion_offset, radar_explosion_damage)


func _set_destroyed(value: bool) -> void:
	if is_destroyed == value:
		return

	is_destroyed = value
	_is_armed = false
	_remaining_seconds = 0.0
	_tracked_bomb = null
	_update_countdown_label()
	_receive_destroyed_state.rpc(is_destroyed)


func _play_dead_animation() -> void:
	if animation_player == null:
		return

	if animation_player.has_animation("dead"):
		animation_player.play("dead")


func _update_countdown_label() -> void:
	if countdown_label == null:
		return

	if is_destroyed:
		countdown_label.visible = false
		return

	countdown_label.visible = _is_armed
	if _is_armed:
		countdown_label.text = "%.1f" % _remaining_seconds


func _spawn_explosion_local(position: Vector3, damage_amount: int) -> void:
	if explosion_scene == null:
		return

	var explosion: Node = explosion_scene.instantiate()
	if explosion == null:
		return

	get_tree().current_scene.add_child(explosion)
	if explosion is Node3D:
		(explosion as Node3D).global_position = position

	if explosion.has_method("configure_from_projectile"):
		explosion.call("configure_from_projectile", damage_amount, explosion_penetration, explosion_team, explosion_tk, self)
	elif "damage" in explosion:
		explosion.set("damage", damage_amount)


@rpc("authority", "call_local", "reliable")
func _spawn_objective_explosion(position: Vector3, damage_amount: int) -> void:
	_spawn_explosion_local(position, damage_amount)


@rpc("authority", "call_local", "reliable")
func _receive_destroyed_state(value: bool) -> void:
	is_destroyed = value
	_is_armed = false
	_remaining_seconds = 0.0
	_tracked_bomb = null
	if is_destroyed:
		_play_dead_animation()

	_update_countdown_label()
	destroyed_state_changed.emit(is_destroyed)


@rpc("authority", "call_local", "unreliable_ordered")
func _receive_armed_state(value: bool, remaining: float) -> void:
	_is_armed = value
	_remaining_seconds = remaining
	_update_countdown_label()
	armed_state_changed.emit(_is_armed, _remaining_seconds)
