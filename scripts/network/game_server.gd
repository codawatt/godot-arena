class_name GameServer
extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const MAX_PLAYERS := 8
const RESPAWN_DELAY_SECONDS := 3.0
const SNAPSHOT_RATE := 20.0

var players: Dictionary = {}
var pending_commands: Dictionary = {}
var last_sequences: Dictionary = {}
var last_input_msec: Dictionary = {}
var active: bool = false
var dedicated: bool = false
var snapshot_accumulator: float = 0.0

@onready var players_root: Node3D = get_node("../Players")
@onready var match_manager: MatchManager = get_node("../MatchManager")
@onready var damage_system: DamageSystem = get_node("../DamageSystem")
@onready var weapon_system: WeaponSystem = get_node("../WeaponSystem")
@onready var game_client: GameClient = get_node("../GameClient")


func _ready() -> void:
	add_to_group("game_server")
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func activate_server(dedicated_mode: bool) -> void:
	reset_session()
	active = true
	dedicated = dedicated_mode
	print("Arena server active (dedicated=%s, max_players=%d)" % [dedicated, MAX_PLAYERS])


func register_local_player(requested_name: String) -> void:
	if multiplayer.is_server() and active:
		_register_player(1, requested_name, true)


@rpc("any_peer", "call_remote", "reliable")
func register_player(requested_name: String) -> void:
	if not multiplayer.is_server() or not active:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 1:
		return
	_register_player(sender_id, requested_name, false)


func _register_player(peer_id: int, requested_name: String, is_local: bool) -> void:
	if players.has(peer_id):
		return
	if players.size() >= MAX_PLAYERS:
		if not is_local:
			client_rejected.rpc_id(peer_id, "Server is full (maximum %d players)." % MAX_PLAYERS)
			multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	var safe_name := _sanitize_name(requested_name, peer_id)
	if not is_local:
		client_bootstrap.rpc_id(peer_id, _player_descriptors(), _pickup_states(), match_manager.serialize_scoreboard())
	match_manager.register_player(peer_id, safe_name)
	var spawn := match_manager.choose_spawn(players)
	spawn_player.rpc(peer_id, safe_name, spawn["position"], float(spawn["yaw"]))
	print("Registered peer %d as %s" % [peer_id, safe_name])


@rpc("authority", "call_remote", "reliable")
func client_bootstrap(descriptors: Array, pickup_states: Dictionary, scoreboard: Array) -> void:
	if multiplayer.is_server():
		return
	for descriptor in descriptors:
		var data := Dictionary(descriptor)
		_spawn_player_local(
			int(data["peer_id"]),
			str(data["name"]),
			data["position"],
			float(data["yaw"])
		)
	for pickup_path in pickup_states:
		var pickup := get_node_or_null(NodePath(str(pickup_path)))
		if pickup != null and pickup.has_method("apply_bootstrap_state"):
			pickup.apply_bootstrap_state(Dictionary(pickup_states[pickup_path]))
	game_client.receive_scoreboard(scoreboard)


@rpc("authority", "call_local", "reliable")
func spawn_player(peer_id: int, player_name: String, spawn_position: Vector3, yaw: float) -> void:
	_spawn_player_local(peer_id, player_name, spawn_position, yaw)


func _spawn_player_local(peer_id: int, player_name: String, spawn_position: Vector3, yaw: float) -> void:
	if players.has(peer_id):
		return
	var player = PLAYER_SCENE.instantiate()
	players_root.add_child(player)
	var local_visual := game_client.is_local_peer(peer_id)
	player.configure(peer_id, player_name, local_visual, multiplayer.is_server(), spawn_position)
	player.aim_yaw = yaw
	player.target_yaw = yaw
	players[peer_id] = player
	game_client.on_player_spawned(player)


@rpc("authority", "call_local", "reliable")
func despawn_player(peer_id: int) -> void:
	if not players.has(peer_id):
		return
	var player = players[peer_id]
	players.erase(peer_id)
	pending_commands.erase(peer_id)
	last_sequences.erase(peer_id)
	last_input_msec.erase(peer_id)
	game_client.on_player_despawned(peer_id)
	player.queue_free()


@rpc("any_peer", "call_remote", "unreliable_ordered", 0)
func submit_input(
	sequence: int,
	move_input: Vector2,
	jump_held: bool,
	yaw: float,
	pitch: float,
	wants_fire: bool,
	requested_weapon: int
) -> void:
	if not multiplayer.is_server():
		return
	_accept_input(
		multiplayer.get_remote_sender_id(), sequence, move_input, jump_held,
		yaw, pitch, wants_fire, requested_weapon
	)


func submit_local_input(
	sequence: int,
	move_input: Vector2,
	jump_held: bool,
	yaw: float,
	pitch: float,
	wants_fire: bool,
	requested_weapon: int
) -> void:
	if multiplayer.is_server():
		_accept_input(1, sequence, move_input, jump_held, yaw, pitch, wants_fire, requested_weapon)


