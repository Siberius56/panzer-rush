extends Node3D

# BombRadarObjective.gd
# Fichier complet à remplacer.
# Godot 4.x / 4.6
#
# Rôle :
# - S'enregistre comme provider d'objectif.
# - Affiche l'objectif dans les HUD des joueurs.
# - Termine l'objectif quand complete_objective() est appelé.
# - Résiste à la régénération procédurale, même si le node est supprimé pendant un call_deferred.

signal objective_registered(objective_id: String, objective_text: String)
signal objective_completed(objective_id: String)
signal objective_removed(objective_id: String)

@export_group("Objective")
@export var objective_id: String = ""
@export var objective_text: String = "Destroy the radar"
@export var completed_text: String = "Radar destroyed"
@export var register_on_ready: bool = true
@export var remove_from_hud_on_exit: bool = true

@export_group("Optional Target")
@export var target_node_path: NodePath
@export var auto_complete_when_target_exits_tree: bool = false

var is_destroyed: bool = false
var _is_registered: bool = false
var _target_node: Node = null


func _ready() -> void:
	add_to_group("objective_providers")

	_connect_optional_target()

	if register_on_ready:
		call_deferred("_deferred_register_objective")


func _exit_tree() -> void:
	# Quand la map est régénérée, le POI et ses objectifs peuvent disparaître.
	# On tente de retirer proprement l'objectif du HUD, sans crasher si l'arbre n'existe déjà plus.
	if remove_from_hud_on_exit and _is_registered and not is_destroyed:
		_safe_call_player_huds("unregister_objective", [get_objective_id()])
		objective_removed.emit(get_objective_id())

	_is_registered = false
	_target_node = null


func get_objective_id() -> String:
	if not objective_id.strip_edges().is_empty():
		return objective_id.strip_edges()

	# ID stable par défaut, assez lisible dans le debug.
	# Le chemin peut changer après génération, donc on inclut aussi le nom.
	var path_text: String = ""
	if is_inside_tree():
		path_text = str(get_path())
	else:
		path_text = name

	return "%s_%d" % [name, path_text.hash()]


func get_objective_text() -> String:
	return objective_text


func is_objective_completed() -> bool:
	return is_destroyed


func register_objective_now() -> void:
	_deferred_register_objective()


func complete_objective() -> void:
	if is_destroyed:
		return

	is_destroyed = true
	objective_completed.emit(get_objective_id())

	_safe_call_player_huds("complete_objective", [get_objective_id(), completed_text])
	_safe_call_player_huds("set_objective_completed", [get_objective_id(), true])
	_safe_call_player_huds("update_objective_status", [get_objective_id(), true])


func fail_or_remove_objective() -> void:
	# Utile si un objectif devient invalide sans être complété.
	if not _is_registered:
		return

	_safe_call_player_huds("unregister_objective", [get_objective_id()])
	objective_removed.emit(get_objective_id())
	_is_registered = false


func reset_objective() -> void:
	is_destroyed = false
	_is_registered = false
	_deferred_register_objective()


# Aliases pratiques, pour éviter de casser si une scène appelle déjà un ancien nom.
func notify_destroyed() -> void:
	complete_objective()


func mark_completed() -> void:
	complete_objective()


func set_completed(value: bool = true) -> void:
	if value:
		complete_objective()
	else:
		is_destroyed = false
		_safe_call_player_huds("set_objective_completed", [get_objective_id(), false])
		_safe_call_player_huds("update_objective_status", [get_objective_id(), false])


func _deferred_register_objective() -> void:
	# Sécurité essentielle.
	# Si la map est régénérée avant l'exécution du call_deferred, le node n'est plus dans l'arbre.
	if not is_inside_tree():
		return

	var tree: SceneTree = get_tree()
	if tree == null:
		return

	var id: String = get_objective_id()
	if id.strip_edges().is_empty():
		return

	_is_registered = true
	objective_registered.emit(id, objective_text)

	_safe_call_player_huds("register_objective", [id, objective_text, is_destroyed])
	_safe_call_player_huds("set_objective_completed", [id, is_destroyed])
	_safe_call_player_huds("update_objective_status", [id, is_destroyed])


func _connect_optional_target() -> void:
	if target_node_path.is_empty():
		return

	_target_node = get_node_or_null(target_node_path)
	if _target_node == null:
		return

	# Support de plusieurs noms de signaux possibles selon tes objets.
	_try_connect_signal(_target_node, "objective_completed", Callable(self, "complete_objective"))
	_try_connect_signal(_target_node, "destroyed", Callable(self, "complete_objective"))
	_try_connect_signal(_target_node, "died", Callable(self, "complete_objective"))
	_try_connect_signal(_target_node, "tree_exiting", Callable(self, "_on_target_tree_exiting"))


func _on_target_tree_exiting() -> void:
	if auto_complete_when_target_exits_tree:
		complete_objective()
	else:
		fail_or_remove_objective()


func _try_connect_signal(source: Object, signal_name: String, target_callable: Callable) -> void:
	if source == null:
		return
	if not source.has_signal(signal_name):
		return
	if source.is_connected(signal_name, target_callable):
		return

	source.connect(signal_name, target_callable)


func _safe_call_player_huds(method_name: String, args: Array = []) -> void:
	if not is_inside_tree():
		return

	var tree: SceneTree = get_tree()
	if tree == null:
		return

	for hud_node: Node in tree.get_nodes_in_group("player_huds"):
		if hud_node == null:
			continue
		if not is_instance_valid(hud_node):
			continue
		if not hud_node.has_method(method_name):
			continue

		hud_node.callv(method_name, args)
