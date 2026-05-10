extends CharacterBody3D

@export_group("Movement")
@export var walk_speed: float = 5.0
@export var acceleration: float = 18.0
@export var friction: float = 22.0
@export var jump_velocity: float = 5.8
@export var turn_speed: float = 14.0

@export_group("Gait")
@export var stance_width: float = 0.26
@export var stride_length: float = 0.34
@export var forward_step_reach: float = 0.10
@export var max_stair_step_up: float = 0.48
@export var max_stair_step_down: float = 0.58
@export var step_height: float = 0.16
@export var gait_frequency: float = 10.5
@export var foot_ground_offset: float = 0.035
@export var max_leg_reach: float = 0.85
@export var min_foot_below_hip: float = 0.22
@export var idle_foot_forward_offset: float = 0.03
@export var support_inward: float = 0.05
@export var swing_outward: float = 0.08
@export var strafe_foot_lead: float = 0.10
@export var foot_follow_speed: float = 18.0
@export var airborne_foot_pull: float = 7.0

@export_group("Body motion")
@export var body_bob_amount: float = 0.045
@export var body_tilt_amount: float = 0.10
@export var landing_squash_strength: float = 0.12

@export_group("Limb lengths")
@export var upper_leg_length: float = 0.44
@export var lower_leg_length: float = 0.44
@export var upper_arm_length: float = 0.36
@export var lower_arm_length: float = 0.40

@export_group("Weapon pose")
@export var weapon_local_position: Vector3 = Vector3(0.22, 1.10, -0.50)
@export var left_grip_local_position: Vector3 = Vector3(-0.09, 0.0, -0.19)
@export var right_grip_local_position: Vector3 = Vector3(0.08, 0.0, 0.16)
@export var weapon_follow_speed: float = 14.0
@export var aim_ray_length: float = 100.0
@export var minimum_aim_distance: float = 0.65
@export var aim_target_height_offset: float = 0.10

@onready var visual_root: Node3D = get_node_or_null("VisualRoot")
@onready var weapon: Node3D = get_node_or_null("VisualRoot/Weapon")

@onready var left_hip: Node3D = get_node_or_null("VisualRoot/LeftHip")
@onready var right_hip: Node3D = get_node_or_null("VisualRoot/RightHip")
@onready var left_shoulder: Node3D = get_node_or_null("VisualRoot/LeftShoulder")
@onready var right_shoulder: Node3D = get_node_or_null("VisualRoot/RightShoulder")
@onready var left_grip: Node3D = get_node_or_null("VisualRoot/Weapon/LeftGrip")
@onready var right_grip: Node3D = get_node_or_null("VisualRoot/Weapon/RightGrip")

@onready var foot_probe_root: Node3D = get_node_or_null("FootProbeRoot")
@onready var left_probe: RayCast3D = get_node_or_null("FootProbeRoot/LeftFootProbe")
@onready var right_probe: RayCast3D = get_node_or_null("FootProbeRoot/RightFootProbe")

@onready var left_foot: Node3D = get_node_or_null("Feet/LeftFoot")
@onready var right_foot: Node3D = get_node_or_null("Feet/RightFoot")

@onready var left_upper_leg: Node3D = get_node_or_null("Limbs/LeftUpperLeg")
@onready var left_lower_leg: Node3D = get_node_or_null("Limbs/LeftLowerLeg")
@onready var right_upper_leg: Node3D = get_node_or_null("Limbs/RightUpperLeg")
@onready var right_lower_leg: Node3D = get_node_or_null("Limbs/RightLowerLeg")
@onready var left_upper_arm: Node3D = get_node_or_null("Limbs/LeftUpperArm")
@onready var left_lower_arm: Node3D = get_node_or_null("Limbs/LeftLowerArm")
@onready var right_upper_arm: Node3D = get_node_or_null("Limbs/RightUpperArm")
@onready var right_lower_arm: Node3D = get_node_or_null("Limbs/RightLowerArm")

