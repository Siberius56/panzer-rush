extends NetworkEnemyBase

class_name NetworkRiflemanEnemy


func _perform_attack(combat_target: Node3D, target_point: Vector3) -> bool:
	if projectile_scene == null:
		_attack_debug("attack blocked: projectile_scene is null. Check NetworkRiflemanEnemy.tscn > projectile_scene")
		return false

	var spawn_position: Vector3 = muzzle.global_position if muzzle != null else global_position + Vector3.UP * aim_height
	var direction: Vector3 = target_point - spawn_position

	if is_melee_attack:
		spawn_position = target_point
		direction = target_point - global_position
	else:
		var forward: Vector3 = target_point - spawn_position
		if forward.length_squared() > 0.0001:
			forward = forward.normalized()
			spawn_position += forward * bullet_spawn_forward_offset
			direction = forward
		direction = _apply_aim_dispersion(direction)

	if direction.length_squared() <= 0.0001:
		direction = combat_target.global_position - global_position
	if direction.length_squared() <= 0.0001:
		direction = -global_basis.z
	direction = direction.normalized()

	_attack_debug("rifle attack, spawn=%s, dir=%s, target=%s" % [str(spawn_position), str(direction), combat_target.name])
	_spawn_attack_projectile_local(spawn_position, direction)
	_spawn_attack_projectile_remote.rpc(spawn_position, direction)
	return true
