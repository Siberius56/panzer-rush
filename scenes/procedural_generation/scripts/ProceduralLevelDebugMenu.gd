extends Control

@export var target_path: NodePath = ^"../.."
@export var start_visible: bool = true

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var status_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatusLabel
@onready var summary_text: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/DatabaseText
@onready var regenerate_button: Button = $PanelContainer/MarginContainer/VBoxContainer/Buttons/RegenerateButton
@onready var save_button: Button = $PanelContainer/MarginContainer/VBoxContainer/Buttons/SaveButton
@onready var load_button: Button = $PanelContainer/MarginContainer/VBoxContainer/Buttons/LoadButton
@onready var copy_button: Button = $PanelContainer/MarginContainer/VBoxContainer/Buttons/CopyButton
@onready var refresh_button: Button = $PanelContainer/MarginContainer/VBoxContainer/Buttons/RefreshButton
@onready var top_down_camera_button: Button = $PanelContainer/MarginContainer/VBoxContainer/Buttons/TopDownCameraButton
@onready var player_camera_button: Button = $PanelContainer/MarginContainer/VBoxContainer/Buttons/PlayerCameraButton
@onready var main_vbox: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer

var enemy_type_option: OptionButton = null
var spawn_enemy_button: Button = null
var trigger_horde_button: Button = null
var trigger_super_horde_button: Button = null

var target_node: Node = null
var last_plain_summary: String = ""
var previous_player_camera: Camera3D = null


func _ready() -> void:
	visible = start_visible
	target_node = _resolve_target()
	_disable_raw_database_prints()

	regenerate_button.pressed.connect(_on_regenerate_pressed)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	copy_button.pressed.connect(_on_copy_pressed)
	refresh_button.pressed.connect(_refresh_debug_summary)
	top_down_camera_button.pressed.connect(_on_top_down_camera_pressed)
	player_camera_button.pressed.connect(_on_player_camera_pressed)

	_setup_enemy_debug_controls()
	_refresh_debug_enemy_options()
	_refresh_debug_summary()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F9:
			visible = not visible
			if visible:
				_refresh_debug_summary()


func _on_regenerate_pressed() -> void:
	var target: Node = _resolve_target()
	if target == null:
		_set_status("Cible introuvable.")
		return

	_disable_raw_database_prints()

	if target.has_method("debug_regenerate_procedural_level"):
		target.call("debug_regenerate_procedural_level", 0)
		_set_status("Regénération demandée au NetworkMain.")
	elif target.has_method("generate_random"):
		target.call("generate_random", 0)
		_set_status("Regénération locale effectuée.")
	else:
		_set_status("La cible ne possède aucune méthode de génération.")

	call_deferred("_refresh_debug_summary")


func _on_save_pressed() -> void:
	var target: Node = _resolve_target()
	if target == null:
		_set_status("Cible introuvable.")
		return

	var saved: bool = false
	if target.has_method("debug_save_procedural_database"):
		saved = bool(target.call("debug_save_procedural_database"))
	elif target.has_method("save_current_database"):
		saved = bool(target.call("save_current_database"))

	_set_status("Database sauvegardée." if saved else "Sauvegarde impossible.")
	_refresh_debug_summary()


func _on_load_pressed() -> void:
	var target: Node = _resolve_target()
	if target == null:
		_set_status("Cible introuvable.")
		return

	var loaded: bool = false
	if target.has_method("debug_load_procedural_database"):
		loaded = bool(target.call("debug_load_procedural_database"))
	elif target.has_method("generate_from_json_file"):
		loaded = target.call("generate_from_json_file", "") != null

	_set_status("Database rechargée." if loaded else "Chargement impossible.")
	call_deferred("_refresh_debug_summary")


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(last_plain_summary)
	_set_status("Résumé copié dans le presse-papiers.")


func _on_top_down_camera_pressed() -> void:
	var camera: Camera3D = _find_top_down_debug_camera()
	if camera == null:
		_set_status("Camera_TopDown_Debug introuvable.")
		return

	var current_camera: Camera3D = get_viewport().get_camera_3d()
	if current_camera != null and current_camera != camera:
		previous_player_camera = current_camera

	camera.make_current()
	_set_status("Camera_TopDown_Debug est maintenant la caméra current.")


func _on_player_camera_pressed() -> void:
	var camera: Camera3D = _find_player_camera()
	if camera == null:
		_set_status("Caméra joueur introuvable.")
		return

	camera.make_current()
	_set_status("Caméra joueur restaurée.")


