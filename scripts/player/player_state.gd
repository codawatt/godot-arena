class_name PlayerState
extends Resource

const MAX_HEALTH := 100
const MAX_ARMOR := 100
const ARMOR_ABSORPTION := 0.66

var health: int = MAX_HEALTH
var armor: int = 0
var is_dead: bool = false
var respawn_at_msec: int = 0
var selected_weapon: int = 0
var ammo: Dictionary = {}
var owned_weapons: Dictionary = {}


func _init() -> void:
	reset_for_spawn()


func reset_for_spawn() -> void:
	health = MAX_HEALTH
	armor = 0
	is_dead = false
	respawn_at_msec = 0
	selected_weapon = 0
	# Every weapon is unlocked in the vertical slice so each can be tested at once.
	# Weapon pickups still validate ownership and refill their matching ammunition.
	owned_weapons = {0: true, 1: true, 2: true, 3: true}
	ammo = {0: 10, 1: 80, 2: 24, 3: 0}


func set_selected_weapon(weapon_id: int) -> bool:
	if not bool(owned_weapons.get(weapon_id, false)):
		return false
	selected_weapon = weapon_id
	return true


func consume_ammo(weapon_id: int, cost: int) -> bool:
	if cost <= 0:
		return true
	var current := int(ammo.get(weapon_id, 0))
	if current < cost:
		return false
	ammo[weapon_id] = current - cost
	return true


func add_health(amount: int, allow_over_max: bool = false) -> bool:
	var limit := MAX_HEALTH + 100 if allow_over_max else MAX_HEALTH
	if health >= limit:
		return false
	health = mini(health + amount, limit)
	return true


func add_armor(amount: int, allow_over_max: bool = false) -> bool:
	var limit := MAX_ARMOR + 100 if allow_over_max else MAX_ARMOR
	if armor >= limit:
		return false
	armor = mini(armor + amount, limit)
	return true


func add_ammo(weapon_id: int, amount: int, maximum: int) -> bool:
	var current := int(ammo.get(weapon_id, 0))
	if current >= maximum:
		return false
	ammo[weapon_id] = mini(current + amount, maximum)
	return true


func unlock_weapon(weapon_id: int) -> bool:
	if bool(owned_weapons.get(weapon_id, false)):
		return false
	owned_weapons[weapon_id] = true
	return true


func serialize() -> Dictionary:
	return {
		"health": health,
		"armor": armor,
		"is_dead": is_dead,
		"selected_weapon": selected_weapon,
		"ammo": ammo.duplicate(true),
		"owned_weapons": owned_weapons.duplicate(true),
	}


func apply_serialized(data: Dictionary) -> void:
	health = int(data.get("health", health))
	armor = int(data.get("armor", armor))
	is_dead = bool(data.get("is_dead", is_dead))
	selected_weapon = int(data.get("selected_weapon", selected_weapon))
	ammo = Dictionary(data.get("ammo", ammo)).duplicate(true)
	owned_weapons = Dictionary(data.get("owned_weapons", owned_weapons)).duplicate(true)
