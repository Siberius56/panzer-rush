extends Control

const LOBBY_SCENE_PATH := "res://scenes/lobby/Lobby.tscn"
const DEFAULT_PORT := 7000
const JOIN_TIMEOUT_SECONDS := 5.0
const DEBUG_PREFIX := "[MAIN_MENU_NET]"

@onready var player_name_edit: LineEdit = %NameEdit
@onready var ip_edit: LineEdit = %IpEdit
@onready var port_edit: LineEdit = %PortEdit
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var status_label: Label = %StatusLabel
@onready var wifi_ip_label: Label = %IpLocal_Wifi
@onready var ethernet_ip_label: Label = %IpLocal_Ethernet

@onready var host_steam_button: Button = %Host_Steam_Lobby
@onready var invite_friend_button: Button = %Invite_Friend
@onready var join_lobby_id_edit: LineEdit = %Join_Lobby_LineEdit #%Join_Lobby_Id
@onready var join_lobby_id_button: Button = %Join_Lobby #%Join_Lobby_Id_Button

var join_attempt_id := 0
var debug_history: PackedStringArray = []


func _ready() -> void:
	#print("Steam exists: ", ClassDB.class_exists("Steam"))
	#print("SteamMultiplayerPeer exists: ", ClassDB.class_exists("SteamMultiplayerPeer"))
#
	#if ClassDB.class_exists("SteamMultiplayerPeer"):
		#var peer := SteamMultiplayerPeer.new()
		#print("Peer: ", peer)
		#print("has create_host: ", peer.has_method("create_host"))
		#print("has create_client: ", peer.has_method("create_client"))
	
	
	if not host_steam_button.pressed.is_connected(_on_host_steam_button_pressed):
		host_steam_button.pressed.connect(_on_host_steam_button_pressed)

	if not invite_friend_button.pressed.is_connected(_on_invite_friend_button_pressed):
		invite_friend_button.pressed.connect(_on_invite_friend_button_pressed)

	if not SteamLobbyManager.lobby_created_success.is_connected(_on_steam_lobby_created):
		SteamLobbyManager.lobby_created_success.connect(_on_steam_lobby_created)

	if not SteamLobbyManager.lobby_joined_success.is_connected(_on_steam_lobby_joined):
		SteamLobbyManager.lobby_joined_success.connect(_on_steam_lobby_joined)

	if not SteamLobbyManager.lobby_failed.is_connected(_on_steam_lobby_failed):
		SteamLobbyManager.lobby_failed.connect(_on_steam_lobby_failed)

	if not SteamLobbyManager.lobby_members_changed.is_connected(_on_steam_lobby_members_changed):
		SteamLobbyManager.lobby_members_changed.connect(_on_steam_lobby_members_changed)
	
	if not join_lobby_id_button.pressed.is_connected(_on_join_lobby_id_button_pressed):
		join_lobby_id_button.pressed.connect(_on_join_lobby_id_button_pressed)
	
	_connect_network_signals()

	var id := int(Time.get_unix_time_from_system()) % 1000
	player_name_edit.text = "Player_%s" % id
	ip_edit.text = "127.0.0.1"
	port_edit.text = str(NetworkManager.current_port if int(NetworkManager.current_port) > 0 else DEFAULT_PORT)

	_set_buttons_enabled(true)
	update_ip_labels()

	status_label.text = NetworkManager.last_message

	debug_log("Menu ready. OS=%s" % OS.get_name())
	debug_log("Default port field=%s" % port_edit.text)
	debug_log("NetworkManager last_message=%s" % str(NetworkManager.last_message))
	print_network_diagnostics()


func _exit_tree() -> void:
	debug_log("Menu exit_tree. Disconnecting network signals.")
	_disconnect_network_signals()


func _connect_network_signals() -> void:
	if NetworkManager.has_signal("connection_succeeded"):
		var callable := Callable(self, "_on_connection_succeeded")
		if not NetworkManager.is_connected("connection_succeeded", callable):
			NetworkManager.connect("connection_succeeded", callable)
			debug_log("Signal connected: connection_succeeded")

	if NetworkManager.has_signal("connection_failed"):
		var callable := Callable(self, "_on_connection_failed")
		if not NetworkManager.is_connected("connection_failed", callable):
			NetworkManager.connect("connection_failed", callable)
			debug_log("Signal connected: connection_failed")

	if NetworkManager.has_signal("connection_closed"):
		var callable := Callable(self, "_on_connection_closed")
		if not NetworkManager.is_connected("connection_closed", callable):
			NetworkManager.connect("connection_closed", callable)
			debug_log("Signal connected: connection_closed")