func _setup_enemy_debug_controls() -> void:
	if main_vbox == null:
		return

	var row: HBoxContainer = main_vbox.get_node_or_null("EnemyDebugRow") as HBoxContainer
	if row == null:
		row = HBoxContainer.new()
		row.name = "EnemyDebugRow"
		main_vbox.add_child(row)
		main_vbox.move_child(row, 3)

	var label: Label = row.get_node_or_null("EnemyDebugLabel") as Label
	if label == null:
		label = Label.new()
		label.name = "EnemyDebugLabel"
		row.add_child(label)
	label.text = "Enemy debug"

	enemy_type_option = row.get_node_or_null("EnemyTypeOption") as OptionButton
	if enemy_type_option == null:
		enemy_type_option = OptionButton.new()
		enemy_type_option.name = "EnemyTypeOption"
		row.add_child(enemy_type_option)
	enemy_type_option.custom_minimum_size = Vector2(150.0, 0.0)

	spawn_enemy_button = row.get_node_or_null("SpawnEnemyButton") as Button
	if spawn_enemy_button == null:
		spawn_enemy_button = Button.new()
		spawn_enemy_button.name = "SpawnEnemyButton"
		row.add_child(spawn_enemy_button)
	spawn_enemy_button.text = "Spawn enemy"

	trigger_horde_button = row.get_node_or_null("TriggerHordeButton") as Button
	if trigger_horde_button == null:
		trigger_horde_button = Button.new()
		trigger_horde_button.name = "TriggerHordeButton"
		row.add_child(trigger_horde_button)
	trigger_horde_button.text = "Start horde"

	trigger_super_horde_button = row.get_node_or_null("TriggerSuperHordeButton") as Button
	if trigger_super_horde_button == null:
		trigger_super_horde_button = Button.new()
		trigger_super_horde_button.name = "TriggerSuperHordeButton"
		row.add_child(trigger_super_horde_button)
	trigger_super_horde_button.text = "Start super horde"

	var spawn_callable: Callable = Callable(self, "_on_spawn_enemy_pressed")
	if not spawn_enemy_button.pressed.is_connected(spawn_callable):
		spawn_enemy_button.pressed.connect(spawn_callable)

	var horde_callable: Callable = Callable(self, "_on_trigger_horde_pressed")
	if not trigger_horde_button.pressed.is_connected(horde_callable):
		trigger_horde_button.pressed.connect(horde_callable)

	var super_horde_callable: Callable = Callable(self, "_on_trigger_super_horde_pressed")
	if not trigger_super_horde_button.pressed.is_connected(super_horde_callable):
		trigger_super_horde_button.pressed.connect(super_horde_callable)


func _refresh_debug_enemy_options() -> void:
	if enemy_type_option == null:
		return

	enemy_type_option.clear()

	var options_added: int = 0
	var director: Node = _find_horde_director()
	if director != null and director.has_method("get_debug_enemy_spawn_options"):
		var raw_options: Variant = director.call("get_debug_enemy_spawn_options")
		if raw_options is Array:
			for option_value: Variant in raw_options:
				if option_value is Dictionary:
					var option_dictionary: Dictionary = option_value as Dictionary
					var option_id: String = String(option_dictionary.get("id", "random"))
					var option_label: String = String(option_dictionary.get("label", option_id))
					enemy_type_option.add_item(option_label)
					enemy_type_option.set_item_metadata(options_added, option_id)
					options_added += 1

	if options_added <= 0:
		_add_fallback_enemy_option("Aléatoire", "random")
		_add_fallback_enemy_option("Tonfa", "tonfa")
		_add_fallback_enemy_option("Bouclier", "shield")
		_add_fallback_enemy_option("Fusil", "rifleman")
		_add_fallback_enemy_option("Anti-tank", "anti_tank")
		_add_fallback_enemy_option("Hammer", "hammer")

	enemy_type_option.select(0)


func _add_fallback_enemy_option(label: String, option_id: String) -> void:
	var index: int = enemy_type_option.get_item_count()
	enemy_type_option.add_item(label)
	enemy_type_option.set_item_metadata(index, option_id)


