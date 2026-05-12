extends Control
class_name VehicleNameMarker

@onready var name_label: Label = %NameLabel

func set_marker_text(value: String) -> void:
	if name_label == null:
		return

	name_label.text = value
