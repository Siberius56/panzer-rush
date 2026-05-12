extends VehicleModBase
class_name AmmoPackVehicleMod

@export var reserve_ammo_bonus: int = 60


func _on_passive_enabled() -> void:
	if vehicle == null:
		return
	vehicle.add_turret_reserve_ammo_modifier(get_modifier_key(), reserve_ammo_bonus)


func _on_passive_disabled() -> void:
	if vehicle == null:
		return
	vehicle.remove_turret_reserve_ammo_modifier(get_modifier_key())