func _on_spawn_enemy_pressed() -> void:
	var director: Node = _find_horde_director()
	if director == null:
		_set_status("HordeDirector introuvable.")
		return

	if not director.has_method("debug_spawn_enemy_near_player"):
		_set_status("Le HordeDirector ne possède pas debug_spawn_enemy_near_player().")
		return

	var enemy_type: String = _get_selected_enemy_type()
	var spawned_value: Variant = director.call("debug_spawn_enemy_near_player", enemy_type)
	if spawned_value is Node:
		_set_status("Spawn debug : %s." % enemy_type)
	else:
		_set_status("Spawn debug impossible : %s." % enemy_type)

	call_deferred("_refresh_debug_summary")


func _on_trigger_horde_pressed() -> void:
	var director: Node = _find_horde_director()
	if director == null:
		_set_status("HordeDirector introuvable.")
		return

	var accepted: bool = false
	if director.has_method("debug_trigger_attack_wave_now"):
		accepted = bool(director.call("debug_trigger_attack_wave_now"))
	elif director.has_method("force_horde_now"):
		director.call("force_horde_now")
		accepted = true

	_set_status("Horde debug lancée." if accepted else "Horde debug refusée.")
	call_deferred("_refresh_debug_summary")


func _on_trigger_super_horde_pressed() -> void:
	var director: Node = _find_horde_director()
	if director == null:
		_set_status("HordeDirector introuvable.")
		return

	var accepted: bool = false
	if director.has_method("debug_trigger_super_horde_now"):
		accepted = bool(director.call("debug_trigger_super_horde_now"))
	elif director.has_method("force_super_horde_now"):
		director.call("force_super_horde_now")
		accepted = true

	_set_status("Super horde debug lancée." if accepted else "Super horde debug refusée.")
	call_deferred("_refresh_debug_summary")


func _get_selected_enemy_type() -> String:
	if enemy_type_option == null or enemy_type_option.get_item_count() <= 0:
		return "random"

	var selected_index: int = enemy_type_option.selected
	if selected_index < 0:
		return "random"

	var metadata: Variant = enemy_type_option.get_item_metadata(selected_index)
	if metadata == null:
		return "random"

	return String(metadata)


func _find_horde_director() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null

	var directors: Array[Node] = tree.get_nodes_in_group("horde_director")
	if not directors.is_empty():
		return directors[0]

	var target: Node = _resolve_target()
	if target != null:
		var local_director: Node = target.find_child("*HordeDirector*", true, false)
		if local_director != null:
			return local_director

	var current_scene: Node = tree.current_scene
	if current_scene != null:
		var scene_director: Node = current_scene.find_child("*HordeDirector*", true, false)
		if scene_director != null:
			return scene_director

	return null


func _find_top_down_debug_camera() -> Camera3D:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null

	var target: Node = _resolve_target()
	if target != null:
		var local_camera: Camera3D = target.get_node_or_null("Camera_TopDown_Debug") as Camera3D
		if local_camera != null:
			return local_camera

	var current_scene: Node = tree.current_scene
	if current_scene != null:
		var scene_camera: Camera3D = current_scene.get_node_or_null("Camera_TopDown_Debug") as Camera3D
		if scene_camera != null:
			return scene_camera

	var cameras: Array[Node] = tree.get_nodes_in_group("top_down_debug_camera")
	for item: Node in cameras:
		if item is Camera3D:
			return item as Camera3D

	return null


func _find_player_camera() -> Camera3D:
	if previous_player_camera != null and is_instance_valid(previous_player_camera):
		return previous_player_camera

	var tree: SceneTree = get_tree()
	if tree == null:
		return null

	var players: Array[Node] = tree.get_nodes_in_group("players")
	for player: Node in players:
		if not is_instance_valid(player):
			continue
		if player.has_method("is_multiplayer_authority") and bool(player.call("is_multiplayer_authority")):
			var authority_camera: Camera3D = _find_camera_inside_player(player)
			if authority_camera != null:
				return authority_camera

	for player: Node in players:
		if not is_instance_valid(player):
			continue
		var camera: Camera3D = _find_camera_inside_player(player)
		if camera != null:
			return camera

	return null


func _find_camera_inside_player(player: Node) -> Camera3D:
	if player == null:
		return null

	var direct_camera: Camera3D = player.get_node_or_null("CameraRig/SpringArm3D/Camera3D") as Camera3D
	if direct_camera != null:
		return direct_camera

	direct_camera = player.get_node_or_null("CameraRig/Camera3D") as Camera3D
	if direct_camera != null:
		return direct_camera

	direct_camera = player.get_node_or_null("Camera3D") as Camera3D
	if direct_camera != null:
		return direct_camera

	return _find_first_camera_recursive(player)


