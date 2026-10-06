class_name GameClient
extends Node

signal menu_toggle_requested

@export var mouse_sensitivity: float = 0.0022

var session_active: bool = false
var local_peer_id: int = 0
var local_player = null
var player_name: String = "Player"
var sequence: int = 0
var aim_yaw: float = 0.0
var aim_pitch: float = 0.0
var desired_weapon: int = 0

@onready var game_server: GameServer = get_node("../GameServer")
@onready var weapon_system: WeaponSystem = get_node("../WeaponSystem")
@onready var hud: ArenaHUD = get_node("../HUD")
@onready var effects: WeaponEffects = get_node("../WeaponEffects")


func begin_session(peer_id: int, new_player_name: String) -> void:
	session_active = true
	local_peer_id = peer_id
	player_name = new_player_name
	sequence = 0
	local_player = null
	hud.set_connection_status("Connected as peer %d" % peer_id)


func register_with_server() -> void:
	if session_active and not multiplayer.is_server():
		game_server.register_player.rpc_id(1, player_name)


func end_session() -> void:
	session_active = false
	local_peer_id = 0
	local_player = null
	sequence = 0
	hud.clear_session()


func is_local_peer(peer_id: int) -> bool:
	return session_active and peer_id == local_peer_id


func on_player_spawned(player) -> void:
	if player.peer_id != local_peer_id:
		return
	local_player = player
	aim_yaw = player.aim_yaw
	aim_pitch = player.aim_pitch
	desired_weapon = player.state.selected_weapon
	hud.set_connection_status("In match — peer %d" % local_peer_id)


func on_player_despawned(peer_id: int) -> void:
	if peer_id == local_peer_id:
		local_player = null


func _unhandled_input(event: InputEvent) -> void:
	if not session_active:
		return
	if event.is_action_pressed("pause_capture"):
		menu_toggle_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		aim_yaw = wrapf(aim_yaw - event.relative.x * mouse_sensitivity, -PI, PI)
		aim_pitch = clampf(
			aim_pitch - event.relative.y * mouse_sensitivity,
			deg_to_rad(-89.0),
			deg_to_rad(89.0)
		)


func _physics_process(delta: float) -> void:
	if not session_active or local_player == null:
		return
	var gameplay_enabled := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if gameplay_enabled:
		_update_weapon_selection()
	var move_input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward") if gameplay_enabled else Vector2.ZERO
	var jump_held := Input.is_action_pressed("jump") if gameplay_enabled else false
	var wants_fire := Input.is_action_pressed("fire") if gameplay_enabled else false
	sequence += 1
	if multiplayer.is_server():
		game_server.submit_local_input(
			sequence, move_input, jump_held, aim_yaw, aim_pitch, wants_fire, desired_weapon
		)
	else:
		game_server.submit_input.rpc_id(
			1, sequence, move_input, jump_held, aim_yaw, aim_pitch, wants_fire, desired_weapon
		)
		local_player.client_predict({
			"move": move_input,
			"jump": jump_held,
			"yaw": aim_yaw,
			"pitch": aim_pitch,
		}, delta)


func receive_snapshot(snapshot: Dictionary, scoreboard: Array) -> void:
	for raw_peer_id in snapshot:
		var peer_id := int(raw_peer_id)
		if not game_server.players.has(peer_id):
			continue
		var player = game_server.players[peer_id]
		var player_snapshot := Dictionary(snapshot[raw_peer_id])
		player.apply_snapshot(player_snapshot)
		if peer_id == local_peer_id:
			desired_weapon = player.state.selected_weapon
			hud.set_player_state(
				player.state,
				weapon_system.get_weapon_name(player.state.selected_weapon),
				float(player_snapshot.get("respawn_remaining", 0.0))
			)
	receive_scoreboard(scoreboard)


func receive_scoreboard(scoreboard: Array) -> void:
	hud.set_scoreboard(scoreboard)


func present_weapon_effect(effect: Dictionary) -> void:
	effects.show_weapon_effect(effect)


func receive_elimination(message: String) -> void:
	hud.add_kill_message(message)


func receive_rejection(message: String) -> void:
	hud.set_connection_status(message)


func _update_weapon_selection() -> void:
	if Input.is_action_just_pressed("weapon_1"):
		desired_weapon = 0
	elif Input.is_action_just_pressed("weapon_2"):
		desired_weapon = 1
	elif Input.is_action_just_pressed("weapon_3"):
		desired_weapon = 2
	elif Input.is_action_just_pressed("weapon_4"):
		desired_weapon = 3
	elif Input.is_action_just_pressed("next_weapon"):
		desired_weapon = _cycle_weapon(1)
	elif Input.is_action_just_pressed("previous_weapon"):
		desired_weapon = _cycle_weapon(-1)


func _cycle_weapon(direction: int) -> int:
	if local_player == null:
		return desired_weapon
	for offset in range(1, 5):
		var candidate := posmod(desired_weapon + direction * offset, 4)
		if bool(local_player.state.owned_weapons.get(candidate, false)):
			return candidate
	return desired_weapon
