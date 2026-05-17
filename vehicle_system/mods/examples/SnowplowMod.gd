extends VehicleModBase
class_name SnowplowVehicleMod

@export var push_area_path: NodePath = NodePath("PushArea")
@export var push_groups: Array[StringName] = [&"enemy", &"enemies"]
@export var push_velocity: float = 18.0
@export var upward_velocity: float = 1.75
@export var position_nudge: float = 0.18
@export var rigidbody_impulse_multiplier: float = 2.0

# Ancien fallback. Laisse a 0 pour utiliser les degats calcules depuis la vitesse du vehicule.
@export var damage_on_push: int = 0

@export_group("Vehicle Impact")
@export var use_vehicle_impact_settings: bool = true
@export var impact_damage_enabled: bool = true
@export var impact_min_speed: float = 1.0
@export var impact_damage_at_min_speed: int = 5
@export var impact_damage_per_speed: float = 2.0
@export var impact_max_damage: int = 40
@export var impact_damage_cooldown: float = 0.35
@export var impact_damage_debug: bool = false
@export var use_vehicle_velocity_direction: bool = true

var push_area: Area3D = null
var _impact_last_hit_time: Dictionary = {}


func _ready() -> void:
	super._ready()
	push_area = get_node_or_null(push_area_path) as Area3D

	if push_area != null:
		push_area.monitoring = true
		push_area.monitorable = false


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if not multiplayer.is_server():
		return

	if vehicle == null or push_area == null:
		return

	if not _get_impact_damage_enabled():
		return

	var speed: float = _get_vehicle_speed()
	var min_speed: float = _get_impact_min_speed()
	if speed < min_speed:
		return

	for body in push_area.get_overlapping_bodies():
		_try_enemy_soft_impact(body, speed, delta)


func _try_enemy_soft_impact(body: Node, speed: float, delta: float) -> void:
	if body == null or body == self or body == vehicle:
		return

	var target: Node = _get_enemy_soft_impact_target(body)
	if target == null:
		return

	_apply_enemy_soft_push(target, speed, delta)

	if _is_impact_target_on_cooldown(target):
		return

	var damage: int = _get_impact_damage_from_speed(speed)
	if damage <= 0:
		return

	_register_impact_hit(target)
	_apply_impact_damage_to_target(target, damage)

	if _get_impact_damage_debug():
		print("[SNOWPLOW IMPACT] ", name, " hit ", target.name, " | speed=", speed, " | damage=", damage)


func _get_enemy_soft_impact_target(body: Node) -> Node:
	if body == null or body == self or body == vehicle:
		return null

	var current: Node = body

	while current != null:
		if current == self or current == vehicle:
			return null

		if current.is_in_group(&"vehicle") or current.is_in_group(&"vehicles"):
			return null

		for group_name in push_groups:
			if current.is_in_group(group_name):
				return current

		if current.has_method(&"apply_vehicle_push"):
			return current

		current = current.get_parent()

	return null


func _apply_enemy_soft_push(target: Node, speed: float, delta: float) -> void:
	if target == null or not (target is Node3D):
		return

	var direction: Vector3 = _get_push_direction(target)
	if direction.length_squared() < 0.01:
		return

	direction = direction.normalized()

	var min_speed: float = maxf(_get_impact_min_speed(), 0.001)
	var speed_factor: float = maxf(speed / min_speed, 1.0)
	var push_vector: Vector3 = direction * push_velocity * speed_factor
	push_vector.y += upward_velocity

	if target.has_method(&"apply_vehicle_push"):
		target.call(&"apply_vehicle_push", push_vector, _get_damage_source())
		return

	if target.has_method(&"apply_knockback"):
		target.call(&"apply_knockback", direction, push_vector.length(), _get_damage_source())
		return

	if target is RigidBody3D:
		var rigidbody: RigidBody3D = target as RigidBody3D
		rigidbody.apply_central_impulse(push_vector * rigidbody_impulse_multiplier)
		return

	if target is CharacterBody3D:
		var character: CharacterBody3D = target as CharacterBody3D
		character.velocity += push_vector
		if position_nudge > 0.0:
			character.global_position += direction * position_nudge * speed_factor * delta
		return

	if "velocity" in target:
		target.velocity += push_vector
		return

	if position_nudge > 0.0:
		(target as Node3D).global_position += direction * position_nudge * speed_factor * delta


func _get_push_direction(target: Node) -> Vector3:
	if use_vehicle_velocity_direction and vehicle != null:
		var vehicle_velocity: Vector3 = _get_vehicle_linear_velocity()
		vehicle_velocity.y = 0.0
		if vehicle_velocity.length_squared() >= 0.01:
			return vehicle_velocity

	var target_3d: Node3D = target as Node3D
	var origin: Vector3 = global_position
	if vehicle is Node3D:
		origin = (vehicle as Node3D).global_position

	var direction: Vector3 = target_3d.global_position - origin
	direction.y = 0.0

	if direction.length_squared() >= 0.01:
		return direction

	var forward: Vector3 = global_basis * Vector3.MODEL_FRONT
	forward.y = 0.0
	return forward


func _get_vehicle_speed() -> float:
	return _get_vehicle_linear_velocity().length()