@onready var aim_cursor: Node3D = get_node_or_null("AimCursor")
@onready var camera: Camera3D = get_node_or_null("CameraRig/Camera3D")

var gravity: float = 9.8
var aim_target_position: Vector3 = Vector3.FORWARD
#var aim_target_offset: Vector3 = Vector3.UP
var last_valid_aim_target_position: Vector3 = Vector3.FORWARD
var visual_yaw: float = 0.0
var walk_phase: float = 0.0
var landing_squash: float = 0.0


func _ready() -> void:
	var scene_is_valid: bool = _validate_scene_nodes()
	if not scene_is_valid:
		set_physics_process(false)
		return

	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	left_probe.enabled = true
	right_probe.enabled = true
	foot_probe_root.rotation.y = visual_yaw

	_apply_weapon_configuration()
	left_foot.global_position = _sample_grounded_foot_position(-1.0, Vector3.ZERO, 0.0, true)
	right_foot.global_position = _sample_grounded_foot_position(1.0, Vector3.ZERO, PI, true)
	aim_target_position = global_position + Vector3.FORWARD * 2.0 + Vector3.UP * aim_target_height_offset
	last_valid_aim_target_position = aim_target_position
	_update_visuals(0.016)


func _validate_scene_nodes() -> bool:
	var missing_nodes: Array[String] = []
	var required_nodes: Dictionary = {
		"VisualRoot": visual_root,
		"VisualRoot/Weapon": weapon,
		"VisualRoot/LeftHip": left_hip,
		"VisualRoot/RightHip": right_hip,
		"VisualRoot/LeftShoulder": left_shoulder,
		"VisualRoot/RightShoulder": right_shoulder,
		"VisualRoot/Weapon/LeftGrip": left_grip,
		"VisualRoot/Weapon/RightGrip": right_grip,
		"FootProbeRoot": foot_probe_root,
		"FootProbeRoot/LeftFootProbe": left_probe,
		"FootProbeRoot/RightFootProbe": right_probe,
		"Feet/LeftFoot": left_foot,
		"Feet/RightFoot": right_foot,
		"CameraRig/Camera3D": camera,
	}

	for node_path: String in required_nodes.keys():
		if required_nodes[node_path] == null:
			missing_nodes.append(node_path)

	if not missing_nodes.is_empty():
		push_error("ProceduralWalker: nodes obligatoires manquants: " + ", ".join(missing_nodes))
		return false

	var missing_limb_nodes: Array[String] = []
	var limb_nodes: Dictionary = {
		"Limbs/LeftUpperLeg": left_upper_leg,
		"Limbs/LeftLowerLeg": left_lower_leg,
		"Limbs/RightUpperLeg": right_upper_leg,
		"Limbs/RightLowerLeg": right_lower_leg,
		"Limbs/LeftUpperArm": left_upper_arm,
		"Limbs/LeftLowerArm": left_lower_arm,
		"Limbs/RightUpperArm": right_upper_arm,
		"Limbs/RightLowerArm": right_lower_arm,
	}

	for limb_path: String in limb_nodes.keys():
		if limb_nodes[limb_path] == null:
			missing_limb_nodes.append(limb_path)

	if not missing_limb_nodes.is_empty():
		push_warning("ProceduralWalker: membres manquants, ils seront ignorés: " + ", ".join(missing_limb_nodes))

	return true


func _physics_process(delta: float) -> void:
	_update_aim_target()
	_update_movement(delta)
	_update_feet(delta)
	_update_visuals(delta)


func _update_movement(delta: float) -> void:
	var was_on_floor: bool = is_on_floor()
	var input_direction: Vector3 = _get_input_direction()
	var target_velocity: Vector3 = input_direction * walk_speed
	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)

	if input_direction.length_squared() > 0.001:
		horizontal_velocity = horizontal_velocity.move_toward(target_velocity, acceleration * delta)
	else:
		horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, friction * delta)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = -0.1

		if Input.is_key_pressed(KEY_SPACE):
			velocity.y = jump_velocity
			landing_squash = -0.55
	else:
		velocity.y -= gravity * delta

	move_and_slide()

	if not was_on_floor and is_on_floor():
		landing_squash = 1.0


