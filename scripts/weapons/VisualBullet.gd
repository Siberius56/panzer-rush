extends Node3D
class_name VisualBullet

enum Team {
	NEUTRAL,
	ALLY,
	ENEMY,
}

@export var speed: float = 30.0
@export var lifetime: float = 0.7
@export var hit_effect_scene: PackedScene
@export_flags_3d_physics var collision_mask: int = 0xFFFFFFFF
@export var debug_logs: bool = true

var direction: Vector3 = Vector3.FORWARD
var team: int = Team.NEUTRAL
var tk: bool = false
var damage: int = 1
var penetration: int = 0
var shooter: Node = null


func fire(
	start_pos: Vector3,
	dir: Vector3,
	source_team: int,
	source_damage: int,
	source_penetration: int = 0,
	allow_tk: bool = false,
	source_node: Node = null,
	impact_scene_override: PackedScene = null
) -> void:
	global_position = start_pos
	direction = dir.normalized()
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	look_at(global_position + direction, Vector3.UP)
	team = source_team
	damage = source_damage
	penetration = source_penetration
	tk = allow_tk
	shooter = source_node
	
	if impact_scene_override != null:
		hit_effect_scene = impact_scene_override
	
	#_debug("fire pos=%s dir=%s speed=%.2f team=%d damage=%d shooter=%s" % [str(global_position), str(direction), speed, team, damage, shooter.name if shooter != null else "null"])


func setup(start_pos: Vector3, dir: Vector3) -> void:
	fire(start_pos, dir, Team.NEUTRAL, damage, penetration, tk, shooter, hit_effect_scene)


func set_direction(dir: Vector3) -> void:
	direction = dir.normalized()
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	
	#global_position += direction * 0.35


func _physics_process(delta: float) -> void:
	var from: Vector3 = global_position
	var to: Vector3 = from + direction * speed * delta

	if from.is_equal_approx(to):
		queue_free()
		return

	var exclude := _build_exclude_rids()
	var hit := _intersect_bullet_ray(from, to, exclude)

	# Si le projectile touche un collider appartenant au tireur, on l'ignore vraiment.
	# Avant, _on_hit() retournait sans avancer le projectile, ce qui pouvait le bloquer au muzzle.
	var ignored_count := 0
	while not hit.is_empty() and _should_ignore_collider(hit.get("collider", null)) and ignored_count < 8:
		var ignored_collider = hit.get("collider", null)
		if ignored_collider is CollisionObject3D:
			var ignored_rid := (ignored_collider as CollisionObject3D).get_rid()
			if not exclude.has(ignored_rid):
				exclude.append(ignored_rid)
		else:
			break
		hit = _intersect_bullet_ray(from, to, exclude)
		ignored_count += 1

	if hit.is_empty():
		global_position = to
	else:
		_debug("hit collider=%s pos=%s" % [hit.get("collider"), str(hit.get("position", global_position))])
		_on_hit(hit)
		return

	lifetime -= delta
	if lifetime <= 0.0:
		_debug("lifetime ended")
		queue_free()


func _intersect_bullet_ray(from: Vector3, to: Vector3, exclude: Array) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = collision_mask
	query.hit_from_inside = true
	query.exclude = exclude
	return get_world_3d().direct_space_state.intersect_ray(query)


func _build_exclude_rids() -> Array:
	var exclude: Array = []
	if is_instance_valid(shooter):
		_collect_collision_rids(shooter, exclude)
	return exclude


func _collect_collision_rids(node: Node, output: Array) -> void:
	if node == null or not is_instance_valid(node):
		return

	if node is CollisionObject3D:
		var rid := (node as CollisionObject3D).get_rid()
		if not output.has(rid):
			output.append(rid)

	for child in node.get_children():
		_collect_collision_rids(child, output)


