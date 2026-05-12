extends VehicleModBase
class_name ShieldVehicleMod


func _on_active_started(_peer_id: int) -> void:
	if vehicle == null:
		return
	vehicle.set_damage_absorption_source(get_modifier_key(), true)


func _on_active_ended() -> void:
	if vehicle == null:
		return
	vehicle.set_damage_absorption_source(get_modifier_key(), false)


func _on_passive_disabled() -> void:
	if vehicle == null:
		return
	vehicle.set_damage_absorption_source(get_modifier_key(), false)