func _get_input_direction() -> Vector3:
	var input_vector: Vector2 = Vector2.ZERO

	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_vector.x += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_LEFT):
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_vector.y += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_UP):
		input_vector.y -= 1.0

	if input_vector.length_squared() > 1.0:
		input_vector = input_vector.normalized()

	return Vector3(input_vector.x, 0.0, input_vector.y)


func _update_aim_target() -> void:
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_position)
	var ray_direction: Vector3 = camera.project_ray_normal(mouse_position)
	var ray_end: Vector3 = ray_origin + ray_direction * aim_ray_length
	var raw_aim_target: Vector3 = last_valid_aim_target_position

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	ray_query.exclude = [get_rid()]
	var hit_result: Dictionary = space_state.intersect_ray(ray_query)

	if not hit_result.is_empty() and hit_result.has("position"):
		raw_aim_target = hit_result["position"] + Vector3.UP * aim_target_height_offset
	elif abs(ray_direction.y) > 0.001:
		var distance_to_ground: float = -ray_origin.y / ray_direction.y
		if distance_to_ground > 0.0:
			raw_aim_target = ray_origin + ray_direction * distance_to_ground + Vector3.UP * aim_target_height_offset

	var flat_from_weapon: Vector3 = raw_aim_target - weapon.global_position
	flat_from_weapon.y = 0.0

	if flat_from_weapon.length() < minimum_aim_distance:
		aim_target_position = last_valid_aim_target_position
	else:
		aim_target_position = raw_aim_target
		last_valid_aim_target_position = aim_target_position

	aim_cursor.global_position = aim_target_position + Vector3.UP * 0.035


func _update_feet(delta: float) -> void:
	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var speed_ratio: float = clamp(horizontal_velocity.length() / walk_speed, 0.0, 1.0)

	if is_on_floor() and speed_ratio > 0.03:
		walk_phase += delta * lerp(3.0, gait_frequency, speed_ratio)

	foot_probe_root.rotation.y = visual_yaw

	if is_on_floor():
		var left_target: Vector3 = _sample_grounded_foot_position(-1.0, horizontal_velocity, 0.0)
		var right_target: Vector3 = _sample_grounded_foot_position(1.0, horizontal_velocity, PI)
		var follow_speed: float = foot_follow_speed + speed_ratio * 8.0
		left_foot.global_position = left_foot.global_position.lerp(left_target, delta * follow_speed)
		right_foot.global_position = right_foot.global_position.lerp(right_target, delta * follow_speed)
		left_foot.global_position = _clamp_foot_target(-1.0, left_foot.global_position)
		right_foot.global_position = _clamp_foot_target(1.0, right_foot.global_position)
	else:
		_update_air_feet(delta)


func _sample_grounded_foot_position(side_sign: float, horizontal_velocity: Vector3, phase_offset: float, instant: bool = false) -> Vector3:
	var horizontal_speed: float = horizontal_velocity.length()
	var speed_ratio: float = clamp(horizontal_speed / walk_speed, 0.0, 1.0)
	var local_velocity: Vector3 = _world_to_visual_local(horizontal_velocity)
	var foot_data: Dictionary = _get_foot_cycle_data(side_sign, local_velocity, speed_ratio, walk_phase + phase_offset)
	var local_x: float = float(foot_data["local_x"])
	var local_z: float = float(foot_data["local_z"])
	var lift_amount: float = float(foot_data["lift"])
	var probe: RayCast3D = left_probe if side_sign < 0.0 else right_probe

	probe.position = Vector3(local_x, 1.38, local_z)
	probe.force_raycast_update()

	var raw_target_position: Vector3 = _get_probe_ground_position(probe, side_sign)
	raw_target_position.y += lift_amount
	raw_target_position = _clamp_foot_target(side_sign, raw_target_position)

	if instant:
		return raw_target_position

	return raw_target_position