func _on_hit(hit: Dictionary) -> void:
	#print("")
	#print("HIT")
	
	var collider: Node = hit.get("collider", null)
	var hit_position: Vector3 = hit.get("position", global_position)
	var hit_normal: Vector3 = hit.get("normal", Vector3.UP)
	
	
	if _should_ignore_collider(collider):
		_debug("ignored collider=%s" % str(collider))
		return

	var target := _find_damage_target(collider)
	
	if target:
		print("collide with : ", target, " groups: ", target.get_groups())
		print("_can_damage_target : ", _can_damage_target(target))
	
	if target == null:
		_debug("hit decor or unknown collider, free")
		_spawn_hit_effect(hit_position, hit_normal)
		queue_free()
		return
	
	if not _can_damage_target(target):
		# Même si la cible est alliée ou neutre, la balle doit mourir au contact.
		# Elle ne transmet simplement pas de dégâts.
		
		_debug("target hit but no damage by team filter: %s" % target.name)
		_spawn_hit_effect(hit_position, hit_normal)
		queue_free()
		return
	
	_debug("apply damage to=%s damage=%d" % [target.name, damage])
	_spawn_hit_effect(hit_position, hit_normal)
	
	var safe_shooter: Node = null
	
	if shooter != null and is_instance_valid(shooter):
		safe_shooter = shooter
	
	if target.has_method("apply_projectile_damage"):
		print("apply damage on bullet 1")
		target.apply_projectile_damage(damage, penetration, team, tk, safe_shooter)
	elif target.has_method("apply_damage"):
		print("apply damage on bullet 2")
		target.apply_damage(damage)

	queue_free()


func _should_ignore_collider(collider: Node) -> bool:
	if collider == null:
		return true

	if collider == shooter:
		return true

	if collider is Area3D:
		if collider.name == "DetectionArea3D":
			return true

	var current: Node = collider
	while current != null:
		if current == shooter:
			return true
		current = current.get_parent()

	return false


func _can_damage_target(target: Node) -> bool:
	var target_team := _get_node_team(target)
	
	#print("team: ", team,  " target_team: ", target_team)
	#print("target_team != team : ", target_team != team)
	
	if target_team == Team.NEUTRAL:
		return false
	if tk:
		return true
	
	return target_team != team


func _get_node_team(node: Node) -> int:
	var current: Node = node
	while current != null:
		if current.is_in_group("ally") or current.is_in_group("player") or current.is_in_group("players"):
			return Team.ALLY
		if current.is_in_group("enemy") or current.is_in_group("enemies"):
			return Team.ENEMY
		current = current.get_parent()
	return Team.NEUTRAL


func _find_damage_target(node: Node) -> Node:
	var current: Node = node
	while current != null:
		if current.is_in_group("ally") or current.is_in_group("enemy") or current.is_in_group("player") or current.is_in_group("players"):
			return current
		if current.has_method("apply_projectile_damage") or current.has_method("apply_damage"):
			return current
		current = current.get_parent()
	return null


func _spawn_hit_effect(hit_position: Vector3, hit_normal: Vector3) -> void:
	if hit_effect_scene == null:
		return

	var fx = hit_effect_scene.instantiate()
	if fx == null:
		return

	var safe_shooter: Node = null
	if shooter != null and is_instance_valid(shooter):
		safe_shooter = shooter

	# Important si le hit effect est une explosion qui applique aussi des dégâts.
	# Sans cela, ProjectileExplosion.shooter reste null et les ennemis ne savent pas qui les a touchés.
	if fx.has_method("configure_from_projectile"):
		fx.configure_from_projectile(damage, penetration, team, tk, safe_shooter)

	get_tree().current_scene.add_child(fx)

	if fx is Node3D:
		(fx as Node3D).global_position = hit_position
		var normal: Vector3 = hit_normal.normalized()
		if normal.length_squared() > 0.0001:
			(fx as Node3D).look_at(hit_position + normal, Vector3.UP)


func _debug(message: String) -> void:
	if not debug_logs:
		return
	print("[VisualBullet:%s] %s" % [name, message])