func _accept_input(
	peer_id: int,
	sequence: int,
	move_input: Vector2,
	jump_held: bool,
	yaw: float,
	pitch: float,
	wants_fire: bool,
	requested_weapon: int
) -> void:
	if not active or not players.has(peer_id) or sequence <= int(last_sequences.get(peer_id, -1)):
		return
	if not is_finite(move_input.x) or not is_finite(move_input.y) or not is_finite(yaw) or not is_finite(pitch):
		return
	var player = players[peer_id]
	var now := Time.get_ticks_msec()
	var elapsed := maxf(0.001, float(now - int(last_input_msec.get(peer_id, now - 16))) / 1000.0)
	var maximum_turn := 20.0 * elapsed + 0.35
	var validated_yaw: float = player.aim_yaw + clampf(
		angle_difference(player.aim_yaw, wrapf(yaw, -PI, PI)),
		-maximum_turn,
		maximum_turn
	)
	var validated_pitch := clampf(pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
	var validated_move := move_input.limit_length(1.0)
	if requested_weapon >= 0 and requested_weapon <= 3:
		player.state.set_selected_weapon(requested_weapon)
	pending_commands[peer_id] = {
		"move": validated_move,
		"jump": jump_held,
		"yaw": validated_yaw,
		"pitch": validated_pitch,
		"fire": wants_fire,
	}
	last_sequences[peer_id] = sequence
	last_input_msec[peer_id] = now


func _physics_process(delta: float) -> void:
	if not active or not multiplayer.is_server():
		return
	var now := Time.get_ticks_msec()
	for peer_id in players.keys():
		var player = players[peer_id]
		if player.state.is_dead:
			if now >= player.state.respawn_at_msec:
				_respawn_player(player)
			continue
		var command: Dictionary = pending_commands.get(peer_id, _neutral_command(player))
		if now - int(last_input_msec.get(peer_id, now)) > 300:
			command = _neutral_command(player)
		player.server_simulate(command, delta)
		weapon_system.process_fire(player, bool(command.get("fire", false)), now)
		if player.global_position.y < -20.0:
			handle_environmental_death(player)

	snapshot_accumulator += delta
	if snapshot_accumulator >= 1.0 / SNAPSHOT_RATE:
		snapshot_accumulator = fmod(snapshot_accumulator, 1.0 / SNAPSHOT_RATE)
		_broadcast_snapshot(now)


func handle_player_death(target, attacker_id: int) -> void:
	if not multiplayer.is_server() or target.state.is_dead:
		return
	var now := Time.get_ticks_msec()
	target.mark_dead(now + int(RESPAWN_DELAY_SECONDS * 1000.0))
	var weapon_name := "the arena"
	if players.has(attacker_id):
		weapon_name = weapon_system.get_weapon_name(players[attacker_id].state.selected_weapon)
	var event := match_manager.record_death(target.peer_id, attacker_id, weapon_name)
	announce_elimination.rpc(str(event["message"]))


func handle_environmental_death(target) -> void:
	if multiplayer.is_server() and target != null and not target.state.is_dead:
		damage_system.apply_damage(
			target, 10000.0, 0, Vector3.DOWN, 0.0,
			"void:%d:%d" % [target.peer_id, Time.get_ticks_msec()]
		)


func broadcast_weapon_effect(effect: Dictionary) -> void:
	if multiplayer.is_server():
		present_weapon_effect.rpc(effect)


@rpc("authority", "call_local", "unreliable_ordered", 2)
func present_weapon_effect(effect: Dictionary) -> void:
	game_client.present_weapon_effect(effect)


@rpc("authority", "call_local", "reliable")
func announce_elimination(message: String) -> void:
	game_client.receive_elimination(message)


@rpc("authority", "call_remote", "reliable")
func client_rejected(message: String) -> void:
	game_client.receive_rejection(message)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func receive_snapshot(snapshot: Dictionary, scoreboard: Array) -> void:
	if not multiplayer.is_server():
		game_client.receive_snapshot(snapshot, scoreboard)


func _broadcast_snapshot(now_msec: int) -> void:
	var snapshot: Dictionary = {}
	for peer_id in players:
		snapshot[peer_id] = players[peer_id].make_snapshot(int(last_sequences.get(peer_id, 0)), now_msec)
	receive_snapshot.rpc(snapshot, match_manager.serialize_scoreboard())
	# The host's HUD shares the server process and therefore needs the same local update.
	if game_client.session_active:
		game_client.receive_snapshot(snapshot, match_manager.serialize_scoreboard())


func _respawn_player(player) -> void:
	var spawn := match_manager.choose_spawn(players)
	player.respawn_at(spawn["position"])
	player.aim_yaw = float(spawn["yaw"])
	player.aim_pitch = 0.0
	pending_commands[player.peer_id] = _neutral_command(player)


func _neutral_command(player) -> Dictionary:
	return {
		"move": Vector2.ZERO,
		"jump": false,
		"yaw": player.aim_yaw,
		"pitch": player.aim_pitch,
		"fire": false,
	}


func _player_descriptors() -> Array:
	var result: Array = []
	for peer_id in players:
		var player = players[peer_id]
		result.append({
			"peer_id": peer_id,
			"name": player.display_name,
			"position": player.global_position,
			"yaw": player.aim_yaw,
		})
	return result


func _pickup_states() -> Dictionary:
	var result: Dictionary = {}
	for pickup in get_tree().get_nodes_in_group("pickups"):
		result[str(pickup.get_path())] = pickup.get_network_state()
	return result


func _sanitize_name(requested_name: String, peer_id: int) -> String:
	var value := requested_name.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ")
	value = value.substr(0, 20)
	return value if not value.is_empty() else "Player %d" % peer_id


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server() and players.has(peer_id):
		match_manager.unregister_player(peer_id)
		despawn_player.rpc(peer_id)


func reset_session() -> void:
	active = false
	dedicated = false
	snapshot_accumulator = 0.0
	for player in players.values():
		player.queue_free()
	players.clear()
	pending_commands.clear()
	last_sequences.clear()
	last_input_msec.clear()
	if is_instance_valid(match_manager):
		match_manager.reset()