func _disconnect_network_signals() -> void:
	if not is_instance_valid(NetworkManager):
		return

	if NetworkManager.has_signal("connection_succeeded"):
		var callable := Callable(self, "_on_connection_succeeded")
		if NetworkManager.is_connected("connection_succeeded", callable):
			NetworkManager.disconnect("connection_succeeded", callable)

	if NetworkManager.has_signal("connection_failed"):
		var callable := Callable(self, "_on_connection_failed")
		if NetworkManager.is_connected("connection_failed", callable):
			NetworkManager.disconnect("connection_failed", callable)

	if NetworkManager.has_signal("connection_closed"):
		var callable := Callable(self, "_on_connection_closed")
		if NetworkManager.is_connected("connection_closed", callable):
			NetworkManager.disconnect("connection_closed", callable)


func debug_log(message: String) -> void:
	var time := Time.get_time_string_from_system()
	var text := "%s [%s] %s" % [DEBUG_PREFIX, time, message]
	print(text)

	debug_history.append(text)

	# On garde l'historique court pour éviter d'accumuler inutilement.
	if debug_history.size() > 80:
		debug_history.remove_at(0)


func update_ip_labels() -> void:
	var wifi_ips := get_interface_ipv4_by_type("wifi")
	var ethernet_ips := get_interface_ipv4_by_type("ethernet")

	if wifi_ips.is_empty():
		wifi_ip_label.text = "IP Wi-Fi (locale) : non détectée"
	else:
		wifi_ip_label.text = "IP Wi-Fi (locale) : " + join_ip_list(wifi_ips)

	if ethernet_ips.is_empty():
		ethernet_ip_label.text = "IP Ethernet (locale) : non détectée"
	else:
		ethernet_ip_label.text = "IP Ethernet (locale) : " + join_ip_list(ethernet_ips)

	debug_log("IP labels updated. wifi=%s ethernet=%s" % [join_ip_list(wifi_ips), join_ip_list(ethernet_ips)])


func join_ip_list(ips: PackedStringArray) -> String:
	var text := ""

	for ip in ips:
		if not text.is_empty():
			text += ", "
		text += ip

	return text


func print_network_diagnostics() -> void:
	debug_log("----- NETWORK DIAGNOSTICS START -----")
	debug_log("OS=%s" % OS.get_name())
	debug_log("Godot local addresses=%s" % str(IP.get_local_addresses()))
	debug_log("NetworkManager peer=%s" % str(NetworkManager.multiplayer.multiplayer_peer))
	debug_log("NetworkManager unique_id=%s is_server=%s" % [NetworkManager.multiplayer.get_unique_id(), NetworkManager.multiplayer.is_server()])

	var mac_devices := {}
	if OS.get_name() == "macOS":
		mac_devices = get_macos_network_devices()
		debug_log("macOS network devices=%s" % str(mac_devices))

	for interface in IP.get_local_interfaces():
		debug_log("Godot interface raw=%s" % str(interface))

	debug_log("Detected Wi-Fi IPs=%s" % join_ip_list(get_interface_ipv4_by_type("wifi")))
	debug_log("Detected Ethernet IPs=%s" % join_ip_list(get_interface_ipv4_by_type("ethernet")))
	debug_log("----- NETWORK DIAGNOSTICS END -----")


func get_connection_debug_state() -> String:
	var peer: MultiplayerPeer = NetworkManager.multiplayer.multiplayer_peer

	if peer == null:
		return "Aucun peer actif."

	var status := peer.get_connection_status()
	var status_text := get_peer_status_text(status)

	return "Peer actif. Status=%s. Unique ID=%s. Is server=%s." % [
		status_text,
		NetworkManager.multiplayer.get_unique_id(),
		NetworkManager.multiplayer.is_server()
	]


func get_peer_status_text(status: int) -> String:
	match status:
		MultiplayerPeer.CONNECTION_DISCONNECTED:
			return "DISCONNECTED"
		MultiplayerPeer.CONNECTION_CONNECTING:
			return "CONNECTING"
		MultiplayerPeer.CONNECTION_CONNECTED:
			return "CONNECTED"
		_:
			return "UNKNOWN_%s" % status