func _get_foot_cycle_data(side_sign: float, local_velocity: Vector3, speed_ratio: float, phase_value: float) -> Dictionary:
	var cycle: float = sin(phase_value)
	var lift_phase: float = max(cycle, 0.0)
	var base_x: float = stance_width * side_sign
	var base_z: float = idle_foot_forward_offset

	if speed_ratio <= 0.03 or local_velocity.length_squared() <= 0.0001:
		return {
			"local_x": base_x,
			"local_z": base_z,
			"lift": 0.0
		}

	var move_direction: Vector3 = local_velocity.normalized()
	var forward_blend: float = abs(move_direction.dot(Vector3.FORWARD))
	var strafe_blend: float = abs(move_direction.dot(Vector3.RIGHT))
	var support_factor: float = max(-cycle, 0.0)
	var swing_factor: float = max(cycle, 0.0)
	var stride_offset: Vector3 = move_direction * (cycle * stride_length * speed_ratio)
	stride_offset += move_direction * (swing_factor * forward_step_reach * speed_ratio)

	var local_x: float = base_x + stride_offset.x
	local_x += -side_sign * support_inward * support_factor * forward_blend * speed_ratio
	local_x += side_sign * swing_outward * swing_factor * forward_blend * speed_ratio

	var local_z: float = base_z + stride_offset.z
	local_z += -side_sign * move_direction.x * strafe_foot_lead * strafe_blend * speed_ratio

	var lift_amount: float = step_height * lift_phase * speed_ratio

	return {
		"local_x": local_x,
		"local_z": local_z,
		"lift": lift_amount
	}


func _update_air_feet(delta: float) -> void:
	var left_air_local: Vector3 = Vector3(-stance_width * 0.85, 0.30, 0.10)
	var right_air_local: Vector3 = Vector3(stance_width * 0.85, 0.30, 0.10)
	var left_air_world: Vector3 = _clamp_foot_target(-1.0, foot_probe_root.to_global(left_air_local))
	var right_air_world: Vector3 = _clamp_foot_target(1.0, foot_probe_root.to_global(right_air_local))
	left_foot.global_position = left_foot.global_position.lerp(left_air_world, delta * airborne_foot_pull)
	right_foot.global_position = right_foot.global_position.lerp(right_air_world, delta * airborne_foot_pull)
	left_foot.global_position = _clamp_foot_target(-1.0, left_foot.global_position)
	right_foot.global_position = _clamp_foot_target(1.0, right_foot.global_position)


func _get_probe_ground_position(probe: RayCast3D, side_sign: float) -> Vector3:
	var hip_world_position: Vector3 = _get_hip_position(side_sign)
	var nominal_foot_y: float = hip_world_position.y - max_leg_reach * 0.82
	var highest_ground_y: float = min(hip_world_position.y - min_foot_below_hip, nominal_foot_y + max_stair_step_up)
	var lowest_ground_y: float = nominal_foot_y - max_stair_step_down

	if probe.is_colliding():
		var hit_world_position: Vector3 = probe.get_collision_point() + Vector3.UP * foot_ground_offset
		hit_world_position.y = clamp(hit_world_position.y, lowest_ground_y, highest_ground_y)
		return _clamp_foot_target(side_sign, hit_world_position)

	var suspended_world_position: Vector3 = probe.global_position
	suspended_world_position.y = nominal_foot_y
	return _clamp_foot_target(side_sign, suspended_world_position)


func _get_hip_position(side_sign: float) -> Vector3:
	if side_sign < 0.0:
		return left_hip.global_position

	return right_hip.global_position


