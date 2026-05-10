extends Node3D

@export var enable_randomization: bool = true

@export_range(0.0, 1.0, 0.01) var size_variation: float = 0.10
@export_range(0.0, 360.0, 1.0) var y_rotation_variation_degrees: float = 360.0

@export var randomize_scale: bool = true
@export var randomize_y_rotation: bool = true

@export var position_snap: float = 0.01
@export var seed_salt: String = ""

var base_scale: Vector3
var base_rotation_degrees: Vector3


func _ready() -> void:
	if not enable_randomization:
		set_process(false)
		set_physics_process(false)
		return

	base_scale = scale
	base_rotation_degrees = rotation_degrees

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _get_seed_from_world_position()

	if randomize_scale:
		_apply_random_scale(rng)

	if randomize_y_rotation:
		_apply_random_y_rotation(rng)


func _apply_random_scale(rng: RandomNumberGenerator) -> void:
	var safe_variation: float = clamp(size_variation, 0.0, 0.99)
	var min_scale: float = 1.0 - safe_variation
	var max_scale: float = 1.0 + safe_variation

	var scale_multiplier: float = rng.randf_range(min_scale, max_scale)
	scale = base_scale * scale_multiplier


func _apply_random_y_rotation(rng: RandomNumberGenerator) -> void:
	var half_range: float = y_rotation_variation_degrees * 0.5
	var random_y_offset: float = rng.randf_range(-half_range, half_range)

	var new_rotation: Vector3 = base_rotation_degrees
	new_rotation.y += random_y_offset

	rotation_degrees = new_rotation


func _get_seed_from_world_position() -> int:
	var snap: float = max(position_snap, 0.0001)

	var snapped_x: int = int(round(global_position.x / snap))
	var snapped_y: int = int(round(global_position.y / snap))
	var snapped_z: int = int(round(global_position.z / snap))

	var seed_text: String = "%d|%d|%d|%s" % [
		snapped_x,
		snapped_y,
		snapped_z,
		seed_salt
	]

	return _hash_string_to_seed(seed_text)


func _hash_string_to_seed(text: String) -> int:
	var seed_value: int = 5381

	for i in range(text.length()):
		seed_value = ((seed_value << 5) + seed_value) + text.unicode_at(i)
		seed_value = seed_value & 0x7FFFFFFFFFFFFFFF

	return seed_value
