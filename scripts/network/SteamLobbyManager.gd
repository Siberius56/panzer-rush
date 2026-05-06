extends Node

signal lobby_created_success(lobby_id: int)
signal lobby_joined_success(lobby_id: int)
signal lobby_failed(message: String)
signal lobby_members_changed

const MAX_PLAYERS := 4

var current_lobby_id: int = 0
var lobby_owner_id: int = 0
var lobby_members: Array[int] = []

func _ready() -> void:
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)


func create_lobby() -> void:
	if not SteamManager.is_ready:
		lobby_failed.emit("Steam n'est pas prêt.")
		return

	print("[STEAM_LOBBY] Create lobby")
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, MAX_PLAYERS)


func join_lobby(lobby_id: int) -> void:
	if not SteamManager.is_ready:
		lobby_failed.emit("Steam n'est pas prêt.")
		return

	print("[STEAM_LOBBY] Join lobby: ", lobby_id)
	Steam.joinLobby(lobby_id)


func leave_lobby() -> void:
	if current_lobby_id == 0:
		return

	print("[STEAM_LOBBY] Leave lobby: ", current_lobby_id)

	Steam.leaveLobby(current_lobby_id)

	current_lobby_id = 0
	lobby_owner_id = 0
	lobby_members.clear()

	lobby_members_changed.emit()


func invite_friends() -> void:
	if current_lobby_id == 0:
		lobby_failed.emit("Aucun lobby Steam actif.")
		return

	Steam.activateGameOverlayInviteDialog(current_lobby_id)


func refresh_members() -> void:
	lobby_members.clear()

	if current_lobby_id == 0:
		lobby_members_changed.emit()
		return

	var count := Steam.getNumLobbyMembers(current_lobby_id)

	for i in range(count):
		var member_id := Steam.getLobbyMemberByIndex(current_lobby_id, i)
		lobby_members.append(member_id)

	lobby_owner_id = Steam.getLobbyOwner(current_lobby_id)

	print("[STEAM_LOBBY] Owner: ", lobby_owner_id)
	print("[STEAM_LOBBY] Members: ", lobby_members)

	lobby_members_changed.emit()


func get_member_name(steam_id: int) -> String:
	return Steam.getFriendPersonaName(steam_id)


func is_lobby_owner() -> bool:
	return current_lobby_id != 0 and SteamManager.steam_id == lobby_owner_id


func _on_lobby_created(connect_result: int, lobby_id: int) -> void:
	print("[STEAM_LOBBY] lobby_created result=", connect_result, " lobby=", lobby_id)

	if connect_result != 1:
		lobby_failed.emit("Création du lobby échouée. Code: %s" % connect_result)
		return

	current_lobby_id = lobby_id

	Steam.setLobbyData(current_lobby_id, "name", "%s's Lobby" % SteamManager.steam_name)
	Steam.setLobbyData(current_lobby_id, "status", "waiting")
	Steam.setLobbyData(current_lobby_id, "host_steam_id", str(SteamManager.steam_id))
	Steam.setLobbyJoinable(current_lobby_id, true)

	refresh_members()
	lobby_created_success.emit(current_lobby_id)


func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	print("[STEAM_LOBBY] lobby_joined lobby=", lobby_id, " response=", response)

	if response != 1:
		lobby_failed.emit("Impossible de rejoindre le lobby. Code: %s" % response)
		return

	current_lobby_id = lobby_id

	refresh_members()
	lobby_joined_success.emit(current_lobby_id)


func _on_lobby_chat_update(lobby_id: int, _changed_id: int, _making_change_id: int, _chat_state: int) -> void:
	if lobby_id != current_lobby_id:
		return

	print("[STEAM_LOBBY] lobby_chat_update")
	refresh_members()
