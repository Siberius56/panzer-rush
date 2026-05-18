extends Area3D
class_name GravityGunBlast

# Cette scène est utilisée comme un projectile classique.
# Elle expose donc la même méthode fire() que VisualBullet.gd.

enum TargetKind {
	PROP,
	VEHICLE,
	CHARACTER,
}

@export_group("Target Groups")
@export var prop_groups: Array[StringName] = [&"prop", &"props"]
@export var vehicle_groups: Array[StringName] = [&"vehicle", &"vehicles"]
@export var character_groups: Array[StringName] = [&"player", &"players"]
@export var deny_group: StringName = &"gravitygun_deny"

@export_group("Push Values")
# Gardé volontairement pour compatibilité avec ta scène actuelle.
# Utilisé comme force des props.
@export var push_impulse: float = 300.0
@export var vehicle_push_impulse: float = 2000.0
@export var character_push_velocity: float = 16.0
@export_range(0.0, 1.0, 0.01) var vertical_lift: float = 0.08
@export var max_target_speed_after_push: float = 24.0
@export var max_character_speed_after_push: float = 22.0

@export_group("Blast")
@export var max_targets: int = 16
@export var blast_lifetime: float = 0.12
@export var physics_frames_before_blast: int = 1
@export var debug_logs: bool = false

@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var direction: Vector3 = Vector3.FORWARD
var team: int = 0
var tk: bool = false
var damage: int = 0
var penetration: int = 0
var shooter: Node = null
var hit_effect_scene: PackedScene = null

var has_blasted: bool = false
var has_fire_data: bool = false


# Même signature que VisualBullet.gd.
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

	_face_direction(direction)

	team = source_team
	damage = source_damage
	penetration = source_penetration
	tk = allow_tk
	shooter = source_node

	if impact_scene_override != null:
		hit_effect_scene = impact_scene_override

	has_fire_data = true
	_debug("fire pos=%s dir=%s shooter=%s" % [str(global_position), str(direction), shooter.name if shooter != null else "null"])


# Compatibilité si un autre code appelle seulement setup(start_pos, dir).
func setup(start_pos: Vector3, dir: Vector3) -> void:
	fire(start_pos, dir, team, damage, penetration, tk, shooter, hit_effect_scene)


func initialize(start_pos: Vector3, dir: Vector3) -> void:
	setup(start_pos, dir)


func set_direction(new_direction: Vector3) -> void:
	direction = new_direction.normalized()
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	_face_direction(direction)


func set_forward_direction(new_direction: Vector3) -> void:
	set_direction(new_direction)


func _ready() -> void:
	monitoring = true
	monitorable = false
	call_deferred("_run_blast")


func _face_direction(new_direction: Vector3) -> void:
	if new_direction.length_squared() <= 0.0001:
		return
	look_at(global_position + new_direction.normalized(), Vector3.UP)


func _run_blast() -> void:
	for i in range(maxi(physics_frames_before_blast, 0)):
		await get_tree().physics_frame

	if not has_fire_data:
		_debug("warning: blast used without fire data. Current pos=%s" % str(global_position))

	_debug("run blast pos=%s dir=%s" % [str(global_position), str(direction)])

	if _should_apply_physics():
		_apply_blast()

	if blast_lifetime > 0.0:
		await get_tree().create_timer(blast_lifetime).timeout

	queue_free()


func _should_apply_physics() -> bool:
	if multiplayer == null:
		return true

	if multiplayer.has_multiplayer_peer():
		return multiplayer.is_server()

	return true


func _apply_blast() -> void:
	if has_blasted:
		return

	has_blasted = true

	var pushed_targets: Dictionary = {}
	_push_overlapping_bodies(pushed_targets)
	_push_intersecting_bodies(pushed_targets)


func _push_overlapping_bodies(pushed_targets: Dictionary) -> void:
	var bodies: Array[Node3D] = get_overlapping_bodies()
	for body in bodies:
		_push_if_valid(body, pushed_targets)


func _push_intersecting_bodies(pushed_targets: Dictionary) -> void:
	if collision_shape == null or collision_shape.shape == null:
		return

	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = collision_shape.shape
	query.transform = global_transform * collision_shape.transform
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var results: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(query, max_targets)
	for result in results:
		var collider: Object = result.get("collider")
		if collider is Node3D:
			_push_if_valid(collider as Node3D, pushed_targets)


func _push_if_valid(start_node: Node3D, pushed_targets: Dictionary) -> void:
	if pushed_targets.size() >= max_targets:
		return

	var target_info: Dictionary = _find_valid_target_info(start_node)
	if target_info.is_empty():
		return

	var target: Node3D = target_info["node"] as Node3D
	var target_kind: int = int(target_info["target_kind"])
	if target == null:
		return

	var target_id: int = target.get_instance_id()
	if pushed_targets.has(target_id):
		return

	pushed_targets[target_id] = true
	_push_target(target, start_node, target_kind)


