extends Resource

# Ressource légère qui représente une génération de niveau.
# Elle peut être transformée en Dictionary pour les RPC et en JSON pour la sauvegarde.

@export var generation_seed: int = 0
@export var generated_at_unix: int = 0
@export var layout_id: String = "line_3"
@export var block_size: float = 150.0
@export var block_records: Array[Dictionary] = []
@export var poi_records: Array[Dictionary] = []
@export var secondary_poi_records: Array[Dictionary] = []
@export var spawn_record: Dictionary = {}
@export var connection_records: Array[Dictionary] = []
@export var connection_errors: Array[Dictionary] = []


func clear() -> void:
	generation_seed = 0
	generated_at_unix = 0
	layout_id = "line_3"
	block_size = 150.0
	block_records.clear()
	poi_records.clear()
	secondary_poi_records.clear()
	spawn_record.clear()
	connection_records.clear()
	connection_errors.clear()


func to_dictionary() -> Dictionary:
	return {
		"generation_seed": generation_seed,
		"generated_at_unix": generated_at_unix,
		"layout_id": layout_id,
		"block_size": block_size,
		"blocks": block_records.duplicate(true),
		"pois": poi_records.duplicate(true),
		"secondary_pois": secondary_poi_records.duplicate(true),
		"spawn": spawn_record.duplicate(true),
		"connections": connection_records.duplicate(true),
		"connection_errors": connection_errors.duplicate(true),
	}


func from_dictionary(data: Dictionary) -> void:
	clear()
	generation_seed = int(data.get("generation_seed", 0))
	generated_at_unix = int(data.get("generated_at_unix", 0))
	layout_id = String(data.get("layout_id", "line_3"))
	block_size = float(data.get("block_size", 150.0))

	var blocks_value: Variant = data.get("blocks", [])
	if blocks_value is Array:
		for item: Variant in blocks_value:
			if item is Dictionary:
				block_records.append((item as Dictionary).duplicate(true))

	var pois_value: Variant = data.get("pois", [])
	if pois_value is Array:
		for item: Variant in pois_value:
			if item is Dictionary:
				poi_records.append((item as Dictionary).duplicate(true))

	var secondary_pois_value: Variant = data.get("secondary_pois", [])
	if secondary_pois_value is Array:
		for item: Variant in secondary_pois_value:
			if item is Dictionary:
				secondary_poi_records.append((item as Dictionary).duplicate(true))

	var spawn_value: Variant = data.get("spawn", {})
	if spawn_value is Dictionary:
		spawn_record = (spawn_value as Dictionary).duplicate(true)

	var connections_value: Variant = data.get("connections", [])
	if connections_value is Array:
		for item: Variant in connections_value:
			if item is Dictionary:
				connection_records.append((item as Dictionary).duplicate(true))

	var errors_value: Variant = data.get("connection_errors", [])
	if errors_value is Array:
		for item: Variant in errors_value:
			if item is Dictionary:
				connection_errors.append((item as Dictionary).duplicate(true))


func to_json_text() -> String:
	return JSON.stringify(to_dictionary(), "\t")


func save_to_json(path: String) -> bool:
	if path.is_empty():
		push_warning("[LevelGenerationDatabase] Chemin de sauvegarde vide.")
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("[LevelGenerationDatabase] Impossible d'écrire : %s" % path)
		return false

	file.store_string(to_json_text())
	file.close()
	return true


static func load_dictionary_from_json(path: String) -> Dictionary:
	if path.is_empty():
		return {}
	if not FileAccess.file_exists(path):
		push_warning("[LevelGenerationDatabase] Fichier introuvable : %s" % path)
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[LevelGenerationDatabase] Impossible de lire : %s" % path)
		return {}

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("[LevelGenerationDatabase] JSON invalide : %s" % path)
		return {}

	return (parsed as Dictionary).duplicate(true)
