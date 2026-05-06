extends Node
class_name UpgradeStationInteractor

@export var player_body_path: NodePath = NodePath("..")
@export var use_action: StringName = &"use"
@export var debug_prints: bool = true

var near_upgrade_station = null

@onready var player_body: Node = get_node_or_null(player_body_path)


func _ready() -> void:
	set_process_unhandled_input(true)
	_dbg("READY | player_body = " + str(player_body))


func _dbg(text: String) -> void:
	if debug_prints:
		print("[UPGRADE_INTERACTOR] ", text)



func set_near_upgrade_station(station) -> void:
	near_upgrade_station = station

func clear_near_upgrade_station(station) -> void:
	if near_upgrade_station == station:
		near_upgrade_station = null


func _unhandled_input(event: InputEvent) -> void:
	if not _is_local_player():
		return
	
	#if player_body != null and bool(player_body.get("ui_input_blocked")):
		#return
	
	if not event.is_action_pressed(use_action):
		return
	
	#_dbg("Input use détecté")
	#_dbg("near_upgrade_station = " + str(near_upgrade_station))
	
	if near_upgrade_station == null:
		return

	if not near_upgrade_station.can_local_player_try_use():
		_dbg("Station non utilisable actuellement")
		return

	_dbg("Tentative d'ouverture du menu d'upgrade")

	if multiplayer.is_server():
		near_upgrade_station.server_try_open_from_host()
	else:
		near_upgrade_station.request_open_menu.rpc_id(1)

	get_viewport().set_input_as_handled()


func _is_local_player() -> bool:
	if player_body == null:
		return false

	if player_body.has_method("is_multiplayer_authority"):
		return player_body.is_multiplayer_authority()

	return false
