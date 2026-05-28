extends Node3D
#class_name DestructibleProp

## Script commun pour des props physiques destructibles.
## Godot 4.x.
##
## Principe :
## - Un seul systeme de degats : apply_damage(amount).
## - Pas de type de degat.
## - Pas de multiplicateur balle / explosion / collision.
## - L'objet est detruit uniquement quand ses PV tombent a zero.
## - Le corps intact peut etre physique ou fige via physics_enabled.
## - Les debris sont visuels, locaux, non synchronises.

signal damaged(prop: DestructibleProp, amount: float, current_hp: float)
signal destroyed(prop: DestructibleProp)
signal debris_visuals_finished(prop: DestructibleProp)
signal final_cleanup_requested(prop: DestructibleProp)

@export_category("Scene paths")
@export var intact_body_path: NodePath = ^"IntactBody"
@export var intact_visual_root_path: NodePath = ^"IntactBody/Intact"
@export var main_collision_path: NodePath = ^"IntactBody/Collision"
@export var debris_root_path: NodePath = ^"DebrisRoot"

@export_category("Durability")
@export var max_hp: float = 20.0
@export var armor: float = 0.0
@export var destroy_when_hp_reaches_zero: bool = true

@export_category("Physics")
## Si false, le prop garde sa collision mais ne bouge plus.
## Utile pour un obstacle anti-char ou un element de decor fixe.
@export var physics_enabled: bool = true
## Par defaut, les props collisionnent avec tout le monde.
## Si tu veux exclure les ennemis, mets false et regle enemy_collision_layer_bit.
@export var enemies_can_physically_interact: bool = true
## Numero de layer Godot utilisee par les ennemis. Valeur entre 1 et 32.
## Cette option ne fonctionne que si tes ennemis sont vraiment sur cette layer.
@export_range(1, 32, 1) var enemy_collision_layer_bit: int = 5

@export_category("Network")
## En multijoueur, il est recommande que seul le serveur / l'autorite applique les degats.
@export var damage_only_on_multiplayer_authority: bool = true
## Alternative simple a un MultiplayerSynchronizer.
## Si true, l'autorite envoie un RPC fiable quand l'objet est detruit.
@export var use_rpc_for_destroyed_state: bool = true 
## Peut etre synchronise via MultiplayerSynchronizer.
## Les debris ne doivent pas etre synchronises.
@export var destroyed_state: bool = false

@export_category("Debris")
@export var activate_embedded_debris_on_destroy: bool = true
@export var detach_debris_on_destroy: bool = true
@export var debris_lifetime_seconds: float = 6.0
@export var debris_min_impulse: float = 1.0
@export var debris_max_impulse: float = 3.0
@export var debris_upward_bias: float = 0.3
@export var debris_randomness: float = 0.6
@export var debris_torque_impulse: float = 1.5
@export_flags_3d_physics var debris_collision_layer: int = 1
@export_flags_3d_physics var debris_collision_mask: int = 4294967295

@export_category("Final cleanup")
## Quand true, le prop racine est supprime apres la duree de vie des debris.
@export var auto_cleanup_original_after_debris: bool = true
@export var original_cleanup_extra_delay_seconds: float = 0.15
## En reseau, evite qu'un client supprime seul un objet synchronise.
@export var cleanup_only_on_multiplayer_authority: bool = true
## Si true et use_rpc_for_destroyed_state est true, l'autorite supprime aussi le prop sur tous les peers.
@export var use_rpc_for_final_cleanup: bool = true

@export_category("Runtime zone streaming")
## Utilise par LevelBlock quand une zone devient inactive.
## L'objet n'est jamais detruit. Son corps intact est gele et ses collisions sont coupees.
@export var preserve_transform_when_zone_inactive: bool = true
## Laisse false pour eviter l'effet "prop qui disparait" pendant le streaming de zone.
@export var hide_when_zone_inactive: bool = false

var current_hp: float = 0.0

var _intact_body: RigidBody3D
var _intact_visual_root: Node3D
var _main_collision: CollisionShape3D
var _debris_root: Node3D

var _is_destroyed: bool = false
var _last_observed_destroyed_state: bool = false
var _last_damage_origin: Vector3 = Vector3.ZERO
var _has_damage_origin: bool = false
var _rng := RandomNumberGenerator.new()

