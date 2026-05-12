extends VehicleModBase
class_name ArmorSkirtVehicleMod

@export var armor_bonus: int = 3


func _on_passive_enabled() -> void:
	if vehicle == null:
		return
	vehicle.add_armor_modifier(get_modifier_key(), armor_bonus)


func _on_passive_disabled() -> void:
	if vehicle == null:
		return
	vehicle.remove_armor_modifier(get_modifier_key())