func _find_first_camera_recursive(root: Node) -> Camera3D:
	if root == null:
		return null

	for child: Node in root.get_children():
		if child is Camera3D:
			return child as Camera3D
		var nested_camera: Camera3D = _find_first_camera_recursive(child)
		if nested_camera != null:
			return nested_camera

	return null


func _refresh_debug_summary() -> void:
	_refresh_debug_enemy_options()

	var target: Node = _resolve_target()
	if target == null:
		summary_text.text = "[color=#aaaaaa]Aucune cible.[/color]"
		last_plain_summary = "Aucune cible."
		_set_status("Aucune cible.")
		return

	_disable_raw_database_prints()

	var database: Dictionary = _get_database_dictionary(target)
	if database.is_empty():
		summary_text.text = "[color=#aaaaaa]Aucune génération lisible.[/color]"
		last_plain_summary = "Aucune génération lisible."
		_set_status("Aucune génération lisible.")
		return

	var built: Dictionary = _build_generation_summary(database)
	summary_text.text = String(built.get("bbcode", ""))
	last_plain_summary = String(built.get("plain", ""))
	_set_status("Résumé de génération affiché. F9 masque ou affiche ce menu.")


func _get_database_dictionary(target: Node) -> Dictionary:
	if target == null:
		return {}

	var data_value: Variant = null
	if target.has_method("debug_get_procedural_database_dictionary"):
		data_value = target.call("debug_get_procedural_database_dictionary")
	elif target.has_method("get_database_dictionary"):
		data_value = target.call("get_database_dictionary")

	if data_value is Dictionary:
		return (data_value as Dictionary).duplicate(true)

	var text: String = ""
	if target.has_method("debug_get_procedural_database_text"):
		text = String(target.call("debug_get_procedural_database_text"))
	elif target.has_method("get_database_text"):
		text = String(target.call("get_database_text"))

	if text.strip_edges().is_empty():
		return {}

	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return (parsed as Dictionary).duplicate(true)

	return {}


func _build_generation_summary(database: Dictionary) -> Dictionary:
	var blocks: Array = _read_array(database, ["blocks", "block_records"])
	var pois: Array = _read_array(database, ["pois", "poi_records"])
	var secondary_pois: Array = _read_array(database, ["secondary_pois", "secondary_poi_records"])

	blocks.sort_custom(_sort_records_by_slot)

	var bbcode_lines: Array[String] = []
	var plain_lines: Array[String] = []

	#var seed_text: String = String(database.get("generation_seed", ""))
	#var layout_text: String = String(database.get("layout_id", ""))
	#if not seed_text.is_empty() or not layout_text.is_empty():
		#var header: String = "Seed: %s    Layout: %s" % [seed_text, layout_text]
		#bbcode_lines.append("[color=#aaaaaa]%s[/color]" % header)
		#plain_lines.append(header)
		#bbcode_lines.append("")
		#plain_lines.append("")

	if blocks.is_empty():
		bbcode_lines.append("[color=#aaaaaa]Aucun block dans la database.[/color]")
		plain_lines.append("Aucun block dans la database.")
		return {"bbcode": "\n".join(bbcode_lines), "plain": "\n".join(plain_lines)}

	var block_display_index: int = 1
	for block_value: Variant in blocks:
		if not (block_value is Dictionary):
			continue

		var block_record: Dictionary = block_value as Dictionary
		var slot_index: int = _record_slot(block_record, block_display_index - 1)
		var block_name: String = _record_name(block_record, ["block_id", "block_name", "name", "block_type"], "Block_%d" % block_display_index)

		bbcode_lines.append("[color=#ff9f1a]Block %d: %s[/color]" % [block_display_index, _escape_bbcode(block_name)])
		plain_lines.append("Block %d: %s" % [block_display_index, block_name])

		var poi_names: Array[String] = _names_for_slot(pois, slot_index, ["poi_id", "poi_name", "name", "poi_type"])
		if poi_names.is_empty():
			bbcode_lines.append("  [color=#5aa7ff]POI: Aucun[/color]")
			plain_lines.append("  POI: Aucun")
		else:
			for poi_name: String in poi_names:
				bbcode_lines.append("  [color=#5aa7ff]POI: %s[/color]" % _escape_bbcode(poi_name))
				plain_lines.append("  POI: %s" % poi_name)

		var secondary_records: Array[Dictionary] = _records_for_slot(secondary_pois, slot_index)
		if secondary_records.is_empty():
			bbcode_lines.append("  [color=#52d273]POI secondaires: Aucun[/color]")
			plain_lines.append("  POI secondaires: Aucun")
		else:
			bbcode_lines.append("  [color=#52d273]POI secondaires:[/color]")
			plain_lines.append("  POI secondaires:")
			for secondary_record: Dictionary in secondary_records:
				var secondary_name: String = _record_name(secondary_record, ["secondary_poi_id", "poi_id", "poi_name", "name", "poi_type"], "POI_Secondary")
				var socket_name: String = _record_name(secondary_record, ["socket_name", "socket", "socket_path"], "")
				if socket_name.is_empty():
					bbcode_lines.append("    [color=#52d273]- %s[/color]" % _escape_bbcode(secondary_name))
					plain_lines.append("    - %s" % secondary_name)
				else:
					bbcode_lines.append("    [color=#52d273]- %s[/color] [color=#888888](%s)[/color]" % [_escape_bbcode(secondary_name), _escape_bbcode(socket_name)])
					plain_lines.append("    - %s (%s)" % [secondary_name, socket_name])

		bbcode_lines.append("")
		plain_lines.append("")
		block_display_index += 1

	return {
		"bbcode": "\n".join(bbcode_lines),
		"plain": "\n".join(plain_lines),
	}