var _debris_bodies: Array[RigidBody3D] = []
var _activated_debris: Array[RigidBody3D] = []
var _debris_local_transforms: Dictionary = {}
var _debris_root_local_to_intact: Transform3D = Transform3D.IDENTITY
var _last_intact_global_transform: Transform3D = Transform3D.IDENTITY

var _zone_runtime_active: bool = true
var _runtime_saved_intact_transform: Transform3D = Transform3D.IDENTITY
var _runtime_has_saved_intact_transform: bool = false
var _runtime_multiplayer_nodes: Array[Node] = []


static func from_collider(collider: Node) -> DestructibleProp:
	## Utilitaire pour les raycasts.
	## Si le collider est IntactBody ou un enfant, remonte jusqu'au DestructibleProp.
	var node := collider
	while node != null:
		if node is DestructibleProp:
			return node as DestructibleProp
		if node.has_meta(&"destructible_prop"):
			var prop = node.get_meta(&"destructible_prop")
			if prop is DestructibleProp:
				return prop as DestructibleProp
		node = node.get_parent()
	return null


func _ready() -> void:
	#add_to_group("props")
	#add_to_group("prop")
	_rng.randomize()
	current_hp = max_hp
	
	_intact_body = get_node_or_null(intact_body_path) as RigidBody3D
	_intact_visual_root = get_node_or_null(intact_visual_root_path) as Node3D
	_main_collision = get_node_or_null(main_collision_path) as CollisionShape3D
	_debris_root = get_node_or_null(debris_root_path) as Node3D

	add_to_group(&"destructible_props")

	if _intact_body != null:
		_intact_body.add_to_group("props")
		_intact_body.add_to_group("prop")
		_intact_body.set_meta(&"destructible_prop", self)
		_intact_body.continuous_cd = true
		_intact_body.collision_mask = _get_physics_mask_with_enemy_rule(_intact_body.collision_mask)
		_remember_runtime_original_collision(_intact_body)
		_apply_physics_enabled()

	_collect_runtime_multiplayer_nodes(self, _runtime_multiplayer_nodes)
	_setup_embedded_debris()

	_last_observed_destroyed_state = destroyed_state
	_last_intact_global_transform = _get_intact_global_transform()

	if destroyed_state:
		_set_destroyed_locally(Vector3.ZERO, false, _last_intact_global_transform)


func _process(_delta: float) -> void:
	## Permet a un MultiplayerSynchronizer de piloter uniquement destroyed_state.
	## Les debris restent locaux sur chaque client.
	if destroyed_state != _last_observed_destroyed_state:
		_last_observed_destroyed_state = destroyed_state
		if destroyed_state:
			_set_destroyed_locally(Vector3.ZERO, false, _last_intact_global_transform)


func _physics_process(_delta: float) -> void:
	if _is_destroyed:
		return
	_last_intact_global_transform = _get_intact_global_transform()


func apply_damage(amount: float, hit_position: Vector3 = Vector3.ZERO, impulse: Vector3 = Vector3.ZERO) -> void:
	if _is_destroyed or amount <= 0.0:
		return

	if _should_ignore_damage_due_to_authority():
		return

	var final_damage := maxf(amount - armor, 0.0)
	if final_damage <= 0.0:
		return

	if hit_position != Vector3.ZERO:
		_last_damage_origin = hit_position
		_has_damage_origin = true

	current_hp = maxf(current_hp - final_damage, 0.0)
	
	print("current_hp: ", current_hp, "/", max_hp)
	
	damaged.emit(self, final_damage, current_hp)

	if impulse.length_squared() > 0.0 and _intact_body != null and physics_enabled:
		_intact_body.apply_central_impulse(impulse)

	if destroy_when_hp_reaches_zero and current_hp <= 0.0:
		destroy()


func take_damage(amount: float, hit_position: Vector3 = Vector3.ZERO, impulse: Vector3 = Vector3.ZERO) -> void:
	## Alias pratique si tes autres objets utilisent deja take_damage().
	apply_damage(amount, hit_position, impulse)


func heal_full() -> void:
	## Repare seulement un objet non detruit.
	if _is_destroyed:
		return
	current_hp = max_hp


func set_physics_enabled(enabled: bool) -> void:
	physics_enabled = enabled
	_apply_physics_enabled()


func set_level_block_runtime_active(active: bool) -> void:
	set_prop_runtime_active(active)