func get_interface_ipv4_by_type(type: String) -> PackedStringArray:
	var os_name := OS.get_name()

	if os_name == "macOS":
		var mac_devices := get_macos_network_devices()

		if mac_devices.has(type):
			var device_name := str(mac_devices[type])
			var ips := get_macos_ipv4_by_device_name(device_name)

			if not ips.is_empty():
				return ips

	return get_interface_ipv4_by_keywords(type)


func get_macos_network_devices() -> Dictionary:
	var devices := {}
	var output: Array = []

	var exit_code := OS.execute(
		"/usr/sbin/networksetup",
		PackedStringArray(["-listallhardwareports"]),
		output,
		true,
		false
	)

	if exit_code != 0 or output.is_empty():
		debug_log("macOS networksetup failed. exit_code=%s output=%s" % [exit_code, str(output)])
		return devices

	var text := ""

	for part in output:
		text += str(part)

	var current_port := ""

	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()

		if line.begins_with("Hardware Port:"):
			current_port = line.replace("Hardware Port:", "").strip_edges().to_lower()

		elif line.begins_with("Device:"):
			var device_name := line.replace("Device:", "").strip_edges()

			if is_macos_wifi_port(current_port):
				devices["wifi"] = device_name

			elif is_macos_ethernet_port(current_port):
				devices["ethernet"] = device_name

			current_port = ""

	return devices


func is_macos_wifi_port(port_name: String) -> bool:
	return (
		port_name.contains("wi-fi")
		or port_name.contains("wifi")
		or port_name.contains("airport")
	)


func is_macos_ethernet_port(port_name: String) -> bool:
	return (
		port_name.contains("ethernet")
		or port_name.contains("10/100")
		or port_name.contains("1000")
		or port_name.contains("lan")
		or port_name.contains("thunderbolt bridge")
		or port_name.contains("usb")
	)


func get_macos_ipv4_by_device_name(device_name: String) -> PackedStringArray:
	var result: PackedStringArray = []
	var output: Array = []

	var exit_code := OS.execute(
		"/usr/sbin/ipconfig",
		PackedStringArray(["getifaddr", device_name]),
		output,
		true,
		false
	)

	if exit_code != 0 or output.is_empty():
		debug_log("ipconfig getifaddr failed for device=%s exit_code=%s output=%s" % [device_name, exit_code, str(output)])
		return result

	var text := ""

	for part in output:
		text += str(part)

	var ip := text.strip_edges()

	if is_lan_ipv4(ip):
		result.append(ip)
	else:
		debug_log("ipconfig returned non-LAN IPv4 for device=%s ip=%s" % [device_name, ip])

	return result


func get_interface_ipv4_by_keywords(type: String) -> PackedStringArray:
	var result: PackedStringArray = []

	for interface in IP.get_local_interfaces():
		var interface_name := str(interface.get("name", "")).to_lower()
		var friendly := str(interface.get("friendly", "")).to_lower()
		var addresses: Array = interface.get("addresses", [])

		var is_matching_interface := false

		match type:
			"wifi":
				is_matching_interface = is_wifi_interface(interface_name, friendly)
			"ethernet":
				is_matching_interface = is_ethernet_interface(interface_name, friendly)

		if not is_matching_interface:
			continue

		for address in addresses:
			var ip := str(address)

			if is_lan_ipv4(ip):
				result.append(ip)

	return result


func is_wifi_interface(interface_name: String, friendly: String) -> bool:
	var os_name := OS.get_name()
	var text := interface_name + " " + friendly

	match os_name:
		"Windows":
			return (
				text.contains("wi-fi")
				or text.contains("wifi")
				or text.contains("wireless")
				or text.contains("wlan")
			)
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			return (
				text.begins_with("wl")
				or text.contains("wlan")
				or text.contains("wifi")
				or text.contains("wireless")
			)
		"macOS":
			return (
				text.contains("wi-fi")
				or text.contains("wifi")
				or text.contains("airport")
			)
		_:
			return (
				text.contains("wi-fi")
				or text.contains("wifi")
				or text.contains("wireless")
				or text.contains("wlan")
			)


func is_ethernet_interface(interface_name: String, friendly: String) -> bool:
	var os_name := OS.get_name()
	var text := interface_name + " " + friendly

	if is_wifi_interface(interface_name, friendly):
		return false

	match os_name:
		"Windows":
			return (
				text.contains("ethernet")
				or text.contains("local area connection")
			)
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			return (
				text.begins_with("eth")
				or text.begins_with("enp")
				or text.begins_with("eno")
				or text.begins_with("ens")
			)
		"macOS":
			return (
				text.contains("ethernet")
				or text.contains("thunderbolt")
				or text.contains("usb")
			)
		_:
			return (
				text.contains("ethernet")
				or text.begins_with("eth")
				or text.begins_with("enp")
				or text.begins_with("eno")
				or text.begins_with("ens")
			)


