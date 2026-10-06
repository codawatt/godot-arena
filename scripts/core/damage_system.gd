class_name DamageSystem
extends Node

var processed_events: Dictionary = {}
var game_server: Node


func _ready() -> void:
	game_server = get_node("../GameServer")


func _process(_delta: float) -> void:
	if not multiplayer.is_server() or processed_events.is_empty():
		return
	var cutoff := Time.get_ticks_msec() - 5000
	for event_key in processed_events.keys():
		if int(processed_events[event_key]) < cutoff:
			processed_events.erase(event_key)


func apply_damage(
	target,
	amount: float,
	attacker_id: int,
	direction: Vector3,
	knockback: float,
	attack_id: String
) -> bool:
	if not multiplayer.is_server() or target == null or target.state.is_dead:
		return false
	var event_key := "%d|%s" % [target.peer_id, attack_id]
	if processed_events.has(event_key):
		return false
	processed_events[event_key] = Time.get_ticks_msec()

	var incoming := maxi(0, int(round(amount)))
	var desired_absorption := int(round(incoming * PlayerState.ARMOR_ABSORPTION))
	var absorbed := mini(target.state.armor, desired_absorption)
	target.state.armor -= absorbed
	target.state.health = maxi(0, target.state.health - (incoming - absorbed))
	if knockback > 0.0 and direction.length_squared() > 0.001:
		target.velocity += (direction.normalized() + Vector3.UP * 0.12).normalized() * knockback

	if target.state.health <= 0:
		game_server.handle_player_death(target, attacker_id)
	return true
