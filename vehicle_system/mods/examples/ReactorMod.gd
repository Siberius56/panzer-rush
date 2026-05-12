extends VehicleModBase
class_name ReactorVehicleMod

@export var thrust_force: float = 22000.0
@export var thrust_direction_local: Vector3 = Vector3.MODEL_FRONT
@export var requires_fuel: bool = true
@export var extra_fuel_consumption_per_second: float = 8.0


func _on_active_physics(delta: float) -> void:
	if vehicle == null:
		force_end_active()
		return

	if requires_fuel and not vehicle.has_fuel():
		force_end_active()
		return

	if requires_fuel and extra_fuel_consumption_per_second > 0.0:
		vehicle.consume_fuel(extra_fuel_consumption_per_second * delta)
		if not vehicle.has_fuel():
			force_end_active()
			return

	var local_direction: Vector3 = thrust_direction_local.normalized()
	if local_direction.length_squared() <= 0.0:
		local_direction = Vector3.MODEL_FRONT

	var world_direction: Vector3 = (global_basis * local_direction).normalized()
	vehicle.apply_central_force(world_direction * -thrust_force)
