extends RigidBody3D
class_name LootPickup

signal picked_up(loot_key: String, amount: int, by: Node)

enum LootType {
	MONEY,
	PISTOL_AMMO,
	RIFLE_AMMO,
	SMG_AMMO
}

@export_group("Loot")
@export var loot_type: LootType = LootType.MONEY
@export var amount: int = 10
@export var auto_pickup: bool = true
@export var pickup_delay: float = 0.3
@export var lifetime: float = 0.0

@export_group("Physics")
@export var freeze_after_seconds: float = 1.0
@export var linear_damp_override: float = 1.8
@export var angular_damp_override: float = 1.8

@onready var pickup_area: Area3D = $PickupArea3D

var drop_id: String = ""
var _pickup_delay_left: float = 0.0
var _lifetime_left: float = 0.0
var _freeze_delay_left: float = 0.0
var _consumed: bool = false


func _ready() -> void:
	add_to_group("loot_pickup")
	contact_monitor = true
	max_contacts_reported = 4
	can_sleep = true
	linear_damp = linear_damp_override
	angular_damp = angular_damp_override
	_pickup_delay_left = max(pickup_delay, 0.0)
	_lifetime_left = max(lifetime, 0.0)
	_freeze_delay_left = max(freeze_after_seconds, 0.0)

	if pickup_area != null and not pickup_area.body_entered.is_connected(_on_pickup_area_body_entered):
		pickup_area.body_entered.connect(_on_pickup_area_body_entered)


func _physics_process(delta: float) -> void:
	if _consumed:
		return

	if _pickup_delay_left > 0.0:
		_pickup_delay_left -= delta

	if lifetime > 0.0:
		_lifetime_left -= delta
		if _lifetime_left <= 0.0:
			_destroy_pickup()
			return

	if _freeze_delay_left > 0.0:
		_freeze_delay_left -= delta
		if _freeze_delay_left <= 0.0 and linear_velocity.length_squared() < 0.04:
			sleeping = true


func configure_drop(new_drop_id: String = "", new_amount: int = -1) -> void:
	drop_id = new_drop_id
	if new_amount >= 0:
		amount = new_amount


func try_pickup_by(body: Node) -> bool:
	return _try_pickup(body)


func get_loot_key() -> String:
	match loot_type:
		LootType.MONEY:
			return "money"
		LootType.PISTOL_AMMO:
			return "pistol"
		LootType.RIFLE_AMMO:
			return "rifle"
		LootType.SMG_AMMO:
			return "smg"
	return "unknown"


func _on_pickup_area_body_entered(body: Node) -> void:
	if not auto_pickup:
		return
	if not multiplayer.is_server():
		return
	_try_pickup(body)


func _try_pickup(body: Node) -> bool:
	if _consumed:
		return false
	if _pickup_delay_left > 0.0:
		return false

	var player := _extract_player_from_body(body)
	if player == null:
		return false

	if not _apply_loot_to_player(player):
		return false

	_consumed = true
	print("emit!")
	picked_up.emit(get_loot_key(), amount, player)
	_remote_consume.rpc()
	return true


func _apply_loot_to_player(player: Node) -> bool:
	var loot_key := get_loot_key()

	if player.has_method("pickup_loot"):
		var generic_result = player.pickup_loot(loot_key, amount, self)
		return _interpret_pickup_result(generic_result)

	match loot_type:
		LootType.MONEY:
			return _apply_money_to_player(player)
		LootType.PISTOL_AMMO, LootType.RIFLE_AMMO, LootType.SMG_AMMO:
			return _apply_ammo_to_player(player, loot_key)

	return false


func _apply_money_to_player(player: Node) -> bool:
	for method_name in ["add_money", "give_money", "add_cash", "receive_money", "add_coins"]:
		if player.has_method(method_name):
			var result = player.call(method_name, amount)
			return _interpret_pickup_result(result)

	if player.has_method("add_currency"):
		var currency_result = player.call("add_currency", "money", amount)
		return _interpret_pickup_result(currency_result)

	return false


func _apply_ammo_to_player(player: Node, ammo_key: String) -> bool:
	if player.has_method("add_ammo"):
		var ammo_result = player.call("add_ammo", ammo_key, amount)
		return _interpret_pickup_result(ammo_result)

	for method_name in [
		"give_ammo",
		"pickup_ammo",
		"add_weapon_ammo",
		"add_inventory_ammo",
		"add_reserve_ammo",
		"receive_ammo"
	]:
		if player.has_method(method_name):
			var result = player.call(method_name, ammo_key, amount)
			return _interpret_pickup_result(result)

	return false


func _interpret_pickup_result(result: Variant) -> bool:
	if typeof(result) == TYPE_BOOL:
		return result
	return true


func _extract_player_from_body(body: Node) -> Node:
	if body == null or not is_instance_valid(body):
		return null

	if body.is_in_group("player"):
		return body

	if body.has_method("get_driver"):
		var driver = body.get_driver()
		if driver != null and driver is Node and driver.is_in_group("player"):
			return driver

	if body.has_method("get_player"):
		var player = body.get_player()
		if player != null and player is Node and player.is_in_group("player"):
			return player

	for property_name in ["driver", "owner_player", "player_owner", "controlling_player", "current_player"]:
		var value = _safe_get_property(body, property_name)
		if value != null and value is Node and value.is_in_group("player"):
			return value

	return null


func _safe_get_property(object: Object, property_name: String) -> Variant:
	if object == null:
		return null

	for property_data in object.get_property_list():
		if String(property_data.name) == property_name:
			return object.get(property_name)

	return null


func _destroy_pickup() -> void:
	if multiplayer.is_server():
		_remote_consume.rpc()
	else:
		queue_free()


@rpc("authority", "call_local", "reliable")
func _remote_consume() -> void:
	queue_free()
