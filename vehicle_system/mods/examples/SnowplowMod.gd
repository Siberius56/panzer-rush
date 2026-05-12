extends VehicleModBase
class_name SnowplowVehicleMod

@export var push_area_path: NodePath = NodePath("PushArea")
@export var push_groups: Array[StringName] = [&"enemy", &"enemies"]
@export var push_velocity: float = 16.0
@export var upward_velocity: float = 1.0
@export var rigidbody_impulse_multiplier: float = 2.0
@export var damage_on_push: int = 0

var push_area: Area3D = null


func _ready() -> void:
	super._ready()
	push_area = get_node_or_null(push_area_path) as Area3D


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if not multiplayer.is_server():
		return

	if vehicle == null or push_area == null:
		return

	for body in push_area.get_overlapping_bodies():
		_try_push_body(body, delta)


func _try_push_body(body: Node, delta: float) -> void:
	if body == null or not is_instance_valid(body):
		return

	if not _is_valid_push_target(body):
		return

	var forward: Vector3 = (global_basis * Vector3.MODEL_FRONT).normalized()
	var push_vector: Vector3 = forward * push_velocity
	push_vector.y = maxf(push_vector.y, upward_velocity)

	if body is CharacterBody3D:
		var character: CharacterBody3D = body as CharacterBody3D
		character.velocity.x = push_vector.x
		character.velocity.z = push_vector.z
		character.velocity.y = maxf(character.velocity.y, push_vector.y)
	elif body is RigidBody3D:
		var rigid_body: RigidBody3D = body as RigidBody3D
		rigid_body.apply_central_impulse(push_vector * rigidbody_impulse_multiplier * delta)
	elif body is Node3D:
		var body_3d: Node3D = body as Node3D
		body_3d.global_position += forward * push_velocity * delta

	if damage_on_push > 0:
		_try_apply_push_damage(body, damage_on_push)


func _is_valid_push_target(body: Node) -> bool:
	for group_name in push_groups:
		if body.is_in_group(group_name):
			return true
	return false


func _try_apply_push_damage(body: Node, amount: int) -> void:
	if body.has_method("apply_vehicle_impact_damage"):
		body.apply_vehicle_impact_damage(amount, vehicle)
		return
	if body.has_method("apply_damage"):
		body.apply_damage(amount)
		return
	if body.has_method("take_damage"):
		body.take_damage(amount)