func _find_valid_target_info(start_node: Node) -> Dictionary:
	var current: Node = start_node
	var steps: int = 0

	while current != null and steps < 10:
		if current.is_in_group(deny_group):
			return {}

		if current is Node3D:
			var current_node_3d: Node3D = current as Node3D

			# Priorité volontaire : véhicule > personnage > prop.
			# Comme ça, un véhicule qui aurait aussi le groupe "prop" garde sa force véhicule.
			if _node_is_in_any_group(current, vehicle_groups):
				return {"node": current_node_3d, "target_kind": TargetKind.VEHICLE}

			if _node_is_in_any_group(current, character_groups):
				return {"node": current_node_3d, "target_kind": TargetKind.CHARACTER}

			if _node_is_in_any_group(current, prop_groups):
				return {"node": current_node_3d, "target_kind": TargetKind.PROP}

		current = current.get_parent()
		steps += 1

	return {}


func _node_is_in_any_group(node: Node, groups: Array[StringName]) -> bool:
	for group_name in groups:
		if node.is_in_group(group_name):
			return true
	return false


func _push_target(target: Node3D, source_node: Node3D, target_kind: int) -> void:
	var push_direction: Vector3 = _get_push_direction()

	match target_kind:
		TargetKind.VEHICLE:
			_push_rigid_target(target, source_node, push_direction, vehicle_push_impulse)
		TargetKind.CHARACTER:
			_push_character_target(target, source_node, push_direction)
		_:
			_push_rigid_target(target, source_node, push_direction, push_impulse)


func _push_rigid_target(target: Node3D, source_node: Node3D, push_direction: Vector3, impulse_strength: float) -> void:
	var impulse: Vector3 = push_direction * impulse_strength

	if target.has_method("apply_gravity_gun_impulse"):
		target.call("apply_gravity_gun_impulse", impulse, global_position)
		return

	var rigid_body: RigidBody3D = _find_rigid_body(target)
	if rigid_body == null:
		rigid_body = _find_rigid_body(source_node)

	if rigid_body == null:
		return

	if rigid_body.has_method("apply_gravity_gun_impulse"):
		rigid_body.call("apply_gravity_gun_impulse", impulse, global_position)
		return

	rigid_body.sleeping = false
	rigid_body.apply_impulse(impulse, global_position - rigid_body.global_position)
	_clamp_rigid_body_speed(rigid_body)


func _push_character_target(target: Node3D, source_node: Node3D, push_direction: Vector3) -> void:
	var push_velocity: Vector3 = push_direction * character_push_velocity

	if target.has_method("apply_gravity_gun_push"):
		target.call("apply_gravity_gun_push", push_velocity, global_position, shooter)
		return

	var character: CharacterBody3D = _find_character_body(target)
	if character == null:
		character = _find_character_body(source_node)

	if character == null:
		# Sécurité : si un personnage est en réalité un RigidBody3D custom, on tente quand même une impulsion physique.
		_push_rigid_target(target, source_node, push_direction, push_impulse)
		return

	if character.has_method("apply_gravity_gun_push"):
		character.call("apply_gravity_gun_push", push_velocity, global_position, shooter)
		return

	if character.has_method("apply_gravity_gun_impulse"):
		character.call("apply_gravity_gun_impulse", push_velocity, global_position)
		return

	# Fallback générique.
	# Fonctionne seulement si le script du personnage ne réécrit pas entièrement velocity juste après.
	character.velocity += push_velocity
	_clamp_character_speed(character)


func _find_rigid_body(start_node: Node) -> RigidBody3D:
	var current: Node = start_node
	var steps: int = 0

	while current != null and steps < 10:
		if current is RigidBody3D:
			return current as RigidBody3D
		current = current.get_parent()
		steps += 1

	return null


func _find_character_body(start_node: Node) -> CharacterBody3D:
	var current: Node = start_node
	var steps: int = 0

	while current != null and steps < 10:
		if current is CharacterBody3D:
			return current as CharacterBody3D
		current = current.get_parent()
		steps += 1

	return null


func _get_push_direction() -> Vector3:
	var forward: Vector3 = direction.normalized()
	if forward.length_squared() <= 0.0001:
		forward = -global_transform.basis.z.normalized()
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD

	var final_direction: Vector3 = (forward + Vector3.UP * vertical_lift).normalized()
	if final_direction.length_squared() <= 0.0001:
		return forward

	return final_direction


func _clamp_rigid_body_speed(rigid_body: RigidBody3D) -> void:
	if max_target_speed_after_push <= 0.0:
		return

	var current_speed: float = rigid_body.linear_velocity.length()
	if current_speed <= max_target_speed_after_push:
		return

	rigid_body.linear_velocity = rigid_body.linear_velocity.normalized() * max_target_speed_after_push


func _clamp_character_speed(character: CharacterBody3D) -> void:
	if max_character_speed_after_push <= 0.0:
		return

	var current_speed: float = character.velocity.length()
	if current_speed <= max_character_speed_after_push:
		return

	character.velocity = character.velocity.normalized() * max_character_speed_after_push


func _debug(message: String) -> void:
	if not debug_logs:
		return
	print("[GravityGunBlast:%s] %s" % [name, message])