func set_prop_runtime_active(active: bool) -> void:
	_zone_runtime_active = active
	set_meta("runtime_active", active)

	# Un prop deja detruit ne doit jamais redevenir solide lors du retour dans la zone.
	if _is_destroyed or destroyed_state:
		_set_runtime_multiplayer_nodes_active(active)
		return

	if hide_when_zone_inactive:
		visible = active
	else:
		visible = true

	if _intact_body == null or not is_instance_valid(_intact_body):
		_set_runtime_multiplayer_nodes_active(active)
		return

	_remember_runtime_original_collision(_intact_body)

	if active:
		_restore_intact_body_after_runtime_pause()
	else:
		_pause_intact_body_for_inactive_zone()

	_set_runtime_multiplayer_nodes_active(active)


func is_prop_runtime_active() -> bool:
	return _zone_runtime_active


func is_destructible_prop_destroyed() -> bool:
	return _is_destroyed or destroyed_state


func destroy() -> void:
	if _is_destroyed:
		return

	if _should_ignore_damage_due_to_authority():
		return

	var destruction_transform := _get_intact_global_transform()
	_last_intact_global_transform = destruction_transform

	destroyed_state = true
	_last_observed_destroyed_state = true

	if use_rpc_for_destroyed_state and multiplayer.has_multiplayer_peer() and is_multiplayer_authority():
		rpc("receive_destroyed_state", _last_damage_origin, _has_damage_origin, destruction_transform)
	else:
		_set_destroyed_locally(_last_damage_origin, _has_damage_origin, destruction_transform)


@rpc("authority", "call_local", "reliable")
func receive_destroyed_state(
	damage_origin: Vector3 = Vector3.ZERO,
	has_damage_origin: bool = false,
	destruction_transform: Transform3D = Transform3D.IDENTITY
) -> void:
	destroyed_state = true
	_last_observed_destroyed_state = true
	_last_intact_global_transform = destruction_transform
	_set_destroyed_locally(damage_origin, has_damage_origin, destruction_transform)


@rpc("authority", "call_local", "reliable")
func receive_final_cleanup() -> void:
	queue_free()


func _set_destroyed_locally(damage_origin: Vector3, has_damage_origin: bool, destruction_transform: Transform3D) -> void:
	if _is_destroyed:
		return

	_is_destroyed = true
	destroyed_state = true
	destroyed.emit(self)

	# Important : on capture la position du corps intact avant de le masquer / freezer.
	_last_intact_global_transform = destruction_transform
	_disable_intact_body()

	if activate_embedded_debris_on_destroy:
		_activate_debris(damage_origin, has_damage_origin, destruction_transform)
	else:
		_start_final_cleanup_timer(0.0)


func _disable_intact_body() -> void:
	if _intact_visual_root != null:
		_intact_visual_root.visible = false

	if _main_collision != null:
		_main_collision.set_deferred("disabled", true)

	if _intact_body != null:
		_intact_body.freeze = true
		_intact_body.sleeping = true
		_intact_body.visible = false
		_intact_body.set_deferred("collision_layer", 0)
		_intact_body.set_deferred("collision_mask", 0)


func _setup_embedded_debris() -> void:
	_debris_bodies.clear()
	_debris_local_transforms.clear()
	_debris_root_local_to_intact = Transform3D.IDENTITY

	if _debris_root == null:
		return

	_collect_debris_bodies(_debris_root, _debris_bodies)

	# Important : on stocke les debris dans le repere de DebrisRoot.
	# Ensuite, a la destruction, on place DebrisRoot sur le corps intact.
	# Cela evite les decalages quand Crate reste a l'origine mais IntactBody a bouge avec la physique.
	var intact_transform := _get_intact_global_transform()
	_debris_root_local_to_intact = intact_transform.affine_inverse() * _debris_root.global_transform
	var debris_root_global_transform := _debris_root.global_transform

	_debris_root.visible = false

	for body in _debris_bodies:
		_debris_local_transforms[body.get_instance_id()] = debris_root_global_transform.affine_inverse() * body.global_transform
		body.visible = false
		body.freeze = true
		body.sleeping = true
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.set_meta(&"destructible_prop", self)
		body.set_deferred("collision_layer", 0)
		body.set_deferred("collision_mask", 0)
		_set_collision_shapes_enabled(body, false)


