extends Area3D

@export var damage: int = 9999
@export var affected_groups: Array[String] = [
	"player",
	"vehicle",
	"enemy"
]

func _ready() -> void:
	add_to_group("killzone")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _try_handle_special_killzone_target(body):
		return

	if not _is_valid_target(body):
		return

	_apply_damage(body)


func _try_handle_special_killzone_target(body: Node) -> bool:
	if body == null:
		return false

	if not body.has_method("handle_killzone_entered"):
		return false

	var handled: Variant = body.call("handle_killzone_entered", self)
	return handled is bool and handled == true


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
