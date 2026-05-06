extends Control

@onready var hp_label: Label = $HPLabel
@onready var enemy_label: Label = $EnemyLabel
@onready var game_over_label: Label = $GameOverLabel

var player: Node = null
var max_health: int = 0


func _ready() -> void:
	game_over_label.visible = false


func _process(_delta: float) -> void:
	enemy_label.text = "Ennemis: %d" % get_tree().get_nodes_in_group("enemies").size()


func set_player(value: Node) -> void:
	player = value
	if player != null:
		player.health_changed.connect(_on_player_health_changed)
		_on_player_health_changed(player.health, player.max_health)


func show_game_over() -> void:
	game_over_label.visible = true


func _on_player_health_changed(current: int, maximum: int) -> void:
	hp_label.text = "HP: %d / %d" % [current, maximum]