func _collect_debris_bodies(root: Node, output: Array[RigidBody3D]) -> void:
	for child in root.get_children():
		if child is RigidBody3D:
			output.append(child as RigidBody3D)
		_collect_debris_bodies(child, output)


func _activate_debris(damage_origin: Vector3, has_damage_origin: bool, base_transform: Transform3D) -> void:
	if _debris_root == null or _debris_bodies.is_empty():
		_start_final_cleanup_timer(0.0)
		return

	# DebrisRoot est recale sur le transform reel du corps intact au moment de la destruction.
	# C'est le point qui corrige les debris qui apparaissent au centre de la map.
	var debris_root_spawn_transform := base_transform * _debris_root_local_to_intact
	_debris_root.global_transform = debris_root_spawn_transform
	_debris_root.visible = true

	var target_parent := _get_debris_target_parent()
	_activated_debris.clear()

	for body in _debris_bodies:
		if not is_instance_valid(body):
			continue

		var local_transform: Transform3D = _debris_local_transforms.get(body.get_instance_id(), Transform3D.IDENTITY)
		var spawn_transform := debris_root_spawn_transform * local_transform

		# On replace le RigidBody pendant qu'il est encore gele, sinon le PhysicsServer peut garder son ancien etat.
		body.freeze = true
		body.sleeping = true
		body.visible = true
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO

		if detach_debris_on_destroy and target_parent != null:
			var old_parent := body.get_parent()
			if old_parent != null:
				old_parent.remove_child(body)
			target_parent.add_child(body)

		_force_rigidbody_transform(body, spawn_transform)

		body.collision_layer = debris_collision_layer
		body.collision_mask = _get_physics_mask_with_enemy_rule(debris_collision_mask)

		_set_collision_shapes_enabled(body, true)

		body.freeze = false
		body.sleeping = false
		_force_rigidbody_transform(body, spawn_transform)

		_apply_debris_impulse(body, base_transform.origin, damage_origin, has_damage_origin)
		_activated_debris.append(body)


