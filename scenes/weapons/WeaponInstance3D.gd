extends Node3D
class_name WeaponInstance3D

const DEFAULT_VISUAL_BULLET_SCENE := preload("res://scenes/weapons/VisualBullet.tscn")

@export_group("Meta")
@export var weapon_id: String = "pistol"
@export var weapon_label: String = "Pistol"
@export var weapon_local_position: Vector3 = Vector3(0.22, 1.25, -0.5)

@export_group("Behaviour")
@export_enum("projectile", "repair_tool") var weapon_behavior: String = "projectile"

@export_group("Ammo")
@export var magazine_size: int = 12
#@export var max_reserve_ammo: int = 48
@export var reload_duration: float = 1.1

@export_group("Fire")
@export var automatic_fire: bool = false
@export var fire_cooldown: float = 0.25
@export var shot_dispersion_degrees: float = 0.0
@export var hitscan_range: float = 40.0
@export var projectile_damage: int = 10
@export var projectile_penetration: int = 0
@export var projectile_tk: bool = false
@export var projectile_scene: PackedScene = DEFAULT_VISUAL_BULLET_SCENE
@export var projectile_impact_scene: PackedScene

@export_group("Repair Tool")
@export var repair_amount: int = 8
@export var repair_damage: int = 4
@export var repair_range: float = 2.8
@export var repair_revive_dead_vehicle: bool = true
@export_flags_3d_physics var repair_collision_mask: int = 0xFFFFFFFF

@export_group("Hold")
@export var hand_position: Vector3 = Vector3.ZERO
@export var hand_rotation_deg: Vector3 = Vector3.ZERO
@export var back_position: Vector3 = Vector3.ZERO
@export var back_rotation_deg: Vector3 = Vector3(-90.0, 0.0, 0.0)

@onready var muzzle: Marker3D = $Muzzle

var ammo_in_magazine: int = -1
var reserve_ammo: int = -1

func _ready() -> void:
	if ammo_in_magazine < 0:
		ammo_in_magazine = magazine_size

	#if reserve_ammo < 0:
		#reserve_ammo = max_reserve_ammo

func apply_runtime_state(state: Dictionary) -> void:
	ammo_in_magazine = clamp(int(state.get("ammo_in_magazine", magazine_size)), 0, magazine_size)
	#reserve_ammo = clamp(int(state.get("reserve_ammo", max_reserve_ammo)), 0, max_reserve_ammo)

func to_runtime_state() -> Dictionary:
	return {
		"weapon_id": weapon_id,
		"ammo_in_magazine": ammo_in_magazine,
		"reserve_ammo": reserve_ammo,
	}

func get_muzzle_transform() -> Transform3D:
	return muzzle.global_transform

#func can_reload() -> bool:
	#return ammo_in_magazine < magazine_size and reserve_ammo > 0

#func perform_reload() -> void:
	#if not can_reload():
		#return
#
	#var needed := magazine_size - ammo_in_magazine
	#var loaded = min(needed, reserve_ammo)
	#ammo_in_magazine += loaded
	#reserve_ammo -= loaded

func consume_round() -> bool:
	if ammo_in_magazine <= 0:
		return false

	ammo_in_magazine -= 1
	return true
