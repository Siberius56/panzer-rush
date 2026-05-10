extends Node3D

@export var weapon_local_position: Vector3 = Vector3(0.18, 1.16, -0.42)
@export var left_grip_position: Vector3 = Vector3(-0.12, 0.0, -0.18)
@export var right_grip_position: Vector3 = Vector3(0.10, 0.0, 0.16)

@onready var left_grip: Node3D = get_node_or_null("LeftGrip") as Node3D
@onready var right_grip: Node3D = get_node_or_null("RightGrip") as Node3D

func _ready() -> void:
	if left_grip != null:
		left_grip.position = left_grip_position
	if right_grip != null:
		right_grip.position = right_grip_position