func is_lan_ipv4(address: String) -> bool:
	var parts := address.split(".")

	if parts.size() != 4:
		return false

	for part in parts:
		if not part.is_valid_int():
			return false

	var a := int(parts[0])
	var b := int(parts[1])

	if a == 127:
		return false

	if a == 169 and b == 254:
		return true

	if a == 10:
		return true

	if a == 192 and b == 168:
		return true

	if a == 172 and b >= 16 and b <= 31:
		return true

	return false


func _on_host_button_pressed() -> void:
	var port := _get_port_value()
	var player_name := player_name_edit.text.strip_edges()

	if player_name.is_empty():
		player_name = "Host"
		player_name_edit.text = player_name

	join_attempt_id += 1
	_set_buttons_enabled(false)

	debug_log("HOST requested. player_name=%s port=%s" % [player_name, port])
	print_network_diagnostics()

	status_label.text = "Lancement du serveur UDP sur le port %s..." % port

	var result = NetworkManager.host_game(port, player_name, 4)

	debug_log("HOST NetworkManager.host_game result=%s" % result)
	debug_log("HOST after call state=%s" % get_connection_debug_state())

	if result != OK:
		status_label.text = "Échec de l'hébergement. Code %s. Regarde la console Godot." % result
		_set_buttons_enabled(true)
		return

	status_label.text = "Serveur lancé sur le port %s. Écoute UDP attendue sur ce port." % port
	_change_scene_safely(LOBBY_SCENE_PATH)


func _on_join_button_pressed() -> void:
	var port := _get_port_value()
	var ip := ip_edit.text.strip_edges()
	var player_name := player_name_edit.text.strip_edges()

	if ip.is_empty():
		status_label.text = "Adresse IP vide. Entre l'IP locale de l'hôte. Exemple : 192.168.1.15."
		debug_log("JOIN aborted. Empty IP.")
		return

	if player_name.is_empty():
		player_name = "Client"
		player_name_edit.text = player_name

	join_attempt_id += 1
	var current_attempt := join_attempt_id

	_set_buttons_enabled(false)
	status_label.text = "Connexion UDP à %s:%s..." % [ip, port]

	debug_log("JOIN requested. player_name=%s ip=%s port=%s attempt=%s" % [player_name, ip, port, current_attempt])
	debug_log("JOIN before call state=%s" % get_connection_debug_state())
	print_network_diagnostics()

	var result = NetworkManager.join_game(ip, port, player_name)

	debug_log("JOIN NetworkManager.join_game result=%s" % result)
	debug_log("JOIN after call state=%s" % get_connection_debug_state())

	if result != OK:
		status_label.text = "Impossible de créer le client ENet. Code %s. Regarde la console Godot." % result
		_set_buttons_enabled(true)
		return

	var tree := get_tree()
	if tree == null:
		debug_log("JOIN timeout not created. get_tree() is null.")
		return

	var timer := tree.create_timer(JOIN_TIMEOUT_SECONDS)
	timer.timeout.connect(_on_join_timeout.bind(current_attempt, ip, port))


func _get_port_value() -> int:
	var text := port_edit.text.strip_edges()
	var port := int(text)

	if port <= 0 or port > 65535:
		port = DEFAULT_PORT
		port_edit.text = str(port)
		debug_log("Invalid port field. Reset to DEFAULT_PORT=%s" % DEFAULT_PORT)

	return port


func _set_buttons_enabled(enabled: bool) -> void:
	host_button.disabled = not enabled
	join_button.disabled = not enabled
	ip_edit.editable = enabled
	port_edit.editable = enabled
	player_name_edit.editable = enabled


func _change_scene_safely(scene_path: String) -> void:
	if not is_inside_tree():
		debug_log("Scene change blocked. Node is not inside tree. path=%s" % scene_path)
		return

	var tree := get_tree()
	if tree == null:
		debug_log("Scene change blocked. get_tree() is null. path=%s" % scene_path)
		return

	debug_log("Changing scene to %s" % scene_path)
	tree.call_deferred("change_scene_to_file", scene_path)


