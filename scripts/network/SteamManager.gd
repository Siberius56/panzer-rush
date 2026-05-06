extends Node

signal steam_ready
signal steam_failed(message: String)

var is_ready := false
var steam_id: int = 0
var steam_name := ""

func _ready() -> void:
	print("[STEAM] Init...")

	var result = Steam.steamInit()

	if result:
		is_ready = true
		steam_id = Steam.getSteamID()
		steam_name = Steam.getPersonaName()

		print("[STEAM] Ready")
		print("[STEAM] ID: ", steam_id)
		print("[STEAM] Name: ", steam_name)

		steam_ready.emit()
	else:
		is_ready = false
		print("[STEAM] Init failed")
		steam_failed.emit("Steam n'a pas pu être initialisé.")


func _process(_delta: float) -> void:
	if is_ready:
		Steam.run_callbacks()
