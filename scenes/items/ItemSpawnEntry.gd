extends Resource
class_name ItemSpawnEntry

@export var item_id: String = ""
@export var scene: PackedScene
@export_range(1, 100, 1) var weight: int = 1
@export var tags: Array[String] = []