func _on_connection_succeeded() -> void:
	if not is_inside_tree():
		return

	join_attempt_id += 1
	debug_log("SIGNAL connection_succeeded. %s" % get_connection_debug_state())
	status_label.text = "Connexion réussie. Ouverture du lobby..."
	_change_scene_safely(LOBBY_SCENE_PATH)


func _on_connection_failed(message: String = "Connexion impossible.") -> void:
	if not is_inside_tree():
		return

	join_attempt_id += 1
	debug_log("SIGNAL connection_failed. message=%s state=%s" % [message, get_connection_debug_state()])
	status_label.text = "%s Vérifie IP, port, pare-feu macOS, réseau invité et isolation Wi-Fi." % message
	_set_buttons_enabled(true)


func _on_connection_closed(message: String = "Connexion fermée.") -> void:
	if not is_inside_tree():
		return

	join_attempt_id += 1
	debug_log("SIGNAL connection_closed. message=%s state=%s" % [message, get_connection_debug_state()])
	status_label.text = message
	_set_buttons_enabled(true)


func _on_join_timeout(attempt_id: int, ip: String, port: int) -> void:
	if not is_inside_tree():
		return

	if attempt_id != join_attempt_id:
		debug_log("JOIN timeout ignored. Old attempt=%s current=%s" % [attempt_id, join_attempt_id])
		return

	var peer: MultiplayerPeer = NetworkManager.multiplayer.multiplayer_peer
	debug_log("JOIN timeout reached. attempt=%s target=%s:%s state=%s" % [attempt_id, ip, port, get_connection_debug_state()])

	if peer == null:
		status_label.text = "Connexion impossible. Aucun peer réseau actif. Regarde la console Godot."
		_set_buttons_enabled(true)
		return

	if NetworkManager.multiplayer.is_server():
		debug_log("JOIN timeout ignored because this instance is server.")
		return

	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		debug_log("JOIN timeout ignored because peer is already connected.")
		return

	if NetworkManager.has_method("leave_game"):
		NetworkManager.leave_game()
	else:
		NetworkManager.multiplayer.multiplayer_peer = null

	status_label.text = "Connexion impossible vers %s:%s. Ping la machine hôte. Si ping échoue, c'est la box ou le Wi-Fi. Si ping marche, vérifie pare-feu macOS et port UDP 7000." % [ip, port]
	_set_buttons_enabled(true)


func _on_host_steam_button_pressed() -> void:
	status_label.text = "Création du lobby Steam..."
	print("[MAIN_MENU_STEAM] Host Steam Lobby pressed")

	SteamLobbyManager.create_lobby()


func _on_invite_friend_button_pressed() -> void:
	print("[MAIN_MENU_STEAM] Invite Friend pressed")

	if SteamLobbyManager.current_lobby_id == 0:
		status_label.text = "Crée d'abord un lobby Steam."
		return

	SteamLobbyManager.invite_friends()


func _on_steam_lobby_created(lobby_id: int) -> void:
	status_label.text = "Lobby Steam créé : %s" % lobby_id
	print("[MAIN_MENU_STEAM] Steam lobby created: ", lobby_id)

	if not is_inside_tree():
		return

	get_tree().change_scene_to_file(LOBBY_SCENE_PATH)


func _on_steam_lobby_joined(lobby_id: int) -> void:
	status_label.text = "Lobby Steam rejoint : %s" % lobby_id
	print("[MAIN_MENU_STEAM] Steam lobby joined: ", lobby_id)

	if not is_inside_tree():
		return

	get_tree().change_scene_to_file(LOBBY_SCENE_PATH)


func _on_steam_lobby_failed(message: String) -> void:
	status_label.text = message
	print("[MAIN_MENU_STEAM] Steam lobby failed: ", message)


func _on_steam_lobby_members_changed() -> void:
	print("[MAIN_MENU_STEAM] Lobby members changed")

	for steam_id in SteamLobbyManager.lobby_members:
		var member_name := SteamLobbyManager.get_member_name(steam_id)
		print("[MAIN_MENU_STEAM] Member: ", member_name, " / ", steam_id)

func _on_join_lobby_id_button_pressed() -> void:
	var text := join_lobby_id_edit.text.strip_edges()

	if text.is_empty():
		print("[STEAM_LOBBY] Lobby ID vide.")
		return

	if not text.is_valid_int():
		print("[STEAM_LOBBY] Lobby ID invalide: ", text)
		return

	var lobby_id := int(text)

	print("[STEAM_LOBBY] Manual join lobby: ", lobby_id)
	SteamLobbyManager.join_lobby(lobby_id)
	