func _get_vehicle_linear_velocity() -> Vector3:
	if vehicle == null:
		return Vector3.ZERO

	if vehicle is RigidBody3D:
		return (vehicle as RigidBody3D).linear_velocity

	if _object_has_property(vehicle, &"linear_velocity"):
		var velocity_value: Variant = vehicle.get("linear_velocity")
		if typeof(velocity_value) == TYPE_VECTOR3:
			return velocity_value as Vector3

	return Vector3.ZERO


func _get_impact_damage_enabled() -> bool:
	return _get_vehicle_bool_property(&"impact_damage_enabled", impact_damage_enabled)


func _get_impact_min_speed() -> float:
	return _get_vehicle_float_property(&"impact_min_speed", impact_min_speed)


func _get_impact_damage_at_min_speed() -> int:
	return _get_vehicle_int_property(&"impact_damage_at_min_speed", impact_damage_at_min_speed)


func _get_impact_damage_per_speed() -> float:
	return _get_vehicle_float_property(&"impact_damage_per_speed", impact_damage_per_speed)


func _get_impact_max_damage() -> int:
	return _get_vehicle_int_property(&"impact_max_damage", impact_max_damage)


func _get_impact_damage_cooldown() -> float:
	return _get_vehicle_float_property(&"impact_damage_cooldown", impact_damage_cooldown)


func _get_impact_damage_debug() -> bool:
	return _get_vehicle_bool_property(&"impact_damage_debug", impact_damage_debug)


func _is_impact_target_on_cooldown(target: Node) -> bool:
	if target == null:
		return true

	var id: int = target.get_instance_id()
	var now: float = Time.get_ticks_msec() * 0.001
	var last_time: float = float(_impact_last_hit_time.get(id, -9999.0))
	return now - last_time < _get_impact_damage_cooldown()


func _register_impact_hit(target: Node) -> void:
	if target == null:
		return

	_impact_last_hit_time[target.get_instance_id()] = Time.get_ticks_msec() * 0.001


func _get_impact_damage_from_speed(speed: float) -> int:
	if damage_on_push > 0 and not use_vehicle_impact_settings:
		return damage_on_push

	var raw_damage: float = float(_get_impact_damage_at_min_speed()) + ((speed - _get_impact_min_speed()) * _get_impact_damage_per_speed())
	var damage: int = int(round(raw_damage))
	return min(max(damage, 0), _get_impact_max_damage())


func _apply_impact_damage_to_target(target: Node, amount: int) -> void:
	if target == null:
		return

	var hit_position: Vector3 = global_position
	if target is Node3D:
		hit_position = (target as Node3D).global_position

	var impulse: Vector3 = Vector3.ZERO
	var vehicle_velocity: Vector3 = _get_vehicle_linear_velocity()
	if vehicle_velocity.length_squared() > 0.0:
		impulse = vehicle_velocity.normalized() * float(amount)

	var source: Node = _get_damage_source()

	if _try_call_damage_method(target, &"apply_vehicle_impact_damage", [amount, source]):
		return

	if _try_call_damage_method(target, &"apply_damage", [amount, hit_position, impulse]):
		return

	if _try_call_damage_method(target, &"take_damage", [amount, hit_position, impulse]):
		return

	if _try_call_damage_method(target, &"apply_projectile_damage", [amount, 0, 0, false, source]):
		return

	if _get_impact_damage_debug():
		print("[SNOWPLOW IMPACT] can't hit target: ", target, " | class=", target.get_class())


func _try_call_damage_method(target: Node, method_name: StringName, candidate_args: Array) -> bool:
	if target == null or not target.has_method(method_name):
		return false

	for method_info in target.get_method_list():
		if StringName(method_info.get("name", "")) != method_name:
			continue

		var method_args: Array = method_info.get("args", [])
		var default_args: Array = method_info.get("default_args", [])
		var min_arg_count: int = max(method_args.size() - default_args.size(), 0)
		var max_arg_count: int = method_args.size()

		if candidate_args.size() < min_arg_count:
			return false

		var call_args: Array = candidate_args.slice(0, min(candidate_args.size(), max_arg_count))
		if call_args.size() < min_arg_count:
			return false

		target.callv(method_name, call_args)
		return true

	return false


func _get_damage_source() -> Node:
	if vehicle != null:
		return vehicle
	return self


func _get_vehicle_bool_property(property_name: StringName, fallback: bool) -> bool:
	if not use_vehicle_impact_settings or vehicle == null:
		return fallback

	if not _object_has_property(vehicle, property_name):
		return fallback

	return bool(vehicle.get(String(property_name)))


func _get_vehicle_float_property(property_name: StringName, fallback: float) -> float:
	if not use_vehicle_impact_settings or vehicle == null:
		return fallback

	if not _object_has_property(vehicle, property_name):
		return fallback

	return float(vehicle.get(String(property_name)))


func _get_vehicle_int_property(property_name: StringName, fallback: int) -> int:
	if not use_vehicle_impact_settings or vehicle == null:
		return fallback

	if not _object_has_property(vehicle, property_name):
		return fallback

	return int(vehicle.get(String(property_name)))


func _object_has_property(object: Object, property_name: StringName) -> bool:
	if object == null:
		return false

	for property_info in object.get_property_list():
		if StringName(property_info.get("name", "")) == property_name:
			return true

	return false
