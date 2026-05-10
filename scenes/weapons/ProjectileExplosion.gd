extends Area3D
class_name ProjectileExplosion

enum Team {
	NEUTRAL = 0,
	ALLY = 1,
	ENEMY = 2
}

@export_group("Damage")
@export var damage: int = 20
@export var penetration: int = 0
@export var team: int = Team.NEUTRAL
@export var tk: bool = false

@export_group("Area Detection")
## Collision mask used by the Area3D to detect damageable targets.
## Set this to the enemy / hurtbox layers only.
@export_flags_3d_physics var damage_detection_mask: int = 0xFFFFFFFF
@export var damage_once_per_target: bool = true

@export_group("Line Of Sight")
## Collision mask used by the ray that checks if a wall blocks the explosion.
## Ideally set this to world / walls / props only, not enemies.
@export_flags_3d_physics var line_of_sight_blocker_mask: int = 1
@export var line_of_sight_required: bool = true
@export var los_origin_height: float = 0.15
@export var target_los_height: float = 1.0
@export var los_collide_with_bodies: bool = true
@export var los_collide_with_areas: bool = false
@export var debug_line_of_sight: bool = false

@export_group("Lifetime")
@export var lifetime: float = 0.15

var shooter: Node = null
var _active: bool = false
var _damaged_targets: Array[Node] = []

@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	monitoring = false
	monitorable = false
	collision_mask = damage_detection_mask

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	call_deferred("_activate_explosion")


func configure_from_projectile(source_damage: int, source_penetration: int, source_team: int, source_tk: bool, source_shooter: Node) -> void:
	damage = source_damage
	penetration = source_penetration
	team = source_team
	tk = source_tk
	shooter = source_shooter


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _activate_explosion() -> void:
	if collision_shape == null or collision_shape.shape == null:
		queue_free()
		return

	_active = true
	monitoring = true

	# Give the physics engine one tick to register bodies already inside the Area3D.
	await get_tree().physics_frame

	_damage_current_overlaps()


func _on_body_entered(body: Node3D) -> void:
	_try_damage_from_collider(body)


func _on_area_entered(area: Area3D) -> void:
	_try_damage_from_collider(area)


func _damage_current_overlaps() -> void:
	for body in get_overlapping_bodies():
		_try_damage_from_collider(body)

	for area in get_overlapping_areas():
		_try_damage_from_collider(area)


func _try_damage_from_collider(collider: Node) -> void:
	if not _active:
		return

	# In multiplayer, only the server applies health changes.
	# Visual-only explosion instances on clients still exist, but do not deal damage.
	if not multiplayer.is_server():
		return

	var target := _find_damage_target(collider)
	if target == null:
		return

	if damage_once_per_target and _damaged_targets.has(target):
		return

	if not _can_damage_target(target):
		return

	if line_of_sight_required and not _has_line_of_sight_to_target(target):
		return

	_damaged_targets.append(target)

	var safe_shooter: Node = null
	if shooter != null and is_instance_valid(shooter):
		safe_shooter = shooter

	if target.has_method("apply_projectile_damage"):
		target.apply_projectile_damage(damage, penetration, team, tk, safe_shooter)
	elif target.has_method("apply_damage"):
		_call_apply_damage(target, damage, safe_shooter)


func _has_line_of_sight_to_target(target: Node) -> bool:
	if not (target is Node3D):
		return true

	var from := global_position + Vector3.UP * los_origin_height
	var to := _get_target_los_point(target as Node3D)

	if from.distance_squared_to(to) <= 0.0001:
		return true

	var ray := PhysicsRayQueryParameters3D.create(from, to, line_of_sight_blocker_mask)
	ray.collide_with_bodies = los_collide_with_bodies
	ray.collide_with_areas = los_collide_with_areas
	ray.exclude = [get_rid()]

	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return true

	var hit_collider: Node = hit.get("collider", null)
	if hit_collider == null:
		return true

	# If the ray hits the target or one of its children first, the target is visible.
	if hit_collider == target:
		return true

	var hit_target := _find_damage_target(hit_collider)
	if hit_target == target:
		return true

	if debug_line_of_sight:
		print("[ProjectileExplosion] LOS blocked. target=%s blocker=%s" % [target.name, hit_collider.name])

	return false


func _get_target_los_point(target: Node3D) -> Vector3:
	var height := target_los_height
	var custom_aim_height = _safe_get_property(target, "aim_height")
	if custom_aim_height != null:
		height = float(custom_aim_height)

	return target.global_position + Vector3.UP * height


func _can_damage_target(target: Node) -> bool:
	var target_team := _get_node_team(target)

	if target_team == Team.NEUTRAL:
		return target.has_method("apply_projectile_damage") or target.has_method("apply_damage")

	if tk:
		return true

	return target_team != team


func _get_node_team(node: Node) -> int:
	var current: Node = node

	while current != null:
		var projectile_team_value = _safe_get_property(current, "projectile_team")
		if projectile_team_value != null:
			return int(projectile_team_value)

		var enemy_team_value = _safe_get_property(current, "team_id")
		if enemy_team_value != null:
			return int(enemy_team_value)

		if current.is_in_group("enemy") or current.is_in_group("enemies"):
			return Team.ENEMY

		if current.is_in_group("ally") or current.is_in_group("allies"):
			return Team.ALLY

		if current.is_in_group("player") or current.is_in_group("players"):
			return Team.ALLY

		if current.is_in_group("vehicle") or current.is_in_group("vehicles"):
			return Team.ALLY

		if _has_property(current, "shop_money"):
			return Team.ALLY

		current = current.get_parent()

	return Team.NEUTRAL


func _find_damage_target(node: Node) -> Node:
	var current: Node = node

	while current != null:
		if current.has_method("apply_projectile_damage") or current.has_method("apply_damage"):
			return current
		current = current.get_parent()

	return null


func _call_apply_damage(target: Node, amount: int, source: Node = null) -> void:
	if target == null or not is_instance_valid(target):
		return

	if _method_accepts_argument_count(target, "apply_damage", 2):
		target.apply_damage(amount, source)
	else:
		target.apply_damage(amount)


func _method_accepts_argument_count(object: Object, method_name: String, argument_count: int) -> bool:
	if object == null:
		return false

	for method_data in object.get_method_list():
		if String(method_data.name) != method_name:
			continue

		var args: Array = method_data.get("args", [])
		var default_args: Array = method_data.get("default_args", [])
		var min_arg_count: int = maxi(args.size() - default_args.size(), 0)
		var max_arg_count: int = args.size()

		return argument_count >= min_arg_count and argument_count <= max_arg_count

	return false


func _safe_get_property(object: Object, property_name: String) -> Variant:
	if object == null:
		return null

	for property_data in object.get_property_list():
		if String(property_data.name) == property_name:
			return object.get(property_name)

	return null


func _has_property(object: Object, property_name: String) -> bool:
	if object == null:
		return false

	for property_data in object.get_property_list():
		if String(property_data.name) == property_name:
			return true

	return false