func _clamp_foot_target(side_sign: float, target_position: Vector3) -> Vector3:
	var hip_world_position: Vector3 = _get_hip_position(side_sign)

	var highest_allowed_y: float = hip_world_position.y - min_foot_below_hip
	var lowest_allowed_y: float = hip_world_position.y - max_leg_reach
	target_position.y = clamp(target_position.y, lowest_allowed_y, highest_allowed_y)

	var hip_to_target: Vector3 = target_position - hip_world_position
	var target_distance: float = hip_to_target.length()

	if target_distance > max_leg_reach:
		var clamped_direction: Vector3 = hip_to_target.normalized()
		target_position = hip_world_position + clamped_direction * max_leg_reach
		target_position.y = clamp(target_position.y, lowest_allowed_y, highest_allowed_y)

	return target_position


func _update_visuals(delta: float) -> void:
	_update_body_rotation(delta)
	_update_body_motion(delta)
	_update_weapon_pose(delta)
	_update_limbs()


func _update_body_rotation(delta: float) -> void:
	var aim_direction: Vector3 = aim_target_position - global_position
	aim_direction.y = 0.0

	if aim_direction.length_squared() <= 0.001:
		return

	var target_yaw: float = atan2(-aim_direction.x, -aim_direction.z)
	visual_yaw = lerp_angle(visual_yaw, target_yaw, delta * turn_speed)


func _update_body_motion(delta: float) -> void:
	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var speed_ratio: float = clamp(horizontal_velocity.length() / walk_speed, 0.0, 1.0)

	var bob: float = sin(walk_phase * 2.0) * body_bob_amount * speed_ratio
	var local_velocity: Vector3 = _world_to_visual_local(horizontal_velocity)
	var pitch: float = clamp(local_velocity.z / walk_speed, -1.0, 1.0) * body_tilt_amount
	var roll: float = clamp(-local_velocity.x / walk_speed, -1.0, 1.0) * body_tilt_amount

	landing_squash = move_toward(landing_squash, 0.0, delta * 5.5)
	var squash: float = landing_squash * landing_squash_strength
	if landing_squash < 0.0:
		squash = landing_squash * landing_squash_strength * 0.5

	visual_root.position.y = lerp(visual_root.position.y, bob, delta * 12.0)
	visual_root.rotation = Vector3(pitch, visual_yaw, roll)
	visual_root.scale = Vector3(1.0 + abs(squash) * 0.45, 1.0 - squash, 1.0 + abs(squash) * 0.25)


func _update_weapon_pose(delta: float) -> void:
	if weapon == null:
		return

	_apply_weapon_configuration()

	var current_weapon_local_position: Vector3 = weapon.position
	weapon.position = current_weapon_local_position.lerp(weapon_local_position, delta * weapon_follow_speed)

	var weapon_to_target: Vector3 = aim_target_position - weapon.global_position
	var flat_weapon_to_target: Vector3 = weapon_to_target
	flat_weapon_to_target.y = 0.0

	if flat_weapon_to_target.length() < minimum_aim_distance:
		return

	if weapon_to_target.length_squared() > 0.001:
		weapon.look_at(aim_target_position, Vector3.UP)


func _apply_weapon_configuration() -> void:
	if weapon != null:
		weapon.position = weapon_local_position
	if left_grip != null:
		left_grip.position = left_grip_local_position
	if right_grip != null:
		right_grip.position = right_grip_local_position


func set_weapon_pose(new_weapon_local_position: Vector3, new_left_grip_local_position: Vector3, new_right_grip_local_position: Vector3) -> void:
	weapon_local_position = new_weapon_local_position
	left_grip_local_position = new_left_grip_local_position
	right_grip_local_position = new_right_grip_local_position
	_apply_weapon_configuration()


func _world_to_visual_local(world_vector: Vector3) -> Vector3:
	var yaw_transform_basis: Basis = Basis(Vector3.UP, visual_yaw)
	return yaw_transform_basis.inverse() * world_vector


