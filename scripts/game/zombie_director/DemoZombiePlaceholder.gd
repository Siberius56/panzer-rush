extends Node3D

@export var attack_speed: float = 3.2
@export var idle_turn_speed: float = 1.2
@export var stop_distance: float = 1.5

var behaviour: String = "idle"
var target_position: Vector3 = Vector3.ZERO
var random_offset: Vector3 = Vector3.ZERO
var spawned_section_id: int = 0
var random: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var label: Label3D = $Label3D


func _ready() -> void:
	random.randomize()
	random_offset = Vector3(random.randf_range(-2.5, 2.5), 0.0, random.randf_range(-2.5, 2.5))
	add_to_group("zombies")
	add_to_group("enemies")
	_refresh_label()


func setup_director_demo(new_behaviour: String, new_target_position: Vector3) -> void:
	behaviour = new_behaviour
	target_position = new_target_position + random_offset
	_refresh_label()


func set_target_position(new_target_position: Vector3) -> void:
	target_position = new_target_position + random_offset


func set_spawn_behaviour(new_behaviour: String) -> void:
	behaviour = new_behaviour
	_refresh_label()


func set_spawned_section_id(new_section_id: int) -> void:
	spawned_section_id = new_section_id


func is_in_combat() -> bool:
	return behaviour == "attack" and global_position.distance_to(target_position) <= stop_distance + 2.0


func _process(delta: float) -> void:
	if behaviour == "attack":
		_update_attack(delta)
	else:
		_update_idle(delta)


func _update_attack(delta: float) -> void:
	var direction: Vector3 = target_position - global_position
	direction.y = 0.0

	if direction.length() <= stop_distance:
		rotation.y += idle_turn_speed * delta
		return

	direction = direction.normalized()
	global_position += direction * attack_speed * delta
	rotation.y = atan2(direction.x, direction.z)


func _update_idle(delta: float) -> void:
	rotation.y += idle_turn_speed * 0.25 * delta


func _refresh_label() -> void:
	if label == null:
		return

	if behaviour == "attack":
		label.text = "HORDE"
	else:
		label.text = "IDLE"