func _read_array(source: Dictionary, keys: Array[String]) -> Array:
	for key: String in keys:
		var value: Variant = source.get(key, [])
		if value is Array:
			return value as Array
	return []


func _sort_records_by_slot(a: Variant, b: Variant) -> bool:
	var a_slot: int = 0
	var b_slot: int = 0
	if a is Dictionary:
		a_slot = _record_slot(a as Dictionary, 0)
	if b is Dictionary:
		b_slot = _record_slot(b as Dictionary, 0)
	return a_slot < b_slot


func _record_slot(record: Dictionary, fallback: int = 0) -> int:
	if record.has("slot_index"):
		return int(record.get("slot_index"))
	if record.has("block_slot"):
		return int(record.get("block_slot"))
	if record.has("block_index"):
		return int(record.get("block_index"))
	return fallback


func _records_for_slot(records: Array, slot_index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in records:
		if not (value is Dictionary):
			continue
		var record: Dictionary = value as Dictionary
		if _record_slot(record, -999999) == slot_index:
			result.append(record)
	return result


func _names_for_slot(records: Array, slot_index: int, keys: Array[String]) -> Array[String]:
	var result: Array[String] = []
	var filtered: Array[Dictionary] = _records_for_slot(records, slot_index)
	for record: Dictionary in filtered:
		result.append(_record_name(record, keys, "Inconnu"))
	return result


func _record_name(record: Dictionary, keys: Array[String], fallback: String) -> String:
	for key: String in keys:
		if record.has(key):
			var value: String = String(record.get(key, "")).strip_edges()
			if not value.is_empty():
				return value

	var scene_path: String = String(record.get("scene_path", "")).strip_edges()
	if not scene_path.is_empty():
		var file_name: String = scene_path.get_file()
		if file_name.ends_with(".tscn"):
			file_name = file_name.trim_suffix(".tscn")
		if not file_name.is_empty():
			return file_name

	return fallback


func _escape_bbcode(value: String) -> String:
	return value.replace("[", "［").replace("]", "］")


func _resolve_target() -> Node:
	if target_node != null and is_instance_valid(target_node):
		return target_node

	if not target_path.is_empty():
		target_node = get_node_or_null(target_path)
		if target_node != null:
			return target_node

	var tree: SceneTree = get_tree()
	if tree == null:
		return null

	var network_nodes: Array[Node] = tree.get_nodes_in_group("network_main")
	if not network_nodes.is_empty():
		target_node = network_nodes[0]
		return target_node

	var generators: Array[Node] = tree.get_nodes_in_group("procedural_level_generator")
	if not generators.is_empty():
		target_node = generators[0]
		return target_node

	return null


func _disable_raw_database_prints() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return

	var target: Node = _resolve_target()
	if target != null:
		_set_bool_property_if_present(target, "debug_print_database", false)

	var generators: Array[Node] = tree.get_nodes_in_group("procedural_level_generator")
	for generator: Node in generators:
		_set_bool_property_if_present(generator, "debug_print_database", false)


func _set_bool_property_if_present(target: Object, property_name: String, value: bool) -> void:
	if target == null:
		return

	for property_info: Dictionary in target.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			target.set(property_name, value)
			return


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text