func _update_limbs() -> void:
	left_foot.global_position = _clamp_foot_target(-1.0, left_foot.global_position)
	right_foot.global_position = _clamp_foot_target(1.0, right_foot.global_position)

	var body_forward: Vector3 = -visual_root.global_transform.basis.z
	var body_right: Vector3 = visual_root.global_transform.basis.x

	var left_knee: Vector3 = _solve_two_bone_joint(
		left_hip.global_position,
		left_foot.global_position,
		(body_forward + body_right * -0.25).normalized(),
		upper_leg_length,
		lower_leg_length
	)
	var right_knee: Vector3 = _solve_two_bone_joint(
		right_hip.global_position,
		right_foot.global_position,
		(body_forward + body_right * 0.25).normalized(),
		upper_leg_length,
		lower_leg_length
	)

	_place_segment_between_points(left_upper_leg, left_hip.global_position, left_knee)
	_place_segment_between_points(left_lower_leg, left_knee, left_foot.global_position)
	_place_segment_between_points(right_upper_leg, right_hip.global_position, right_knee)
	_place_segment_between_points(right_lower_leg, right_knee, right_foot.global_position)

	var left_elbow: Vector3 = _solve_two_bone_joint(
		left_shoulder.global_position,
		left_grip.global_position,
		(-body_forward + body_right * -1.00).normalized(),
		upper_arm_length,
		lower_arm_length
	)
	var right_elbow: Vector3 = _solve_two_bone_joint(
		right_shoulder.global_position,
		right_grip.global_position,
		(-body_forward + body_right * 0.70).normalized(),
		upper_arm_length,
		lower_arm_length
	)

	_place_segment_between_points(left_upper_arm, left_shoulder.global_position, left_elbow)
	_place_segment_between_points(left_lower_arm, left_elbow, left_grip.global_position)
	_place_segment_between_points(right_upper_arm, right_shoulder.global_position, right_elbow)
	_place_segment_between_points(right_lower_arm, right_elbow, right_grip.global_position)


func _solve_two_bone_joint(root_position: Vector3, target_position: Vector3, bend_direction: Vector3, upper_length: float, lower_length: float) -> Vector3:
	var to_target: Vector3 = target_position - root_position
	var distance_to_target: float = to_target.length()

	if distance_to_target <= 0.0001:
		return root_position + bend_direction.normalized() * upper_length

	var target_direction: Vector3 = to_target / distance_to_target
	var clamped_distance: float = clamp(distance_to_target, 0.001, upper_length + lower_length - 0.001)
	var bend_axis: Vector3 = bend_direction - target_direction * bend_direction.dot(target_direction)

	if bend_axis.length_squared() <= 0.0001:
		bend_axis = target_direction.cross(Vector3.UP)
		if bend_axis.length_squared() <= 0.0001:
			bend_axis = target_direction.cross(Vector3.RIGHT)

	bend_axis = bend_axis.normalized()

	var along_distance: float = (upper_length * upper_length - lower_length * lower_length + clamped_distance * clamped_distance) / (2.0 * clamped_distance)
	var height_squared: float = max(upper_length * upper_length - along_distance * along_distance, 0.0)
	var bend_height: float = sqrt(height_squared)

	return root_position + target_direction * along_distance + bend_axis * bend_height


func _place_segment_between_points(segment: Node3D, start_position: Vector3, end_position: Vector3) -> void:
	if segment == null:
		return

	var segment_direction: Vector3 = end_position - start_position
	var segment_length: float = segment_direction.length()

	if segment_length <= 0.001:
		return

	var midpoint: Vector3 = start_position + segment_direction * 0.5
	var y_axis: Vector3 = segment_direction.normalized()
	var x_axis: Vector3 = y_axis.cross(Vector3.FORWARD)

	if x_axis.length_squared() <= 0.001:
		x_axis = y_axis.cross(Vector3.RIGHT)

	x_axis = x_axis.normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	var segment_basis: Basis = Basis(x_axis, y_axis, z_axis).orthonormalized()

	segment.global_transform = Transform3D(segment_basis, midpoint)
	segment.scale = Vector3(1.0, segment_length, 1.0)