func _force_rigidbody_transform(body: RigidBody3D, target_transform: Transform3D) -> void:
	body.global_transform = target_transform
	PhysicsServer3D.body_set_state(body.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, target_transform)
	PhysicsServer3D.body_set_state(body.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(body.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)


func _set_collision_shapes_enabled(root: Node, enabled: bool) -> void:
	if root is CollisionShape3D:
		(root as CollisionShape3D).set_deferred("disabled", not enabled)

	for child in root.get_children():
		_set_collision_shapes_enabled(child, enabled)


func _apply_debris_impulse(body: RigidBody3D, base_position: Vector3, damage_origin: Vector3, has_damage_origin: bool) -> void:
	var direction: Vector3

	if has_damage_origin:
		direction = body.global_position - damage_origin
	else:
		direction = body.global_position - base_position

	if direction.length_squared() < 0.001:
		direction = _random_unit_vector()
	else:
		direction = direction.normalized()

	var random_direction := _random_unit_vector()
	direction = direction.lerp(random_direction, clampf(debris_randomness, 0.0, 1.0)).normalized()
	direction.y += debris_upward_bias
	direction = direction.normalized()

	var impulse_strength := _rng.randf_range(debris_min_impulse, debris_max_impulse)
	body.apply_central_impulse(direction * impulse_strength)

	if debris_torque_impulse > 0.0:
		body.apply_torque_impulse(_random_unit_vector() * debris_torque_impulse)


func _start_final_cleanup_timer(delay_seconds: float) -> void:
	var total_delay := maxf(delay_seconds, 0.0)
	if auto_cleanup_original_after_debris:
		total_delay += maxf(original_cleanup_extra_delay_seconds, 0.0)

	_cleanup_after_delay(total_delay)


func _cleanup_after_delay(delay_seconds: float) -> void:
	await get_tree().create_timer(delay_seconds).timeout

	for body in _activated_debris:
		if is_instance_valid(body):
			body.queue_free()
	_activated_debris.clear()

	debris_visuals_finished.emit(self)

	if not auto_cleanup_original_after_debris:
		return

	final_cleanup_requested.emit(self)

	if multiplayer.has_multiplayer_peer():
		if cleanup_only_on_multiplayer_authority and not is_multiplayer_authority():
			return
		if use_rpc_for_final_cleanup and use_rpc_for_destroyed_state:
			rpc("receive_final_cleanup")
		else:
			queue_free()
	else:
		queue_free()


func _pause_intact_body_for_inactive_zone() -> void:
	if _intact_body == null or not is_instance_valid(_intact_body):
		return

	if preserve_transform_when_zone_inactive:
		_runtime_saved_intact_transform = _intact_body.global_transform
		_runtime_has_saved_intact_transform = true

	_intact_body.linear_velocity = Vector3.ZERO
	_intact_body.angular_velocity = Vector3.ZERO
	_intact_body.sleeping = true
	_intact_body.freeze = true
	_intact_body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	_intact_body.collision_layer = 0
	_intact_body.collision_mask = 0


func _restore_intact_body_after_runtime_pause() -> void:
	if _intact_body == null or not is_instance_valid(_intact_body):
		return

	_intact_body.freeze = true
	_intact_body.sleeping = true
	_intact_body.linear_velocity = Vector3.ZERO
	_intact_body.angular_velocity = Vector3.ZERO

	if preserve_transform_when_zone_inactive and _runtime_has_saved_intact_transform:
		_force_rigidbody_transform(_intact_body, _runtime_saved_intact_transform)

	_restore_runtime_original_collision(_intact_body)
	_apply_physics_enabled()

	if physics_enabled:
		_intact_body.sleeping = false


func _remember_runtime_original_collision(body: CollisionObject3D) -> void:
	if body == null or not is_instance_valid(body):
		return

	const META_LAYER: String = "destructible_runtime_original_collision_layer"
	const META_MASK: String = "destructible_runtime_original_collision_mask"
	if not body.has_meta(META_LAYER):
		body.set_meta(META_LAYER, body.collision_layer)
	if not body.has_meta(META_MASK):
		body.set_meta(META_MASK, body.collision_mask)


func _restore_runtime_original_collision(body: CollisionObject3D) -> void:
	if body == null or not is_instance_valid(body):
		return

	const META_LAYER: String = "destructible_runtime_original_collision_layer"
	const META_MASK: String = "destructible_runtime_original_collision_mask"
	if body.has_meta(META_LAYER):
		body.collision_layer = int(body.get_meta(META_LAYER))
	if body.has_meta(META_MASK):
		body.collision_mask = int(body.get_meta(META_MASK))


func _collect_runtime_multiplayer_nodes(root: Node, output: Array[Node]) -> void:
	if root == null:
		return

	if root is MultiplayerSynchronizer or root is MultiplayerSpawner:
		if not output.has(root):
			output.append(root)

	for child in root.get_children():
		_collect_runtime_multiplayer_nodes(child, output)


func _object_has_property(target: Object, property_name: String) -> bool:
	if target == null:
		return false

	for property_info: Dictionary in target.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return true

	return false


func _set_runtime_multiplayer_nodes_active(active: bool) -> void:
	for multiplayer_node: Node in _runtime_multiplayer_nodes:
		if multiplayer_node == null or not is_instance_valid(multiplayer_node):
			continue
		if _object_has_property(multiplayer_node, "public_visibility"):
			multiplayer_node.set("public_visibility", active)
		multiplayer_node.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func _apply_physics_enabled() -> void:
	if _intact_body == null:
		return

	_intact_body.freeze = not physics_enabled
	_intact_body.sleeping = not physics_enabled

	if not physics_enabled:
		_intact_body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC


func _get_intact_global_transform() -> Transform3D:
	if _intact_body != null:
		return _intact_body.global_transform
	return global_transform


func _get_debris_target_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene
	return get_parent()


func _get_physics_mask_with_enemy_rule(mask_value: int) -> int:
	if enemies_can_physically_interact:
		return mask_value

	var enemy_bit_mask := 1 << (enemy_collision_layer_bit - 1)
	return mask_value & ~enemy_bit_mask


func _should_ignore_damage_due_to_authority() -> bool:
	if not damage_only_on_multiplayer_authority:
		return false
	if not multiplayer.has_multiplayer_peer():
		return false
	return not is_multiplayer_authority()


func _random_unit_vector() -> Vector3:
	var value := Vector3(
		_rng.randf_range(-1.0, 1.0),
		_rng.randf_range(-0.25, 1.0),
		_rng.randf_range(-1.0, 1.0)
	)

	if value.length_squared() < 0.001:
		return Vector3.UP

	return value.normalized()
