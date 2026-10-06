class_name WeaponSystem
extends Node

const RAILGUN: WeaponBase = preload("res://resources/weapons/railgun.tres")
const LIGHTNING_GUN: WeaponBase = preload("res://resources/weapons/lightning_gun.tres")
const SHOTGUN: WeaponBase = preload("res://resources/weapons/shotgun.tres")
const GAUNTLET: WeaponBase = preload("res://resources/weapons/gauntlet.tres")

var weapons: Dictionary = {}
var damage_system: Node
var game_server: Node


func _ready() -> void:
	weapons = {
		int(RAILGUN.weapon_id): RAILGUN,
		int(LIGHTNING_GUN.weapon_id): LIGHTNING_GUN,
		int(SHOTGUN.weapon_id): SHOTGUN,
		int(GAUNTLET.weapon_id): GAUNTLET,
	}
	damage_system = get_node("../DamageSystem")
	game_server = get_node("../GameServer")


func get_weapon(weapon_id: int) -> WeaponBase:
	return weapons.get(weapon_id) as WeaponBase


func get_weapon_name(weapon_id: int) -> String:
	var weapon := get_weapon(weapon_id)
	return weapon.display_name if weapon != null else "Unknown"


func process_fire(player, wants_fire: bool, now_msec: int) -> void:
	if not wants_fire or player.state.is_dead:
		return
	var weapon := get_weapon(player.state.selected_weapon)
	if weapon == null or not bool(player.state.owned_weapons.get(int(weapon.weapon_id), false)):
		return
	var next_allowed := int(player.next_fire_msec.get(int(weapon.weapon_id), 0))
	if now_msec < next_allowed:
		return
	if not player.state.consume_ammo(int(weapon.weapon_id), weapon.ammo_cost):
		return

	player.next_fire_msec[int(weapon.weapon_id)] = now_msec + weapon.cooldown_msec()
	player.attack_counter += 1
	var attack_id := "%d:%d" % [player.peer_id, player.attack_counter]
	# The spread seed is created by the server and is independent of client timing.
	var seed := int((player.peer_id * 73856093) ^ (player.attack_counter * 19349663)) & 0x7fffffff
	var context := {
		"shooter": player,
		"origin": player.get_aim_origin(),
		"direction": player.get_aim_direction(),
		"space_state": player.get_world_3d().direct_space_state,
		"damage_system": damage_system,
		"attack_id": attack_id,
		"seed": seed,
	}
	var effect := weapon.server_fire(context)
	if not effect.is_empty():
		effect["weapon_id"] = int(weapon.weapon_id)
		effect["shooter_id"] = player.peer_id
		game_server.broadcast_weapon_effect(effect)
