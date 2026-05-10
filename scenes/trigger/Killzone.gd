extends Area3D

@export var damage: int = 9999
@export var affected_groups: Array[String] = [
	"player",
	"vehicle",
	"enemy"
]

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not _is_valid_target(body):
		return

	_apply_damage(body)


func _is_valid_target(body: Node) -> bool:
	for group_name: String in affected_groups:
		if body.is_in_group(group_name):
			return true

	return false


func _apply_damage(target: Node) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage)
		return

	if target.has_method("apply_damage"):
		target.apply_damage(damage)
		return

	if target.has_method("die"):
		target.die()
		return

	push_warning("Killzone: target has no damage method: " + target.name)
