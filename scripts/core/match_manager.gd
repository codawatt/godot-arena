class_name MatchManager
extends Node

var entries: Dictionary = {}
var spawn_cursor: int = 0


func reset() -> void:
	entries.clear()
	spawn_cursor = 0


func register_player(peer_id: int, display_name: String) -> void:
	entries[peer_id] = {
		"peer_id": peer_id,
		"name": display_name,
		"kills": 0,
		"deaths": 0,
	}


func unregister_player(peer_id: int) -> void:
	entries.erase(peer_id)


func record_death(victim_id: int, attacker_id: int, weapon_name: String) -> Dictionary:
	if entries.has(victim_id):
		entries[victim_id]["deaths"] = int(entries[victim_id]["deaths"]) + 1
	if attacker_id != victim_id and entries.has(attacker_id):
		entries[attacker_id]["kills"] = int(entries[attacker_id]["kills"]) + 1
	var victim_name := get_player_name(victim_id)
	var attacker_name := get_player_name(attacker_id) if attacker_id != 0 else "THE VOID"
	var message := "%s fell into the void" % victim_name
	if attacker_id != 0 and attacker_id != victim_id:
		message = "%s eliminated %s with %s" % [attacker_name, victim_name, weapon_name]
	elif attacker_id == victim_id:
		message = "%s eliminated themselves" % victim_name
	return {
		"message": message,
		"attacker": attacker_name,
		"victim": victim_name,
		"weapon": weapon_name,
	}


func get_player_name(peer_id: int) -> String:
	if entries.has(peer_id):
		return str(entries[peer_id]["name"])
	return "Player %d" % peer_id


func serialize_scoreboard() -> Array:
	var result: Array = []
	for entry in entries.values():
		result.append(Dictionary(entry).duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["kills"]) == int(b["kills"]):
			return int(a["deaths"]) < int(b["deaths"])
		return int(a["kills"]) > int(b["kills"])
	)
	return result


func choose_spawn(players: Dictionary) -> Dictionary:
	var spawn_nodes := get_tree().get_nodes_in_group("spawn_points")
	if spawn_nodes.is_empty():
		return {"position": Vector3(0, 1, 0), "yaw": 0.0}
	var best_spawn: Marker3D = spawn_nodes[spawn_cursor % spawn_nodes.size()]
	var best_score := -1.0
	for candidate_node in spawn_nodes:
		var candidate := candidate_node as Marker3D
		var minimum_distance := 10000.0
		var found_alive := false
		for player in players.values():
			if not player.state.is_dead:
				found_alive = true
				minimum_distance = minf(minimum_distance, candidate.global_position.distance_to(player.global_position))
		if not found_alive:
			minimum_distance = 1000.0
		if minimum_distance > best_score:
			best_score = minimum_distance
			best_spawn = candidate
	spawn_cursor += 1
	return {"position": best_spawn.global_position, "yaw": best_spawn.global_rotation.y}
